;;; lisply-secret-test.el --- Tests for the /lisply shared secret -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;; Run in batch only -- the last test starts an httpd of its own:
;;   emacs --batch -L . -l lisply-secret-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'url)
(require 'lisply-secret)

(defmacro lisply-secret-test--with (bindings &rest body)
  "Run BODY with no secret anywhere but what BINDINGS set.
BINDINGS is a plist of :var, :env and :file."
  (declare (indent 1))
  `(let ((emacs-lisply-secret ,(plist-get bindings :var))
         (emacs-lisply--secret-file-cache nil)
         (process-environment (copy-sequence process-environment)))
     (setenv "GENDL_LISPLY_SECRET" ,(plist-get bindings :env))
     (setenv "GENDL_LISPLY_SECRET_FILE" ,(plist-get bindings :file))
     ,@body))

(defun lisply-secret-test--request (path &rest headers)
  "A parsed request for PATH carrying HEADERS, (NAME VALUE) lists."
  `(("POST" ,path "HTTP/1.1") ("Host" "ready-room:7080") ,@headers))

(defun lisply-secret-test--passes (path &rest headers)
  "True when the filter lets a request for PATH with HEADERS through."
  (let ((request (apply #'lisply-secret-test--request path headers)))
    (eq (emacs-lisply--secret-filter request) request)))

;; The servlets the filter judges by; the end-to-end test answers on them.
(defun httpd/lisply/ping-lisp (proc _path _query _request)
  (with-temp-buffer (insert "pong") (httpd-send-header proc "text/plain" 200)))
(defun httpd/lisply/lisp-eval (proc _path _query _request)
  (with-temp-buffer (insert "{}") (httpd-send-header proc "application/json" 200)))
(defun httpd/elsewhere (proc _path _query _request)
  (with-temp-buffer (insert "ok") (httpd-send-header proc "text/plain" 200)))

(ert-deftest lisply-secret-none-leaves-the-doors-open ()
  (lisply-secret-test--with ()
    (should (null (emacs-lisply-secret)))
    (should (null (emacs-lisply-secret-headers)))
    (should (lisply-secret-test--passes "/lisply/lisp-eval"))))

(ert-deftest lisply-secret-variable-guards-all-but-the-ping ()
  (lisply-secret-test--with (:var "s3cret")
    (should-not (lisply-secret-test--passes "/lisply/lisp-eval"))
    (should-not (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "nope")))
    (should (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "s3cret")))
    (should (lisply-secret-test--passes "/lisply/lisp-eval" '("x-lisply-secret" "s3cret")))
    (should (lisply-secret-test--passes "/lisply/ping-lisp"))
    (should (lisply-secret-test--passes "/elsewhere"))
    (should (equal (emacs-lisply-secret-headers) '(("X-Lisply-Secret" . "s3cret"))))))

(ert-deftest lisply-secret-judges-the-servlet-not-the-spelling ()
  (lisply-secret-test--with (:var "s3cret")
    (should-not (lisply-secret-test--passes "/lisply/lisp-eval?x=1"))
    (should-not (lisply-secret-test--passes "/lisply/lisp-eval/"))
    (should-not (lisply-secret-test--passes "/lisply/lisp%2Deval"))
    (should-not (lisply-secret-test--passes "/lisply/lisp-eval/deeper"))))

(ert-deftest lisply-secret-from-the-environment ()
  (lisply-secret-test--with (:env "env-s3cret")
    (should-not (lisply-secret-test--passes "/lisply/lisp-eval"))
    (should (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "env-s3cret")))))

(ert-deftest lisply-secret-from-a-file-rotates-and-fails-closed ()
  (let ((file (make-temp-file "lisply-secret-" nil nil "file-one\n")))
    (unwind-protect
        (lisply-secret-test--with (:file file)
          (should (equal (emacs-lisply-secret) "file-one"))
          (should (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "file-one")))
          ;; a rotation is heard at once: the size changes with it here,
          ;; and the mtime does in life
          (write-region "file-two-rotated\n" nil file nil 'silent)
          (should-not (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "file-one")))
          (should (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "file-two-rotated")))
          ;; a blank file is no secret: closed
          (write-region "\n" nil file nil 'silent)
          (should (eq (emacs-lisply-secret) :unavailable))
          (should-not (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "")))
          (should (null (emacs-lisply-secret-headers)))
          ;; a named file gone missing: closed, the ping still open
          (delete-file file)
          (should (eq (emacs-lisply-secret) :unavailable))
          (should-not (lisply-secret-test--passes "/lisply/lisp-eval" '("X-Lisply-Secret" "file-two-rotated")))
          (should (lisply-secret-test--passes "/lisply/ping-lisp")))
      (when (file-exists-p file) (delete-file file)))))

(ert-deftest lisply-secret-variable-wins-over-the-environment ()
  (lisply-secret-test--with (:var "var-s3cret" :env "env-s3cret")
    (should (equal (emacs-lisply-secret) "var-s3cret"))))

(ert-deftest lisply-secret-over-http ()
  "Round trips through a real simple-httpd on a spare port."
  (let ((httpd-port 17991) (httpd-host "127.0.0.1")
        (httpd-servlets t) (httpd-root (make-temp-file "lisply-secret-root-" t))
        (url-show-status nil) (inhibit-message t))
    (cl-flet ((status (path &optional secret)
                (let* ((url-request-method "POST")
                       (url-request-data "{}")
                       (url-request-extra-headers
                        (and secret (list (cons "X-Lisply-Secret" secret))))
                       (buf (url-retrieve-synchronously
                             (format "http://127.0.0.1:17991%s" path) t t 5)))
                  (prog1 (and buf (with-current-buffer buf url-http-response-status))
                    (when buf (kill-buffer buf))))))
      (unwind-protect
          (progn
            (httpd-start)
            (lisply-secret-test--with (:var "s3cret")
              (should (equal (status "/lisply/lisp-eval") 403))
              (should (equal (status "/lisply/lisp-eval" "nope") 403))
              (should (equal (status "/lisply/lisp-eval" "s3cret") 200))
              (should (equal (status "/lisply/ping-lisp") 200))
              (should (equal (status "/elsewhere") 200)))
            (lisply-secret-test--with ()
              (should (equal (status "/lisply/lisp-eval") 200))))
        (httpd-stop)
        (delete-directory httpd-root t)))))

(provide 'lisply-secret-test)
;;; lisply-secret-test.el ends here
