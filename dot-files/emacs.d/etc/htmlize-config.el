;; Copyright (C) 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.



(defun dc/html-export-buffer-exact (&optional file)
  "Export current buffer to a self-contained HTML file that matches on-screen appearance."
  (interactive)
  (require 'htmlize)
  ;; Ensure everything is actually fontified (jit-lock is lazy by default).
  (save-restriction
    (widen)
    (when (fboundp 'font-lock-ensure)
      (font-lock-ensure (point-min) (point-max))))

  (let* ((file (or file
                   (concat (file-name-nondirectory
                            (or (buffer-file-name) (buffer-name))) ".html")))
         (bg (or (face-background 'default nil t)
                 (frame-parameter nil 'background-color)
                 "white"))
         (fg (or (face-foreground 'default nil t)
                 (frame-parameter nil 'foreground-color)
                 "black"))
         (tabw (or tab-width 8))
         (html-buf (htmlize-buffer)))
    (with-current-buffer html-buf
      ;; Inject a tiny stylesheet for page bg + monospace + tab width + no wrapping.
      (goto-char (point-min))
      (when (re-search-forward "</title>\\s-*\n" nil t)
        (insert (format
                 "<style>
  html,body{height:100%%}
  body{background:%s;color:%s;margin:0}
  /* htmlize already emits inline colors for every span; this just sets page basics */
  pre{
    margin:0; padding:1rem;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace;
    white-space: pre;           /* preserve indentation & line endings; no wrapping */
    tab-size:%d;
    overflow-x:auto;            /* allow horizontal scroll for long lines */
  }
</style>\n" bg fg tabw)))
      (write-file file))
    (kill-buffer html-buf)
    (message "Wrote %s" (expand-file-name file))))

(defun dc/html-export-region-exact (beg end &optional file)
  (interactive "r")
  (require 'htmlize)
  (when (fboundp 'font-lock-ensure) (font-lock-ensure beg end))
  (let ((html-buf (htmlize-region beg end)))
    (with-current-buffer html-buf
      (write-file (or file "region.html")))
    (kill-buffer html-buf)))

(defun dc/copy-tree-with-lisp-to-html (source-dir target-dir)
  "Copy directory tree from SOURCE-DIR to TARGET-DIR, converting Lisp files to HTML.
Files with extensions .lisp, .gdl, or .gendl are converted to corresponding .html files.
All other files are copied as-is."
  (interactive "DSource directory: \nDTarget directory: ")
  (unless (file-directory-p source-dir)
    (error "Source directory does not exist: %s" source-dir))
  
  ;; Create target directory if it doesn't exist
  (unless (file-directory-p target-dir)
    (make-directory target-dir t))
  
  ;; Process directory recursively
  (dc/copy-tree-helper source-dir target-dir)
  (message "Directory tree copied with Lisp files converted to HTML: %s -> %s" 
           source-dir target-dir))

(defun dc/copy-tree-helper (source-dir target-dir)
  "Recursive helper function for dc/copy-tree-with-lisp-to-html."
  (let ((files (directory-files source-dir t "^[^.]"))) ; Skip . and ..
    (dolist (file files)
      (let* ((relative-name (file-name-nondirectory file))
             (target-file (expand-file-name relative-name target-dir)))
        (cond
         ;; Handle subdirectories
         ((file-directory-p file)
          (make-directory target-file t)
          (dc/copy-tree-helper file target-file))
         
         ;; Handle Lisp files - convert to HTML
         ((string-match "\\.\\(lisp\\|gdl\\|gendl\\)\\'" file)
          (dc/convert-lisp-file-to-html file target-file))
         
         ;; Handle all other files - copy as-is
         (t
          (copy-file file target-file t)))))))

(defun dc/convert-lisp-file-to-html (source-file target-file)
  "Convert a single Lisp source file to HTML with syntax highlighting."
  (let* ((file-ext (file-name-extension source-file))
         (html-file (concat target-file ".html"))
         (temp-buffer (generate-new-buffer " *lisp-to-html*")))
    
    (unwind-protect
        (progn
          ;; Read source file into temporary buffer
          (with-current-buffer temp-buffer
            (insert-file-contents source-file)
            
            ;; Set appropriate major mode for syntax highlighting
            (cond
             ((string= file-ext "lisp") (lisp-mode))
             ((string= file-ext "gdl") (lisp-mode))   ; GDL files use Lisp syntax
             ((string= file-ext "gendl") (lisp-mode))) ; GENDL files use Lisp syntax
            
            ;; Ensure fontification is complete
            (when (fboundp 'font-lock-ensure)
              (font-lock-ensure (point-min) (point-max)))
            
            ;; Export to HTML using existing function logic
            (dc/export-buffer-to-html-file html-file)))
      
      ;; Clean up temporary buffer
      (kill-buffer temp-buffer))
    
    (message "Converted %s -> %s" source-file html-file)))

(defun dc/export-buffer-to-html-file (output-file)
  "Export current buffer to HTML file using htmlize with exact appearance."
  (require 'htmlize)
  (let* ((bg (or (face-background 'default nil t)
                 (frame-parameter nil 'background-color)
                 "white"))
         (fg (or (face-foreground 'default nil t)
                 (frame-parameter nil 'foreground-color)
                 "black"))
         (tabw (or tab-width 8))
         (html-buf (htmlize-buffer)))
    (unwind-protect
        (with-current-buffer html-buf
          ;; Inject stylesheet for proper appearance
          (goto-char (point-min))
          (when (re-search-forward "</title>\\s-*\n" nil t)
            (insert (format
                     "<style>
  html,body{height:100%%}
  body{background:%s;color:%s;margin:0}
  pre{
    margin:0; padding:1rem;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, 'Liberation Mono', monospace;
    white-space: pre;
    tab-size:%d;
    overflow-x:auto;
  }
</style>\n" bg fg tabw)))
          (write-file output-file))
      ;; Clean up htmlize buffer
      (kill-buffer html-buf))))
