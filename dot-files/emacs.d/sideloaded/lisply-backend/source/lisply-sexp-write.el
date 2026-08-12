;;; lisply-sexp-write.el --- Structurally author balanced Lisp source files  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.


;; Author: Dave Cooper / Claude (Anthropic)
;; Maintainer: dave@genworks.com
;; Keywords: lisp, tools, files

;;; Commentary:

;; This module solves a specific reliability problem that comes up when an AI
;; agent (or any program) needs to author Common Lisp source files via the
;; lisply-backend MCP.
;;
;; THE PROBLEM
;; -----------
;; The natural approach — generate the file's text as a string (heredoc, format,
;; or concatenation) and write it to disk — is fragile.  Long Lisp forms have
;; deep nesting; the closing-paren counts at the end of a file are easy to get
;; wrong by one, and the failure mode is invisible until something later tries
;; to read the file.  The agent then has to debug paren counts at character
;; offsets, which it is bad at.
;;
;; THE INSIGHT
;; -----------
;; In Emacs Lisp, a quoted list literal is BALANCED BY CONSTRUCTION.  The elisp
;; reader will refuse to construct an unbalanced list.  So if you build your
;; Common Lisp form as an elisp data structure first, paren-balance becomes
;; impossible to get wrong — the elisp reader has already enforced it before
;; you even reach the serialization step.
;;
;; CL and elisp share enough surface syntax that the round-trip works:
;;
;;   (define-object foo (base-html-page)
;;     :computed-slots
;;     ((title "Hi")
;;      (body (with-lhtml-string ()
;;              ((:h1 :class "text-2xl") "Hello")))))
;;
;; is valid elisp data AND valid Common Lisp source.  Keywords, strings,
;; symbols, nested lists, and Unicode all round-trip cleanly.
;;
;; USAGE
;; -----
;;   (lisply-write-sexp-file
;;    "/path/to/file.lisp"
;;    "my-package"
;;    '((define-object foo (base-html-page)
;;        :computed-slots
;;        ((title "Hello")
;;         (body ...)))))
;;
;; The function:
;;   1. Writes (in-package :MY-PACKAGE) at the top.
;;   2. Pretty-prints each form via `pp'.
;;   3. Cleans up two cosmetic things pp gets wrong for CL: empty arg
;;      lists print as `nil' (restored to `()' in known idioms) and section
;;      keywords inside define-object get newlines.
;;   4. Reindents with lisp-mode.
;;   5. Runs `check-parens'.  This is a redundant safety net — the form was
;;      balanced by construction — but it catches surprises and proves
;;      correctness to the caller.
;;   6. Saves the buffer.
;;
;; WHEN TO USE THIS
;; ----------------
;; Use `lisply-write-sexp-file' when:
;;   - Creating a new CL/Gendl source file from scratch.
;;   - Wholesale-rewriting an existing file where no inline comments need
;;     to be preserved.
;;   - Generating boilerplate (publishing setup, package definitions, ASDF
;;     stubs, etc.).
;;
;; DO NOT use it when:
;;   - Making a localized change to an existing file — use paredit /
;;     `kill-sexp' and structural navigation instead (see the lisply-backend
;;     CLAUDE.md section "Safe Lisp Code Editing with Paredit").
;;   - You need to preserve inline `;;' comments inside the form being
;;     replaced — `pp' is operating on the AST and drops comments.
;;   - The form is small enough that a structural edit is cheaper.
;;
;; LARGE FORMS: AVOIDING MCP TIMEOUTS
;; ----------------------------------
;; Very large forms can exceed the MCP call payload comfort zone and time
;; out before completion.  The workaround that works reliably:
;;
;;   ;; Call 1: store the heavy body in a variable.
;;   (setq my-body '((:main :class "...")
;;                   ((:h1 :class "...") "Title")
;;                   ...))
;;
;;   ;; Call 2: write the file, splicing the body in via backtick/comma.
;;   (lisply-write-sexp-file
;;    "/path/file.lisp"
;;    "my-package"
;;    (list `(define-object foo (base-html-page)
;;             :computed-slots
;;             ((title "...")
;;              (body (with-lhtml-string () ,my-body))))))
;;
;; A FOOTGUN WORTH KNOWING
;; -----------------------
;; The lisply-backend `lisp_eval' endpoint reads ONE top-level form per call.
;; Multiple top-level forms in the same payload silently drop everything after
;; the first.  Always wrap multi-form payloads in `(progn ...)'.

