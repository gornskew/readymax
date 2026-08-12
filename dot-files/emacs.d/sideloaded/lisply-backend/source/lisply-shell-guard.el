;;; lisply-shell-guard.el --- bounded/async shell helpers + pre-eval lint  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.


;; Added 2026-07-26 after the unbounded-curl transport-wedge incident.
;; Any synchronous child process blocks the single Emacs event loop until
;; the child exits, starving timers, network filters, and the lisply httpd.
;; These helpers provide safe alternatives; the lint refuses known-blocking
;; payloads that arrive without a visible bound.

;;; Code:

(require 'seq)

(defvar lisply-shell-default-timeout 25
  "Default bound in seconds for `lisply-shell-bounded'.
Kept under the ~35s claude.ai MCP relay response timeout.")

(defun lisply-shell-bounded (command &optional timeout)
  "Run shell COMMAND synchronously, hard-bounded by TIMEOUT seconds.
Wraps COMMAND in timeout(1).  Returns a plist:
(:exit-code N :output STRING :timed-out BOOL).
Exit code 124 means the bound fired."
  (let ((secs (or timeout lisply-shell-default-timeout)))
    (with-temp-buffer
      (let ((code (call-process "timeout" nil t nil
                                (number-to-string secs)
                                "sh" "-c" command)))
        (list :exit-code code
              :output (buffer-string)
              :timed-out (eql code 124))))))

(defvar lisply-shell-async-results (make-hash-table :test 'equal)
  "Token -> result plist for `lisply-shell-async' jobs.")

(defun lisply-shell-async (command &optional token)
  "Start shell COMMAND asynchronously; return a TOKEN string immediately.
The Emacs event loop is never blocked.  When the process exits, its
result is stored under TOKEN; retrieve it with `lisply-shell-async-result'."
  (let* ((tok (or token (format "job-%s" (format-time-string "%s%3N"))))
         (buf (generate-new-buffer (format " *lisply-async-%s*" tok)))
         (proc (start-process-shell-command
                (format "lisply-async-%s" tok) buf command)))
    (puthash tok (list :status :running :started (current-time-string))
             lisply-shell-async-results)
    (set-process-sentinel
     proc
     (lambda (p _event)
       (when (memq (process-status p) '(exit signal))
         (puthash tok (list :status :done
                            :exit-code (process-exit-status p)
                            :output (if (buffer-live-p (process-buffer p))
                                        (with-current-buffer (process-buffer p)
                                          (buffer-string))
                                      "")
                            :finished (current-time-string))
                  lisply-shell-async-results)
         (when (buffer-live-p (process-buffer p))
           (kill-buffer (process-buffer p))))))
    tok))

(defun lisply-shell-async-result (token &optional keep)
  "Return the result plist for TOKEN.
(:status :running ...) while the job is still going;
(:status :done :exit-code N :output STR ...) when finished.
When finished and KEEP is nil, the stored entry is removed on retrieval."
  (let ((res (gethash token lisply-shell-async-results)))
    (cond ((null res) (list :status :unknown-token))
          ((eq (plist-get res :status) :done)
           (unless keep (remhash token lisply-shell-async-results))
           res)
          (t res))))

;;; ---- pre-eval lint (defense layer for the lisply httpd) ----

(defvar lisply-lint-enabled t
  "When non-nil, `lisply-payload-lint' vets incoming lisp_eval payloads.")

(defvar lisply-lint-blocking-patterns
  '("shell-command" "call-process" "process-file" "sleep-for")
  "Substrings identifying potentially event-loop-blocking forms.
Note \"shell-command\" also covers shell-command-to-string and
shell-command-on-region.")

(defvar lisply-lint-bound-markers
  '("timeout " "--max-time" "lisply-shell-bounded" "lisply-shell-async"
    "lisply:allow-unbounded")
  "Substrings whose presence indicates the payload carries its own bound.
The comment ;; lisply:allow-unbounded is an explicit escape hatch.")

(defun lisply-payload-lint (code)
  "Return an error string if CODE looks event-loop-blocking without a bound.
Return nil if CODE passes.  Purely textual heuristic; see
`lisply-lint-blocking-patterns' and `lisply-lint-bound-markers'."
  (when (and lisply-lint-enabled (stringp code))
    (let ((hit (seq-find (lambda (pat) (string-match-p (regexp-quote pat) code))
                         lisply-lint-blocking-patterns)))
      (when (and hit
                 (not (seq-find (lambda (m) (string-match-p (regexp-quote m) code))
                                lisply-lint-bound-markers)))
        (format (concat "LISPLY-LINT: payload contains `%s' without a visible bound. "
                        "Synchronous child processes block the entire Emacs event loop "
                        "and can wedge this transport until the child exits. "
                        "Use (lisply-shell-bounded CMD &optional SECS), or "
                        "(lisply-shell-async CMD) then (lisply-shell-async-result TOKEN), "
                        "or include an explicit bound (timeout(1) wrapper / curl --max-time). "
                        "To override deliberately, include the comment: ;; lisply:allow-unbounded")
                hit)))))

(provide 'lisply-shell-guard)
;;; lisply-shell-guard.el ends here
