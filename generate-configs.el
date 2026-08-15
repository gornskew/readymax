;;; generate-configs.el --- Generate configs from services.sexp -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;;
;;; Usage: (load "/projects/skewed-emacs/generate-configs.el")
;;;        (skewed-generate-all-configs)
;;;
;;; Or from command line:
;;;   emacs --batch -l generate-configs.el -f skewed-generate-all-configs
;;;
;;; For overlays (non-skewed-emacs directories), also generates install script.
;;;
;;; This generator reads ONE services.sexp and outputs configs.
;;; Overlay behavior is handled at runtime:
;;;   - Docker Compose: native multi-file merge (-f base.yml -f overlay.yml)
;;;   - MCP configs: merged at startup via mcp/merge-configs.sh
;;;   - Install script: auto-generated for overlays (non-empty prefix);;; This generator reads ONE services.sexp and outputs configs.
;;; Overlay behavior is handled at runtime:
;;;   - Docker Compose: native multi-file merge (-f base.yml -f overlay.yml)
;;;   - MCP configs: merged at startup via mcp/merge-configs.sh

;;; Code:

(require 'cl-lib)
(require 'json)

(defvar skewed-gen-input-file nil
  "Input services.sexp file. Set before calling generator.")

(defvar skewed-gen-output-dir nil
  "Output directory for generated files. Set before calling generator.")

(defvar skewed-gen-output-prefix ""
  "Prefix for output filenames (e.g. 'betatest-' for overlay configs).")

;;; ============================================================================
;;; Reading and Parsing
;;; ============================================================================

(defun skewed--read-sexp-file (filepath)
  "Read and parse a .sexp file, returning the plist."
  (when (file-exists-p filepath)
    (with-temp-buffer
      (insert-file-contents filepath)
      (goto-char (point-min))
      (read (current-buffer)))))

(defun skewed--get-prop (plist key)
  "Get property KEY from PLIST."
  (plist-get plist key))

(defun skewed--has-mcp-services-p (config)
  "Return non-nil if CONFIG has at least one service with :mcp t."
  (cl-some (lambda (svc) (skewed--get-prop svc :mcp))
           (skewed--get-prop config :services)))

(defun skewed--mcp-approved-tools (_svc)
  "Return the standard tool names that should be pre-approved for an MCP service."
  '("ping_lisp" "http_request" "lisp_eval"))

;;; ============================================================================
;;; skewed_search Config Generation
;;; ============================================================================


;;; ============================================================================
;;; Docker Compose Generation
;;; ============================================================================

(defun skewed--generate-compose-yaml (config)
  "Generate docker-compose.yml content from CONFIG."
  (let* ((defaults (skewed--get-prop config :defaults))
         (services (skewed--get-prop config :services))
         (network-name (or (skewed--get-prop defaults :network) "skewed-network"))
         (lines '()))
    
    ;; Header
    (push "# DO NOT EDIT - Generated from services.sexp" lines)
    (push "# Regenerate with: (skewed-generate-all-configs)" lines)
    (push "" lines)
    
    ;; Only include networks block for base config (no prefix)
    (when (string-empty-p skewed-gen-output-prefix)
      (let ((ipv6        (skewed--get-prop defaults :network-ipv6))
            (ipv4-subnet (skewed--get-prop defaults :network-ipv4-subnet))
            (ipv6-subnet (skewed--get-prop defaults :network-ipv6-subnet)))
        (push "networks:" lines)
        (push "  skewed-network:" lines)
        (push (format "    name: ${DOCKER_NETWORK_NAME:-%s}" network-name) lines)
        (push "    driver: bridge" lines)
        (when ipv6
          (push "    enable_ipv6: true" lines)
          (when (or ipv4-subnet ipv6-subnet)
            (push "    ipam:" lines)
            (push "      config:" lines)
            (when ipv4-subnet
              (push (format "        - subnet: \"%s\"" ipv4-subnet) lines))
            (when ipv6-subnet
              (push (format "        - subnet: \"%s\"" ipv6-subnet) lines))))
        (push "" lines)))

    
    (push "services:" lines)
    (push "" lines)
    
    ;; Services
    (dolist (svc services)
      (let* ((name (skewed--get-prop svc :name))
             (image (skewed--get-prop svc :image))
             (ports (skewed--get-prop svc :ports))
             (env (skewed--get-prop svc :environment))
             (vols (skewed--get-prop svc :volumes))
             (user (skewed--get-prop svc :user))
             (network-mode (skewed--get-prop svc :network-mode))
             (extra-hosts (skewed--get-prop svc :extra-hosts))
             (group-add (skewed--get-prop svc :group-add))
             (healthcheck (skewed--get-prop svc :healthcheck))
             (env-file (skewed--get-prop svc :env-file))
             (restart (or (skewed--get-prop svc :restart)
                          (skewed--get-prop defaults :restart)
                          "unless-stopped")))
        
        (push (format "  %s:" name) lines)
        (when image
          (push (format "    image: %s" image) lines))
        (push (format "    container_name: %s" name) lines)
        (push (format "    hostname: %s" name) lines)
        (when user (push (format "    user: %s" user) lines))
        (push (format "    restart: %s" restart) lines)
        (push "    stdin_open: true" lines)
        (push "    tty: true" lines)
        (when network-mode
          (push (format "    network_mode: %s" network-mode) lines))
        
        ;; Ports
        (unless network-mode
          (let ((ports-with-host (cl-remove-if-not (lambda (p) (skewed--get-prop p :host)) ports)))
            (when ports-with-host
              (push "    ports:" lines)
              (dolist (port ports-with-host)
                (let ((container (skewed--get-prop port :container))
                      (host (skewed--get-prop port :host)))
                  (push (format "      - \"%s:%s\"" host container) lines))))))
        
        ;; Environment
        (push "    environment:" lines)
        (dolist (port ports)
          (let ((port-name (upcase (skewed--get-prop port :name)))
                (container (skewed--get-prop port :container))
                (host (skewed--get-prop port :host)))
            (when (equal port-name "HTTP")
              (push (format "      - HTTP_PORT=%s" container) lines)
              (when host
                (push (format "      - HTTP_HOST_PORT=%s" host) lines))
              (push "      - START_HTTP=true" lines))
            (when (equal port-name "SWANK")
              (push (format "      - SWANK_PORT=%s" container) lines)
              (when host
                (push (format "      - SWANK_HOST_PORT=%s" host) lines))
              (push "      - START_SWANK=true" lines))))
        (dolist (env-pair env)
          ;; Quote the whole NAME=VALUE as a YAML single-quoted scalar.
          ;; Unquoted values with a trailing colon (e.g. HTTP_HOST=::)
          ;; parse as YAML mappings and break docker compose validation.
          (push (format "      - '%s=%s'"
                        (car env-pair)
                        (replace-regexp-in-string "'" "''"
                                                  (format "%s" (cdr env-pair))))
                lines))
        (push (format "      - TZ=%s" (or (skewed--get-prop defaults :timezone) "${TZ:-Etc/UTC}")) lines)

        ;; env_file (long-form, required:false) -- lets a service read
        ;; secrets from an uncommitted per-host file without breaking
        ;; startup when the file is absent (default-secure).  Each spec is
        ;; a string PATH (required) or a plist (:path P :required BOOL).
        (when env-file
          (push "    env_file:" lines)
          (dolist (spec (cond ((stringp env-file) (list env-file))
                              ((keywordp (car env-file)) (list env-file))
                              (t env-file)))
            (let ((path (if (stringp spec) spec (skewed--get-prop spec :path)))
                  (required (if (stringp spec) t (skewed--get-prop spec :required))))
              (push (format "      - path: %s" path) lines)
              (push (format "        required: %s" (if required "true" "false")) lines))))
        
        ;; Volumes
        (let ((default-vols (skewed--get-prop defaults :volumes))
              (svc-vols vols))
          (push "    volumes:" lines)
          (dolist (vol default-vols)
            (let ((src (skewed--get-prop vol :source))
                  (tgt (skewed--get-prop vol :target)))
              (push "      - type: bind" lines)
              (push (format "        source: %s" src) lines)
              (push (format "        target: %s" tgt) lines)
              (push "        bind:" lines)
              (push "          create_host_path: true" lines)))
          (dolist (vol svc-vols)
            (let ((src (skewed--get-prop vol :source))
                  (tgt (skewed--get-prop vol :target))
                  (mode (skewed--get-prop vol :mode)))
              (if mode
                  (push (format "      - %s:%s:%s" src tgt mode) lines)
                (push (format "      - %s:%s" src tgt) lines)))))
        
        ;; Extra hosts
        (when (and extra-hosts (not network-mode))
          (push "    extra_hosts:" lines)
          (dolist (host-pair extra-hosts)
            (push (format "      - \"%s:%s\"" (car host-pair) (cdr host-pair)) lines)))
        
        ;; Group add
        (when group-add
          (push "    group_add:" lines)
          (dolist (grp group-add)
            (push (format "      - \"%s\"" grp) lines)))
        
        ;; Ulimits
        (let ((ulimits (skewed--get-prop svc :ulimits)))
          (when ulimits
            (push "    ulimits:" lines)
            (dolist (ul ulimits)
              (let* ((resource (let* ((raw (symbol-name (skewed--get-prop ul :resource)))
                       (stripped (if (string-prefix-p ":" raw) (substring raw 1) raw)))
                  (downcase stripped)))
                     (soft (skewed--get-prop ul :soft))
                     (hard (skewed--get-prop ul :hard)))
                (push (format "      %s:" resource) lines)
                (when soft (push (format "        soft: %s" soft) lines))
                (when hard (push (format "        hard: %s" hard) lines))))))

                ;; Networks
        (unless network-mode
          (push "    networks:" lines)
          (push "      - skewed-network" lines))
        
        ;; Healthcheck
        (when healthcheck
          (let ((endpoint (skewed--get-prop healthcheck :endpoint))
                (interval (or (skewed--get-prop healthcheck :interval) "60s"))
                (http-port (skewed--get-prop
                            (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                            :container)))
            (push "    healthcheck:" lines)
            (push (format "      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:%s%s\"]"
                          (or http-port 80) endpoint) lines)
            (push (format "      interval: %s" interval) lines)
            (push "      timeout: 3s" lines)
            (push "      retries: 3" lines)
            (push "      start_period: 15s" lines)))
        
        (push "" lines)))
    
    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; MCP Config Generation  
;;; ============================================================================

(defun skewed--generate-mcp-json-container (config)
  "Generate MCP config for in-container usage (claude/gemini CLI)."
  (let* ((mcp-config (skewed--get-prop config :mcp))
         (wrapper-path (skewed--get-prop mcp-config :wrapper-path-container))
         (request-timeout (skewed--get-prop mcp-config :request-timeout-ms))
         (services (skewed--get-prop config :services))
         (servers '()))

    (dolist (svc services)
      (when (skewed--get-prop svc :mcp)
        (let* ((name (skewed--get-prop svc :name))
               (ports (skewed--get-prop svc :ports))
               (http-port (skewed--get-prop
                           (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                           :container))
               (args (list wrapper-path
                           "--server-name" name
                           "--backend-host" name
                           "--http-port" (number-to-string http-port))))
          (when request-timeout
            (setq args (append args (list "--request-timeout-ms"
                                          (number-to-string request-timeout)))))
          (push (cons name `((command . "node")
                             (args . ,(vconcat args))))
                servers))))

    (let ((json-encoding-pretty-print t))
      (json-encode (list (cons 'mcpServers (nreverse servers)))))))

(defun skewed--generate-mcp-json-windows (config)
  "Generate MCP config for Windows Claude Desktop via WSL.
Uses placeholder ${SKEWED_CLONE_PATH} which gets substituted at merge time."
  (let* ((exec-path "${SKEWED_CLONE_PATH}/mcp/mcp-exec")
         (request-timeout (skewed--get-prop (skewed--get-prop config :mcp) :request-timeout-ms))
         (services (skewed--get-prop config :services))
         (servers '()))

    (dolist (svc services)
      (when (skewed--get-prop svc :mcp)
        (let* ((name (skewed--get-prop svc :name))
               (ports (skewed--get-prop svc :ports))
               (http-port (skewed--get-prop
                           (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                           :container))
               (args (list exec-path
                           "--server-name" name
                           "--backend-host" name
                           "--http-port" (number-to-string http-port))))
          (when request-timeout
            (setq args (append args (list "--request-timeout-ms"
                                          (number-to-string request-timeout)))))
          (push (cons name `((command . "wsl")
                             (args . ,(vconcat args))))
                servers))))

    (let ((json-encoding-pretty-print t))
      (json-encode (list (cons 'mcpServers (nreverse servers))
                         (cons 'globalShortcut ""))))))

(defun skewed--generate-mcp-toml (config)
  "Generate MCP config in TOML format for Codex and Grok.
Codex also gets nested tool-approval tables; Grok's merge step
filters those out and keeps only top-level [mcp_servers.NAME] tables."
  (let* ((mcp-config (skewed--get-prop config :mcp))
         (wrapper-path (skewed--get-prop mcp-config :wrapper-path-container))
         (request-timeout (skewed--get-prop mcp-config :request-timeout-ms))
         (services (skewed--get-prop config :services))
         (lines '()))
    
    (dolist (svc services)
      (when (skewed--get-prop svc :mcp)
        (let* ((name (skewed--get-prop svc :name))
               (ports (skewed--get-prop svc :ports))
               (http-port (skewed--get-prop
                           (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports)
                           :container)))
          (push (format "[mcp_servers.%s]" name) lines)
          (push "command = \"node\"" lines)
          (let ((args (list wrapper-path "--server-name" name
                            "--backend-host" name "--http-port" (number-to-string http-port))))
            (when request-timeout
              (setq args (append args (list "--request-timeout-ms"
                                            (number-to-string request-timeout)))))
            (push (format "args = [%s]"
                          (mapconcat (lambda (arg) (format "\"%s\"" arg)) args ", "))
                  lines))
          (dolist (tool-name (skewed--mcp-approved-tools svc))
            (push "" lines)
            (push (format "[mcp_servers.%s.tools.%s__%s]"
                          name name tool-name)
                  lines)
            (push "approval_mode = \"approve\"" lines))
          (push "" lines))))
    
    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; Services Discovery (Elisp) Generation
;;; ============================================================================

(defun skewed--generate-elisp (config)
  "Generate services-generated.el for Emacs dashboard."
  (let* ((services (skewed--get-prop config :services))
         (lines '()))
    
    (push ";;; services-generated.el --- Generated from services.sexp -*- lexical-binding: t; -*-" lines)
    ;; The header is EMITTED, not hand-added.  It was hand-added before
    ;; 2026-08-15 and every regeneration silently stripped it again --
    ;; harmless while regenerating was rare, not harmless now that symbolic
    ;; rosters make it routine, in a repo whose sibling products ship closed.
    (push "" lines)
    (push ";; Copyright © 2026 Gornskew Enterprises" lines)
    (push ";;" lines)
    (push ";; The software, data and information contained herein are proprietary" lines)
    (push ";; to, and comprise valuable trade secrets of, Gornskew Enterprises." lines)
    (push ";; They may be stored and used only in accordance with a written" lines)
    (push ";; license agreement from Gornskew Enterprises, and may not be" lines)
    (push ";; redistributed." lines)
    (push "" lines)
    (push ";;; DO NOT EDIT - Regenerate with: (skewed-generate-all-configs)" lines)
    (push "" lines)
    (push "(defvar skewed-generated-services nil)" lines)
    (push "(setq skewed-generated-services" lines)
    (push "  '(" lines)
    
    (dolist (svc services)
      (let* ((name (skewed--get-prop svc :name))
             (type (skewed--get-prop svc :type))
             (lisp-impl (skewed--get-prop svc :lisp-impl))
             (mcp (skewed--get-prop svc :mcp))
             (ports (skewed--get-prop svc :ports))
             (http-port (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "http")) ports))
             (swank-port (cl-find-if (lambda (p) (equal (skewed--get-prop p :name) "swank")) ports)))
        (push (format "    (:name \"%s\"" name) lines)
        (when type
          (push (format "     :type \"%s\"" type) lines))
        (when lisp-impl
          (push (format "     :lisp-impl \"%s\"" lisp-impl) lines))
        (when mcp
          (push "     :mcp t" lines))
        (when http-port
          (push (format "     :http-host \"%s\"" name) lines)
          (push (format "     :http-port %s" (skewed--get-prop http-port :container)) lines)
          (when (skewed--get-prop http-port :host)
            (push (format "     :http-host-port %s" (skewed--get-prop http-port :host)) lines)))
        (when swank-port
          (push (format "     :swank-host \"%s\"" name) lines)
          (push (format "     :swank-port %s" (skewed--get-prop swank-port :container)) lines)
          (when (skewed--get-prop swank-port :host)
            (push (format "     :swank-host-port %s" (skewed--get-prop swank-port :host)) lines)))
        (push "    )" lines)))
    
    (push "   ))" lines)
    (push ";; Services configuration generated from services.sexp." lines)
    (push "" lines)
    (push "(provide 'services-generated)" lines)
    (push ";;; services-generated.el ends here" lines)
    
    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; Main Entry Points
;;; ============================================================================
;;; Install Script Generation (for overlays only)
;;; ============================================================================

(defun skewed--generate-install-script (prefix &optional has-mcp)
  "Generate install script for overlay or base repository with PREFIX.
When PREFIX is empty, generates a base install (copies docker-compose.yml).
When HAS-MCP is non-nil, include MCP config copy commands.
Returns the install script content as a string."
  (let ((lines '())
        (is-base (string-empty-p prefix))
        (label (if (string-empty-p prefix) "base config" 
                 (string-trim-right prefix "-"))))
    (push "#!/bin/bash" lines)
    (push "#" lines)
    (push (format "# Install script for %s" label) lines)
    (push "#" lines)
    (push "# This copies pre-generated configs to skewed-emacs." lines)
    (push "# Docker Compose will automatically merge the .yml files." lines)
    (push "# MCP configs are merged automatically by compose-dev up." lines)
    (push "" lines)
    (push "set -e" lines)
    (push "" lines)
    (push "SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"" lines)
    (push "TARGET_DIR=\"$SCRIPT_DIR/../skewed-emacs\"" lines)
    (push "" lines)
    (push (format "echo \"Installing %s...\"" label) lines)
    (push "echo \"\"" lines)
    (push "" lines)
    (push "# Check if target directory exists" lines)
    (push "if [ ! -d \"$TARGET_DIR\" ]; then" lines)
    (push "    echo \"Error: Target directory $TARGET_DIR does not exist\"" lines)
    (push "    echo \"Please clone skewed-emacs first.\"" lines)
    (push "    exit 1" lines)
    (push "fi" lines)
    (push "" lines)

    ;; Compose file copy
    (if is-base
        (progn
          (push "# Copy base compose (replaces skewed-emacs default)" lines)
          (push "echo \"Installing docker-compose.yml (base with networks)...\"" lines)
          (push "cp \"$SCRIPT_DIR/docker-compose.yml\" \"$TARGET_DIR/docker-compose.yml\"" lines))
      (push "# Copy compose overlay" lines)
      (push (format "echo \"Installing %scompose.yml...\"" prefix) lines)
      (push (format "cp \"$SCRIPT_DIR/%scompose.yml\" \"$TARGET_DIR/\"" prefix) lines))
    (push "" lines)

    ;; MCP configs
    (when has-mcp
      (push "# Copy MCP configs" lines)
      (push "echo \"Installing MCP configs...\"" lines)
      (push "mkdir -p \"$TARGET_DIR/mcp\"" lines)
      (if is-base
          (progn
            (push "for f in \"$SCRIPT_DIR/mcp/\"*.json \"$SCRIPT_DIR/mcp/\"*.toml; do" lines)
            (push "    [ -f \"$f\" ] && cp \"$f\" \"$TARGET_DIR/mcp/\"" lines)
            (push "done" lines))
        (push (format "cp \"$SCRIPT_DIR/mcp/%smcp-container.json\" \"$TARGET_DIR/mcp/\"" prefix) lines)
        (push (format "cp \"$SCRIPT_DIR/mcp/%smcp-windows.json\" \"$TARGET_DIR/mcp/\"" prefix) lines)
        (push (format "cp \"$SCRIPT_DIR/mcp/%smcp.toml\" \"$TARGET_DIR/mcp/\"" prefix) lines))
      (push "" lines))

    ;; Services discovery
    (push "# Copy services discovery (dashboard + swank)" lines)
    (push "echo \"Installing services discovery...\"" lines)
    (push "mkdir -p \"$TARGET_DIR/dot-files/emacs.d/etc\"" lines)
    (if is-base
        (progn
          (push "for f in \"$SCRIPT_DIR/dot-files/emacs.d/etc/\"*services-generated.el; do" lines)
          (push "    [ -f \"$f\" ] && cp \"$f\" \"$TARGET_DIR/dot-files/emacs.d/etc/\"" lines)
          (push "done" lines))
      (push "for svc_file in \"$SCRIPT_DIR/dot-files/emacs.d/etc/\"*-services-generated.el; do" lines)
      (push "    if [ -f \"$svc_file\" ]; then" lines)
      (push "        cp \"$svc_file\" \"$TARGET_DIR/dot-files/emacs.d/etc/\"" lines)
      (push "    fi" lines)
      (push "done" lines))
    (push "" lines)

    (push "echo \"\"" lines)
    (push "echo \"Installation complete!\"" lines)
    (push "echo \"\"" lines)

    (string-join (nreverse lines) "\n")))

;;; ============================================================================
;;; SYMBOLIC ROSTERS (Basilisk fittings, 2026-08-15)
;;;
;;; A host's services.sexp may name who is aboard SYMBOLICALLY in :meta --
;;; either a coarse :crew-level or a specific :roster -- instead of restating
;;; service definitions that are identical across five stacks.  Expansion
;;; happens on the CONFIG PLIST immediately after reading, so every
;;; downstream generator (compose yaml, MCP json, elisp discovery, install
;;; script) sees ordinary :services and needs no changes at all.
;;;
;;; Level expands to roster; roster infers level.  See fittings.sexp for the
;;; catalogue and BASILISK.md for the conceit.

(defvar skewed-gen-fittings-file "/projects/skewed-emacs/fittings.sexp"
  "The Basilisk fitting catalogue: posts -> container services.")

(defun skewed--stack-short-name (dir)
  "Short stack name from DIR: /projects/narad-stack/ -> \"narad\"."
  (let ((base (file-name-nondirectory (directory-file-name dir))))
    (if (string-suffix-p "-stack" base)
        (substring base 0 (- (length base) (length "-stack")))
      base)))

(defun skewed--subst-stack (form stack)
  "Recursively replace {{STACK}} with STACK in every string in FORM.
Substitution is done at GENERATION time deliberately, so one catalogue
serves every ship without anything having to exist in .env."
  (cond ((stringp form) (replace-regexp-in-string "{{STACK}}" stack form t t))
        ((consp form) (cons (skewed--subst-stack (car form) stack)
                            (skewed--subst-stack (cdr form) stack)))
        (t form)))

(defun skewed--catalogue-post (catalogue post)
  "The catalogue entry for POST, or nil."
  (seq-find (lambda (e) (eq (plist-get e :post) post))
            (skewed--get-prop catalogue :posts)))

(defun skewed--level-roster (catalogue level)
  "The roster named by LEVEL, or nil if LEVEL is unknown."
  (let ((e (seq-find (lambda (x) (eq (plist-get x :level) level))
                     (skewed--get-prop catalogue :crew-levels))))
    (and e (plist-get e :roster))))

(defun skewed--infer-crew-level (catalogue roster)
  "Infer a crew-level from ROSTER: the highest level wholly contained in it.
Returns `:custom' when no named level fits, which is a first-class
outcome -- the scheme must keep describing ships we actually build."
  (let ((best :custom) (best-n -1))
    (dolist (e (skewed--get-prop catalogue :crew-levels))
      (let* ((lr (plist-get e :roster)) (n (length lr)))
        (when (and (> n best-n)
                   (seq-every-p (lambda (p) (memq p roster)) lr))
          (setq best (plist-get e :level) best-n n))))
    best))

(defun skewed--merge-service (base over)
  "Merge service plist OVER onto BASE; OVER's keys win."
  (let ((out (copy-sequence base)))
    (cl-loop for (k v) on over by #'cddr do (setq out (plist-put out k v)))
    out))

(defun skewed--expand-roster (config dir prefix)
  "Expand a symbolic :crew-level/:roster in CONFIG into concrete :services.
Returns CONFIG unchanged when neither is declared, so hosts still using
fully explicit :services keep working untouched."
  (let* ((meta (skewed--get-prop config :meta))
         (level (plist-get meta :crew-level))
         (declared (plist-get meta :roster)))
    (if (not (or level declared))
        config
      (let* ((catalogue (skewed--read-sexp-file skewed-gen-fittings-file))
             (stack (skewed--stack-short-name dir))
             (overlay-p (not (string-empty-p (or prefix ""))))
             (roster (or declared (skewed--level-roster catalogue level))))
        (unless catalogue
          (error "Cannot read fitting catalogue: %s" skewed-gen-fittings-file))
        (unless roster
          (error "Unknown :crew-level %s (see fittings.sexp :crew-levels)" level))
        ;; Declaring both is allowed only if they agree.  Refuse rather than
        ;; silently pick a winner: a config that lies about its own crew is
        ;; worse than one that will not build.
        (when (and level declared
                   (not (equal (sort (copy-sequence declared) #'string<)
                               (sort (copy-sequence
                                      (skewed--level-roster catalogue level))
                                     #'string<))))
          (error ":crew-level %s and :roster disagree; declare one or make them match"
                 level))
        ;; A Basilisk-class ship carries a Captain BY DEFAULT, and having
        ;; that Captain be skewed-emacs or a derived species is recommended
        ;; -- but it is a recommendation, not a class invariant (Dave,
        ;; 2026-08-15, revising the same morning's stricter reading).  A
        ;; roster of just a Pilot is a standalone Cyclops deployment; just a
        ;; ship's engineer is a standalone monolithic KBE server.  Those are
        ;; real shapes we ship, so the generator WARNS and proceeds -- the
        ;; :captain entry in the catalogue's :warnings table carries the
        ;; message, exactly like every other omission.
        (let ((expanded '()))
          (dolist (post roster)
            (let ((entry (skewed--catalogue-post catalogue post)))
              (unless entry
                (error "Unknown post %s (see fittings.sexp :posts)" post))
              ;; An overlay emits only the delta from the vanilla base: the
              ;; roster still names in-base posts, because it describes the
              ;; whole ship, but restating them here would fight the base.
              (unless (and overlay-p (plist-get entry :in-base))
                (dolist (svc (plist-get entry :services))
                  (push (skewed--subst-stack svc stack) expanded)))))
          (setq expanded (nreverse expanded))
          ;; The host's own :services are now deviation only, merged key-wise
          ;; over what expansion produced -- the same sparse-overlay
          ;; discipline already used against the base services.sexp.
          (dolist (hsvc (skewed--get-prop config :services))
            (let* ((name (plist-get hsvc :name))
                   (pos (seq-position expanded name
                                      (lambda (s n) (equal (plist-get s :name) n)))))
              (if pos
                  (setf (nth pos expanded)
                        (skewed--merge-service (nth pos expanded) hsvc))
                (setq expanded (append expanded (list hsvc))))))
          ;; Say out loud, once, what is not aboard.
          (dolist (w (skewed--get-prop catalogue :warnings))
            (unless (memq (plist-get w :post) roster)
              (message "  Note (%s): %s" stack (plist-get w :when-absent))))
          (message "  %s: crew-level %s, roster %s -> %d service(s)"
                   stack (or level (skewed--infer-crew-level catalogue roster))
                   roster (length expanded))
          (let ((out (copy-sequence config)))
            (plist-put out :services expanded)))))))

;;; EYES ONLY HEAP PROBES FROM THE ROSTER (2026-08-15)
;;;
;;; The roster is the SSoT for who is aboard, so it is also the authority on
;;; what can be PROBED.  eyes-only's *heap-probes* was hand-maintained per
;;; board, which meant a probe could name a crew member who was never aboard
;;; the ship it points at -- and an absent optional post then presents as a
;;; permanently red tile rather than as nothing at all.  That is exactly
;;; shelly's 2026-08-14 symptom.  Deriving the list from each ship's roster
;;; makes the failure impossible: no post, no probe, no tile.

(defvar skewed-gen-probe-posts '(:captain :ship-engineers :guild)
  "Posts that can yield an eyes-only heap probe, in emission order.")

(defun skewed--stack-roster (stack-dir catalogue)
  "The roster of the ship whose services.sexp lives in STACK-DIR.
Expands a declared :crew-level against CATALOGUE.  NIL when that stack
does not use symbolic rosters."
  (let* ((f (expand-file-name "services.sexp" stack-dir))
         (config (and (file-exists-p f) (skewed--read-sexp-file f)))
         (meta (and config (skewed--get-prop config :meta))))
    (when meta
      (or (plist-get meta :roster)
          (let ((level (plist-get meta :crew-level)))
            (and level (skewed--level-roster catalogue level)))))))

(defun skewed--heap-probe-entries (config dir)
  "Build the eyes-only *heap-probes* list for the board declared in CONFIG.
Returns nil unless CONFIG's :meta carries an :eyes-only-board.

Each watch entry names a :stack and either :in-stack t (this board's own
ship, sampled over the docker bridge) or an :edge URL prefix reaching that
ship's token-gated metrics.  An optional :watch narrows which posts this
board cares about; it can never widen past what the target's roster
actually carries, which is the guarantee that kills phantom tiles."
  (let* ((meta (skewed--get-prop config :meta))
         (board (plist-get meta :eyes-only-board)))
    (when board
      (let ((catalogue (skewed--read-sexp-file skewed-gen-fittings-file))
            (root (file-name-directory (directory-file-name dir)))
            (out '()))
        (dolist (w board)
          (let* ((stack (plist-get w :stack))
                 (in-stack (plist-get w :in-stack))
                 (edge (plist-get w :edge))
                 (watch (plist-get w :watch))
                 (sdir (expand-file-name (concat stack "-stack/") root))
                 (roster (skewed--stack-roster sdir catalogue)))
            (unless roster
              (error "Board watches %s, whose services.sexp declares no roster"
                     stack))
            (dolist (post skewed-gen-probe-posts)
              (when (and (memq post roster)
                         (or (null watch) (memq post watch)))
                (let* ((entry (skewed--catalogue-post catalogue post))
                       (probe (plist-get entry :probe))
                       ;; A post with no :in-stack form contributes nothing
                       ;; to its own board -- the board self-samples its own
                       ;; image for the heap gendl-ccl tile.
                       (spec (and probe (if in-stack
                                            (plist-get probe :in-stack)
                                          (plist-get probe :remote)))))
                  (when spec
                    (unless (or in-stack edge)
                      (error "Board watch for %s is off-ship but declares no :edge"
                             stack))
                    (push (list (format "%s %s" (plist-get probe :tile) stack)
                                (plist-get spec :kind)
                                (or (plist-get spec :url)
                                    (concat edge (plist-get spec :path)))
                                (plist-get spec :alert-mb))
                          out)))))
            (dolist (post skewed-gen-probe-posts)
              (when (and watch (memq post watch) (not (memq post roster)))
                (message "  Note (%s): board asks for %s, which is not aboard -- no probe emitted"
                         stack post)))))
        (nreverse out)))))

(defun skewed--generate-heap-probes-file (config dir)
  "Write eyes-only-probes-generated.lisp for a board stack, if it is one."
  (let ((probes (skewed--heap-probe-entries config dir)))
    (when probes
      (let ((file (expand-file-name "eyes-only-probes-generated.lisp" dir)))
        (with-temp-file file
          (insert ";;; eyes-only-probes-generated.lisp -*- mode: lisp -*-\n")
          (insert ";;; DO NOT EDIT -- generated from the fleet's Basilisk rosters by\n")
          (insert ";;; skewed-emacs/generate-configs.el.  Regenerate with:\n")
          (insert (format ";;;   (skewed-generate-configs \"%s\")\n" dir))
          (insert ";;;\n")
          (insert ";;; Every entry here corresponds to a post actually on the target\n")
          (insert ";;; ship's roster, so a crew member who is not aboard cannot show up\n")
          (insert ";;; as a permanently red tile.  Change the fleet by editing the\n")
          (insert ";;; rosters, or this board's :eyes-only-board, in services.sexp.\n\n")
          (insert "(in-package :gdl-user)\n\n")
          (insert "(setq eyes-only::*heap-probes*\n      '(")
          (let ((first t))
            (dolist (p probes)
              (if first (setq first nil) (insert "\n        "))
              (insert (format "(%S %s %S %d)"
                              (nth 0 p) (nth 1 p) (nth 2 p) (nth 3 p)))))
          (insert "))\n"))
        (message "Generated: %s (%d probe(s))" file (length probes))
        probes))))

;;; ============================================================================

(defun skewed-generate-configs (&optional dir services-file prefix)
  "Generate all configs for directory DIR using SERVICES-FILE.

Generated files:
  - Compose YAML (docker-compose.yml or PREFIX-compose.yml)
  - MCP configs (container, windows, codex)
  - Emacs services discovery
  - Install script (for overlays only, when prefix is non-empty)  SERVICES-FILE - Path to services.sexp (default: \"services.sexp\" in DIR)
  PREFIX        - Output filename prefix (default: auto-derived from DIR basename)
                  Auto-derived: empty for 'skewed-emacs', 'basename-' for others

Examples:
  (skewed-generate-configs)                          ; Current dir, services.sexp
  (skewed-generate-configs \"/projects/betatest/\")   ; Betatest dir, auto-prefix
  (skewed-generate-configs nil \"/tmp/custom.sexp\") ; Current dir, custom file
  (skewed-generate-configs \"/tmp/foo/\" nil \"bar-\") ; Foo dir, override prefix"
  (let* ((skewed-gen-output-dir (expand-file-name (or dir default-directory)))
         (default-services-file (expand-file-name "services.sexp" skewed-gen-output-dir))
         (skewed-gen-input-file (expand-file-name (or services-file default-services-file)))
         ;; Auto-derive prefix from directory name if not provided
         (auto-prefix (let ((basename (file-name-nondirectory
                                       (directory-file-name skewed-gen-output-dir))))
                        (if (equal basename "skewed-emacs")
                            ""
                          (concat basename "-"))))
         (skewed-gen-output-prefix (if prefix prefix auto-prefix))
         (config (skewed--expand-roster
                  (skewed--read-sexp-file skewed-gen-input-file)
                  skewed-gen-output-dir
                  skewed-gen-output-prefix))
         (mcp-dir (expand-file-name "mcp/" skewed-gen-output-dir))
         (elisp-dir (expand-file-name "dot-files/emacs.d/etc/" skewed-gen-output-dir)))
    
    (unless config
      (error "Could not read services file: %s" skewed-gen-input-file))
    
    ;; Ensure directories exist
    (make-directory mcp-dir t)
    (make-directory elisp-dir t)
    
    ;; Generate docker-compose.yml (or overlay yml)
    (let* ((compose-name (if (string-empty-p skewed-gen-output-prefix)
                             "docker-compose.yml"
                           (format "%scompose.yml" skewed-gen-output-prefix)))
           (compose-file (expand-file-name compose-name skewed-gen-output-dir)))
      (with-temp-file compose-file
        (insert (skewed--generate-compose-yaml config)))
      (message "Generated: %s" compose-file))
    
    ;; Generate MCP configs (only when services declare :mcp t)
    (when (skewed--has-mcp-services-p config)
      (make-directory mcp-dir t)
      (let ((container-json (expand-file-name 
                             (format "%smcp-container.json" skewed-gen-output-prefix) mcp-dir)))
        (with-temp-file container-json
          (insert "// DO NOT EDIT - Generated from services.sexp\n")
          (insert (skewed--generate-mcp-json-container config)))
        (message "Generated: %s" container-json))
    
      (let ((windows-json (expand-file-name 
                           (format "%smcp-windows.json" skewed-gen-output-prefix) mcp-dir)))
        (with-temp-file windows-json
          (insert "// DO NOT EDIT - Generated from services.sexp\n")
          (insert "// For Windows: merge with base config or copy to %APPDATA%\\Claude\\\n")
          (insert (skewed--generate-mcp-json-windows config)))
        (message "Generated: %s" windows-json))
    
      (let ((codex-toml (expand-file-name 
                         (format "%smcp.toml" skewed-gen-output-prefix) mcp-dir)))
        (with-temp-file codex-toml
          (insert "# DO NOT EDIT - Generated from services.sexp\n\n")
          (insert (skewed--generate-mcp-toml config)))
        (message "Generated: %s" codex-toml))
    ) ;; end when has-mcp-services

    ;; Generate Elisp services file (base or overlay, using prefix)
    (let* ((elisp-name (if (string-empty-p skewed-gen-output-prefix)
                           "services-generated.el"
                         (format "%sservices-generated.el" skewed-gen-output-prefix)))
           (elisp-file (expand-file-name elisp-name elisp-dir)))
      (with-temp-file elisp-file
        (insert (skewed--generate-elisp config)))
      (message "Generated: %s" elisp-file))

    ;; Generate install script (for any non-skewed-emacs directory)
    (unless (equal (file-name-nondirectory (directory-file-name skewed-gen-output-dir)) "skewed-emacs")
      (let ((install-file (expand-file-name "install" skewed-gen-output-dir)))
        (with-temp-file install-file
          (insert (skewed--generate-install-script skewed-gen-output-prefix (skewed--has-mcp-services-p config))))
        (set-file-modes install-file #o755)
        (message "Generated: %s" install-file)))

    ;; Eyes Only heap probes, for a stack that declares itself a board.
    ;; Reads the OTHER ships' rosters, so it runs last.
    (skewed--generate-heap-probes-file config skewed-gen-output-dir)

    (message "=== Generation complete ===")))

(defun skewed-generate-all-configs ()
  "Generate all configs from services.sexp in current directory.
This is a convenience wrapper around skewed-generate-configs.
Automatically derives prefix from directory basename (empty for 'skewed-emacs').

For more control, use skewed-generate-configs directly."
  (interactive)
  (skewed-generate-configs))

(provide 'generate-configs)
;;; generate-configs.el ends here
