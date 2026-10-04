;;; lisply-file-tools.el --- Bounded file reading, searching and editing for agents  -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Commentary:

;; The helpers an agent reaches for instead of cat, grep, sed -n and
;; sed -i, loaded at boot with the lisply endpoints.  `(lisply-help)'
;; lists them, with the rest of the backend's toolkit, from their
;; docstrings.
;;
;; Every helper is bounded: output is capped, a child process runs under
;; timeout(1), and every loop advances point.  None leaves a buffer
;; behind, and none writes a file underneath a buffer that visits it:
;;
;; - a file some buffer already visits is edited IN that buffer and
;;   saved, so the live session never meets "changed on disk"; a buffer
;;   with unsaved edits is refused, since those edits are someone's work;
;; - any other file is edited in a temp buffer and written back in the
;;   coding system it was read with.
;;
;; A Lisp file (`lisply-lisp-file-extensions') must balance before an
;; edit, and an edit that would unbalance it is refused with nothing
;; written.  Inserted text goes in verbatim: nothing is re-indented, so a
;; hand-indented form is never reflowed and no tabs appear.

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'help)
(require 'lisply-shell-guard)

(defvar lisply-lisp-file-extensions
  '("lisp" "lsp" "cl" "asd" "gdl" "gendl" "el" "sexp" "isc")
  "File extensions the edit helpers treat as Lisp, checking balance.")

(defvar lisply-read-max-lines 400
  "Most lines `lisply-read' returns in one call.")

(defvar lisply-grep-max-matches 200
  "Default cap on the matching lines `lisply-grep' returns.")

(defvar lisply-grep-max-line-length 300
  "Matching lines longer than this are cut, so a minified file stays readable.")

(defvar lisply-grep-timeout 15
  "Seconds `lisply-grep' lets its search run.
Kept well under the MCP transport's 30 s eval limit.")

(defvar lisply-help-groups
  '(("Read and search"
     lisply-read lisply-grep)
    ("Edit any file by exact text"
     lisply-replace)
    ("Edit Lisp by top-level form"
     lisply-form-get lisply-form-replace lisply-form-delete
     lisply-form-insert lisply-check-parens)
    ("Edit GDL define-object sections (take a BUFFER, not a file)"
     lisply-insert-slot-spec lisply-kill-named-slot
     lisply-replace-parent-class lisply-add-keyword-to-object-spec)
    ("Write a whole Lisp file from s-expression data"
     lisply-write-sexp-file)
    ("Run a child process without wedging the daemon"
     lisply-shell-bounded lisply-shell-async lisply-shell-async-result)
    ("Search the indexed Gendl/GDL corpus (also the lisply_search tool)"
     lisply-search))
  "The toolkit as `lisply-help' lists it: (HEADING FUNCTION...) groups.")

;;; ---- lisply-help ----

(defun lisply--signature (sym)
  "Return SYM's calling signature as a string."
  (let* ((doc (documentation sym t))
         (split (and doc (help-split-fundoc doc sym))))
    (or (car split)
        (format "%S" (cons sym (help-function-arglist sym t))))))

(defun lisply--doc-body (sym)
  "Return SYM's docstring without its usage line."
  (let* ((doc (or (documentation sym t) ""))
         (split (help-split-fundoc doc sym)))
    (string-trim (if split (or (cdr split) "") doc))))

(defun lisply-help (&optional name)
  "Return the agent toolkit as text: every helper's signature and summary.
With NAME, a symbol or string, return that helper's full documentation."
  (if name
      (let ((sym (if (symbolp name) name (intern name))))
        (if (fboundp sym)
            (format "%s\n\n%s" (lisply--signature sym) (lisply--doc-body sym))
          (format "No such function: %s" sym)))
    (concat
     "Prefer these to shell tools for files: each is bounded, keeps the live\n"
     "session's buffers consistent, and checks Lisp balance.  (lisply-help 'NAME)\n"
     "gives one in full.\n\n"
     (mapconcat
      (lambda (group)
        (concat "## " (car group) "\n"
                (mapconcat
                 (lambda (sym)
                   (if (fboundp sym)
                       (format "%s\n    %s" (lisply--signature sym)
                               (car (split-string (lisply--doc-body sym) "\n")))
                     (format "%s  [not loaded]" sym)))
                 (cdr group) "\n")))
      lisply-help-groups "\n\n"))))

;;; ---- buffers and balance ----

(defun lisply--lisp-file-p (file)
  "Non-nil when FILE's extension is one of `lisply-lisp-file-extensions'."
  (member (file-name-extension file) lisply-lisp-file-extensions))

