;;; lisply-secret.el --- An optional shared secret on the /lisply endpoints -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;; `lisp-eval' evaluates any Emacs Lisp it is sent, so a server whose
;; port can be reached by anyone else should require a shared secret.
;; When one is configured, every /lisply servlet except the ping answers
;; only a request carrying it in the X-Lisply-Secret header, and answers
;; 403 to any other.  The ping stays open: it answers only "pong", and
;; container healthchecks and watchdogs ask it without a secret.
;;
;; The secret is `emacs-lisply-secret' when that is a non-empty string,
;; else the environment variable GENDL_LISPLY_SECRET, else the first
;; line of the file named by GENDL_LISPLY_SECRET_FILE -- the names the
;; Gendl lisply backend reads, so a stack tells every room once.  All are
;; read per request, the file again whenever it changes, so rotating the
;; secret needs no restart.  A named file that cannot be read, or holds
;; no secret, keeps the endpoints closed.  With none set the endpoints
;; stay open, as before.
;;
;; The check sits on `httpd-filter-functions' and judges the servlet a
;; request resolves to, not its spelling, so no variant of a path
;; reaches a guarded servlet around it.

;; Tests: emacs --batch -L . -l lisply-secret-test.el -f ert-run-tests-batch-and-exit

(require 'cl-lib)
(require 'subr-x)
(require 'simple-httpd)

(defcustom emacs-lisply-secret nil
  "Shared secret the /lisply endpoints require, or nil.
See lisply-secret.el for the environment variables read when this is nil."
  :type '(choice (const :tag "None" nil) string)
  :group 'emacs-lisply)

(defconst emacs-lisply-secret-header "X-Lisply-Secret"
  "The request header that carries the secret.")

(defvar emacs-lisply--secret-file-cache nil
  "(FILE MTIME SIZE SECRET) from the last read of the secret file.")

(defun emacs-lisply--secret-from-file (file)
  "The first line of FILE, trimmed, read again only when FILE changes.
:unavailable when FILE cannot be read or its first line is blank."
  (let ((attrs (file-attributes file)))
    (if (not (and attrs (file-readable-p file)))
        :unavailable
      (let ((mtime (file-attribute-modification-time attrs))
            (size (file-attribute-size attrs))
            (cache emacs-lisply--secret-file-cache))
        (if (and cache
                 (equal (nth 0 cache) file)
                 (equal (nth 1 cache) mtime)
                 (equal (nth 2 cache) size))
            (nth 3 cache)
          (let* ((line (condition-case nil
                           (with-temp-buffer
                             (insert-file-contents file nil 0 4096)
                             (goto-char (point-min))
                             (string-trim (buffer-substring-no-properties
                                           (point-min) (line-end-position))))
                         (error nil)))
                 (secret (if (and line (not (string-empty-p line))) line :unavailable)))
            (setq emacs-lisply--secret-file-cache (list file mtime size secret))
            secret))))))

(defun emacs-lisply-secret ()
  "The secret the /lisply endpoints require.
Nil when none is configured, a string, or :unavailable when a secret
file was named but cannot be read (the endpoints are then closed)."
  (let ((env (getenv "GENDL_LISPLY_SECRET"))
        (file (getenv "GENDL_LISPLY_SECRET_FILE")))
    (cond ((and (stringp emacs-lisply-secret)
                (not (string-empty-p emacs-lisply-secret)))
           emacs-lisply-secret)
          ((and env (not (string-empty-p env))) env)
          ((and file (not (string-empty-p file)))
           (emacs-lisply--secret-from-file file))
          (t nil))))

(defun emacs-lisply-secret-headers ()
  "Headers carrying this room's secret to another room's /lisply
endpoints, as an alist for `url-request-extra-headers'; nil when no
usable secret is configured."
  (let ((secret (emacs-lisply-secret)))
    (and (stringp secret)
         (list (cons emacs-lisply-secret-header secret)))))

(defun emacs-lisply-authorized-p (request)
  "True when no secret is required, or REQUEST carries it."
  (let ((secret (emacs-lisply-secret)))
    (cond ((null secret) t)
          ((eq secret :unavailable) nil)
          (t (let ((given (cadr (assoc-string emacs-lisply-secret-header
                                              (cdr request) t))))
               (and (stringp given) (string= given secret)))))))

(defun emacs-lisply--guarded-servlet-p (servlet)
  "True for SERVLET when it is a /lisply servlet other than the ping."
  (and (symbolp servlet)
       (let ((name (symbol-name servlet)))
         (and (or (string= name "httpd/lisply")
                  (string-prefix-p "httpd/lisply/" name))
              (not (string= name "httpd/lisply/ping-lisp"))))))

(defconst emacs-lisply--forbidden-request
  '(("GET" "/lisply-forbidden" "HTTP/1.1") ("Connection" "close"))
  "What a refused request is replaced with.")

(defun emacs-lisply--secret-filter (request)
  "On `httpd-filter-functions': REQUEST itself when it may pass, else a
request for `httpd/lisply-forbidden'.  A request that cannot be judged
is refused."
  (condition-case nil
      (let* ((path (car (httpd-parse-uri (concat (cadar request)))))
             (servlet (httpd-get-servlet path)))
        (if (or (not (emacs-lisply--guarded-servlet-p servlet))
                (emacs-lisply-authorized-p request))
            request
          emacs-lisply--forbidden-request))
    (error emacs-lisply--forbidden-request)))

(defun httpd/lisply-forbidden (proc _path _query _request)
  "Answer PROC with 403: the request did not carry the /lisply secret."
  (httpd-error proc 403))

(add-hook 'httpd-filter-functions #'emacs-lisply--secret-filter)

(provide 'lisply-secret)
;;; lisply-secret.el ends here
