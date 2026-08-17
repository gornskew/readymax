;;; skewed-install-config.el --- on-demand module installs  -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.


;; Elisp-first UI over /usr/local/bin/skewed-install, the on-demand
;; module installer baked into the skewed-emacs container images.
;; The default-distribution image ships without the AI TUI CLIs and
;; (in -lite) without a snapshot browser; install them here as needed.
;;
;; Installs are ephemeral BY DESIGN: they land in the container home
;; and vanish when the container is recreated.  For baked-in
;; persistence pull the -aituis or -full image instead.

;;; Code:

(defconst skewed-install-modules
  '(("claude-code"             . "Anthropic Claude Code TUI (npm, ~300MB)")
    ("codex"                   . "OpenAI Codex TUI (npm, ~300MB)")
    ("gemini-cli"              . "Google Gemini CLI (npm, ~130MB)")
    ("grok"                    . "xAI Grok CLI (binary installer, ~160MB)")
    ("copilot-language-server" . "GitHub Copilot LSP server (npm, ~260MB)")
    ("headless-shell"          . "chrome-headless-shell + libs for webshot (~610MB)"))
  "Modules skewed-install knows, with size/description annotations.")

(defun skewed-install--read-module (prompt)
  (completing-read
   prompt
   (lambda (string pred action)
     (if (eq action 'metadata)
         `(metadata
           (annotation-function
            . ,(lambda (cand)
                 (when-let ((desc (cdr (assoc cand skewed-install-modules))))
                   (concat "  " desc)))))
       (complete-with-action action skewed-install-modules string pred)))
   nil t))

(defun skewed-install--run (args)
  (let ((buffer (get-buffer-create "*skewed-install*")))
    (async-shell-command (concat "skewed-install " args) buffer)
    buffer))

;;;###autoload
(defun skewed-install (module)
  "Install on-demand MODULE (AI TUIs, snapshot browser, ...) into this container."
  (interactive (list (skewed-install--read-module "Install module: ")))
  (skewed-install--run (shell-quote-argument module)))

;;;###autoload
(defun skewed-uninstall (module)
  "Remove an on-demand MODULE previously added with `skewed-install'."
  (interactive (list (skewed-install--read-module "Remove module: ")))
  (skewed-install--run (concat "remove " (shell-quote-argument module))))

;;;###autoload
(defun skewed-install-list ()
  "Show skewed-install modules and their install status."
  (interactive)
  (skewed-install--run "list"))

(provide 'skewed-install-config)
;;; skewed-install-config.el ends here
