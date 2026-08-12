;; Copyright (C) 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.


(add-to-list 'load-path (concat emacs-config-directory "sideloaded/slime-v2.28/lib/"))

(let ((default-directory (concat emacs-config-directory "sideloaded/slime-v2.28/")))
  (load-file "slime.el"))

(eval-after-load "slime"
  '(progn
     (dolist (extension (list "\\.cl\\'"  "\\.gdl\\'" "\\.gendl\\'"
			      "\\.lhtm\\'"  "\\.lhtml\\'" "\\.sexp\\'"
			      "\\.sexpr\\'" "\\.sexps\\'"))
       (add-to-list 'auto-mode-alist (cons extension 'lisp-mode)))
     (slime-setup '(slime-fancy slime-banner slime-tramp))
     (add-hook 'slime-connected-hook 'set-slime-shortcuts)
     (add-hook 'slime-connected-hook 'customise-slime)
     ;;(add-hook 'slime-connected-hook 'load-and-or-start-gendl)
     (add-hook 'slime-repl-mode-hook 'remove-dos-eol)))

(defvar gdl-startup-string
  "(unless (find-package :gendl)
     (when (probe-file \"~/.load-gendl.cl\")
         (load \"~/.load-gendl.cl\")))")

(defvar user-startup-string nil)

(defun load-and-or-start-gendl ()
  (setq slime-enable-evaluate-in-emacs t)
  (slime-repl)
  (insert gdl-startup-string)
  (slime-repl-return)
  (end-of-buffer)

  ;;
  ;; DAP  -- Added to support user-startup-string
  ;;
  (when user-startup-string 
    (slime-repl-return)
    (insert user-startup-string)
    (slime-repl-return)))
  

(defun set-slime-shortcuts ()
  "Set keybindings for switching to slime buffers"
  (interactive)
  (global-set-key "\C-x&" #'(lambda()(interactive) (switch-to-buffer (slime-repl-buffer))))
  (global-set-key "\C-x*" #'(lambda()(interactive) (switch-to-buffer "*inferior-lisp*"))))

(defun customise-slime ()
  (setq slime-autodoc-use-multiline-p t)

  (defvar my-slime-default-words-of-encouragement slime-words-of-encouragement
    "Default SLIME connection messages for reference or restoration.")
  
  (defcustom slime-words-of-encouragement
    '("Spin up the MCP (e.g. M-x claude-code), let the agents earn their keep."
      "Buffers primed, backends wired. Ship it."
      "Welcome to the real REPL (who wants to tell replit)?"
      "Prepared to proceed in a Lisply manner."
      "Try an MCP handshake (e.g. M-x claude-code), then delegate, iterate, elevate."
      "Skewed and ready, sir. Let the yak-shaving commence."
      "May your model match your intent."
      "Define, Compile, regenerate, and let geometry tell the truth."
      "KBE engaged. Prepared to redefine worlds."
      "Gendl loaded: describe the system, immediately probe the solution."
      "Input-slots in, insight out."
      "Shape ideas, not just triangles."
      "From spec to surface, tweak & repeat elegantly."
      "Model once, tweak and reuse forever."
      "read the fine manual, please. —Erik Naggum"
      "common Lisp: you’re not in Kansas anymore. —Erik Naggum"
      "optimization helps today; design helps tomorrow. —Erik Naggum"
      "presentation is information. —Erik Naggum"
      "distinguish good uses from bad. tools aren’t the sin. —Erik Naggum"
      "learn, understand, extend the craft. —Erik Naggum"
      "lisp lets adults get real work done. —Erik Naggum"
      "Gorn-powered practicality: emit s-expressions, not excuses."
      "Skew the defaults, batten down the hatches, center the craft."
      "Small source files, big leverage."
      "Today’s keystrokes are Tomorrow’s breakthrough.")
    "List of motivational messages displayed on SLIME connection."
    :type '(repeat string)
    :group 'slime))


(defun remove-dos-eol ()
  "Do not show ^M in files containing mixed UNIX and DOS line endings."
  (interactive)
  (setq buffer-display-table (make-display-table))
  (aset buffer-display-table ?\^M []))


(defun slime-init-command (port-filename _coding-system)
  "Return a string to initialize Lisp."
  (let ((loader (if (file-name-absolute-p slime-backend)
                    slime-backend
                  (concat slime-path slime-backend))))
    ;; Return a single form to avoid problems with buffered input.
    (format "%S\n\n"
            `(if (find-package :gendl)
                 (progn
                   (funcall (read-from-string "gendl::initialize"))
                   (funcall (read-from-string "glisp:load-swank") :from-emacs? t)
                   (funcall (read-from-string "swank:start-server" ,(slime-to-lisp-filename port-filename))))
               (progn
                 (load ,(slime-to-lisp-filename (expand-file-name loader))
                       :verbose t)
                 (funcall (read-from-string "swank-loader:init")
                          :from-emacs t)
                 (setf (symbol-value (read-from-string "swank::*loopback-interface*")) "127.0.0.1")
                 (funcall (read-from-string "swank:start-server")
                          ,(slime-to-lisp-filename port-filename)))
               ))))


(defun replace-in-dir (dir pattern replacement &optional excludes keeps)
  
  (unless excludes (setq excludes '("node_modules" "ql-temp-patches")))
  (unless keeps (setq keeps '(".+\\.lisp" ".+\\.lsp" ".+\\.cl" ".+\\.gdl" ".+\\.gendl")))
  
  (let ((files (directory-files-recursively dir ".+\\..+")))
    (dolist (exclude excludes)
      (setq files (cl-remove-if (lambda (file) (string-match-p exclude file)) files)))
    
    (setq files (cl-remove-if-not (lambda (file)
                                    (cl-dolist (keep keeps)
                                      (when (string-match-p keep file)
                                        (cl-return t)))) files))
    (dolist (file files)
      (when
          (with-temp-buffer
            (insert-file-contents file)
            (string-match-p pattern (buffer-string)))
        (find-file file)
        (replace-regexp pattern replacement nil (point-min) (point-max))
        (save-buffer)
        (kill-buffer)
        
        ))))

(setq slime-compile-file-options '(:external-format :utf-8))

(provide 'slime-config)
