;;; gendl-doc-fold.el --- Fold slot documentation out of Gendl define-object forms  -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Commentary:
;;
;; `gendl-doc-fold-mode' folds the documentation strings of Gendl slot
;; specs away, so a `define-object' reads as its code:
;;
;;   ("Spring rate at the axle seat, N/mm" spring-rate (/ ...))
;;
;; shows as
;;
;;   (... spring-rate (/ ...))
;;
;; and a doc on a line of its own above the name folds together with the
;; line break, so the name moves up beside the paren.
;;
;; Only the strings the define-object grammar reads as documentation are
;; folded: leading strings in an item of :input-slots, :computed-slots,
;; :objects, :hidden-objects, :functions, :methods or
;; :trickle-down-slots, and a string standing alone in a section before
;; the item it documents (gendl-mop/source/define-object.lisp,
;; `parse-slot-items').  Format strings, :color names, string defaults
;; and docstrings inside function bodies are left alone.
;;
;; Folds are overlays: the buffer text, its undo history and its
;; modified flag are untouched, so the mode is safe on a buffer someone
;; else is visiting too.
;;
;; The documentation stays reachable:
;; - eldoc shows a slot's doc while point is on its name;
;; - the mouse shows it over the name (help-echo);
;; - isearch opens a fold it finds a match in;
;; - `gendl-doc-fold-show' echoes the doc at point or on its line;
;; - `gendl-doc-fold-toggle-style' switches between hiding the docs and
;;   only dimming them in place.
;;
;; Folds follow edits: the buffer is refolded when Emacs goes idle after
;; a change, and a doc string point is inside is left open, so a doc
;; being typed does not vanish under the cursor.

;;; Code:

(require 'cl-lib)

(defgroup gendl-doc-fold nil
  "Fold slot documentation in Gendl define-object forms."
  :group 'lisp
  :prefix "gendl-doc-fold-")

(defcustom gendl-doc-fold-style 'hide
  "How `gendl-doc-fold-mode' shows slot documentation.
`hide' folds each doc string behind an ellipsis; `dim' leaves it in
place in the `gendl-doc-fold-dim' face."
  :type '(choice (const :tag "Hide behind an ellipsis" hide)
                 (const :tag "Dim in place" dim)))

(defcustom gendl-doc-fold-sections
  '(:input-slots :computed-slots :objects :hidden-objects
    :functions :methods :trickle-down-slots)
  "The define-object sections whose item documentation is folded."
  :type '(repeat symbol))

(defcustom gendl-doc-fold-defining-forms
  '("define-object" "define-object-amendment")
  "Operators of the forms scanned, matched with or without a package prefix."
  :type '(repeat string))

(defcustom gendl-doc-fold-idle-delay 0.4
  "Seconds of idle time after a change before the buffer is refolded."
  :type 'number)

(defface gendl-doc-fold-dim
  '((t :inherit shadow))
  "Face for slot documentation when `gendl-doc-fold-style' is `dim'.")

(defvar-local gendl-doc-fold--timer nil
  "The pending idle refold for this buffer, or nil.")

(defvar gendl-doc-fold-mode)            ; defined by the minor mode below

;;;; Scanning

(defun gendl-doc-fold--form-regexp ()
  "Regexp for the opening of a defining form at the start of a line."
  (concat "^(\\(?:[[:alnum:]-]+::?\\)?"
          (regexp-opt gendl-doc-fold-defining-forms)
          "\\_>"))

(defun gendl-doc-fold--skip ()
  "Move point past whitespace and comments."
  (forward-comment (buffer-size)))

(defun gendl-doc-fold--fold-string (str-beg keep-open)
  "Fold the documentation string starting at STR-BEG; return its end.
The fold runs through the whitespace after the string but one
character, so the name it documents keeps a space before it.  The
fold is made open when position KEEP-OPEN lies inside it."
  (let* ((str-end (scan-sexps str-beg 1))
         (doc (ignore-errors
                (car (read-from-string
                      (buffer-substring-no-properties str-beg str-end)))))
         (next (save-excursion
                 (goto-char str-end)
                 (skip-chars-forward " \t\n")
                 (point)))
         (fold-end (if (> next str-end) (1- next) str-end))
         (ov (make-overlay str-beg fold-end nil t nil)))
    (overlay-put ov 'gendl-doc-fold t)
    (overlay-put ov 'evaporate t)
    (if (eq gendl-doc-fold-style 'dim)
        (overlay-put ov 'face 'gendl-doc-fold-dim)
      (unless (and keep-open (<= str-beg keep-open fold-end))
        (overlay-put ov 'invisible 'gendl-doc-fold))
      (overlay-put ov 'isearch-open-invisible #'gendl-doc-fold--open)
      (overlay-put ov 'isearch-open-invisible-temporary
                   #'gendl-doc-fold--open-temporary))
    (when (stringp doc)
      (overlay-put ov 'help-echo doc)
      ;; Hang the doc on the name it documents as well, for eldoc and
      ;; the mouse.
      (let ((name-end (and (< next (point-max))
                           (not (memq (char-after next) '(?\( ?\) ?\")))
                           (ignore-errors (scan-sexps next 1)))))
        (when name-end
          (let ((name-ov (make-overlay next name-end nil t nil)))
            (overlay-put name-ov 'gendl-doc-fold t)
            (overlay-put name-ov 'evaporate t)
            (overlay-put name-ov 'gendl-doc-fold-doc doc)
            (overlay-put name-ov 'help-echo doc)))))
    str-end))

(defun gendl-doc-fold--scan-items (beg end keep-open)
  "Fold item documentation in a section list whose contents run BEG..END.
KEEP-OPEN is passed to `gendl-doc-fold--fold-string'."
  (goto-char beg)
  (gendl-doc-fold--skip)
  (while (< (point) end)
    (let ((item (point)))
      (pcase (char-after item)
        (?\"                            ; "doc" before a bare item
         (goto-char (gendl-doc-fold--fold-string item keep-open)))
        (?\(                            ; ("doc" name ...)
         (let ((item-end (scan-sexps item 1)))
           (goto-char (1+ item))
           (gendl-doc-fold--skip)
           (while (eq (char-after) ?\")
             (goto-char (gendl-doc-fold--fold-string (point) keep-open))
             (gendl-doc-fold--skip))
           (goto-char item-end)))
        (_ (forward-sexp 1))))
    (gendl-doc-fold--skip)))

(defun gendl-doc-fold--scan-form (form-beg keep-open)
  "Fold the documentation in the defining form starting at FORM-BEG.
Return the end of the form.  KEEP-OPEN is passed to
`gendl-doc-fold--fold-string'."
  (let ((form-end (scan-sexps form-beg 1)))
    (save-excursion
      (goto-char (1+ form-beg))
      (forward-sexp 3)                  ; operator, name, mixin list
      (gendl-doc-fold--skip)
      (while (< (point) (1- form-end))
        (if (not (eq (char-after) ?:))
            (forward-sexp 1)
          (let* ((key-beg (point))
                 (key (progn (forward-sexp 1)
                             (intern (downcase (buffer-substring-no-properties
                                                key-beg (point)))))))
            (gendl-doc-fold--skip)
            (let* ((value-beg (point))
                   (value-end (scan-sexps value-beg 1)))
              (when (and (memq key gendl-doc-fold-sections)
                         (eq (char-after value-beg) ?\())
                (save-excursion
                  (gendl-doc-fold--scan-items (1+ value-beg) (1- value-end)
                                              keep-open)))
              (goto-char value-end))))
        (gendl-doc-fold--skip)))
    form-end))

(defun gendl-doc-fold--remove ()
  "Remove every fold in the buffer."
  (save-restriction
    (widen)
    (remove-overlays (point-min) (point-max) 'gendl-doc-fold t)))

(defun gendl-doc-fold--refold ()
  "Fold the slot documentation of every defining form in the buffer.
A form that does not read (half typed, say) is skipped."
  (let ((keep-open (point))
        (case-fold-search t)
        (re (gendl-doc-fold--form-regexp)))
    (gendl-doc-fold--remove)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward re nil t)
          (let ((form-beg (match-beginning 0))
                (after-match (match-end 0)))
            (goto-char
             (or (and (not (nth 8 (syntax-ppss form-beg)))
                      (condition-case nil
                          (gendl-doc-fold--scan-form form-beg keep-open)
                        (scan-error nil)))
                 after-match))))))))

;;;; Following edits

(defun gendl-doc-fold--after-change (&rest _)
  "Schedule a refold of this buffer for the next idle moment."
  (unless gendl-doc-fold--timer
    (setq gendl-doc-fold--timer
          (run-with-idle-timer gendl-doc-fold-idle-delay nil
                               #'gendl-doc-fold--idle (current-buffer)))))

(defun gendl-doc-fold--idle (buffer)
  "Refold BUFFER if the mode is still on there."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq gendl-doc-fold--timer nil)
      (when gendl-doc-fold-mode
        (gendl-doc-fold--refold)))))

;;;; Reaching the documentation

(defun gendl-doc-fold--open (ov)
  "Leave fold OV open: isearch ended inside it."
  (overlay-put ov 'invisible nil))

(defun gendl-doc-fold--open-temporary (ov hide-p)
  "Open fold OV while isearch visits it; close it again when HIDE-P."
  (overlay-put ov 'invisible (and hide-p 'gendl-doc-fold)))

(defun gendl-doc-fold--doc-at (pos)
  "The folded documentation of the slot name at or just before POS."
  (cl-some (lambda (ov) (overlay-get ov 'gendl-doc-fold-doc))
           (append (overlays-at pos)
                   (and (> pos (point-min)) (overlays-at (1- pos))))))

(defun gendl-doc-fold--eldoc (&rest _)
  "An `eldoc-documentation-functions' entry: the doc of the slot at point."
  (gendl-doc-fold--doc-at (point)))

(defun gendl-doc-fold-show ()
  "Echo the folded documentation at point, or else the first on its line."
  (interactive)
  (let ((doc (or (gendl-doc-fold--doc-at (point))
                 (cl-some (lambda (ov)
                            (and (overlay-get ov 'gendl-doc-fold)
                                 (overlay-get ov 'help-echo)))
                          (overlays-in (line-beginning-position)
                                       (line-end-position))))))
    (message "%s" (or doc "No folded documentation here"))))

(defun gendl-doc-fold-toggle-style ()
  "Switch this buffer between hiding slot documentation and dimming it."
  (interactive)
  (setq-local gendl-doc-fold-style
              (if (eq gendl-doc-fold-style 'dim) 'hide 'dim))
  (when gendl-doc-fold-mode
    (gendl-doc-fold--refold))
  (message "gendl-doc-fold: %s" gendl-doc-fold-style))

;;;; The mode

;;;###autoload
(define-minor-mode gendl-doc-fold-mode
  "Fold the slot documentation out of Gendl define-object forms.
Each doc string of an :input-slots, :computed-slots, :objects,
:hidden-objects, :functions, :methods or :trickle-down-slots item is
folded behind an ellipsis (or dimmed: `gendl-doc-fold-toggle-style'),
so the forms read as their code.  The buffer text is not changed.
eldoc shows a slot's doc while point is on its name, and
`gendl-doc-fold-show' echoes the doc on the current line."
  :lighter " DocFold"
  (cond
   (gendl-doc-fold-mode
    (add-to-invisibility-spec '(gendl-doc-fold . t))
    (add-hook 'after-change-functions #'gendl-doc-fold--after-change nil t)
    (add-hook 'eldoc-documentation-functions #'gendl-doc-fold--eldoc -50 t)
    (gendl-doc-fold--refold))
   (t
    (remove-hook 'after-change-functions #'gendl-doc-fold--after-change t)
    (remove-hook 'eldoc-documentation-functions #'gendl-doc-fold--eldoc t)
    (when gendl-doc-fold--timer
      (cancel-timer gendl-doc-fold--timer)
      (setq gendl-doc-fold--timer nil))
    (remove-from-invisibility-spec '(gendl-doc-fold . t))
    (gendl-doc-fold--remove))))

(provide 'gendl-doc-fold)

;;; gendl-doc-fold.el ends here
