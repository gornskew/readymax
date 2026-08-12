;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;; <!-- language: lang-lisp -->



(defun strapdown-html (buffer)
    (princ (with-current-buffer buffer
             (format "<!DOCTYPE html><html><title>Impatient Markdown</title><xmp theme=\"united\" style=\"display:none;\"> %s  </xmp><script src=\"http://ndossougbe.github.io/strapdown/dist/strapdown.js\"></script></html>"
                     (buffer-substring-no-properties (point-min) (point-max))))
           (current-buffer)))

(setq httpd-port 8058)

(defun start-impatient-server ()
  (httpd-start)
  (message "Serving on port %s" httpd-port))



(message "Do M-x imp-set-user-filter RET strapdown-html RET")
;;
;; (imp-set-user-filter 'markdown-html) ;; need to do this with M-x
;; imp-set-user-filter until we figure out how to do it
;; programatically.

(provide 'impatient-markdown-config)
