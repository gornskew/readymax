;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; simulate-user-start.el --- Simulate user startup to trigger and compile loaded files
;;; Commentary:
;;; This file simulates a normal user startup to load packages and built-in libraries,
;;; triggering native compilation of any .el files that lack .eln files, and waits for
;;; compilation to complete.

;;; Code:


;; Wait for any asynchronous compilations to complete
(let ((wait-time 0)
      (increment 1)
      (max-wait 480)) ; Maximum wait time of 8 minutes
  (while (and (> (hash-table-count comp-async-compilations) 0)
	      (progn (sleep-for 0.5) (hash-table-count comp-async-compilations))
              (< wait-time max-wait))
    (message "Waited %s seconds for %d straggling native compilation jobs to complete..."
	     wait-time (hash-table-count comp-async-compilations))
    (sleep-for increment)
    (cl-incf wait-time increment))
  (if (>= wait-time max-wait)
      (message "Warning: Deferred Compilations during simulated startup did not complete within %d seconds!" max-wait)
    (message "All straggling compilation jobs completed in %d seconds" wait-time)))

(message "Our work here is done.")
(kill-emacs 0)

;;; wait-for-async.el ends here
