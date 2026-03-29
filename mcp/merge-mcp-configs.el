;;; merge-mcp-configs.el --- Merge MCP configuration files -*- lexical-binding: t; -*-
;;;
;;; This merges base MCP configs with overlays for all three formats:
;;;   - mcp-container.json  -> for in-container Claude/Gemini CLI
;;;   - mcp-windows.json    -> for Windows Claude Desktop via WSL
;;;   - mcp.toml            -> for Codex CLI
;;;
;;; Call this at container startup time (from compose-dev or similar)
;;;
;;; Usage:
;;;   (load-file "/path/to/merge-mcp-configs.el")
;;;   (skewed-merge-all-mcp-configs "/path/to/mcp/")
;;;
;;; Or individually:
;;;   (skewed-merge-mcp-json "/path/to/mcp/" "mcp-container.json" "/tmp/output.json")
;;;   (skewed-merge-mcp-toml "/path/to/mcp/" "/tmp/output.toml")
;;;
;;; For Windows config, set SKEWED_CLONE_PATH environment variable to the
;;; host path where skewed-emacs is cloned (done by compose-dev).

;;; Code:

(require 'json)

(defun skewed-merge-mcp-json (mcp-dir base-name output-file)
  "Merge base and overlay MCP JSON configs from MCP-DIR to OUTPUT-FILE.
BASE-NAME is the base config filename (e.g., 'mcp-container.json').
Merges with any overlay files matching pattern '*-{base-name}'."
  (let* ((base-file (expand-file-name base-name mcp-dir))
         (base-config (unless (file-exists-p base-file)
                        (error "Base config not found: %s" base-file)))
         (base-config (with-temp-buffer
                        (insert-file-contents base-file)
                        ;; Remove comment lines
                        (goto-char (point-min))
                        (while (re-search-forward "^[ \t]*//.*$" nil t)
                          (replace-match ""))
                        (goto-char (point-min))
                        (json-read)))
         (merged-servers (copy-alist (alist-get 'mcpServers base-config)))
         (overlay-pattern (concat "-" (regexp-quote base-name) "$"))
         (overlay-files (directory-files mcp-dir t overlay-pattern)))

    ;; Merge each overlay file
    (dolist (overlay-file overlay-files)
      (message "Merging %s overlay: %s" base-name (file-name-nondirectory overlay-file))
      (let* ((overlay-config (with-temp-buffer
                               (insert-file-contents overlay-file)
                               ;; Remove comment lines
                               (goto-char (point-min))
                               (while (re-search-forward "^[ \t]*//.*$" nil t)
                                 (replace-match ""))
                               (goto-char (point-min))
                               (json-read)))
             (overlay-servers (alist-get 'mcpServers overlay-config)))
        ;; Merge servers (overlay takes precedence)
        (dolist (server overlay-servers)
          (setf (alist-get (car server) merged-servers) (cdr server)))))

    ;; Preserve globalShortcut if present (for Windows configs)
    (let* ((global-shortcut (alist-get 'globalShortcut base-config))
           (json-encoding-pretty-print t)
           (merged (if global-shortcut
                       `((mcpServers . ,merged-servers)
                         (globalShortcut . ,global-shortcut))
                     `((mcpServers . ,merged-servers)))))
      (with-temp-file output-file
        (insert (json-encode merged))))

    (message "Merged MCP config written to: %s" output-file)
    output-file))

(defun skewed-merge-mcp-toml (mcp-dir output-file)
  "Merge base and overlay MCP TOML configs from MCP-DIR to OUTPUT-FILE.
Reads mcp.toml as base, then merges any *-mcp.toml overlay files."
  (let* ((base-file (expand-file-name "mcp.toml" mcp-dir))
         (base-servers (unless (file-exists-p base-file)
                         (error "Base TOML config not found: %s" base-file)))
         (base-servers (with-temp-buffer
                         (insert-file-contents base-file)
                         ;; Remove comment lines
                         (goto-char (point-min))
                         (while (re-search-forward "^[ \t]*#.*$" nil t)
                           (replace-match ""))
                         (buffer-string)))
         (overlay-files (directory-files mcp-dir t "-mcp\\.toml$"))
         (merged-content base-servers))

    ;; Merge each overlay file
    (dolist (overlay-file overlay-files)
      (message "Merging TOML overlay: %s" (file-name-nondirectory overlay-file))
      (let ((overlay-content (with-temp-buffer
                               (insert-file-contents overlay-file)
                               ;; Remove comment lines
                               (goto-char (point-min))
                               (while (re-search-forward "^[ \t]*#.*$" nil t)
                                 (replace-match ""))
                               (buffer-string))))
        ;; Simple concatenation for TOML (later entries override earlier ones)
        (setq merged-content (concat merged-content "\n" overlay-content))))

    ;; Write merged TOML
    (with-temp-file output-file
      (insert "# DO NOT EDIT - Merged MCP configuration\n")
      (insert "# Generated from base + overlay mcp.toml files\n\n")
      (insert merged-content))

    (message "Merged MCP TOML written to: %s" output-file)
    output-file))

(defun skewed--codex-config-path ()
  "Return the Codex config path inside the container."
  (or (getenv "CODEX_CONFIG_PATH")
      "/home/emacs-user/.codex/config.toml"))

(defun skewed--mcp-toml-to-codex (toml-path)
  "Return TOML content from TOML-PATH with MCP tables prefixed for Codex."
  (with-temp-buffer
    (insert-file-contents toml-path)
    (goto-char (point-min))
    (while (re-search-forward "^\\[\\([^]]+\\)\\]" nil t)
      (let ((table (match-string 1)))
        (unless (string-prefix-p "mcp_servers." table)
          (replace-match (format "[mcp_servers.%s]" table) t t))))
    (buffer-string)))

(defun skewed-update-codex-config-from-mcp (toml-path)
  "Write MCP server entries from TOML-PATH into Codex config.toml.
Replaces the managed block if it already exists."
  (let* ((codex-config (skewed--codex-config-path))
         (begin-marker "# BEGIN SKEWED-EMACS MCP")
         (end-marker "# END SKEWED-EMACS MCP")
         (mcp-content (skewed--mcp-toml-to-codex toml-path)))
    (make-directory (file-name-directory codex-config) t)
    (with-temp-buffer
      (when (file-exists-p codex-config)
        (insert-file-contents codex-config))

      ;; Remove any existing managed block.
      (goto-char (point-min))
      (when (re-search-forward (concat "^" (regexp-quote begin-marker) "$" ) nil t)
        (let ((start (match-beginning 0)))
          (when (re-search-forward (concat "^" (regexp-quote end-marker) "$" ) nil t)
            (delete-region start (match-end 0))
            (delete-blank-lines))))

      ;; Append managed block at end.
      (goto-char (point-max))
      (unless (bolp)
        (insert "\n"))
      (insert begin-marker "\n")
      (insert mcp-content)
      (unless (bolp)
        (insert "\n"))
      (insert end-marker "\n")

      (write-region (point-min) (point-max) codex-config))

    (message "Updated Codex config with MCP servers: %s" codex-config)
    codex-config))

(defun skewed--grok-settings-path ()
  "Return the grok user-settings.json path inside the container."
  (expand-file-name ".grok/user-settings.json" (expand-file-name "~")))

(defun skewed-update-grok-config-from-json (json-path)
  "Merge mcpServers from JSON-PATH into grok user-settings.json.
Preserves existing keys (apiKey, model, etc.) and only updates mcpServers."
  (let* ((grok-settings (skewed--grok-settings-path))
         (existing (when (file-exists-p grok-settings)
                     (with-temp-buffer
                       (insert-file-contents grok-settings)
                       (goto-char (point-min))
                       (condition-case nil (json-read) (error nil)))))
         (merged-config (with-temp-buffer
                          (insert-file-contents json-path)
                          (goto-char (point-min))
                          (json-read)))
         (new-servers (alist-get 'mcpServers merged-config))
         (result (or existing '())))
    ;; Update mcpServers in existing settings
    (setf (alist-get 'mcpServers result) new-servers)
    (make-directory (file-name-directory grok-settings) t)
    (let ((json-encoding-pretty-print t))
      (with-temp-file grok-settings
        (insert (json-encode result))))
    (message "Updated grok user-settings.json with MCP servers: %s" grok-settings)
    grok-settings))

(defun skewed-merge-all-mcp-configs (mcp-dir)
  "Merge all MCP config formats from MCP-DIR to /tmp.
For Windows config, substitutes ${SKEWED_CLONE_PATH} placeholder with
the value from the environment (set by compose-dev via docker exec -e).
Returns list of generated files."
  (let ((container-config (skewed-merge-mcp-json mcp-dir "mcp-container.json" "/tmp/merged-mcp-config.json"))
        (windows-config (skewed-merge-mcp-json mcp-dir "mcp-windows.json" "/tmp/merged-mcp-windows.json"))
        (toml-config (skewed-merge-mcp-toml mcp-dir "/tmp/merged-mcp.toml"))
        ;; Get clone path from environment
        (clone-path (getenv "SKEWED_CLONE_PATH")))
    
    ;; Substitute host clone path in Windows config if env var is set
    (when (and clone-path (not (string-empty-p clone-path)))
      (with-temp-buffer
        (insert-file-contents windows-config)
        (goto-char (point-min))
        (while (search-forward "${SKEWED_CLONE_PATH}" nil t)
          (replace-match clone-path t t))
        (write-region (point-min) (point-max) windows-config))
      (message "Substituted SKEWED_CLONE_PATH=%s in %s" clone-path windows-config))

    ;; Update grok user-settings.json with MCP servers from merged JSON
    (skewed-update-grok-config-from-json container-config)

    ;; Update Codex config with MCP servers from merged TOML
    (skewed-update-codex-config-from-mcp toml-config)
    
    (list container-config windows-config toml-config)))

;; Backwards compatibility wrapper
(defun skewed-merge-mcp-configs (mcp-dir output-file)
  "Backwards compatibility wrapper. Use skewed-merge-mcp-json instead."
  (skewed-merge-mcp-json mcp-dir "mcp-container.json" output-file))

(provide 'merge-mcp-configs)
;;; merge-mcp-configs.el ends here
