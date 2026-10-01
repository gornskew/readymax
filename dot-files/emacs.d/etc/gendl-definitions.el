;;; gendl-definitions.el --- M-. reaches a Gendl type's define-object  -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Commentary:
;;
;; M-. on a Gendl object type lists its `define-object' AND every
;; `define-object-amendment', the original first (gendl/gendl#16).
;;
;; An amendment re-emits the whole defclass from its own file, so the
;; Lisp's record of where the class is defined moves there and plain
;; SLIME only ever offers the newest amendment.  The original is still
;; reachable from what the Lisp already keeps, through the portable
;; swank API: the methods a define-object or an amendment generates for
;; each slot are specialized on the class and keep their own source
;; locations (and CCL keeps one source note per defining file for the
;; class itself).  That gives the set of files; this file reads each one
;; and lists the `define-object' / `define-object-amendment' forms for
;; the name, by line, so the result does not depend on how any one
;; implementation counts character positions.
;;
;; Installed as `slime-find-definitions-function' by slime-config.el.
;; It wraps the stock `slime-find-definitions-rpc' and changes nothing
;; unless the connected Lisp has a GDL package and the name is a Gendl
;; object type: other definitions of the same name (a function, a
;; method) are kept, and so is the stock class entry whenever its file
;; cannot be read from Emacs (sources inside an image).
;;
;; Known limit: an amendment that adds no slots generates no methods,
;; so on SBCL and Allegro it is found only while it is the newest
;; definition of the class.  CCL finds it regardless.

;;; Code:

