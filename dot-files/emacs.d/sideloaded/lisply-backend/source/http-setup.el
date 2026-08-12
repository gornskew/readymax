;;; lisply-http-setup.el --- HTTP server setup for MCP protocol

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

(require 'cl-lib)
(require 'json)
(require 'simple-httpd)

(defgroup emacs-lisply nil
  "Emacs Lisply Server for LLM integration."
  :group 'tools)

(defcustom emacs-lisply-port 7080
  "Port for the Emacs Lisply server."
  :type 'integer
  :group 'emacs-lisply)

(defcustom emacs-lisply-debug nil
  "Whether to enable debug logging. Should be disabled in production."
  :type 'boolean
  :group 'emacs-lisply)

(defcustom emacs-lisply-endpoint-prefix "/lisply"
  "Base path for the Lisply endpoints."
  :type 'string
  :group 'emacs-lisply)

(defcustom emacs-lisply-ping-endpoint "/ping-lisp"
  "Endpoint path for ping-lisp."
  :type 'string
  :group 'emacs-lisply)

(defcustom emacs-lisply-eval-endpoint "/lisp-eval"
  "Endpoint path for lisp-eval."
  :type 'string
  :group 'emacs-lisply)

(defvar emacs-lisply-server-running nil
  "Flag tracking whether the Lisply server is running.")

(defun emacs-lisply-log (format-string &rest args)
  "Log a message with FORMAT-STRING and ARGS if debug is enabled."
  (when emacs-lisply-debug
    (let ((msg (apply 'format format-string args)))
      (message "[EMACS-LISPLY] %s" msg))))

(defun emacs-lisply--maybe-dechunk (body)
  "Return dechunked BODY if it looks like chunked encoding."
  (let ((pos 0)
        (len (length body))
        (chunks '())
        (looks-chunked (string-match-p "\\`[0-9a-fA-F]+\\(?:\r?\n\\)" body)))
    (if (not looks-chunked)
        body
      (condition-case _err
          (progn
            (while (< pos len)
              (let ((line-end (string-match "\r?\n" body pos)))
                (when (not line-end)
                  (setq pos len))
                (let* ((line (substring body pos line-end))
                       (line-break (match-string 0 body))
                       (break-len (length line-break))
                       (size-hex (car (split-string line ";" t)))
                       (size (string-to-number size-hex 16)))
                  (setq pos (+ line-end break-len))
                  (when (<= size 0)
                    (setq pos len))
                  (when (> size 0)
                    (when (> (+ pos size) len)
                      (setq pos len))
                    (push (substring body pos (+ pos size)) chunks)
                    (setq pos (+ pos size))
                    (let ((trailer (string-match "\r?\n" body pos)))
                      (when trailer
                        (setq pos (match-end 0))))))))
            (apply #'concat (nreverse chunks)))
        (error body)))))

(defun emacs-lisply-get-request-body ()
  "Get the body of the current HTTP request as a UTF-8 string."
  (let ((raw-body (cadr (assoc "Content" httpd-request))))
    (when raw-body
      (emacs-lisply--maybe-dechunk
       (decode-coding-string raw-body 'utf-8)))))

(defun emacs-lisply-parse-json-body ()
  "Parse the JSON body from the current HTTP request."
  (let ((body (emacs-lisply-get-request-body)))
    (when (and body (not (string-empty-p body)))
      (condition-case err
          (json-read-from-string body)
        (error
         (emacs-lisply-log "Error parsing JSON body: %s" err)
         nil)))))

;;(defun emacs-lisply-send-response (data &optional content-type)
;;  "Send a response with DATA and optional CONTENT-TYPE.
;;DATA can be a string, in which case it will be sent as-is,
;;or an object which will be JSON-encoded."
;;  (let ((content-type (or content-type "application/json")))
;;    (httpd-send-header content-type 200
;;                        '("Access-Control-Allow-Origin" . "*"))
;;    (princ
;;     (if t ;;(stringp data)
;;         data
;;       (json-encode data)))))

(defun emacs-lisply-send-response (data &optional content-type)
  "Send a response with DATA and optional CONTENT-TYPE.
DATA can be a string, in which case it will be sent as-is,
or an object which will be JSON-encoded."
  (insert
   (if (stringp data)
       data
     (json-encode data))))



;;;###autoload
(defun emacs-lisply-start-server ()
  "Start the Emacs Lisply server."
  (interactive)
  (httpd-stop)
  (setq httpd-port emacs-lisply-port)
  (httpd-start)
  (setq emacs-lisply-server-running t)
  (emacs-lisply-log "Emacs Lisply server started on port %d" emacs-lisply-port)
  (message "Emacs Lisply server started on port %d" emacs-lisply-port))

;;;###autoload
(defun emacs-lisply-stop-server ()
  "Stop the Emacs Lisply server."
  (interactive)
  (httpd-stop)
  (setq emacs-lisply-server-running nil)
  (emacs-lisply-log "Emacs Lisply server stopped")
  (message "Emacs Lisply server stopped"))

;;;###autoload
(defun emacs-lisply-server-status ()
  "Show the status of the Emacs Lisply server."
  (interactive)
  (if emacs-lisply-server-running
      (message "Emacs Lisply server is running on port %d" emacs-lisply-port)
    (message "Emacs Lisply server is not running")))

(provide 'lisply-http-setup)
;;; lisply-http-setup.el ends here