;;; Code:

(require 'pp)
(require 'lisp-mode)

(defgroup lisply-sexp-write nil
  "Author balanced Lisp source files from elisp data structures."
  :group 'lisp)

(defcustom lisply-sexp-write-fill-column 200
  "Fill column used while pretty-printing.

The default `pp' / `fill-column' of 70 wraps long Tailwind class strings
and href attributes mid-keyword, producing ugly output.  Widening keeps
attribute/value pairs together on one line."
  :type 'integer
  :group 'lisply-sexp-write)

(defcustom lisply-sexp-write-section-keywords
  '(":input-slots" ":computed-slots" ":objects" ":hidden-objects"
    ":functions" ":pseudo-inputs" ":documentation" ":methods"
    ":default-initargs" ":trickle-down-slots")
  "Define-object section keywords to break onto their own line for readability."
  :type '(repeat string)
  :group 'lisply-sexp-write)

(defcustom lisply-sexp-write-nil-to-empty-list-prefixes
  '("(with-lhtml-string nil"
    "(with-cl-who-string nil")
  "Idioms where `pp' prints `nil' for an empty arg list; restore `()' for these.

Add other macro names whose empty arg-list convention is `()' rather
than `nil'.  This is a purely cosmetic substitution."
  :type '(repeat string)
  :group 'lisply-sexp-write)

(defun lisply-pp-sexp-to-string (form)
  "Return FORM pretty-printed as a string, suitable for CL source.

Configures print-* variables so that Unicode characters survive
round-tripping (no `\\uXXXX' escaping) and lists/strings of arbitrary
size are printed in full."
  (with-temp-buffer
    (let ((print-escape-newlines nil)
          (print-escape-multibyte nil)
          (print-length nil)
          (print-level nil)
          (print-quoted t)
          (fill-column lisply-sexp-write-fill-column)
          (pp-max-width lisply-sexp-write-fill-column))
      (pp form (current-buffer)))
    (buffer-string)))

(defun lisply-write-sexp-file (path package-name forms)
  "Write PATH as a Common Lisp source file.

The file gets `(in-package :PACKAGE-NAME)' at the top, followed by each
form in FORMS pretty-printed via `pp'.

FORMS is a list of elisp lists — balanced by construction.  Strings,
keywords, symbols and Unicode round-trip cleanly into Common Lisp.

Returns a plist describing the outcome:
  (:ok t :path PATH :size BYTES :lines N)             on success
  (:ok nil :path PATH :err MSG)                       on `check-parens' failure

`check-parens' is the last gate — the form was already balanced when it
was constructed, so a failure here usually means cosmetic post-processing
broke something and should be investigated."
  ;; Kill any pre-existing buffer to avoid stale state.
  (let ((existing (get-file-buffer path)))
    (when existing (kill-buffer existing)))
  (with-current-buffer (find-file-noselect path)
    (set-buffer-file-coding-system 'utf-8)
    (erase-buffer)
    (insert (format "(in-package :%s)\n\n" package-name))
    (dolist (form forms)
      (insert (lisply-pp-sexp-to-string form))
      (insert "\n"))
    ;; Cosmetic: restore () for known empty-arg-list idioms.
    (dolist (idiom lisply-sexp-write-nil-to-empty-list-prefixes)
      (let* ((needle idiom)
             (replacement (replace-regexp-in-string " nil\\'" " ()" needle)))
        (goto-char (point-min))
        (while (search-forward needle nil t)
          (replace-match replacement t t))))
    ;; Cosmetic: put each define-object section keyword on its own line.
    (dolist (kw lisply-sexp-write-section-keywords)
      (goto-char (point-min))
      (while (re-search-forward (concat " " (regexp-quote kw) "$") nil t)
        (replace-match (concat "\n\n  " kw) t t)))
    ;; Reindent under lisp-mode.
    (let ((fill-column lisply-sexp-write-fill-column))
      (lisp-mode)
      (indent-region (point-min) (point-max)))
    (condition-case err
        (progn
          (check-parens)
          (save-buffer)
          (list :ok t
                :path path
                :size (buffer-size)
                :lines (count-lines (point-min) (point-max))))
      (error
       (list :ok nil
             :path path
             :err (format "%s" err))))))

(provide 'lisply-sexp-write)
;;; lisply-sexp-write.el ends here
