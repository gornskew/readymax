;;; lisply-config.el --- Enablement glue for the Lisply MCP backend -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Genworks
;; SPDX-License-Identifier: AGPL-3.0-or-later

;;; Commentary:
;; Wires the sideloaded lisply-backend (an HTTP server that evaluates arbitrary
;; Emacs Lisp) into skewed-emacs, and decides WHETHER and HOW to start it:
;;
;;   * In a container (SKEWED_EMACS_CONTAINER set): start on 0.0.0.0, honoring
;;     START_HTTP, exactly as before.  The container is the sandbox.
;;
;;   * On a host Emacs: OFF by default.  Starting the server here hands an LLM
;;     the ability to run arbitrary code on your machine (see the warning in
;;     `lisply--risk-warning').  Opt in with `M-x lisply-enable-host-server'
;;     (interactive, gated) or by setting `lisply-host-server-enable' (e.g. via
;;     `./setup --with-mcp').  Host binds to loopback by default.
;;
;; See docs/HOST_EMACS_MCP.md for the full story and how to connect a client.

;;; Code:

(defconst lisply--backend-source-dir
  (if (boundp 'emacs-config-directory)
      (concat emacs-config-directory "sideloaded/lisply-backend/source/")
    (expand-file-name
     "../sideloaded/lisply-backend/source/"
     (file-name-directory (or load-file-name buffer-file-name default-directory))))
  "Directory holding the lisply-backend elisp sources.")

(add-to-list 'load-path lisply--backend-source-dir)

(defgroup lisply-host nil
  "Host-side enablement of the Lisply MCP backend."
  :group 'emacs-lisply)

(defcustom lisply-host-server-enable nil
  "If non-nil, auto-start the Lisply MCP server in a *host* (non-container) Emacs.
Off by default.  Enabling this lets any MCP client that can reach the server
evaluate arbitrary Emacs Lisp in this Emacs -- i.e. run arbitrary code on this
machine with your privileges.  Prefer `M-x lisply-enable-host-server' for a
one-off; set this (e.g. via \"./setup --with-mcp\") for automatic startup."
  :type 'boolean :group 'lisply-host)

(defcustom lisply-host-server-risk-acknowledged nil
  "Non-nil means the arbitrary-code-execution risk has been acknowledged.
When nil, `lisply-enable-host-server' asks for interactive confirmation first.
\"./setup --with-mcp\" sets this (after its own terminal confirmation) so that
unattended daemon startup does not block on a prompt."
  :type 'boolean :group 'lisply-host)

(defcustom lisply-host-server-bind-address "127.0.0.1"
  "Address the *host* Lisply server binds to.
Loopback by default so it is not reachable from other machines.  Change only if
you understand that a routable address exposes arbitrary code execution to your
network."
  :type 'string :group 'lisply-host)

(defconst lisply--risk-warning
  "============================ SECURITY WARNING ============================
Starting the Lisply server on this HOST Emacs opens an HTTP endpoint that
evaluates arbitrary Emacs Lisp sent by any MCP client that can reach it.
Because Emacs Lisp can read/write your files, run shell commands, and drive
your desktop, this effectively grants an LLM FULL ACCESS TO THIS MACHINE with
your user privileges -- comparable to letting an autonomous agent operate your
computer directly.

The container path (./compose-dev up) sandboxes this; the host path does NOT.
Only proceed on a machine/account where that trade-off is acceptable, and keep
the bind address on loopback (127.0.0.1) unless you have a specific reason not
to.
========================================================================="
  "Text shown before starting the host Lisply server.")

(defun lisply--load-backend ()
  "Ensure `simple-httpd' is available and load the lisply-backend sources."
  (unless (require 'simple-httpd nil t)
    (when (and (fboundp 'package-installed-p)
               (not (package-installed-p 'simple-httpd)))
      (package-refresh-contents)
      (package-install 'simple-httpd))
    (require 'simple-httpd))
  (load "http-setup")
  (load "endpoints"))

(defun lisply--connection-hint ()
  "Return a human-readable hint for connecting an MCP client to the host server."
  (format (concat "Lisply host server listening on %s:%d.  Point an MCP client at it, e.g.:\n"
                  "  node /path/to/lisply-mcp/scripts/mcp-wrapper.js \\\n"
                  "    --server-name emacs-host \\\n"
                  "    --backend-host %s --http-host-port %d")
          lisply-host-server-bind-address emacs-lisply-port
          lisply-host-server-bind-address emacs-lisply-port))

;;;###autoload
(defun lisply-enable-host-server (&optional no-confirm)
  "Start the Lisply MCP server in this (host) Emacs, after a security check.
Interactively, prompt with `lisply--risk-warning' unless the risk has already
been acknowledged via `lisply-host-server-risk-acknowledged'.  With optional
NO-CONFIRM non-nil (used by unattended startup once the risk is acknowledged),
skip the prompt.  Binds to `lisply-host-server-bind-address'."
  (interactive)
  (lisply--load-backend)
  (unless (or no-confirm lisply-host-server-risk-acknowledged)
    (unless (yes-or-no-p
             (concat lisply--risk-warning "\n\nStart the Lisply host server anyway? "))
      (user-error "Lisply host server not started"))
    (setq lisply-host-server-risk-acknowledged t)
    (when (and (called-interactively-p 'interactive)
               (y-or-n-p "Remember this acknowledgment across sessions? "))
      (customize-save-variable 'lisply-host-server-risk-acknowledged t)))
  (setq httpd-host lisply-host-server-bind-address)
  (emacs-lisply-start-server)
  (message "%s" (lisply--connection-hint)))

(defun lisply-maybe-autostart ()
  "Start the Lisply server appropriately for the current environment.
Container: start on 0.0.0.0 honoring START_HTTP (unchanged behavior).
Host: start only when `lisply-host-server-enable' is set, gated on the
acknowledgment, bound to loopback.  Does nothing during a Docker build."
  (cond
   ((bound-and-true-p skewed-emacs-docker-build?) nil)
   ((getenv "SKEWED_EMACS_CONTAINER")
    (unless (string= (getenv "START_HTTP") "false")
      (lisply--load-backend)
      (setq httpd-host "0.0.0.0")
      (emacs-lisply-start-server)
      (message "Lisply server started on 0.0.0.0:%d (container)" emacs-lisply-port)))
   (lisply-host-server-enable
    (cond
     (lisply-host-server-risk-acknowledged
      (lisply-enable-host-server t))
     (noninteractive
      (message (concat "lisply-host-server-enable is set but the risk is not "
                       "acknowledged; not starting.  Run M-x lisply-enable-host-server "
                       "or set lisply-host-server-risk-acknowledged.")))
     (t (lisply-enable-host-server))))))

(provide 'lisply-config)
;;; lisply-config.el ends here
