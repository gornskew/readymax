;;; lisply-file-tools-test.el --- Regression tests for lisply-file-tools -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;; Run:  emacs --batch -L . -l lisply-file-tools.el -l lisply-file-tools-test.el \
;;             -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'lisply-file-tools)

(defvar lisply-file-tools-test--source
  "(in-package :demo)

(defun alpha (x)
  \"Doubles X.
(this line opens a paren in column 0 inside a docstring)\"
  (* 2 x))

#| a block comment holding a stray ( paren |#

(define-object box (base-object)
  :computed-slots ((width 10)))

(defmethod area ((b box)) 1)

(defmethod area ((c circle)) 2)
"
  "A Lisp file exercising docstrings, block comments and shared names.")

(defmacro lisply-file-tools-test--with-file (spec &rest body)
  "Bind (VAR CONTENT &optional EXT) to a fresh temp file holding CONTENT."
  (declare (indent 1))
  (let ((var (nth 0 spec)) (content (nth 1 spec)) (ext (or (nth 2 spec) ".lisp")))
    `(let ((,var (make-temp-file "lisply-ft-" nil ,ext ,content)))
       (unwind-protect (progn ,@body)
         (let ((buf (find-buffer-visiting ,var)))
           (when buf
             (with-current-buffer buf (set-buffer-modified-p nil))
             (kill-buffer buf)))
         (delete-file ,var)))))

(defun lisply-file-tools-test--text (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(ert-deftest lisply-file-tools-read-range ()
  (lisply-file-tools-test--with-file (f "one\ntwo\nthree\nfour\n" ".txt")
    (let ((out (lisply-read f 2 3)))
      (should (string-match-p "^     2\ttwo\n     3\tthree\n\\[" out))
      (should (string-match-p "lines 2-3 of 4\\]" out))
      (should-not (string-match-p "four" out)))
    (should (string-match-p "lines 1-4 of 4" (lisply-read f)))
    (let ((lisply-read-max-lines 2))
      (should (string-match-p "lines 1-2 of 4" (lisply-read f))))))

(ert-deftest lisply-file-tools-replace-once ()
  (lisply-file-tools-test--with-file (f "a foo b\nc bar d\n" ".txt")
    (should (equal (plist-get (lisply-replace f "bar" "BAR") :lines) '(2)))
    (should (equal (lisply-file-tools-test--text f) "a foo b\nc BAR d\n"))))

(ert-deftest lisply-file-tools-replace-refuses-wrong-count ()
  (lisply-file-tools-test--with-file (f "x x\n" ".txt")
    (should-error (lisply-replace f "x" "y"))
    (should-error (lisply-replace f "absent" "y"))
    (should (equal (lisply-file-tools-test--text f) "x x\n"))
    (lisply-replace f "x" "y" :count 2)
    (should (equal (lisply-file-tools-test--text f) "y y\n"))))

(ert-deftest lisply-file-tools-replace-does-not-rescan-new-text ()
  (lisply-file-tools-test--with-file (f "ab\n" ".txt")
    (lisply-replace f "a" "aa")
    (should (equal (lisply-file-tools-test--text f) "aab\n"))))

(ert-deftest lisply-file-tools-refuses-unbalancing-edit ()
  (lisply-file-tools-test--with-file (f lisply-file-tools-test--source)
    (should-error (lisply-replace f "(* 2 x))" "(* 2 x)"))
    (should (equal (lisply-file-tools-test--text f) lisply-file-tools-test--source))))

(ert-deftest lisply-file-tools-check-parens ()
  (lisply-file-tools-test--with-file (f lisply-file-tools-test--source)
    (should (eq (lisply-check-parens f) t)))
  (lisply-file-tools-test--with-file (f "(defun broken ()\n  (foo)\n")
    (should (stringp (lisply-check-parens f)))
    (should-error (lisply-replace f "foo" "bar"))))

(ert-deftest lisply-file-tools-form-get-skips-strings-and-comments ()
  (lisply-file-tools-test--with-file (f lisply-file-tools-test--source)
    (should (string-prefix-p "(defun alpha (x)" (lisply-form-get f "alpha")))
    (should (string-suffix-p "(* 2 x))" (lisply-form-get f "alpha")))
    (should (string-prefix-p "(define-object box" (lisply-form-get f "box")))
    (should-error (lisply-form-get f "this"))
    (should-error (lisply-form-get f "missing"))))

(ert-deftest lisply-file-tools-form-shared-name ()
  (lisply-file-tools-test--with-file (f lisply-file-tools-test--source)
    (should-error (lisply-form-get f "area"))
    (let ((second-line (with-temp-buffer
                         (insert lisply-file-tools-test--source)
                         (goto-char (point-min))
                         (search-forward "(defmethod area ((c")
                         (line-number-at-pos))))
      (should (string-match-p "circle" (lisply-form-get f "area" :line second-line))))))

(ert-deftest lisply-file-tools-form-replace-delete-insert ()
  (lisply-file-tools-test--with-file (f lisply-file-tools-test--source)
    (lisply-form-replace f "alpha" "(defun alpha (x)\n  (* 3 x))")
    (should (equal (lisply-form-get f "alpha") "(defun alpha (x)\n  (* 3 x))"))
    (should-error (lisply-form-replace f "alpha" "(defun alpha (x)"))
    (lisply-form-insert f "(defun beta () 'b)" :after "alpha")
    (should (string-match-p "(\\* 3 x))\n\n(defun beta () 'b)\n\n#|"
                            (lisply-file-tools-test--text f)))
    (lisply-form-insert f "(defun omega () 'z)")
    (should (string-suffix-p "2)\n\n(defun omega () 'z)\n" (lisply-file-tools-test--text f)))
    (lisply-form-delete f "beta")
    (should-not (string-match-p "beta" (lisply-file-tools-test--text f)))
    (should (string-match-p "(\\* 3 x))\n\n#|" (lisply-file-tools-test--text f)))
    (should (eq (lisply-check-parens f) t))))

(ert-deftest lisply-file-tools-edits-through-live-buffer ()
  (lisply-file-tools-test--with-file (f "(defun alpha () 1)\n")
    (let ((buf (find-file-noselect f)))
      (lisply-replace f "1" "2")
      (should (equal (with-current-buffer buf (buffer-string)) "(defun alpha () 2)\n"))
      (should-not (buffer-modified-p buf))
      (should (verify-visited-file-modtime buf))
      (should (equal (lisply-file-tools-test--text f) "(defun alpha () 2)\n"))
      (should-not (file-exists-p (concat f "~")))
      (with-current-buffer buf (goto-char (point-max)) (insert ";; unsaved"))
      (should-error (lisply-replace f "2" "3"))
      (should (equal (lisply-file-tools-test--text f) "(defun alpha () 2)\n")))))

(ert-deftest lisply-file-tools-leaves-no-buffer ()
  (lisply-file-tools-test--with-file (f "(defun alpha () 1)\n")
    (let ((before (length (buffer-list))))
      (lisply-read f)
      (lisply-replace f "1" "2")
      (lisply-form-get f "alpha")
      (should (= before (length (buffer-list))))
      (should-not (find-buffer-visiting f)))))

(ert-deftest lisply-file-tools-grep-plain-dir ()
  (let ((dir (make-temp-file "lisply-ft-dir-" t)))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "a.lisp" dir) (insert "(defun needle ())\nhay\n"))
          (with-temp-file (expand-file-name "b.txt" dir) (insert "needle too\n"))
          (let ((all (lisply-grep "needle" dir)))
            (should (string-match-p "^a.lisp:1:(defun needle" all))
            (should (string-match-p "^b.txt:1:needle too" all)))
          (let ((lisp (lisply-grep "needle" dir :glob "*.lisp")))
            (should (string-match-p "a.lisp" lisp))
            (should-not (string-match-p "b.txt" lisp)))
          (should (string-match-p "first 1 hits only" (lisply-grep "needle" dir :max 1)))
          (should (string-match-p "no matches" (lisply-grep "absent-word" dir))))
      (delete-directory dir t))))

(ert-deftest lisply-file-tools-help-lists-toolkit ()
  (let ((help (lisply-help)))
    (dolist (sym '(lisply-read lisply-grep lisply-replace lisply-form-replace))
      (should (string-match-p (symbol-name sym) help))))
  (should (string-match-p "exactly COUNT times" (lisply-help 'lisply-replace))))

(provide 'lisply-file-tools-test)
;;; lisply-file-tools-test.el ends here