(defun lisply--setup-mode (file)
  "Give the current temp buffer FILE's Lisp syntax, running no mode hooks."
  (when (lisply--lisp-file-p file)
    (delay-mode-hooks
      (if (equal (file-name-extension file) "el")
          (emacs-lisp-mode)
        (lisp-mode)))))

(defun lisply--unbalanced-line ()
  "Return nil when the current buffer balances, else the line where it fails."
  (syntax-propertize (point-max))
  (save-excursion
    (condition-case nil
        (progn (check-parens) nil)
      (error (line-number-at-pos)))))

(defun lisply--abbrev (string)
  "STRING cut to a length that reads well inside an error message."
  (truncate-string-to-width (replace-regexp-in-string "\n" "\\\\n" string)
                            60 nil nil "..."))

(defun lisply--live-buffer (file)
  "Return the buffer visiting FILE, made current with its file, or nil.
Refuses a buffer holding unsaved edits."
  (let ((live (find-buffer-visiting file)))
    (when live
      (with-current-buffer live
        (when (buffer-modified-p)
          (error "lisply: %s has unsaved edits in buffer %s; nothing written -- save or revert that buffer first"
                 file (buffer-name)))
        (unless (verify-visited-file-modtime live)
          (let ((revert-without-query '(".")))
            (revert-buffer t t t)))))
    live))

(defun lisply--insert-file-text (file live)
  "Insert FILE's text into the current buffer, from LIVE when it visits FILE.
Return the coding system the text was read with."
  (if live
      (progn
        (insert (with-current-buffer live
                  (save-restriction
                    (widen)
                    (buffer-substring-no-properties (point-min) (point-max)))))
        (buffer-local-value 'buffer-file-coding-system live))
    (insert-file-contents file)
    last-coding-system-used))

(defun lisply--read-file (file fn)
  "Call FN with point at the start of a temp buffer holding FILE's text."
  (let ((file (expand-file-name file)))
    (unless (file-readable-p file)
      (error "lisply: cannot read %s" file))
    (with-temp-buffer
      (lisply--setup-mode file)
      (insert-file-contents file)
      (goto-char (point-min))
      (funcall fn))))

(defun lisply--edit-file (file fn)
  "Edit FILE by calling FN at the start of a temp buffer holding its text.
Return FN's value.  Nothing is written when FN leaves the text unmodified.
A Lisp FILE must balance before FN runs and after, or nothing is
written.  When a buffer visits FILE the new text goes into that buffer,
which is then saved; otherwise the temp buffer is written to FILE."
  (let* ((file (expand-file-name file))
         (lisp (lisply--lisp-file-p file)))
    (unless (file-writable-p file)
      (error "lisply: cannot write %s" file))
    (let ((live (lisply--live-buffer file)))
      (with-temp-buffer
        (lisply--setup-mode file)
        (let ((coding (lisply--insert-file-text file live))
              (tmp (current-buffer))
              value)
          (set-buffer-modified-p nil)
          (when lisp
            (let ((bad (lisply--unbalanced-line)))
              (when bad
                (error "lisply: %s is unbalanced before the edit (near line %d); nothing written"
                       file bad))))
          (goto-char (point-min))
          (setq value (funcall fn))
          (when (buffer-modified-p)
            (when lisp
              (let ((bad (lisply--unbalanced-line)))
                (when bad
                  (error "lisply: the edit would leave %s unbalanced near line %d; nothing written"
                         file bad))))
            (if live
                (with-current-buffer live
                  (let ((create-lockfiles nil)
                        (before-save-hook nil)
                        (require-final-newline nil)
                        (make-backup-files nil))
                    (save-restriction
                      (widen)
                      (replace-buffer-contents tmp 2))
                    (save-buffer)))
              (let ((coding-system-for-write coding))
                (write-region nil nil file nil 'silent))))
          value)))))

;;; ---- read and search ----

(defun lisply-read (file &optional start end)
  "Return lines START to END of FILE, numbered the way `cat -n' numbers them.
START is 1-based and defaults to 1; END is inclusive and defaults to
the end of the file.  At most `lisply-read-max-lines' lines come back
per call; a trailer gives the range shown and the file's line count."
  (lisply--read-file
   file
   (lambda ()
     (let* ((total (count-lines (point-min) (point-max)))
            (start (max 1 (or start 1)))
            (end (min total (or end total)
                      (+ start lisply-read-max-lines -1)))
            (n start)
            lines)
       (forward-line (1- start))
       (while (and (<= n end) (not (eobp)))
         (push (format "%6d\t%s" n (buffer-substring-no-properties
                                    (line-beginning-position) (line-end-position)))
               lines)
         (setq n (1+ n))
         (forward-line 1))
       (concat (string-join (nreverse lines) "\n")
               (format "\n[%s: lines %d-%d of %d]"
                       (abbreviate-file-name (expand-file-name file))
                       start (1- n) total))))))

(cl-defun lisply-grep (pattern dir &key glob fixed ignore-case
                               (max lisply-grep-max-matches))
  "Search the files under DIR for PATTERN; return the hits as FILE:LINE:TEXT.
PATTERN is a POSIX extended regexp, as `grep -E' reads it, not an Emacs
regexp; with FIXED non-nil it is a literal string.  GLOB, such as
\"*.lisp\", limits the files searched; IGNORE-CASE folds case.  Inside
a git work tree this is `git grep' over tracked and untracked files,
honouring .gitignore; elsewhere it is `grep -r', skipping .git.  Paths
are relative to DIR.  At most MAX hits come back, within
`lisply-grep-timeout' seconds, and a trailer says when either cut the
result short."
  (let* ((dir (file-name-as-directory (expand-file-name dir)))
         (default-directory dir)
         (git (locate-dominating-file dir ".git"))
         (flags (concat (if fixed " -F" " -E") (if ignore-case " -i" "")))
         (command
          (if git
              (format "git grep -n -I --untracked --no-color%s -e %s%s | head -n %d"
                      flags (shell-quote-argument pattern)
                      (if glob (concat " -- " (shell-quote-argument glob)) "")
                      (1+ max))
            (format "grep -rnI --exclude-dir=.git%s%s -e %s . | head -n %d"
                    (if glob (concat " --include=" (shell-quote-argument glob)) "")
                    flags (shell-quote-argument pattern) (1+ max))))
         (result (lisply-shell-bounded command lisply-grep-timeout))
         (lines (split-string (plist-get result :output) "\n" t))
         (more (> (length lines) max))
         (shown (mapcar (lambda (line)
                          (truncate-string-to-width
                           (string-remove-prefix "./" line)
                           lisply-grep-max-line-length nil nil "..."))
                        (seq-take lines max))))
    (concat
     (if shown (string-join shown "\n") (format "[no matches for %s]" pattern))
     (format "\n[%s under %s%s%s]"
             (if git "git grep" "grep -r") (abbreviate-file-name dir)
             (if more (format "; first %d hits only, narrow DIR or GLOB" max) "")
             (if (plist-get result :timed-out)
                 (format "; stopped at %d s, results incomplete" lisply-grep-timeout)
               "")))))

(defun lisply-check-parens (file)
  "Return t when the Lisp FILE balances, else a string naming where it fails."
  (lisply--read-file
   file
   (lambda ()
     (let ((bad (lisply--unbalanced-line)))
       (if bad (format "%s: unbalanced near line %d" file bad) t)))))

;;; ---- edit by exact text ----

(cl-defun lisply-replace (file old new &key (count 1))
  "Replace the literal string OLD with NEW in FILE, exactly COUNT times.
COUNT defaults to 1.  When OLD occurs any other number of times nothing
is written and the error says how many times it does occur, so the
count is the check that the edit lands where it was meant to: give OLD
enough surrounding text to be unique.  Matching is literal and
case-sensitive.  Return (:file FILE :replaced COUNT :lines LINES)."
  (when (string-empty-p old)
    (error "lisply-replace: OLD is empty"))
  (lisply--edit-file
   file
   (lambda ()
     (let ((case-fold-search nil)
           (found 0)
           lines)
       (while (search-forward old nil t)
         (setq found (1+ found)))
       (unless (= found count)
         (error "lisply-replace: %S occurs %d times in %s, expected %d; nothing written"
                (lisply--abbrev old) found file count))
       (goto-char (point-min))
       (while (search-forward old nil t)
         (push (line-number-at-pos (match-beginning 0)) lines)
         (replace-match new t t))
       (list :file file :replaced count :lines (nreverse lines))))))

;;; ---- edit Lisp by top-level form ----

(defun lisply--form-bounds (name kind line)
  "Return (START . END) of the top-level form named NAME in the current buffer.
A top-level form opens with `(' in column 0 outside any string or
comment, and NAME is its second element: (defun NAME ...),
(define-object NAME ...), (defparameter NAME ...).  KIND, a string such
as \"defmethod\", restricts the operator; LINE picks the form starting
on that line.  Signals unless exactly one form qualifies."
  (let ((re (format "^(\\(%s\\)[ \t\n]+'?\\(%s\\)\\_>"
                    (if kind (regexp-quote kind) "[^ \t\n()]+")
                    (regexp-quote name)))
        (case-fold-search t)
        hits)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward re nil t)
        (let* ((beg (match-beginning 0))
               (ppss (save-excursion (syntax-ppss beg))))
          (when (and (zerop (nth 0 ppss)) (not (nth 8 ppss))
                     (or (null line) (= line (line-number-at-pos beg))))
            (push (list beg (line-number-at-pos beg) (match-string-no-properties 1))
                  hits)))))
    (cond
     ((null hits)
      (error "lisply: no top-level form named %s%s%s" name
             (if kind (format " (kind %s)" kind) "")
             (if line (format " at line %d" line) "")))
     ((cdr hits)
      (error "lisply: %d top-level forms named %s, at %s; pass :kind or :line"
             (length hits) name
             (mapconcat (lambda (h) (format "line %d (%s)" (nth 1 h) (nth 2 h)))
                        (nreverse hits) ", ")))
     (t
      (save-excursion
        (goto-char (car (car hits)))
        (condition-case nil
            (forward-sexp)
          (scan-error
           (error "lisply: the form named %s at line %d does not close"
                  name (nth 1 (car hits)))))
        (cons (car (car hits)) (point)))))))

(defun lisply--check-text (text file)
  "Signal unless TEXT, as Lisp of FILE's dialect, balances."
  (with-temp-buffer
    (lisply--setup-mode file)
    (insert text)
    (let ((bad (lisply--unbalanced-line)))
      (when bad
        (error "lisply: the new text is unbalanced near its line %d; nothing written" bad)))))

(cl-defun lisply-form-get (file name &key kind line)
  "Return the text of the top-level form named NAME in FILE.
NAME is the form's second element, so (defun NAME ...) and
(define-object NAME ...) both qualify.  KIND, such as \"defmethod\",
or LINE, where the form starts, settles a name several forms share."
  (lisply--read-file
   file
   (lambda ()
     (let ((b (lisply--form-bounds name kind line)))
       (buffer-substring-no-properties (car b) (cdr b))))))

(cl-defun lisply-form-replace (file name text &key kind line)
  "Replace the top-level form named NAME in FILE with TEXT.
TEXT goes in verbatim, so indent it as it should read; it may hold
more than one form.  It must balance, and so must FILE afterwards, or
nothing is written.  KIND and LINE are as for `lisply-form-get'.
Return (:file FILE :line LINE) for the line the form starts on."
  (lisply--check-text text file)
  (lisply--edit-file
   file
   (lambda ()
     (let ((b (lisply--form-bounds name kind line)))
       (goto-char (car b))
       (delete-region (car b) (cdr b))
       (insert (string-trim text))
       (list :file file :line (line-number-at-pos (car b)))))))

(cl-defun lisply-form-delete (file name &key kind line)
  "Delete the top-level form named NAME from FILE, with one blank line after it.
KIND and LINE are as for `lisply-form-get'.  Return (:file FILE :line LINE)."
  (lisply--edit-file
   file
   (lambda ()
     (let ((b (lisply--form-bounds name kind line)))
       (goto-char (cdr b))
       (skip-chars-forward " \t")
       (when (eq (char-after) ?\n) (forward-char))
       (when (looking-at "[ \t]*\n") (goto-char (match-end 0)))
       (let ((at (line-number-at-pos (car b))))
         (delete-region (car b) (point))
         (list :file file :line at))))))

(cl-defun lisply-form-insert (file text &key before after kind line)
  "Insert TEXT into FILE as new top-level forms, set off by blank lines.
With BEFORE or AFTER naming a top-level form, TEXT goes just before or
just after it (KIND and LINE as for `lisply-form-get'); with neither,
it goes at the end of the file.  TEXT goes in verbatim and must
balance.  Return (:file FILE :line LINE) for the line TEXT starts on."
  (when (and before after)
    (error "lisply-form-insert: give BEFORE or AFTER, not both"))
  (lisply--check-text text file)
  (let ((text (string-trim text)))
    (lisply--edit-file
     file
     (lambda ()
       (cond
        (before
         (goto-char (car (lisply--form-bounds before kind line)))
         (insert text "\n\n")
         (list :file file
               :line (- (line-number-at-pos) (cl-count ?\n text) 2)))
        (after
         (goto-char (cdr (lisply--form-bounds after kind line)))
         (insert "\n\n" text)
         (list :file file
               :line (- (line-number-at-pos) (cl-count ?\n text))))
        (t
         (goto-char (point-max))
         (skip-chars-backward " \t\n")
         (delete-region (point) (point-max))
         (insert (if (bobp) "" "\n\n") text "\n")
         (list :file file
               :line (- (line-number-at-pos) (cl-count ?\n text) 1))))))))

(provide 'lisply-file-tools)
;;; lisply-file-tools.el ends here