(require 'cl-lib)

(declare-function slime-eval "slime" (sexp &optional package))
(declare-function slime-find-definitions-rpc "slime" (name))
(declare-function slime-from-lisp-filename "slime" (filename))

(defconst gendl-definitions--lisp-query
  "(lambda (name)
  (multiple-value-bind (sym found) (swank::find-definitions-find-symbol-or-package name)
    (let ((class (and found sym (symbolp sym) (find-class sym nil))))
      (when (and class (typep class 'gdl::gdl-class))
        (let ((files nil))
          (flet ((note-file (file)
                   (when (and file (not (member file files :test #'equal)))
                     (push file files)))
                 (location-file (loc)
                   (when (and (consp loc) (eq (car loc) :location))
                     (let ((buf (second loc)))
                       (case (car buf)
                         (:file (second buf))
                         (:buffer-and-file (third buf)))))))
            (dolist (def (ignore-errors (swank/backend:find-definitions sym)))
              (note-file (location-file (second def))))
            #+ccl
            (dolist (def (ignore-errors (ccl:find-definition-sources sym)))
              (dolist (src (cdr def))
                (when (ccl:source-note-p src)
                  (note-file (ignore-errors
                              (ccl:native-translated-namestring
                               (truename (ccl:source-note-filename src))))))))
            (dolist (m (ignore-errors (swank-mop:specializer-direct-methods class)))
              (note-file (location-file (ignore-errors (swank/backend:find-source-location m))))))
          (list (symbol-name sym) (nreverse files)))))))"
  "Lisp source of a one-argument function, evaluated in the connected Lisp.
Given a symbol name as M-. passes it, it returns (SYMBOL-NAME FILES) when
the name is a Gendl object type, FILES being every source file the Lisp
associates with the type, else nil.  Read in the SWANK package so it
interns nothing in the user's packages.")

(defun gendl-definitions--query (name)
  "Ask the connected Lisp which files define Gendl object type NAME.
Return (SYMBOL-NAME FILES) or nil.  A Lisp without a GDL package, or
any error on the Lisp side, answers nil."
  (slime-eval
   `(cl:ignore-errors
     (cl:when (cl:find-package :gdl)
       (cl:funcall
        (cl:coerce (cl:let ((cl:*package* (cl:find-package :swank)))
                     (cl:read-from-string ,gendl-definitions--lisp-query))
                   'cl:function)
        ,name)))))

(defun gendl-definitions--forms-in-file (file name)
  "Return the define-object forms for NAME in FILE, or :unreadable.
FILE is the Lisp's filename.  Each form is (KIND LINE COLUMN SNIPPET),
KIND being \"define-object\" or \"define-object-amendment\"."
  (let ((local (slime-from-lisp-filename file)))
    (if (not (and (stringp local) (file-readable-p local)))
        :unreadable
      (with-temp-buffer
        (insert-file-contents local)
        (set-syntax-table lisp-mode-syntax-table)
        (let ((case-fold-search t)
              (rx (concat "(\\(?:[^ \t\n()]+:\\{1,2\\}\\)?"
                          "\\(define-object\\(?:-amendment\\)?\\)"
                          "[ \t\n]+\\(?:[^ \t\n()]+:\\{1,2\\}\\)?"
                          (regexp-quote name) "\\_>"))
              (forms nil))
          (goto-char (point-min))
          (while (re-search-forward rx nil t)
            (let ((start (match-beginning 0))
                  (kind (downcase (match-string 1))))
              (unless (save-excursion (nth 8 (syntax-ppss start)))
                (save-excursion
                  (goto-char start)
                  (push (list kind
                              (line-number-at-pos start)
                              (current-column)
                              (buffer-substring-no-properties
                               start (line-end-position)))
                        forms)))))
          (nreverse forms))))))

(defun gendl-definitions--class-dspec-p (dspec)
  "True if DSPEC is the stock class entry, \"(CLASS X)\" or \"(DEFCLASS X)\"."
  (let ((case-fold-search t))
    (and (stringp dspec) (string-match-p "\\`(\\(def\\)?class " dspec))))

(defun gendl-definitions--xref-file (xref)
  "The Lisp filename of XREF's location, or nil."
  (let ((loc (cadr xref)))
    (and (eq (car-safe loc) :location)
         (let ((buf (nth 1 loc)))
           (pcase (car-safe buf)
             (:file (nth 1 buf))
             (:buffer-and-file (nth 2 buf)))))))

(defun gendl-definitions-find (name)
  "Find definitions for NAME, listing a Gendl type's define-object forms.
A `slime-find-definitions-function': the stock xrefs, with a Gendl
object type's class entry replaced by its `define-object' form(s) first
and then each `define-object-amendment', each by file and line."
  (let ((xrefs (slime-find-definitions-rpc name)))
    (condition-case err
        (let ((answer (gendl-definitions--query name)))
          (if (not answer)
              xrefs
            (cl-destructuring-bind (symbol-name files) answer
              ;; FILES comes newest definition first (the stock entry,
              ;; then CCL's notes, newest first), so amendment files are
              ;; listed in reverse: oldest first, close to load order.
              (let ((originals nil) (amendment-groups nil) (scanned nil))
                (dolist (file files)
                  (let ((forms (gendl-definitions--forms-in-file file symbol-name))
                        (amendments nil))
                    (unless (eq forms :unreadable)
                      (push file scanned)
                      (dolist (form forms)
                        (cl-destructuring-bind (kind line column snippet) form
                          (let ((xref
                                 (list (format "(%s %s)"
                                               (if (string= symbol-name (upcase symbol-name))
                                                   (upcase kind)
                                                 kind)
                                               symbol-name)
                                       `(:location (:file ,file) (:line ,line ,column)
                                                   (:snippet ,snippet)))))
                            (if (string= kind "define-object")
                                (push xref originals)
                              (push xref amendments)))))
                      (when amendments
                        (push (nreverse amendments) amendment-groups)))))
                (if (not (or originals amendment-groups))
                    xrefs
                  (append (nreverse originals)
                          (apply #'append amendment-groups)
                          (cl-remove-if
                           (lambda (xref)
                             (and (gendl-definitions--class-dspec-p (car xref))
                                  (member (gendl-definitions--xref-file xref) scanned)))
                           xrefs)))))))
      (error
       (message "gendl-definitions: %s; showing the stock definitions"
                (error-message-string err))
       xrefs))))

(provide 'gendl-definitions)

;;; gendl-definitions.el ends here
