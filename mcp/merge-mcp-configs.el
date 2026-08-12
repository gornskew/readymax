;;; merge-mcp-configs.el --- Merge MCP configuration files -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;;
;;; This merges base MCP configs with overlays for all three formats:
;;;   - mcp-container.json  -> for in-container Claude/Gemini CLI
;;;   - mcp-windows.json    -> for Windows Claude Desktop via WSL
;;;   - mcp.toml            -> for Codex CLI and Grok CLI
;;;   (a native-host Claude Desktop config is derived from the Windows one)
;;;   Grok reads the same [mcp_servers.*] tables into ~/.grok/config.toml
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

(defun skewed--read-file-without-comment-lines (filepath comment-prefix-regexp)
  "Return FILEPATH contents with full-line comments matching COMMENT-PREFIX-REGEXP removed."
  (with-temp-buffer
    (insert-file-contents filepath)
    (goto-char (point-min))
    (while (re-search-forward comment-prefix-regexp nil t)
      (replace-match ""))
    (buffer-string)))

(defun skewed--parse-toml-sections (content)
  "Parse CONTENT into an ordered alist of TOML table name to section text.
Only table sections are returned. Repeated tables later in the file replace
earlier values when the caller merges the resulting alists."
  (let ((sections '())
        (current-table nil)
        (current-lines '()))
    (dolist (line (split-string content "\n"))
      (if (string-match "^\\[\\([^]]+\\)\\][ \\t]*$" line)
          (progn
            (when current-table
              (push (cons current-table
                          (string-trim-right (string-join (nreverse current-lines) "\n")))
                    sections))
            (setq current-table (match-string 1 line))
            (setq current-lines (list line)))
        (when current-table
          (push line current-lines))))
    (when current-table
      (push (cons current-table
                  (string-trim-right (string-join (nreverse current-lines) "\n")))
            sections))
    (nreverse sections)))

(defun skewed--merge-toml-files (filepaths)
  "Merge TOML table sections from FILEPATHS with later files overriding earlier ones."
  (let ((section-order '())
        (merged-sections (make-hash-table :test #'equal)))
    (dolist (filepath filepaths)
      (dolist (section (skewed--parse-toml-sections
                        (skewed--read-file-without-comment-lines filepath "^[ \\t]*#.*$")))
        (let ((table (car section)))
          (unless (member table section-order)
            (setq section-order (append section-order (list table))))
          (puthash table (cdr section) merged-sections))))
    (mapconcat (lambda (table) (gethash table merged-sections))
               section-order
               "\n\n")))

(defun skewed-merge-mcp-json (mcp-dir base-name output-file)
  "Merge base and overlay MCP JSON configs from MCP-DIR to OUTPUT-FILE.
BASE-NAME is the base config filename (e.g., 'mcp-container.json').
Merges with any overlay files matching pattern '*-{base-name}'."
  (let* ((base-file (expand-file-name base-name mcp-dir))
         (base-config (unless (file-exists-p base-file)
                        (error "Base config not found: %s" base-file)))
         (base-config (with-temp-buffer
                        (insert (skewed--read-file-without-comment-lines
                                 base-file "^[ \t]*//.*$"))
                        (goto-char (point-min))
                        (json-read)))
         (merged-servers (copy-alist (alist-get 'mcpServers base-config)))
         (overlay-pattern (concat "-" (regexp-quote base-name) "$"))
         (overlay-files (directory-files mcp-dir t overlay-pattern)))

    ;; Merge each overlay file
    (dolist (overlay-file overlay-files)
      (message "Merging %s overlay: %s" base-name (file-name-nondirectory overlay-file))
      (let* ((overlay-config (with-temp-buffer
                               (insert (skewed--read-file-without-comment-lines
                                        overlay-file "^[ \t]*//.*$"))
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
         (_base-servers (unless (file-exists-p base-file)
                          (error "Base TOML config not found: %s" base-file)))
         (overlay-files (directory-files mcp-dir t "-mcp\\.toml$"))
         (all-files (cons base-file overlay-files))
         (merged-content nil))

    (dolist (overlay-file overlay-files)
      (message "Merging TOML overlay: %s" (file-name-nondirectory overlay-file)))
    (setq merged-content (skewed--merge-toml-files all-files))

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

(defun skewed--grok-config-path ()
  "Return the Grok config path inside the container."
  (or (getenv "GROK_CONFIG_PATH")
      "/home/emacs-user/.grok/config.toml"))

(defun skewed--mcp-toml-to-codex (toml-path)
  "Return TOML content from TOML-PATH with MCP tables prefixed for Codex."
  (with-temp-buffer
    (insert-file-contents toml-path)
    (goto-char (point-min))
    (while (re-search-forward "^\\[\\([^]]+\\)\\]" nil t)
      (let ((table (match-string 1)))
        (unless (or (string-prefix-p "mcp_servers." table)
                    (string-match-p "\\." table))
          (replace-match (format "[mcp_servers.%s]" table) t t))))
    (buffer-string)))

(defun skewed--mcp-toml-to-grok (toml-path)
  "Return Grok-ready MCP TOML from TOML-PATH.

Keeps only top-level `[mcp_servers.NAME]` server tables (drops nested
Codex tool-approval tables like `[mcp_servers.NAME.tools....]`), and
ensures each server has `enabled = true` so Grok loads them."
  (let* ((sections (skewed--parse-toml-sections
                    (skewed--read-file-without-comment-lines
                     toml-path "^[ \t]*#.*$")))
         (lines '()))
    (dolist (section sections)
      (let ((table (car section))
            (body (cdr section)))
        ;; mcp_servers.<name> only — one dot after the mcp_servers prefix
        (when (string-match-p "^mcp_servers\\.[^.]+$" table)
          (unless (string-match-p "^[ \t]*enabled[ \t]*=" body)
            (setq body (replace-regexp-in-string
                        (concat "^\\(\\[" (regexp-quote table) "\\]\\)[ \t]*$")
                        "\\1\nenabled = true"
                        body)))
          (push body lines))))
    (string-join (nreverse lines) "\n\n")))

(defun skewed--update-config-managed-mcp-block (config-path mcp-content)
  "Insert or replace the SKEWED-EMACS MCP managed block in CONFIG-PATH."
  (let ((begin-marker "# BEGIN SKEWED-EMACS MCP")
        (end-marker "# END SKEWED-EMACS MCP"))
    (make-directory (file-name-directory config-path) t)
    (with-temp-buffer
      (when (file-exists-p config-path)
        (insert-file-contents config-path))

      ;; Remove any existing managed block.
      (goto-char (point-min))
      (while (re-search-forward (concat "^" (regexp-quote begin-marker) "$") nil t)
        (let ((start (match-beginning 0)))
          (when (re-search-forward (concat "^" (regexp-quote end-marker) "$") nil t)
            (delete-region start (match-end 0))
            (delete-blank-lines)
            (goto-char start))))

      ;; Append managed block at end.
      (goto-char (point-max))
      (unless (bolp)
        (insert "\n"))
      (insert begin-marker "\n")
      (insert mcp-content)
      (unless (bolp)
        (insert "\n"))
      (insert end-marker "\n")

      (write-region (point-min) (point-max) config-path))
    config-path))

(defun skewed-update-codex-config-from-mcp (toml-path)
  "Write MCP server entries from TOML-PATH into Codex config.toml.
Replaces the managed block if it already exists."
  (let ((codex-config (skewed--update-config-managed-mcp-block
                       (skewed--codex-config-path)
                       (skewed--mcp-toml-to-codex toml-path))))
    (message "Updated Codex config with MCP servers: %s" codex-config)
    codex-config))

(defun skewed-update-grok-config-from-mcp (toml-path)
  "Write MCP server entries from TOML-PATH into Grok config.toml.
Replaces the managed block if it already exists. Grok reads
`[mcp_servers.<name>]` tables from `~/.grok/config.toml`."
  (let ((grok-config (skewed--update-config-managed-mcp-block
                      (skewed--grok-config-path)
                      (skewed--mcp-toml-to-grok toml-path))))
    (message "Updated Grok config with MCP servers: %s" grok-config)
    grok-config))

(defun skewed-derive-host-config (windows-config-file output-file)
  "Derive a native-host (Linux/macOS) Claude Desktop config.
Reads WINDOWS-CONFIG-FILE (the merged, path-substituted Windows/WSL
config) and converts each server entry of the form
command=\"wsl\", args=[EXEC ARGS...] into command=EXEC, args=[ARGS...],
suitable for running mcp-exec directly on a Linux or macOS host.
Writes the result to OUTPUT-FILE and returns it."
  (let* ((config (with-temp-buffer
                   (insert-file-contents windows-config-file)
                   (goto-char (point-min))
                   (json-read)))
         (servers (alist-get 'mcpServers config)))
    (dolist (server servers)
      (let* ((props (cdr server))
             (command (alist-get 'command props))
             (args (append (alist-get 'args props) nil)))
        (when (and (equal command "wsl") (consp args))
          (setf (alist-get 'command props) (car args))
          (setf (alist-get 'args props) (vconcat (cdr args)))
          (setcdr server props))))
    (let ((json-encoding-pretty-print t))
      (with-temp-file output-file
        (insert (json-encode config))))
    output-file))

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

    ;; Update Codex and Grok configs with MCP servers from merged TOML
    (skewed-update-codex-config-from-mcp toml-config)
    (skewed-update-grok-config-from-mcp toml-config)
    
    ;; Derive native-host (Linux/macOS) Claude Desktop config
    (skewed-derive-host-config windows-config "/tmp/merged-mcp-host.json")

    (list container-config windows-config toml-config "/tmp/merged-mcp-host.json")))

;; Backwards compatibility wrapper
(defun skewed-merge-mcp-configs (mcp-dir output-file)
  "Backwards compatibility wrapper. Use skewed-merge-mcp-json instead."
  (skewed-merge-mcp-json mcp-dir "mcp-container.json" output-file))

(provide 'merge-mcp-configs)
;;; merge-mcp-configs.el ends here
