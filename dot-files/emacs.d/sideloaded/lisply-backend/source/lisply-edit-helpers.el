;;; lisply-edit-helpers.el --- Higher-level structural edit helpers  -*- lexical-binding: t; -*-

;; Author: Dave Cooper / Claude (Anthropic)
;; Maintainer: dave@genworks.com
;; Keywords: lisp, tools, editing

;;; Commentary:

;; This module provides a small set of higher-level structural editing
;; helpers for Common Lisp / GDL source files, built on top of paredit-mode.
;; Each helper performs a complete, paren-balanced operation with
;; `check-parens' verification on both entry and exit.
;;
;; Why these exist
;; ---------------
;; The manipulations they perform come up repeatedly when refactoring GDL
;; `define-object' forms (extracting duplicated slots into a mixin,
;; swapping a parent class, adding inputs to child specs, ...).  The
;; naive approach has a footgun worth internalizing:
;;
;;   (search-forward "(slot-name")    ;; point ends up just past `e' of `name'
;;   (backward-char)                   ;; lands on the LAST char of the symbol,
;;                                     ;; NOT on the opening paren!
;;
;; The right pattern is
;;
;;   (re-search-forward "(slot-name\\b")
;;   (goto-char (match-beginning 0))   ;; lands on the `(' as intended
;;
;; The helpers below encapsulate that pattern and the surrounding
;; bookkeeping (line-level deletion, trailing-blank-line cleanup, etc).
;;
;; Loading
;; -------
;; Like `lisply-sexp-write', this is opt-in.  Add
;;
;;   (require 'lisply-edit-helpers)
;;
;; from your MCP `lisp_eval' calls when you need it.

;;; Code:

(require 'paredit nil t)

(defun lisply-kill-named-slot (buffer-or-name slot-name)
  "Delete the (SLOT-NAME ...) spec from BUFFER-OR-NAME, including the
line it sits on and any single immediately-following blank line.

This is the operation you want when removing a slot from a
:computed-slots or :input-slots block — for example to delete a
duplicated default that has migrated up into a parent mixin.

BUFFER-OR-NAME may be a buffer object or a buffer name string.
SLOT-NAME is a string naming the slot (e.g. \"body-class\").

Returns the number of characters deleted, or 0 if no such slot was
found.  Signals an error via `check-parens' if the buffer is unbalanced
before or after the edit."
  (with-current-buffer (get-buffer buffer-or-name)
    (when (fboundp 'paredit-mode) (paredit-mode 1))
    (check-parens)
    (let ((deleted 0))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward
               (format "^[ \t]*(%s\\b" (regexp-quote slot-name))
               nil t)
          (goto-char (match-beginning 0))
          (let ((start (line-beginning-position)))
            (forward-sexp)
            (end-of-line)
            (unless (eobp) (forward-char))
            (when (looking-at "[ \t]*$")
              (forward-line 1))
            (setq deleted (- (point) start))
            (delete-region start (point)))))
      (check-parens)
      deleted)))

(defun lisply-replace-parent-class (buffer-or-name obj-name new-parent)
  "Replace the parent-class list of (define-object OBJ-NAME (...) ...)
with a single-element list containing NEW-PARENT, in BUFFER-OR-NAME.

OBJ-NAME and NEW-PARENT are strings (e.g. \"cows\",
\"base-site-page\").  Multi-mixin headers are overwritten in full —
this helper is for the common case of swapping one parent for another.

Returns t on success, nil if the define-object header was not found.
Signals an error via `check-parens' if the buffer is unbalanced before
or after the edit."
  (with-current-buffer (get-buffer buffer-or-name)
    (when (fboundp 'paredit-mode) (paredit-mode 1))
    (check-parens)
    (let ((found nil))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward
               (format "(define-object %s " (regexp-quote obj-name))
               nil t)
          (let ((list-start (point)))
            (forward-sexp)
            (delete-region list-start (point))
            (insert (format "(%s)" new-parent))
            (setq found t))))
      (check-parens)
      found)))

(defun lisply-add-keyword-to-object-spec (buffer-or-name child-name keyword value-text)
  "Insert ` KEYWORD VALUE-TEXT' just inside the closing paren of the
spec for CHILD-NAME within an :objects (or :hidden-objects) block in
BUFFER-OR-NAME.

CHILD-NAME is the spec name (e.g. \"cows\"), KEYWORD is a string
beginning with a colon (e.g. \":landing-page\"), and VALUE-TEXT is
the Lisp text to insert as the value (e.g. \"self\" or
\"(the parent)\").

This relies on finding the literal substring \":type 'CHILD-NAME)\";
if the spec is shaped differently it returns nil.

Returns t on success, nil if the spec was not found."
  (with-current-buffer (get-buffer buffer-or-name)
    (when (fboundp 'paredit-mode) (paredit-mode 1))
    (check-parens)
    (let ((found nil))
      (save-excursion
        (goto-char (point-min))
        (when (search-forward (format ":type '%s)" child-name) nil t)
          (backward-char)
          (insert (format " %s %s" keyword value-text))
          (setq found t)))
      (check-parens)
      found)))

(provide 'lisply-edit-helpers)
;;; lisply-edit-helpers.el ends here
