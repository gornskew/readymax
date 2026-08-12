;;; Dashboard Config --- splashy dash  -*- lexical-binding: nil -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Dashboard setup

(require 'subr-x)
(require 'url)
(require 'dashboard)
(require 'dashboard-additions)
(require 'cl-lib)
(require 'skewed-icons)

;;; Code:

(defvar skewed-emacs-container? nil) ;; assumed to be pre-defined from init.el
(defvar skewed-dashboard-banner-file
  (concat (temporary-file-directory) "skewed-emacs-banner.txt"))

(defvar projects-dir
  (expand-file-name
   (if (or skewed-emacs-container? skewed-emacs-docker-build?
           (file-exists-p "/projects/"))
       "/projects/" "~/projects/")))

(dashboard-setup-startup-hook)
;;(setq dashboard-banner-logo-title "𝒮𝓀𝑒𝓌𝑒𝒹 𝓉𝑜𝓌𝒶𝓇𝒹 𝒴𝑜𝓊𝓇 𝐵𝑒𝓈𝓉 𝐼𝓃𝓉𝑒𝓇𝑒𝓈𝓉𝓈")
(setq dashboard-banner-logo-title nil)

(setq dashboard-startup-banner skewed-dashboard-banner-file)

(setq dashboard-items '((help . 3)
                        (active-projects . 5)
                        (other-status . 1)
                        (lisply-status . 1)
                        (system-info . 1)
                        ))

(setq dashboard-item-generators
      (append '((help . dashboard-insert-help-info)
                (active-projects . dashboard-insert-active-projects)
                (lisply-status . dashboard-insert-lisply-backends)
                (system-info . dashboard-insert-system-info)
                (other-status . dashboard-insert-other-status))
              (cl-remove-if (lambda (item)
                              (memq (car item) '(system-info lisply-status active-projects projects)))
                            dashboard-item-generators)))

(setq dashboard-center-content t)
(setq dashboard-footer-messages '("Brought to you by 𝙶𝚘𝚛𝚗𝚜𝚔𝚎𝚠 𝙴𝚗𝚝𝚎𝚛𝚙𝚛𝚒𝚜𝚎𝚜"))

(setq initial-buffer-choice
      (lambda ()
        (dashboard-refresh-buffer)
        (get-buffer-create "*dashboard*")))

;;; Helper for Alignment =======================================================

(defun skewed-dashboard-is-wide-char-p (icon-str)
  "Return t if the first char of ICON-STR is in a known wide Unicode range.
This detects 'Ghost' icons (like ⚙) that Emacs claims are width 1 but display as 2."
  (and (not (string-empty-p icon-str))
       (let ((char (aref icon-str 0)))
         (or
          (and (>= char #x2600) (<= char #x27BF))   ;; Misc Symbols & Dingbats (e.g. ⚙, ✈, ✔)
          (and (>= char #x1F300) (<= char #x1F9FF)) ;; Modern Emoji / Symbols (e.g. 🚀, 🤖)
          (and (>= char #x1F680) (<= char #x1F6FF)) ;; Transport / Map
          (>= (string-width icon-str) 2)))))         ;; Trust Emacs if it already says 2

(defun skewed-dashboard-pad-icon (icon-key)
  "Lookup icon by KEY and pad selectively.
Ghost emojis get 2 spaces, normal emojis get 1 space."
  (let ((icon-str (skewed-icon icon-key)))
    (if (skewed-icon-is-ghost icon-key)
        (concat icon-str "  ") ;; Ghost: 2 spaces
      (concat icon-str " ")))) ;; Normal: 1 space


;;; Item Generators ============================================================

(defun dashboard-insert-help-info (list-size)
  "Insert getting-started info."
  (when list-size
  (dashboard-insert-heading (concat (skewed-dashboard-pad-icon :getting-started)
				      "Getting Started:"))
    (insert "\n")
    (dolist (line (help-info-strings))
      (insert line))))

(defun dashboard-insert-active-projects (list-size)
  "Insert active projects info.  LIST-SIZE is passed along."
  (dashboard-insert-heading (concat (skewed-dashboard-pad-icon :active-projects)
				      (format "Active Projects in %s:" projects-dir)))
  (insert "\n")
  (dolist (proj-string (active-projects-strings list-size))
    (insert proj-string)))

(defun dashboard-insert-system-info (list-size)
  "Insert system information."
  (when list-size
    (dashboard-insert-heading (concat (skewed-dashboard-pad-icon :svc-ccl)
					"System Information:"))
    (insert "\n")
    (dolist (line (system-info-strings list-size))
      (insert line))))

(defun dashboard-insert-lisply-backends (list-size)
  "Insert Lisply backends status using propertized strings list."
  (when list-size
     (dashboard-insert-heading (concat (skewed-dashboard-pad-icon :lisply-backends)
					"Lisply Backends (configurable for Lisply-MCP):"))
    (insert "\n")
    (dolist (line (lisply-backends-strings list-size))
      (insert line))))

(defun dashboard-insert-other-status (list-size)
  "Insert other services status section using propertized strings list.
LIST-SIZE used as boolean"
  (when list-size
    (dashboard-insert-heading (concat (skewed-dashboard-pad-icon :swanky-services)
					"𝓢𝓦𝓐𝓝𝓚 Services (hosts and ports):"))
      (insert "\n")
    (dolist (line (other-status-strings list-size))
      (insert line))))


;;; String Generators ==========================================================

(defun help-info-strings ()
  "Return a list of propertized strings for help dashboard item."
  (list
   (concat "    "
           (propertize (concat (skewed-dashboard-pad-icon :help-book)
                               "Emacs Tutorial: C-h t\n")
                       'keymap (let ((map (make-sparse-keymap)))
                                 (define-key map (kbd "RET") 'help-with-tutorial)
                                 (define-key map [mouse-1] 'help-with-tutorial)
                                 map)
                       'face 'button
                       'help-echo "Run Emacs tutorial (C-h C-t)"))
   (concat "    "
           (propertize (concat (skewed-dashboard-pad-icon :help-target)
                               "Daily Focus: C-c a d\n")
                       'keymap (let ((map (make-sparse-keymap))
                                     (function (lambda () (interactive)
                                                 (require 'org)
                                                 (require 'org-config)
                                                 (skewed-daily-focus))))
                                 (define-key map (kbd "RET") function)
                                 (define-key map [mouse-1] function)
                                 map)
                       'face 'button
                       'help-echo "Open Daily Focus agenda (first use sets up starter org files)"))

   
   (concat "    "
        (propertize (concat (skewed-dashboard-pad-icon :help-robot) "AI TUIs (claude code, gemini-cli, codex...): M-x vterm\n")
                       'keymap (let ((map (make-sparse-keymap))
                                     (function (lambda () (interactive) (eat))))
                                 (define-key map (kbd "RET") function)
                                 (define-key map [mouse-1] function)
                                 map)
                       'face 'button
                       'help-echo "Run in a *vterm* terminal"))

   (concat "    "
        (propertize (concat (skewed-dashboard-pad-icon :help-palette) "M-x light-theme, dark-theme, load-theme\n")
                       'keymap (let ((map (make-sparse-keymap)))
                                 (define-key map (kbd "RET") 'load-theme)
                                 (define-key map [mouse-1] 'load-theme)
                                 map)
                       'face 'button
                       'help-echo "Run load-theme"))))


(defun active-projects-strings (list-size)
  "Return a list of propertized strings for active projects."
  (let* ((project-dirs
          (when (file-exists-p projects-dir)
            (seq-filter
             (lambda (dir)
               (and (file-directory-p (expand-file-name dir projects-dir))
                    (file-exists-p
                     (expand-file-name (concat dir "/.git") projects-dir))))
             (directory-files projects-dir nil "^[^.]"))))
         (projects-with-mtime
          (mapcar
           (lambda (proj)
             (let* ((full-path (expand-file-name proj projects-dir))
                    (git-time (get-cached-directory-mtime
                               full-path #'get-git-recent-activity))
                    (dir-time (get-simple-directory-mtime full-path))
                    (activity-time (or git-time dir-time)))
               (cons proj activity-time)))
           project-dirs))
         (sorted-projects (sort projects-with-mtime
                               (lambda (a b)
                                 (time-less-p (cdr b) (cdr a)))))
         (display-projects (seq-take sorted-projects (or list-size 8))))
    (cond
     (display-projects
      (mapcar
       (lambda (proj-time-pair)
         (let* ((proj (car proj-time-pair))
                (mtime (cdr proj-time-pair))
                (full-path (expand-file-name proj projects-dir))
                (seconds-ago
                 (if (and mtime (not (equal mtime '(0 0))))
                     (float-time (time-subtract (current-time) mtime))
                   nil))
                (folder-icon
                 (cond
                  ((null seconds-ago) :folder)
                  ((< seconds-ago 86400) :folder-open)
                  ((< seconds-ago 604800) :folder)
                  (t :folder-archive)))
                (time-ago
                 (if seconds-ago
                     (cond
                      ((< seconds-ago 3600)
                       (format "%.0fm ago" (/ seconds-ago 60)))
                      ((< seconds-ago 86400)
                       (format "%.1fh ago" (/ seconds-ago 3600)))
                      ((< seconds-ago 604800)
                       (format "%.1fd ago" (/ seconds-ago 86400)))
                      (t (format-time-string "%Y-%m-%d" mtime)))
                   "unknown")))
           (format "    %s - %s\n"
                   (propertize (format "%s%s" (skewed-dashboard-pad-icon folder-icon) proj)
                               'keymap (let ((map (make-sparse-keymap)))
                                          (define-key map (kbd "RET")
                                                      (eval
                                                       `(lambda () (interactive)
                                                          (dired ,full-path))))
                                          (define-key map [mouse-1]
                                                      `(lambda () (interactive)
                                                         (dired ,full-path)))
                                          map)
                               'face 'button
                               'help-echo (format "Open %s in Dired" full-path))
                   time-ago)))
       display-projects))
     ((and (file-exists-p projects-dir)
           (file-directory-p projects-dir))
      (list (format "    --- No projects detected in %s ---\n" projects-dir)))
     (t
      (list (format "    --- No %s directory exists ---\n" projects-dir))))))


(defun lisply-backends-strings (list-size)
  "Return a list of propertized strings for lisply backends dashboard item."
  (if list-size
      (let ((backends (or (discover-network-lisply-backends)
                          '((:host "localhost" :port 7080 :name "skewed-emacs")
                            (:host "localhost" :port 9081 :name "gendl")))))
        (if backends
            (mapcar (lambda (backend)
                      (let* ((host (plist-get backend :host))
                             (port (plist-get backend :port))
                             (name (or (plist-get backend :name) "unknown"))
                             (result (silent-http-ping host port "/lisply/ping-lisp" 0.5))
                             (is-ok (string= (plist-get result :status) "OK"))
                             (icon (if is-ok :check :cross)))
                        (format "    %s\n"
                               (propertize
                                (format "%s%s (%s:%s)%s"
                                        (skewed-dashboard-pad-icon icon)
                                        name host port
                                        (if is-ok
                                            (format " - %s" (or (plist-get result :time) "?ms"))
                                          ""))
                                'keymap (let ((map (make-sparse-keymap)))
                                          (define-key map (kbd "RET")
                                                      `(lambda () (interactive)
                                                         (browse-url (format "http://%s:%s" ,host ,port))))
                                          (define-key map [mouse-1]
                                                      `(lambda () (interactive)
                                                         (browse-url (format "http://%s:%s" ,host ,port))))
                                          map)
                                'face (if is-ok 'success 'error)
                                'help-echo (format "Open %s Lisply backend in browser" name)))))
                    backends)
          (list "    No Lisply backends discovered\n")))
    '()))

(defun other-status-strings (list-size)
  "Return a list of propertized strings for other status (SWANK services) dashboard item."
  (if list-size
      (let ((services (discover-swank-services)))
        (if services
            (append
             (mapcar (lambda (service-info)
                       (let* ((host (plist-get service-info :host))
                              (icon (plist-get service-info :icon))
                              (port (plist-get service-info :port))
                              (name (plist-get service-info :name)))
                         (format "    %s\n"
                                 (propertize
                                  ;; Use pad-icon helper to guarantee alignment
                                  (format "%s%s on %s" (skewed-dashboard-pad-icon icon) (or name host) port)
                                  'keymap (let ((map (make-sparse-keymap)))
                                            (define-key map (kbd "RET")
                                                        `(lambda () (interactive)
                                                           (slime-connect ,host ,port)))
                                            (define-key map [mouse-1]
                                                        `(lambda () (interactive)
                                                           (slime-connect ,host ,port)))
                                            map)
                                  'face 'button
                                  'help-echo (format "Connect to SLIME on %s:%s" host port)))))
                     services)
             (list "  Enter via an above link or use 𝙼-𝚡 𝚜𝚕𝚒𝚖𝚎-𝚌𝚘𝚗𝚗𝚎𝚌𝚝.\n"))
          (list "  No SWANK services detected\n")))
    '()))

(defun system-info-strings (list-size)
  "Return a list of propertized strings for system information dashboard item."
  (if list-size
      (let ((system-info (gather-system-info)))
        (list
         (format "    %sEmacs PID: %s | Uptime: %s\n"
                 (skewed-dashboard-pad-icon :sys-process)
                 (plist-get system-info :emacs-pid)
                 (emacs-uptime))
         (let ((memory (plist-get system-info :memory-mb))
               (cpu-time (plist-get system-info :cpu-seconds)))
           (format "    %sMemory: %s | CPU Time: %s\n"
                   (skewed-dashboard-pad-icon :sys-memory)
                   (if memory (format "%.1f MB" memory) "N/A")
                   (if cpu-time
                       (let ((minutes (floor (/ cpu-time 60)))
                             (seconds (mod cpu-time 60)))
                         (if (> minutes 0)
                             (format "%dm %.1fs" minutes seconds)
                           (format "%.1fs" seconds)))
                     "N/A")))
         (format "    %sPackages: %d | Buffers: %d/%d total\n"
                 (skewed-dashboard-pad-icon :sys-package)
                 (plist-get system-info :active-packages)
                 (plist-get system-info :visible-buffers)
                 (plist-get system-info :total-buffers))
         (format "    %sVersion: %s | %sPlatform: %s\n"
                 (skewed-dashboard-pad-icon :sys-version)
                 (plist-get system-info :emacs-version)
		 (skewed-dashboard-pad-icon :platform)
                 (plist-get system-info :system-type))
         (format "    %sTime: %s %s\n"
                 (skewed-dashboard-pad-icon :sys-time)
                 (plist-get system-info :current-time)
                 (format-time-string "%Z"))))
    '()))


;;; Utilities and Banner =======================================================

(defun silent-http-ping (host port endpoint &optional timeout)
  "Ping HTTP ENDPOINT on HOST at PORT silently.
Returns (:status OK|ERROR :time response-time-ms)."
  (let ((url (format "http://%s:%d%s" host port (or endpoint "/")))
        (url-request-timeout (or timeout 2))
        (start-time (current-time))
        (inhibit-message t)             ; Suppress all messages
        (message-log-max nil)           ; Don't log messages
        (url-show-status nil)           ; Don't show URL status
        (url-automatic-caching nil)     ; Disable caching
        (url-debug nil)
        (url-http-attempt-keepalives nil))                ; Disable debug output
    (condition-case err
        (let ((buffer (url-retrieve-synchronously url nil t url-request-timeout)))
          (if buffer
              (unwind-protect
                  (with-current-buffer buffer
                    (let ((response-time (float-time (time-subtract (current-time) start-time))))
                      (goto-char (point-min))
                      (if (re-search-forward "HTTP/[0-9]\\.[0-9] \\([0-9]+\\)" nil t)
                          (let ((status-code (string-to-number (match-string 1))))
                            (list :status (if (< status-code 400) "OK" "ERROR")
                                  :code status-code
                                  :time (format "%.0fms" (* response-time 1000))))
                        (list :status "ERROR" :error "No HTTP response"))))
                ;; Always clean up the buffer
                (kill-buffer buffer))
            (list :status "ERROR" :error "No response")))
      (error (list :status "ERROR" :error (error-message-string err))))))


(defun get-emacs-memory-usage ()
  "Get current Emacs process memory usage in MB."
  (let ((status-file (format "/proc/%d/status" (emacs-pid))))
    (when (file-exists-p status-file)
      (with-temp-buffer
        (insert-file-contents status-file)
        (goto-char (point-min))
        ;; Look for VmRSS (Resident Set Size) - this is like RES in htop
        (when (re-search-forward "^VmRSS:[[:space:]]+\\([0-9]+\\)[[:space:]]+kB" nil t)
          (let ((rss-kb (string-to-number (match-string 1))))
            (/ rss-kb 1024.0)))))))

(defun get-emacs-cpu-time ()
  "Get total CPU time consumed by Emacs process in seconds."
  (let ((stat-file (format "/proc/%d/stat" (emacs-pid))))
    (when (file-exists-p stat-file)
      (with-temp-buffer
        (insert-file-contents stat-file)
        (goto-char (point-min))
        ;; /proc/pid/stat format: pid comm state ppid ... utime stime ...
        ;; Fields 14 and 15 are utime and stime (in clock ticks)
        (let ((fields (split-string (buffer-string))))
          (when (>= (length fields) 15)
            (let ((utime (string-to-number (nth 13 fields)))  ; user time
                  (stime (string-to-number (nth 14 fields)))  ; system time
                  (clock-ticks-per-sec 100)) ; typically 100 on Linux
              (/ (+ utime stime) clock-ticks-per-sec))))))))


(defun visible-buffer-list ()
  "Return a list of open, non-internal buffers as seen in `electric-buffer-list`."
  (seq-filter (lambda (buf)
                (not (string-prefix-p " " (buffer-name buf))))
              (buffer-list)))

(defun gather-system-info ()
  "System info gathering with memory and CPU usage."
  (let ((memory-mb (get-emacs-memory-usage))
        (cpu-seconds (get-emacs-cpu-time)))
    (list :emacs-pid (emacs-pid)
          :current-time (current-time-string)
          :active-packages (length package-activated-list)
          :visible-buffers (length (visible-buffer-list))
          :total-buffers (length (buffer-list))
          :emacs-version emacs-version
          :system-type system-type
          :working-dir default-directory
          :memory-mb memory-mb
          :cpu-seconds cpu-seconds
          :lisply-backends '((:name "skewed-emacs" :port 7080 :endpoint "/lisply/lisp-eval")
                           (:name "gendl" :port 9080 :endpoint "/lisply/lisp-eval"))
          :quick-actions '((:key "[C-c d r]" :action  "Refresh Dashboard")
                         (:Key "[C-c d d]" :action "Open Dashboard")
                         (:key "[C-c d a]" :action "Toggle Auto-refresh")))))


(defun get-simple-directory-mtime (dir)
  "Get directory modification time of DIR (when files added/removed)."
  (file-attribute-modification-time (file-attributes dir)))

(defun get-git-recent-activity (dir)
  "Get most recent git commit time of DIR."
  (when (file-exists-p (expand-file-name ".git" dir))
    (let ((default-directory dir))
      (condition-case nil
          (let ((output (shell-command-to-string "git log -1 --format=%ct")))
            (when (string-match "^[0-9]+" output)
              (seconds-to-time (string-to-number (match-string 0 output)))))
        (error nil)))))

(defvar project-mtime-cache (make-hash-table :test 'equal))
(defvar project-cache-timeout 30)

(defun get-cached-directory-mtime (dir strategy-function)
  "Get directory mtime with caching of DIR using STRATEGY-FUNCTION."
  (let* ((cache-key dir)
         (cached-entry (gethash cache-key project-mtime-cache))
         (now (current-time)))
    (if (and cached-entry
             (< (float-time (time-subtract now (plist-get cached-entry :timestamp)))
                project-cache-timeout))
        (plist-get cached-entry :mtime)
      (let ((new-mtime (funcall strategy-function dir)))
        (puthash cache-key (list :mtime new-mtime :timestamp now) project-mtime-cache)
        new-mtime))))

(defvar skewed-dashboard-banners
  '(:blur-vision
    "
 ░▒▓███████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░▒▓███████▓▒░ 
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
 ░▒▓██████▓▒░░▒▓███████▓▒░░▒▓██████▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓██████▓▒░ ░▒▓█▓▒░░▒▓█▓▒░
       ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
       ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░
░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░░▒▓█████████████▓▒░░▒▓████████▓▒░▒▓███████▓▒░ 
                                                                                      
                                                                                      
      ░▒▓████████▓▒░▒▓██████████████▓▒░ ░▒▓██████▓▒░ ░▒▓██████▓▒░ ░▒▓███████▓▒░        
      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░              
      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░       ░▒▓█▓▒░              
      ░▒▓██████▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░▒▓█▓▒░       ░▒▓██████▓▒░        
      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░            ░▒▓█▓▒░        
      ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░        
      ░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓███████▓▒░
"
    :big-money-ne
    (:skewed
     "
  /$$$$$$  /$$   /$$ /$$$$$$$$ /$$       /$$ /$$$$$$$$ /$$$$$$$
 /$$__  $$| $$  /$$/| $$_____/| $$  /$ | $$| $$_____/| $$__  $$
| $$  \\__/| $$ /$$/ | $$       | $$ /$$$| $$| $$       | $$  \\ $$
|  $$$$$$ | $$$$$/  | $$$$$    | $$/$$ $$ $$| $$$$$    | $$  | $$
 \\____  $$| $$  $$  | $$__/    | $$$$_  $$$$| $$__/    | $$  | $$
 /$$  \\ $$| $$\\  $$ | $$       | $$$/ \\  $$$| $$       | $$  | $$
|  $$$$$$/| $$ \\  $$| $$$$$$$$| $$/    \\  $$| $$$$$$$$| $$$$$$$/
 \\______/ |__/  \\__/|________/|__/      \\__/|________/|_______/
"
     :emacs
     "
       /$$$$$$$$ /$$       /$$  /$$$$$$   /$$$$$$   /$$$$$$
      | $$_____/| $$$     /$$$ /$$__  $$ /$$__  $$ /$$__  $$
      | $$      | $$$$   /$$$$| $$  \\ $$| $$  \\__/| $$  \\__/
      | $$$$$   | $$ $$/$$ $$| $$$$$$$$| $$       |  $$$$$$
      | $$__/   | $$  $$$| $$| $$__  $$| $$        \\____  $$
      | $$      | $$\\  $ | $$| $$  | $$| $$    $$ /$$  \\ $$
      | $$$$$$$$| $$ \\/  | $$| $$  | $$|  $$$$$$/|  $$$$$$/
      |________/|__/      |__/|__/  |__/ \\______/  \\______/
")

    :big-money-nw
    (:skewed
     "
 $$$$$$\\  $$\\   $$\\ $$$$$$$$\\ $$\\       $$\\ $$$$$$$$\\ $$$$$$$\\
$$  __$$\\ $$ | $$  |$$  _____|$$ | $\\  $$ |$$  _____|$$  __$$\\
$$ /  \\__|$$ |$$  / $$ |      $$ |$$$\\ $$ |$$ |      $$ |  $$ |
\\$$$$$$\\  $$$$$  /  $$$$$\\    $$ $$ $$\\$$ |$$$$$\\    $$ |  $$ |
 \\____$$\\ $$  $$<   $$  __|   $$$$  _$$$$ |$$  __|   $$ |  $$ |
$$\\   $$ |$$ |\\$$\\  $$ |      $$$  / \\$$$ |$$ |      $$ |  $$ |
\\$$$$$$  |$$ | \\$$\\ $$$$$$$$\\ $$  /    \\$$ |$$$$$$$$\\ $$$$$$$  |
 \\______/ \\__|  \\__|\\________|\\__/      \\__|\\________|\\_______/
"
     :emacs
     "
       $$$$$$$$\\ $$\\       $$\\  $$$$$$\\   $$$$$$\\   $$$$$$\\
       $$  _____|$$$\\     $$$ |$$  __$$\\ $$  __$$\\ $$  __$$\\
       $$ |      $$$$\\   $$$$ |$$ /  $$ |$$ /  \\__|$$ /  \\__|
       $$$$$\\    $$\\$$\\$$ $$ |$$$$$$$$ |$$ |      \\$$$$$$\\
       $$  __|   $$ \\$$$  $$ |$$  __$$ |$$ |       \\____$$\\
       $$ |      $$ |\\$  /$$ |$$ |  $$ |$$ |  $$\\ $$\\   $$ |
       $$$$$$$$\\ $$ | \\_/ $$ |$$ |  $$ |\\$$$$$$  |\\$$$$$$  |
       \\________|\\__|      \\__|\\__|  \\__| \\______/  \\______/
")
    :big-money-se
    (:skewed
    "
  ______   __     __  ________  __        __  ________  _______
 /      \\ |  \\   /  \\|        \\|  \\  _   |  \\|        \\|       \\
|  $$$$$$\\| $$ /  $$| $$$$$$$$| $$ / \\ | $$| $$$$$$$$| $$$$$$$\\
| $$___\\$$| $$/  $$ | $$__     | $$/  $\\| $$| $$__     | $$  | $$
 \\$$    \\ | $$  $$  | $$  \\    | $$  $$$\\ $$| $$  \\    | $$  | $$
 _\\$$$$$$\\| $$$$$\\  | $$$$$    | $$ $$\\$$\\$$| $$$$$    | $$  | $$
|  \\__| $$| $$ \\$$\\ | $$_____ | $$$$  \\$$$$| $$_____ | $$__/ $$
 \\$$    $$| $$  \\$$\\| $$      \\| $$$     \\$$$| $$      \\| $$    $$
  \\$$$$$$  \\$$   \\$$ \\$$$$$$$$ \\$$      \\$$ \\$$$$$$$$ \\$$$$$$$
"
    :emacs
    "
       ________  __       __   ______    ______    ______      
      |        \\|  \\     /  \\ /      \\  /      \\  /      \\     
      | $$$$$$$$| $$\\   /  $$|  $$$$$$\\|  $$$$$$\\|  $$$$$$\\    
      | $$__    | $$$\\ /  $$$| $$__| $$| $$   \\$$| $$___\\$$    
      | $$  \\   | $$$$\\  $$$$| $$    $$| $$       \\$$    \\     
      | $$$$$   | $$\\$$ $$ $$| $$$$$$$$| $$   __  _\\$$$$$$\\    
      | $$_____ | $$ \\$$$| $$| $$  | $$| $$__/  \\|  \\__| $$    
      | $$     \\| $$  \\$ | $$| $$  | $$ \\$$    $$ \\$$    $$    
       \\$$$$$$$$ \\$$      \\$$ \\$$   \\$$  \\$$$$$$   \\$$$$$$
")

    :big-money-sw
    (:skewed
     "
  ______   __    __  ________  __       __  ________  _______  
 /      \\ /  |  /  |/        |/  |  _  /  |/        |/       \\ 
/$$$$$$  |$$ | /$$/ $$$$$$$$/ $$ | / \\ $$ |$$$$$$$$/ $$$$$$$  |
$$ \\__$$/ $$ |/$$/  $$ |__    $$ |/$  \\$$ |$$ |__    $$ |  $$ |
$$      \\ $$  $$<   $$    |   $$ /$$$  $$ |$$    |   $$ |  $$ |
 $$$$$$  |$$$$$  \\  $$$$$/    $$ $$/$$ $$ |$$$$$/    $$ |  $$ |
/  \\__$$ |$$ |$$  \\ $$ |_____ $$$$/  $$$$ |$$ |_____ $$ |__$$ |
$$    $$/ $$ | $$  |$$       |$$$/    $$$ |$$       |$$    $$/ 
 $$$$$$/  $$/   $$/ $$$$$$$$/ $$/      $$/ $$$$$$$$/ $$$$$$$/
"
     :emacs
     "
       ________  __       __   ______    ______    ______      
      /        |/  \\     /  | /      \\  /      \\  /      \\     
      $$$$$$$$/ $$  \\   /$$ |/$$$$$$  |/$$$$$$  |/$$$$$$  |    
      $$ |__    $$$  \\ /$$$ |$$ |__$$ |$$ |  $$/ $$ \\__$$/     
      $$    |   $$$$  /$$$$ |$$    $$ |$$ |      $$      \\     
      $$$$$/    $$ $$ $$/$$ |$$$$$$$$ |$$ |   __  $$$$$$  |    
      $$ |_____ $$ |$$$/ $$ |$$ |  $$ |$$ \\__/  |/  \\__$$ |    
      $$       |$$ | $/  $$ |$$ |  $$ |$$    $$/ $$    $$/     
      $$$$$$$$/ $$/      $$/ $$/   $$/  $$$$$$/   $$$$$$/      
")))



(defun generate-skewed-dashboard-banner (&optional text-file)
  "Generate our needed dashboard banner TEXT-FILE."
  (unless text-file (setq text-file skewed-dashboard-banner-file))
  (let ((skewed-banner (plist-get
                        (plist-get skewed-dashboard-banners :big-money-sw) :skewed))
        (emacs-banner (plist-get
                       (plist-get skewed-dashboard-banners :big-money-se) :emacs)))

    (write-region (concat skewed-banner emacs-banner) nil text-file nil nil nil nil)
    ))


(provide 'dashboard-config)
;;; dashboard-config.el ends here
