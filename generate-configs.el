;;; generate-configs.el --- Generate configs from services.sexp -*- lexical-binding: t; -*-
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
      (push "networks:" lines)
      (push "  skewed-network:" lines)
      (push (format "    name: ${DOCKER_NETWORK_NAME:-%s}" network-name) lines)
      (push "    driver: bridge" lines)
      (push "" lines))
    
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
             (extra-hosts (skewed--get-prop svc :extra-hosts))
             (group-add (skewed--get-prop svc :group-add))
             (healthcheck (skewed--get-prop svc :healthcheck))
             (restart (or (skewed--get-prop svc :restart)
                          (skewed--get-prop defaults :restart)
                          "unless-stopped")))
        
        (push (format "  %s:" name) lines)
        (push (format "    image: %s" image) lines)
        (push (format "    container_name: %s" name) lines)
        (push (format "    hostname: %s" name) lines)
        (when user (push (format "    user: %s" user) lines))
        (push (format "    restart: %s" restart) lines)
        (push "    stdin_open: true" lines)
        (push "    tty: true" lines)
        
        ;; Ports
        (let ((ports-with-host (cl-remove-if-not (lambda (p) (skewed--get-prop p :host)) ports)))
          (when ports-with-host
            (push "    ports:" lines)
            (dolist (port ports-with-host)
              (let ((container (skewed--get-prop port :container))
                    (host (skewed--get-prop port :host)))
                (push (format "      - \"%s:%s\"" host container) lines)))))
        
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
          (push (format "      - %s=%s" (car env-pair) (cdr env-pair)) lines))
        (push (format "      - TZ=%s" (or (skewed--get-prop defaults :timezone) "${TZ:-Etc/UTC}")) lines)
        
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
        (when extra-hosts
          (push "    extra_hosts:" lines)
          (dolist (host-pair extra-hosts)
            (push (format "      - \"%s:%s\"" (car host-pair) (cdr host-pair)) lines)))
        
        ;; Group add
        (when group-add
          (push "    group_add:" lines)
          (dolist (grp group-add)
            (push (format "      - \"%s\"" grp) lines)))
        
        ;; Networks
        (push "    networks:" lines)
        (push "      - skewed-network" lines)
        
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
  "Generate MCP config in TOML format for Codex."
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
        (push (format "     :type \"%s\"" type) lines)
        (push (format "     :lisp-impl \"%s\"" (or lisp-impl "Unknown")) lines)
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
         (config (skewed--read-sexp-file skewed-gen-input-file))
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
