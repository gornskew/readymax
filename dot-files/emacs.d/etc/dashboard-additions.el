;; Copyright (C) 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; dashboard-additions --- Look up services more dynamically
;;; Commentary: supplement for dashboard-config.el
;;; Code:

(require 'services-discovery)
(require 'skewed-icons)


(defun discover-network-lisply-backends ()
  "Discover lisply backends from services.json (Single Source of Truth).
Falls back to hardcoded container names if services.json not available."
  (condition-case nil
      (let ((services (skewed-get-lisply-backends)))
        (if services
            ;; Use services from services.json
            (mapcar (lambda (svc)
                      (list :host (plist-get svc :http-host)
                            :port (plist-get svc :http-port)
                            :name (plist-get svc :name)
                            :type (plist-get svc :type)
                            :running t))
                    services)
          ;; Fallback to hardcoded defaults if services.json empty/missing
          '((:host "skewed-emacs" :port 7080 :name "skewed-emacs" :type "emacs-lisp")
            (:host "gendl-ccl" :port 9080 :name "gendl-ccl" :type "common-lisp")
            (:host "gendl-sbcl" :port 9090 :name "gendl-sbcl" :type "common-lisp"))))
    (error
     ;; If services-discovery fails, return minimal fallback
     '((:host "skewed-emacs" :port 7080 :name "skewed-emacs" :type "emacs-lisp")))))

(defun discover-swank-services ()
  "Discover SWANK services from services.json (Single Source of Truth)."
  (condition-case nil
      (let ((services (skewed-get-swank-services)))
        (if services
            (mapcar (lambda (svc)
                      (let ((lisp-impl (plist-get svc :lisp-impl))
                            (name (plist-get svc :name)))
                        (list :host (plist-get svc :swank-host)
                              :port (plist-get svc :swank-port)
                              :host-port (plist-get svc :swank-host-port)
                              :name name
                              :impl lisp-impl
                              :icon (cond ((string-equal lisp-impl "CCL") :svc-ccl)
                                         ((string-equal lisp-impl "SBCL") :svc-sbcl)
                                         ((string-match-p "SMP" lisp-impl) :svc-smp)
                                         ((string-match-p "Allegro" lisp-impl) :svc-commercial)
                                         ((string-match-p "Commercial" lisp-impl) :svc-commercial)
                                         (t :svc-lisp)))))
                    services)
          '()))
    (error '())))

(provide 'dashboard-additions)

;;; dashboard-additions.el ends here
