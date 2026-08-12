;;; services-discovery.el --- Load services from SSoT or generated file -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.


;;; Commentary:
;; This module provides service discovery for the dashboard, SLIME connections,
;; and other Emacs integrations.
;;
;; It can load services from either:
;;   1. services-generated.el (fast, pre-generated)
;;   2. services.json (legacy, runtime parsing)
;;   3. services.sexp (SSoT, runtime parsing - for development)
;;
;; The SSoT (services.sexp) generates all config files including docker-compose.yml
;; and MCP configs. Run (skewed-generate-all-configs) after editing services.sexp.

;;; Code:

(require 'cl-lib)

(defvar skewed-services-base-dir nil
  "Base directory for skewed-emacs - computed at load time.")

(defvar skewed-discovery-script-dir 
  (let ((this-file (or load-file-name buffer-file-name)))
    (and this-file (file-name-directory this-file)))
  "Directory where services-discovery.el resides.")

(let* ((this-dir skewed-discovery-script-dir)
       ;; Root is 4 levels up: etc/ -> emacs.d/ -> dot-files/ -> ROOT/
       (derived-root (and this-dir (expand-file-name "../../../../" this-dir)))
       (env-clone-path (getenv "SKEWED_CLONE_PATH"))
       (candidates (list env-clone-path
                         derived-root
                         (expand-file-name "../.." (file-truename user-emacs-directory))
                         "/projects/skewed-emacs/")))
  (setq skewed-services-base-dir
        (seq-find (lambda (dir) (and dir (file-directory-p dir))) candidates)))

(defvar skewed-services-config nil
  "Cached services configuration.")

(defvar skewed-services-cache-time nil
  "Time when services config was last loaded.")

(defvar skewed-services-cache-signature nil
  "Signature of the service config inputs used for the current cache.")

(defvar skewed-services-cache-timeout 60
  "Seconds before reloading services config.")

;;; ============================================================================
;;; Merge Helpers
;;; ============================================================================

(defun skewed--plist-merge (base overlay)
  "Return a copy of BASE with OVERLAY's keys merged in (overlay wins)."
  (let ((result (copy-sequence base)))
    (cl-loop for (key val) on overlay by #'cddr
             do (setq result (plist-put result key val)))
    result))

(defun skewed--merge-services-by-name (services)
  "Merge SERVICES by :name, preserving first-seen order.
Later entries merge key-wise into earlier ones -- keys present in a
later (overlay) entry win, keys it omits are inherited.  This mirrors
docker compose multi-file merge semantics, so sparse overlay entries
augment rather than clobber the base definition."
  (let ((table (make-hash-table :test 'equal))
        (order '()))
    (dolist (svc services)
      (let* ((name (plist-get svc :name))
             (existing (gethash name table)))
        (unless existing
          (push name order))
        (puthash name
                 (if existing (skewed--plist-merge existing svc) svc)
                 table)))
    (mapcar (lambda (name) (gethash name table)) (nreverse order))))

(defun skewed--generated-service-files ()
  "Return generated service files in deterministic merge order."
  (let* ((generated-dir (or skewed-discovery-script-dir 
                           (expand-file-name "dot-files/emacs.d/etc/" skewed-services-base-dir)))
         (base-file (expand-file-name "services-generated.el" generated-dir))
         (overlay-files (when (file-directory-p generated-dir)
                          (sort (directory-files generated-dir t
                                                 ".*-services-generated\\.el$")
                                #'string-lessp))))
    (append (when (file-exists-p base-file) (list base-file))
            overlay-files)))

(defun skewed--services-source-signature ()
  "Return a signature for the current service config inputs."
  (let* ((generated-files (skewed--generated-service-files))
         (json-file (expand-file-name "services.json" skewed-services-base-dir)))
    (append
     (mapcar (lambda (file)
               (list file
                     (file-attribute-modification-time
                      (file-attributes file))))
             generated-files)
     (when (file-exists-p json-file)
       (list (list json-file
                   (file-attribute-modification-time
                    (file-attributes json-file))))))))

;;; ============================================================================
;;; Loading from Generated File (preferred)
;;; ============================================================================

(defun skewed--load-from-generated ()
  "Load services from pre-generated elisp file."
  (let ((services '()))
    (dolist (service-file (skewed--generated-service-files))
      ;; Each generated file resets `skewed-generated-services`, so accumulate
      ;; after every load and merge once at the end.
      (load service-file t t)
      (when (boundp 'skewed-generated-services)
        (setq services (append services skewed-generated-services))))
    (when services
      (setq services (skewed--merge-services-by-name services))
      (setq skewed-generated-services services)
      services)))

;;; ============================================================================
;;; Loading from JSON (legacy fallback)
;;; ============================================================================

(defun skewed--load-from-json ()
  "Load services from services.json (legacy format)."
  (require 'json)
  (let ((json-file (expand-file-name "services.json" skewed-services-base-dir)))
    (when (file-exists-p json-file)
      (with-temp-buffer
        (insert-file-contents json-file)
        (goto-char (point-min))
        (let* ((config (json-parse-buffer :object-type 'plist :array-type 'list))
               (services-plist (plist-get config :services))
               (result '()))
          (cl-loop for (name props) on services-plist by #'cddr
                   do (let* ((name-str (if (keywordp name)
                                           (substring (symbol-name name) 1)
                                         (format "%s" name)))
                             (ports (plist-get props :ports))
                             (http-ports (plist-get ports :http))
                             (swank-ports (plist-get ports :swank))
                             (service-plist
                              (list :name name-str
                                    :type (plist-get props :type)
                                    :lisp-impl (or (plist-get props :lisp_impl)
                                                   (plist-get props :lisp-impl)
                                                   "Unknown"))))
                        (when http-ports
                          (setq service-plist
                                (plist-put service-plist :http-host name-str))
                          (setq service-plist
                                (plist-put service-plist :http-port
                                           (plist-get http-ports :container)))
                          (setq service-plist
                                (plist-put service-plist :http-host-port
                                           (plist-get http-ports :host))))
                        (when swank-ports
                          (setq service-plist
                                (plist-put service-plist :swank-host name-str))
                          (setq service-plist
                                (plist-put service-plist :swank-port
                                           (plist-get swank-ports :container)))
                          (setq service-plist
                                (plist-put service-plist :swank-host-port
                                           (plist-get swank-ports :host))))
                        (push service-plist result)))
          (nreverse result))))))

;;; ============================================================================
;;; Main API
;;; ============================================================================

(defun skewed--load-services ()
  "Load services from best available source."
  (or (skewed--load-from-generated)
      (skewed--load-from-json)
      ;; Ultimate fallback
      '((:name "skewed-emacs" :type "emacs-lisp" :http-host "localhost" :http-port 7080)
        (:name "gendl-ccl" :type "common-lisp" :http-host "localhost" :http-port 9080))))

(defun skewed-get-services-config ()
  "Get services config, reloading if cache expired."
  (let ((now (float-time))
        (signature (skewed--services-source-signature)))
    (when (or (null skewed-services-config)
              (null skewed-services-cache-time)
              (not (equal signature skewed-services-cache-signature))
              (> (- now skewed-services-cache-time) skewed-services-cache-timeout))
      (setq skewed-services-config (skewed--load-services))
      (setq skewed-services-cache-time now)
      (setq skewed-services-cache-signature signature)))
  skewed-services-config)

(defun skewed-get-services ()
  "Return list of all configured services."
  (skewed-get-services-config))

(defun skewed-get-lisply-backends ()
  "Return services suitable for lisply backend display.
Includes Lisp runtimes and any service explicitly marked :mcp t."
  (seq-filter (lambda (svc)
                (or (member (plist-get svc :type) '("emacs-lisp" "common-lisp"))
                    (plist-get svc :mcp)))
              (skewed-get-services)))

(defun skewed-get-swank-services ()
  "Return services with SWANK ports configured."
  (seq-filter (lambda (svc) (plist-get svc :swank-port))
              (skewed-get-services)))

(defun skewed-reload-services ()
  "Force reload of services configuration."
  (interactive)
  (setq skewed-services-config nil)
  (setq skewed-services-cache-time nil)
  (setq skewed-services-cache-signature nil)
  (message "Reloaded %d services" (length (skewed-get-services))))

;;; ============================================================================
;;; Dashboard Integration (compatibility layer)
;;; ============================================================================

(defun discover-network-lisply-backends ()
  "Return lisply backends for dashboard display.
Returns list of plists with :host, :port, :name."
  (mapcar (lambda (svc)
            (list :host (plist-get svc :http-host)
                  :port (plist-get svc :http-port)
                  :name (plist-get svc :name)))
          (skewed-get-lisply-backends)))

(defun discover-swank-services ()
  "Return SWANK services for dashboard display.
Returns list of plists with :host, :port, :name, :icon."
  (mapcar (lambda (svc)
            (let ((impl (or (plist-get svc :lisp-impl) "")))
              (list :host (plist-get svc :swank-host)
                    :port (plist-get svc :swank-port)
                    :name (plist-get svc :name)
                    :icon (cond
                           ((string-match-p "CCL" impl) :svc-ccl)
                           ((string-match-p "SBCL" impl) :svc-sbcl)
                           ((string-match-p "LispWorks" impl) :svc-lispworks)
                           ((string-match-p "AllegroCL" impl)
                            (if (string-match-p "SMP" impl) :svc-smp :svc-commercial))
                           (t :svc-lisp)))))
          (skewed-get-swank-services)))

(provide 'services-discovery)
;;; services-discovery.el ends here
