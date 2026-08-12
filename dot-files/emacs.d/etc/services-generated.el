;;; services-generated.el --- Generated from services.sexp -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; DO NOT EDIT - Regenerate with: (skewed-generate-all-configs)

(defvar skewed-generated-services nil)
(setq skewed-generated-services
  '(
    (:name "skewed-emacs"
     :type "emacs-lisp"
     :lisp-impl "Emacs"
     :mcp t
     :http-host "skewed-emacs"
     :http-port 7080
    )
    (:name "gendl-ccl"
     :type "common-lisp"
     :lisp-impl "CCL"
     :mcp t
     :http-host "gendl-ccl"
     :http-port 9080
     :http-host-port 19080
     :swank-host "gendl-ccl"
     :swank-port 4200
    )
    (:name "gendl-sbcl"
     :type "common-lisp"
     :lisp-impl "SBCL"
     :mcp t
     :http-host "gendl-sbcl"
     :http-port 9090
     :http-host-port 29080
     :swank-host "gendl-sbcl"
     :swank-port 4210
    )
    (:name "autoheal"
     :type "utility"
     :lisp-impl "Unknown"
    )
   ))
;; Services configuration generated from services.sexp.

(provide 'services-generated)
;;; services-generated.el ends here