;;; org-config.el --- Org Mode customizations -*- lexical-binding: t -*-
;;
;; Loaded lazily via hook; assumes org is already required.

;;; Code:

(require 'org-habit)
(require 'skewed-icons)

;; Use ellipsis instead of $ for truncated lines
(unless standard-display-table
  (setq standard-display-table (make-display-table)))
(set-display-table-slot standard-display-table 'truncation (make-glyph-code ?… 'escape-glyph))
;; Use safe single-width characters for habit glyphs
(setq org-habit-completed-glyph ?+
      org-habit-today-glyph ?#)
(set-face-attribute 'org-habit-alert-face nil :background "#2d6a6a")
(add-to-list 'org-modules 'org-habit)

;; Enable org-depend for task dependencies
(require 'org-depend)
(add-to-list 'org-modules 'org-depend)

;; ============================================================================
;; Key bindings
;; ============================================================================

(global-set-key "\C-cl" 'org-store-link)
(global-set-key "\C-ca" 'org-agenda)
(global-set-key "\C-cc" 'org-capture)
(global-set-key "\C-cb" 'org-iswitchb)

;; ============================================================================
;; TODO keywords and state transitions
;; ============================================================================

(setq org-todo-keywords
      '((sequence "TODO(t)" "NEXT(n)" "|" "DONE(d)")
        (sequence "WAITING(w@/!)" "HOLD(h@/!)" "|"
                  "CANCELLED(c@/!)" "PHONE" "MEETING")))

(setq org-todo-keyword-faces
      '(("TODO"      :foreground "red"          :weight bold)
        ("NEXT"      :foreground "blue"         :weight bold)
        ("DONE"      :foreground "forest green" :weight bold)
        ("WAITING"   :foreground "orange"       :weight bold)
        ("HOLD"      :foreground "magenta"      :weight bold)
        ("CANCELLED" :foreground "forest green" :weight bold)
        ("MEETING"   :foreground "forest green" :weight bold)
        ("PHONE"     :foreground "forest green" :weight bold)))

(setq org-todo-state-tags-triggers
      '(("CANCELLED" ("CANCELLED" . t) ("must") ("should") ("could"))
        ("WAITING"   ("WAITING"   . t) ("must") ("should") ("could"))
        ("HOLD"      ("WAITING") ("HOLD" . t) ("must") ("should") ("could"))
        (done        ("WAITING") ("HOLD"))
        ("TODO"      ("WAITING") ("CANCELLED") ("HOLD"))
        ("NEXT"      ("WAITING") ("CANCELLED") ("HOLD"))
        ("DONE"      ("WAITING") ("CANCELLED") ("HOLD"))))

;; ============================================================================
;; Tags
;; ============================================================================

(setq org-tag-alist
      '((:startgroup)
        ("must"   . ?m)
        ("should" . ?s)
        ("could"  . ?c)
        (:endgroup)
        ("meta"         . ?M)
        ("urgent"       . ?u)
        ("website"      . ?w)
        ("skewed_emacs" . ?k)
        ("infra"        . ?i)))

;; ============================================================================
;; Clocking
;; ============================================================================

(setq org-use-fast-todo-selection t
      org-treat-S-cursor-todo-selection-as-state-change nil
      org-log-done 'time
      org-log-note-clock-out t
      org-clock-out-when-done t
      org-clock-persist 'history)

(org-clock-persistence-insinuate)

(defun org-find-dangling-clock ()
  "Find a dangling clock entry."
  (interactive)
  (re-search-forward "CLOCK: \\[[^]]*\\] *$"))

(defun org-archive-done-tasks ()
  "Archive all DONE tasks in current tree."
  (interactive)
  (org-map-entries
   (lambda ()
     (org-archive-subtree)
     (setq org-map-continue-from (outline-previous-heading)))
   "/DONE" 'tree))

;; ============================================================================
;; Org file paths
;; ============================================================================

(defvar my/org-root
  (cond ((file-directory-p "~/projects/org") (expand-file-name "~/projects/org"))
        ((file-directory-p "/projects/org") "/projects/org")
        (t nil))
  "Root directory for Org files, or nil if unavailable.")

(defvar my/org-projects-file (when my/org-root (expand-file-name "projects.org" my/org-root)))
(defvar my/org-future-file   (when my/org-root (expand-file-name "future.org" my/org-root)))
(defvar my/org-journal-file  (when my/org-root (expand-file-name "journal.org" my/org-root)))

(when my/org-root
  (setq org-directory my/org-root
        org-agenda-files (delq nil (list my/org-projects-file))))

;; ============================================================================
;; Agenda settings
;; ============================================================================

(setq org-agenda-span 21
      org-agenda-start-on-weekday nil)

(defun my/org-has-urgent-inbox-p ()
  "Return non-nil if future.org has any :urgent: TODOs."
  (when (and my/org-future-file (file-exists-p my/org-future-file))
    (let ((files (list my/org-future-file)) found)
      (org-agenda-prepare-buffers files)
      (org-map-entries (lambda () (setq found t)) "urgent/TODO" files)
      found)))

(setq org-agenda-custom-commands
      `(("d" "Daily Focus"
         ((agenda "" ((org-agenda-span 'day)
                       (org-agenda-start-day "today")
                       (org-agenda-skip-scheduled-if-done t)
                       (org-agenda-skip-deadline-if-done t)
                       (org-agenda-skip-timestamp-if-done t)))
          (tags-todo "urgent"
                     ((org-agenda-files (when my/org-future-file (list my/org-future-file)))
                      (org-agenda-skip-function
                       '(if (my/org-has-urgent-inbox-p) nil '(goto-char (point-max))))
                      (org-agenda-overriding-header
                       (if (my/org-has-urgent-inbox-p) (concat (skewed-icon :lightning) " Urgent (from Inbox)") ""))))
          (tags-todo "must"   ((org-agenda-files (delq nil (list my/org-projects-file my/org-future-file)))
                               (org-agenda-overriding-header "Must Do")))
          (tags-todo "should" ((org-agenda-files (delq nil (list my/org-projects-file my/org-future-file)))
                               (org-agenda-overriding-header "Should Do")))
          (tags-todo "could"  ((org-agenda-files (delq nil (list my/org-projects-file my/org-future-file)))
                               (org-agenda-overriding-header "Could Do"))))
         ((org-agenda-tag-filter-preset '("-meta"))))
        ("i" "Inbox Review"
         ((alltodo "" ((org-agenda-files ',(when my/org-future-file (list my/org-future-file)))
                        (org-agenda-overriding-header "Inbox - Review & Refile")
                        (org-agenda-sorting-strategy '(priority-down time-up scheduled-up))))))
        ("m" "Meta Tasks"
         ((tags-todo "meta" ((org-agenda-overriding-header "System & Planning Tasks")))))
        ("p" "Full Backlog"
         ((todo "" ((org-agenda-overriding-header "Complete Backlog")))))))

;; ============================================================================
;; Capture templates
;; ============================================================================

(setq org-capture-templates
      (delq nil
            (list
             (when my/org-future-file
               `("t" "Todo (Inbox)" entry
                 (file+headline ,my/org-future-file "Inbox")
                 "** TODO %?\n   :PROPERTIES:\n   :CREATED: %U\n   :END:\n"))
             (when my/org-journal-file
               `("j" "Journal" entry
                 (file+olp+datetree ,my/org-journal-file)
                 "* %U\n%?\n"
                 :tree-type month))
             (when (and my/org-journal-file my/org-projects-file my/org-future-file)
               `("d" "Daily journal with clock summary" entry
                 (file+olp+datetree ,my/org-journal-file)
                 ,(format (concat "* %%<%%Y-%%m-%%d %%A>\n:PROPERTIES:\n:CREATED: %%U\n:END:\n\n"
                                  "** Daily Notes\n%%?\n\n"
                                  "** Time Summary\n"
                                  "#+BEGIN: clocktable :scope (\"%s\" \"%s\") "
                                  ":maxlevel 3 :block %%<%%Y-%%m-%%d> :link t :compact t :narrow 40!\n"
                                  "#+END:\n")
                          my/org-projects-file my/org-future-file)
                 :tree-type month)))))

;; ============================================================================
;; Refile
;; ============================================================================

(when my/org-projects-file
  (setq org-refile-targets `((org-agenda-files :maxlevel . 2)
                             (,my/org-projects-file :maxlevel . 2))))
(setq org-refile-use-outline-path 'file
      org-outline-path-complete-in-steps nil)

;; ============================================================================
;; D-Bus fallback for containers
;; ============================================================================

(when (bound-and-true-p my/in-docker-p)
  (defvar skewed-emacs-dbus-session-available nil)
  (defun skewed-emacs--dbus-suppress-session (orig-fun bus &rest args)
    (unless (and (eq bus :session) (not skewed-emacs-dbus-session-available))
      (apply orig-fun bus args)))
  (advice-add 'dbus-call-method :around #'skewed-emacs--dbus-suppress-session)
  (setq org-show-notification-handler
        (lambda (msg)
          (message (concat (skewed-icon :bell) " Org: %s") msg)
          (let ((orig-bg (face-attribute 'mode-line :background)))
            (set-face-attribute 'mode-line nil :background "DarkOrange")
            (run-with-timer 0.5 nil
                            (lambda (bg) (set-face-attribute 'mode-line nil :background bg))
                            orig-bg)))))

;; ============================================================================
;; Auto-save on clock/state changes
;; ============================================================================

(defun my/org-save-current-buffer ()
  "Save current buffer if it's an org file."
  (when (and (derived-mode-p 'org-mode) (buffer-file-name))
    (save-buffer)))

(defun my/org-save-all-org-buffers ()
  "Save all org buffers."
  (org-save-all-org-buffers))

(defun my/org-clock-cleanup-stale-vars ()
  "Clear stale clock variables after clock-out."
  (unless (org-clocking-p)
    (setq org-clock-heading nil
          org-clock-start-time nil)))

;; ============================================================================
;; Japa tracking
;; ============================================================================

(defvar my/japa-headline-pattern "Today's japa")

(defun my/japa-task-p ()
  "Return non-nil if current clocked task is japa."
  (and org-clock-heading
       (string-match-p my/japa-headline-pattern org-clock-heading)))

(defun my/japa-bonus-indicator (rounds)
  "Return indicator string for ROUNDS completed."
  (cond ((>= rounds 64) (skewed-icon :japa-epic))
        ((>= rounds 32) (skewed-icon :japa-bonus3))
        ((>= rounds 24) (skewed-icon :japa-bonus2))
        ((>= rounds 20) (skewed-icon :japa-bonus1))
        ((>= rounds 16) (skewed-icon :japa-complete))
        (t (format "%d/16" rounds))))

(defun my/japa-mala-format (total)
  "Format TOTAL rounds as mala notation."
  (let ((sets (1+ (/ total 16)))
        (remainder (mod total 16)))
    (if (= sets 1)
        (format "%d/16" remainder)
      (format "%d/16/%d" remainder sets))))

(defun my/japa-parse-note (note)
  "Parse NOTE, returning (rounds . mala-total) or nil.
Rounds: first freestanding integer.
Mala: N/16 or N/16/M where M is 1-based (1=first set of 16)."
  (let (rounds mala-total)
    (let ((stripped (replace-regexp-in-string "[0-9]+/16\\(/[1-4]\\)?" "" note)))
      (when (string-match "\\b\\([0-9]+\\)\\b" stripped)
        (setq rounds (string-to-number (match-string 1 stripped)))))
    (when (string-match "\\b\\([0-9]\\|1[0-6]\\)/16\\(?:/\\([1-4]\\)\\)?\\b" note)
      (let ((n (string-to-number (match-string 1 note)))
            (m (if (match-string 2 note) (string-to-number (match-string 2 note)) 1)))
        (setq mala-total (+ n (* (1- m) 16)))))
    (when (or rounds mala-total)
      (cons rounds mala-total))))

(defun my/japa-get-today-rounds ()
  "Get total rounds logged today."
  (let ((today (format-time-string "%Y-%m-%d"))
        (total 0))
    (when my/org-projects-file
      (with-current-buffer (find-file-noselect my/org-projects-file)
        (save-excursion
          (goto-char (point-min))
          (when (search-forward my/japa-headline-pattern nil t)
            (let ((end (save-excursion (org-end-of-subtree t) (point))))
              (while (re-search-forward (concat "CLOCK: \\[" today "[^]]+\\]--\\[") end t)
                (forward-line 1)
                (when (looking-at "[ \t]+- \\(.+\\)")
                  (let ((parsed (my/japa-parse-note (match-string 1))))
                    (when (car parsed)
                      (setq total (+ total (car parsed))))))))))))
    total))

(defun my/japa-get-today-mala ()
  "Get most recent mala count from today's notes."
  (let ((today (format-time-string "%Y-%m-%d"))
        latest)
    (when my/org-projects-file
      (with-current-buffer (find-file-noselect my/org-projects-file)
        (save-excursion
          (goto-char (point-min))
          (when (search-forward my/japa-headline-pattern nil t)
            (let ((end (save-excursion (org-end-of-subtree t) (point))))
              (while (re-search-forward (concat "CLOCK: \\[" today "[^]]+\\]--\\[") end t)
                (forward-line 1)
                (when (looking-at "[ \t]+- \\(.+\\)")
                  (let ((parsed (my/japa-parse-note (match-string 1))))
                    (when (cdr parsed)
                      (setq latest (cdr parsed)))))))))))
    latest))

(defun my/japa-validate-after-note ()
  "Validate japa checksum after clock-out."
  (when (and my/org-projects-file
             org-clock-heading
             (string-match-p my/japa-headline-pattern org-clock-heading))
    (let ((rounds (my/japa-get-today-rounds))
          (mala (my/japa-get-today-mala)))
      (when (and mala (> rounds 0))
        (if (= rounds mala)
            (message (concat (skewed-icon :japa-complete) " ✓ Checksum OK: %d rounds = %s") rounds (my/japa-mala-format mala))
          (message (concat (skewed-icon :warning) " Mismatch: recorded %d, mala shows %s (%d)")
                   rounds (my/japa-mala-format mala) mala))))))

(defun my/japa-agenda-finalize-hook ()
  "Add japa indicator to agenda."
  (let ((rounds (my/japa-get-today-rounds)))
    (when (> rounds 0)
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward "Today's japa" nil t)
          (end-of-line)
          (let ((inhibit-read-only t))
            (insert " " (my/japa-bonus-indicator rounds))))))))

;; ============================================================================
;; Hooks (consolidated)
;; ============================================================================

(add-hook 'org-clock-in-hook     #'my/org-save-all-org-buffers)
(add-hook 'org-clock-out-hook    #'my/org-save-all-org-buffers)
(add-hook 'org-clock-out-hook    #'my/org-clock-cleanup-stale-vars)
(add-hook 'org-clock-out-hook    #'my/japa-validate-after-note)
(add-hook 'org-clock-cancel-hook #'my/org-save-all-org-buffers)
(add-hook 'org-after-todo-state-change-hook #'my/org-save-current-buffer)
(add-hook 'org-after-tags-change-hook       #'my/org-save-current-buffer)
(add-hook 'org-after-refile-insert-hook     #'my/org-save-all-org-buffers)
(add-hook 'org-agenda-finalize-hook         #'my/japa-agenda-finalize-hook)

(advice-add 'org-store-log-note :after #'my/org-save-all-org-buffers)



;; ============================================================================
;; Japa habit graph - custom icons based on round counts  
;; ============================================================================

(defun my/japa-get-rounds-by-date ()
  "Get hash table of date -> total rounds by summing standalone numbers.
Returns (hash-table . earliest-date)."
  (let ((by-date (make-hash-table :test 'equal))
        (earliest-date nil))
    (when my/org-projects-file
      (with-current-buffer (find-file-noselect my/org-projects-file)
        (save-excursion
          (goto-char (point-min))
          (when (search-forward my/japa-headline-pattern nil t)
            (let ((end (save-excursion (org-end-of-subtree t) (point))))
              (while (re-search-forward "CLOCK: \\[\\([0-9-]+\\)" end t)
                (let ((date (match-string 1)))
                  (when (or (null earliest-date) (string< date earliest-date))
                    (setq earliest-date date))
                  (unless (gethash date by-date)
                    (puthash date 0 by-date))
                  (forward-line 1)
                  (when (looking-at "[ \t]+- \\(.+\\)")
                    (let* ((note (match-string 1))
                           (parsed (my/japa-parse-note note))
                           (rounds (car parsed)))
                      (when rounds
                        (puthash date (+ (gethash date by-date 0) rounds) by-date)))))))))))
    (cons by-date earliest-date)))

(defun my/japa-day-icon (rounds)
  "Return icon for ROUNDS completed."
  (cond
   ((null rounds) nil)
   ((= rounds 0) (skewed-icon :japa-zero))
   ((< rounds 16) (skewed-icon :japa-progress))
   ((< rounds 20) (skewed-icon :japa-complete))
   ((< rounds 24) (skewed-icon :japa-bonus1))
   ((< rounds 32) (skewed-icon :japa-bonus2))
   ((< rounds 64) (skewed-icon :japa-bonus3))
   (t (skewed-icon :japa-epic))))                          ; Epic: rocket

(defun my/japa-build-custom-graph ()
  "Build custom japa habit graph - 7 day window (4 past + today + 2 future)."
  (let* ((today (format-time-string "%Y-%m-%d"))
         (today-time (org-time-string-to-time today))
         (data-and-earliest (my/japa-get-rounds-by-date))
         (rounds-data (car data-and-earliest))
         (earliest-date (cdr data-and-earliest))
         (preceding 4)   ; 4 days back
         (following 2)   ; 2 days forward
         (icons '()))
    (dotimes (i (+ preceding following 1))
      (let* ((day-offset (- i preceding))
             (day-time (time-add today-time (days-to-time day-offset)))
             (day-str (format-time-string "%Y-%m-%d" day-time))
             (day-rounds (gethash day-str rounds-data))
             (is-today (= day-offset 0))
             (is-future (> day-offset 0))
             (is-before-tracking (and earliest-date (string< day-str earliest-date)))
             (icon (cond
                    (is-future (skewed-icon :japa-future))
                    (is-before-tracking (skewed-icon :japa-future))
                    (is-today 
                     (or (my/japa-day-icon (or day-rounds 0))
                         (skewed-icon :japa-zero)))
                    ((null day-rounds) (skewed-icon :japa-zero))
                    (t (my/japa-day-icon day-rounds)))))
        (push icon icons)))
    (string-join (nreverse icons) " ")))

(defun my/japa-replace-habit-graph-in-agenda ()
  "Replace standard habit graph for japa with custom icon-based graph."
  (when (derived-mode-p 'org-agenda-mode)
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "Today's japa" nil t)
        (let* ((line-end (line-end-position))
               (custom-graph (my/japa-build-custom-graph)))
          (move-to-column (or org-habit-graph-column 40))
          (when (< (point) line-end)
            (let ((graph-start (point))
                  (inhibit-read-only t))
              (delete-region graph-start line-end)
              (insert " " custom-graph))))))))

(add-hook 'org-agenda-finalize-hook #'my/japa-replace-habit-graph-in-agenda 90)




;; ============================================================================
;; First-time Daily Focus setup
;; ============================================================================

(defun skewed-daily-focus-init ()
  "Set up Daily Focus org files from bundled starter templates.
Creates the org directory (~/projects/org on a host, /projects/org
inside a skewed-emacs container), populates projects.org and future.org
from templates when absent, and reconfigures org/agenda to use them.
Idempotent: existing org files are never overwritten."
  (interactive)
  (let* ((root (or my/org-root
                   (if (file-directory-p "/projects")
                       "/projects/org"
                     (expand-file-name "~/projects/org"))))
         (template-dir (expand-file-name "etc/org-templates" user-emacs-directory)))
    (make-directory root t)
    (dolist (f '("projects.org" "future.org"))
      (let ((dest (expand-file-name f root))
            (src (expand-file-name f template-dir)))
        (when (and (file-exists-p src) (not (file-exists-p dest)))
          (copy-file src dest))))
    (setq my/org-root root
          my/org-projects-file (expand-file-name "projects.org" root)
          my/org-future-file (expand-file-name "future.org" root)
          my/org-journal-file (expand-file-name "journal.org" root))
    ;; Reload this file so path-derived config (agenda commands, capture
    ;; templates, refile targets) picks up the new locations. The defvars
    ;; above retain the values just set; hooks use named functions and
    ;; add-to-list, so reloading is idempotent.
    (load "org-config" nil t)
    (message "Daily Focus ready at %s — open it with C-c a d" root)))

(provide 'org-config)
;;; org-config.el ends here
