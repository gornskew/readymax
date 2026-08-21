;;; init.el --- skewed config -*- lexical-binding: nil -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Commentary:
;;; This is my personal Emacs configuration.
;;; It was inspired by but is no longer based on Crafted Emacs.
;;;
;;; Code:

(require 'cl-lib)

;; Define emacs-config-directory
(defvar emacs-config-directory (file-name-directory (file-truename load-file-name)))

(defvar start-lisply? (not (string= (getenv "START_HTTP") "false")))
(defvar skewed-emacs-container? (getenv "SKEWED_EMACS_CONTAINER"))
(defvar skewed-emacs-docker-build? (or (getenv "EMACS_BATCH_MODE")
				       (getenv "SKEWED_EMACS_DOCKER_BUILD")))


(defconst my/on-android-p   (eq system-type 'android))
(defconst my/in-docker-p    (getenv "SKEWED_EMACS_CONTAINER"))
(defconst my/docker-build-p (getenv "SKEWED_EMACS_DOCKER_BUILD"))
(message "Environment – Android: %s | Docker container: %s | Docker build: %s"
         my/on-android-p my/in-docker-p my/docker-build-p)

;; Redirect custom settings to a separate file
(setq custom-file (concat emacs-config-directory "custom.el"))

;; Inode-safe saves: this stack bind-mounts SINGLE FILES into
;; containers (every cyclops config, for one), and a container pins
;; the file's inode at mount time.  Emacs's default first-save-of-a-
;; session makes the backup by RENAMING the original -- the old inode
;; becomes file~, the path gets a fresh inode, and the container
;; silently reads stale content forever after (cyclops reload-config
;; then "succeeds" against the old bytes).  backup-by-copying makes
;; Emacs copy the backup aside and truncate-write the original inode
;; in place.  Keep file-precious-flag nil for the same reason.
(setq backup-by-copying t)

(defvar second-party-packages nil)
(defvar third-party-packages nil)

;; Simple, reliable icon detection
(defun skewed-should-use-icons-p ()
  "Simple icon detection: graphical=icons, terminal=unicode."
  (display-graphic-p))



(setq
 third-party-packages
 (remove
  nil
  `((flycheck
     :commands flycheck-mode
     :hook (prog-mode . flycheck-mode)
     :defer (not skewed-emacs-docker-build?)
     )
    (company
     :commands company-mode
     :hook (prog-mode . company-mode)  
     :defer (not skewed-emacs-docker-build?)
     )

    
    ;; (vterm
    ;;  :commands vterm
    ;;  :bind ("C-c v" . vterm)
    ;;  :defer (not skewed-emacs-docker-build?)
    ;;  :config
    ;;  (setq vterm-max-scrollback 10000)
    ;;  )
    
    (eat
     :commands eat
     :bind ("C-c t" . eat)
     :defer (not skewed-emacs-docker-build?)
     )

    (vterm
     :commands vterm
     :defer (not skewed-emacs-docker-build?)
     :init (setq vterm-always-compile-module t)
     :config (setq vterm-max-scrollback 10000
		   vterm-kill-buffer-on-exit t))
    
    
    (doom-themes
     :demand t				; Load immediately for UI
     :config (load-theme 'modus-vivendi t)
     :defer nil
     )

    (nerd-icons
     :demand t
     ;; Fonts are baked at image-build time; a container must never
     ;; download them at startup (airgap guarantee).
     :config (when (and (display-graphic-p)
			(not skewed-emacs-container?)
			(not (find-font
			      (font-spec :name "Symbols Nerd Font Mono"))))
	       (nerd-icons-install-fonts :quiet)))
    
    (doom-modeline
     :demand t
     :hook (after-init . doom-modeline-mode)
     :defer nil
     :config
     (setq doom-modeline-height 25
           doom-modeline-bar-width 3
           doom-modeline-enable-word-count t
           doom-modeline-buffer-file-name-style 'truncate-upto-project
           doom-modeline-icon (display-graphic-p)
           doom-modeline-unicode-fallback t
           doom-modeline-buffer-encoding nil
           doom-modeline-env-version t
           doom-modeline-vcs-max-length 12
           doom-modeline-workspace-name t)
     (when (package-installed-p 'nerd-icons)
       (setq nerd-icons-font-family "Symbols Nerd Font Mono")))

    (rainbow-delimiters
     ;;:defer (not skewed-emacs-docker-build?)
     :demand t
     :defer nil
     :hook ((prog-mode . rainbow-delimiters-mode)
            (emacs-lisp-mode . rainbow-delimiters-mode)
            (lisp-mode . rainbow-delimiters-mode)
            (scheme-mode . rainbow-delimiters-mode)
            (clojure-mode . rainbow-delimiters-mode)
            (json-mode . rainbow-delimiters-mode)
            (eshell-mode . rainbow-delimiters-mode))
     :config
     (setq rainbow-delimiters-max-face-count 8
           rainbow-delimiters-highlight-braces-p t
           rainbow-delimiters-highlight-brackets-p t))

    (projectile
     :commands (projectile-mode projectile-find-file projectile-switch-project)
     :bind-keymap ("C-c p" . projectile-command-map)
     :defer (not skewed-emacs-docker-build?)
     :config
     (projectile-mode 1)
     (setq projectile-completion-system 'default
           projectile-project-search-path '("~/projects/" "~/")))

    (solaire-mode
     :demand t
     :defer nil
     :config
     (solaire-global-mode 1)
     ;; Better contrast settings for modeline
     (setq solaire-mode-auto-swap-bg nil
           solaire-mode-remap-modeline nil)
     ;; Auto-enable for appropriate buffer types
     (add-hook 'dired-mode-hook #'solaire-mode)
     (add-hook 'help-mode-hook #'solaire-mode)
     (add-hook 'compilation-mode-hook #'solaire-mode))
    
    (zenburn-theme
     :demand t				; Alternative theme
     :config (load-theme 'zenburn t)
     :defer nil)
    (yaml
     :mode (("\\.ya?ml\\'" . yaml-mode))
     :hook (yaml-mode . (lambda () (setq yaml-indent-offset 2)))
     :defer nil)
    (ellama
     :commands ellama
     :defer (not skewed-emacs-docker-build?))
    (json-mode
     :mode ("\\.json\\'" . json-mode)
     :defer nil
     :hook (json-mode . (lambda () (setq js-indent-level 2))))
    (simple-httpd
     :commands httpd-start
     :defer nil)
    (dashboard
     :demand t				; Load for daemon startup
     :defer nil
     :config (dashboard-setup-startup-hook))
    (paredit
     :hook (emacs-lisp-mode . paredit-mode)
     :defer (not skewed-emacs-docker-build?))
    (magit
     :defer (not skewed-emacs-docker-build?)
     :commands (magit-status magit-blame)
     :bind ("C-x g" . magit-status)
     :config (setq magit-git-executable (locate-file "git" exec-path)))

    ,(unless (eql system-type 'android)
       `(pdf-tools
	 :mode ("\\.pdf\\'" . pdf-view-mode)
	 :config
	 (cond
	  (skewed-emacs-docker-build?
	   ;; Dockerfile builds epdfinfo via autobuild; never prompt in init.
	   (message "pdf-tools: docker build mode; skipping pdf-tools-install (epdfinfo built in Dockerfile)"))
	  (t
	   (pdf-tools-install :no-query)
	   (pdf-loader-install)))))

    
    (org
     :ensure nil
     :defer (not skewed-emacs-docker-build?)
     :commands (org-mode org-agenda)
     )

    (org-contrib
     :defer (not skewed-emacs-docker-build?)
     :after org
     :config
     (require 'org-depend)
     )


    (htmlize
     :defer (not skewed-emacs-docker-build?)
     :init
     (setq htmlize-output-type 'inline-css
	   htmlize-pre-style t
	   htmlize-html-charset "utf-8")
     )

    (inheritenv :ensure t :defer t)
    
    


   )))

(setq
 second-party-packages
 `(   (org-config
    :ensure nil
    :defer (not skewed-emacs-docker-build?)
    :load-path ,(lambda () (get-config-path "etc"))
    :hook (org-mode . (lambda () (require 'org-config))))
   (sa-translit-config
    :ensure nil
    :defer nil
    :load-path ,(lambda () (get-config-path "etc")))
   (skewed-install-config
    :ensure nil
    :defer t
    :load-path ,(lambda () (get-config-path "etc"))
    :commands (skewed-install skewed-uninstall skewed-install-list))
   (dashboard-config
    :ensure nil
    :defer nil
    :load-path ,(lambda () (get-config-path "etc"))
    :config
    (require 'dashboard-config)
    (generate-skewed-dashboard-banner))
   (impatient-markdown-config
    :ensure nil
    :defer (not skewed-emacs-docker-build?)
    :load-path ,(lambda () (get-config-path "etc")))
   (slime-config
    :ensure nil
    :defer (not skewed-emacs-docker-build?)
    :load-path ,(lambda () (get-config-path "etc"))
    :commands (slime slime-connect slime-repl slime-selector
		     load-and-or-start-gendl set-slime-shortcuts)
    :mode (("\\.lisp\\'" . lisp-mode)
           ("\\.cl\\'" . lisp-mode)
           ("\\.gdl\\'" . lisp-mode)
           ("\\.gendl\\'" . lisp-mode)
           ("\\.lhtm\\'" . lisp-mode)
           ("\\.lhtml\\'" . lisp-mode)
           ("\\.sexp\\'" . lisp-mode)
           ("\\.sexpr\\'" . lisp-mode)
           ("\\.sexps\\'" . lisp-mode))
    :hook (lisp-mode . (lambda () (require 'slime-config))))
   (lisply-config
    :ensure nil
    :defer nil
    :load-path ,(lambda () (get-config-path "etc"))
    :config
    ;; Always load the config so the command + defcustoms exist.  Container
    ;; detection is env-based (available now), so start inline to preserve the
    ;; dashboard self-check timing.  The host opt-in lives in custom.el /
    ;; .emacs-local, which load later, so defer that case to
    ;; `emacs-startup-hook'.  See etc/lisply-config.el.
    (require 'lisply-config)
    (if (getenv "SKEWED_EMACS_CONTAINER")
        (lisply-maybe-autostart)
      (add-hook 'emacs-startup-hook #'lisply-maybe-autostart)))

   (htmlize-config
    :ensure nil
    :defer (not skewed-emacs-docker-build?)
    :load-path ,(lambda () (get-config-path "etc"))
    :config (require 'htmlize-config))))

(load (concat emacs-config-directory "etc/load-and-compile.el"))
(setup-packages-and-customizations emacs-config-directory)

(defvar light-theme-options
  '(("doom-feather-light" . doom-feather-light)
    ("adwaita" . adwaita)
    ("tsdh-light" . tsdh-light)
    ("light-blue" . light-blue)
    ("doom-one-light" . doom-one-light)
    ("doom-light" . doom-gruvbox-light))
  "List of light themes for `light-theme' function.")

(defvar dark-theme-options
  '(("modus-vivendi" . modus-vivendi-deuteranopia)
    ("doom-purple" . doom-shades-of-purple)
    ("doom-one" . doom-one)
    ("doom-tokyo-night" . doom-tokyo-night)
    ("doom-pine" . doom-pine)
    ("doom-gruvbox" . doom-gruvbox)
    ("zenburn" . zenburn))
  "List of dark themes for `dark-theme' function.")

(defun main-setup ()
  "Set up hooks and Lisply server if enabled."

  (add-hook 'before-make-frame-hook 'on-before-make-frame)
  (add-hook 'after-make-frame-functions 'on-after-make-frame)
  (add-hook 'eshell-load-hook #'eat-eshell-mode)
  (add-hook 'eshell-load-hook #'eat-eshell-visual-command-mode)



  ;;
  ;; FLAG -- do something to not have to hardcode "gendl-ccl" and the port here. 
  ;;
  (when skewed-emacs-container?
    (message "We Are a Skewed-emacs container, defaulting slime-connect settings to
gendl-ccl/4200.")
    (setq slime-lisp-host "gendl-ccl"
   	  slime-connect-host-history '("gendl-ccl")
   	  slime-port 4200
   	  slime-connect-port-history '("4200")))

  (message "Done with main-setup.")


  )

(defun my/is-theme-light-p ()
  "Return t if the current theme has a light background, nil otherwise."
  (let* ((bg (face-background 'default nil t))
         (rgb (color-name-to-rgb bg)))
    (if rgb
        (let ((luminance (+ (* 0.299 (nth 0 rgb))
                           (* 0.587 (nth 1 rgb))
                           (* 0.114 (nth 2 rgb)))))
          (> luminance 0.5)) ; Threshold for light vs dark
      (eq frame-background-mode 'light))))


(defvar my/dark-theme-colors
  '((show-paren-match :background "#33E0E0" :foreground "#EEEEEE" :weight bold) 
    (rainbow-delimiters-depth-1 :foreground "#FF3333") ; Bright red
    (rainbow-delimiters-depth-2 :foreground "#33CC33") ; Lime green
    (rainbow-delimiters-depth-3 :foreground "#8888FF") ; Bright blue
    (rainbow-delimiters-depth-4 :foreground "#FF9933") ; Orange
    (rainbow-delimiters-depth-5 :foreground "#CC33CC") ; Magenta
    (rainbow-delimiters-depth-6 :foreground "#33CCCC") ; Cyan
    (rainbow-delimiters-depth-7 :foreground "#CCCC33") ; Yellow
    (rainbow-delimiters-depth-8 :foreground "#BB55EE") ; Purple
    ) ; Light blue
  "Colors for dark background themes.")

(defvar my/light-theme-colors
  '((show-paren-match :background "#22A0A0" :foreground "#EEEEEE" :weight bold)    (rainbow-delimiters-depth-1 :foreground "#A10000") ; Deep red
    (rainbow-delimiters-depth-2 :foreground "#006600") ; Forest green
    (rainbow-delimiters-depth-3 :foreground "#000099") ; Deep blue
    (rainbow-delimiters-depth-4 :foreground "#CC6600") ; Burnt orange
    (rainbow-delimiters-depth-5 :foreground "#660066") ; Deep purple
    (rainbow-delimiters-depth-6 :foreground "#007070") ; Teal
    (rainbow-delimiters-depth-7 :foreground "#666600") ; Olive
    (rainbow-delimiters-depth-8 :foreground "#EB87E1") ; Magenta
    ) 
  "Colors for light background themes.")


(defun my/update-paren-and-delimiter-faces ()
  (interactive)
  "Set show-paren-match and rainbow-delimiters faces based on theme background."
  (let ((colors (if (my/is-theme-light-p)
                    my/light-theme-colors
                  my/dark-theme-colors)))
    ;; Set show-paren-match
    (apply 'set-face-attribute 'show-paren-match nil
           (cdr (assoc 'show-paren-match colors)))
    ;; Set rainbow-delimiters
    (dolist (depth (number-sequence 1 9))
      (let ((face (intern (format "rainbow-delimiters-depth-%d-face" depth))))
        (apply 'set-face-attribute face nil
               (cdr (assoc (intern (format "rainbow-delimiters-depth-%d" depth)) colors)))))))

(defun set-default-settings ()
  "Set my personal preferred default settings."
  (interactive)


  (set-face-attribute 'show-paren-match nil
		      :background "#4A3728" ;
		      :foreground "#FFFFFF" ;
		      :weight 'bold)
  
  (if (display-graphic-p)
      (setup-graphical-keybindings-and-faces)
    (setup-terminal-keybindings-and-faces))
  (setup-other-keybindings-and-faces)
  (when (display-graphic-p)
    ;;(set-fontset-font "DejaVu Sans" nil t)
    (setq-default
     font-use-system-font t
     inhibit-compacting-font-caches t
     line-spacing 0.1)
    (when (package-installed-p 'pdf-tools)
      (setq pdf-view-display-size 'fit-page
            pdf-view-resize-factor 1.1
            pdf-view-use-scaling t
            pdf-view-use-imagemagick nil))
    
    (setq scroll-step 1
          scroll-conservatively 10000
          scroll-preserve-screen-position 1))
  (prefer-coding-system 'utf-8)
  (set-default-coding-systems 'utf-8)
  (set-terminal-coding-system 'utf-8)
  (set-keyboard-coding-system 'utf-8)
  (set-selection-coding-system 'utf-8)
  (set-file-name-coding-system 'utf-8)
  (set-clipboard-coding-system 'utf-8)
  (set-buffer-file-coding-system 'utf-8)


  ;; Force SLIME to use UTF-8 for all Lisp file operations
  (setq slime-net-coding-system 'utf-8-unix)
  
  ;; Also make sure Emacs uses UTF-8 for Lisp files by default
  (modify-coding-system-alist 'file "\\.lisp\\'" 'utf-8-unix)
  (modify-coding-system-alist 'file "\\.lsp\\'"  'utf-8-unix)
  (modify-coding-system-alist 'file "\\.cl\\'"   'utf-8-unix)


  
  (setq column-number-mode t)
  (global-font-lock-mode t)
  (setq-default transient-mark-mode t)
  (show-paren-mode t)
  (setq scroll-step 1)
  (setup-input-methods)
  (setq confirm-kill-processes nil)
  (menu-bar-mode 0)
  (tool-bar-mode 0))


(defun enable-company-mode ()
  "Enable company mode."
  (interactive)
  (company-mode 1))

(defun disable-company-mode ()
  "Disable company mode."
  (interactive)
  (company-mode 0))

(defun disable-line-number-mode ()
  "Disable line number mode."
  (interactive)
  (line-number-mode -1))

(defun server-shutdown ()
  "Save buffers, quit, and shutdown server."
  (interactive)
  (save-some-buffers)
  (kill-emacs))

(defun setup-terminal-keybindings-and-faces ()
  "Set up bindings for terminal."
  (interactive)
  (message "About to set up keybindings for terminal use.")
  (dolist (map (list input-decode-map function-key-map))
    (define-key map "[113;7u" (kbd "C-M-q"))
    (define-key map "[102;7u" (kbd "C-M-f"))
    (define-key map "[98;7u" (kbd "C-M-b"))
    (define-key map "[107;7u" (kbd "C-M-k")))
  (global-set-key (kbd "ESC C-M-f") 'forward-sexp)
  (global-set-key (kbd "ESC C-M-b") 'backward-sexp)
  (global-set-key (kbd "ESC C-M-k") 'kill-sexp)
  (global-set-key (kbd "ESC C-M-q") 'indent-sexp)
  (global-set-key (kbd "M-]") 'kill-region)
  (message "Done with keybindings setup."))

(defun setup-graphical-keybindings-and-faces ()
  "Set up keybindings and faces for graphical mode."
  (let ((scale-factor (if (> (x-display-pixel-width) 1920) 1.5 1.0)))
    (set-face-attribute 'default nil
			;;:family "DejaVu Sans"
                        :height (round (* 110 scale-factor))
                        :weight 'normal
                        :width 'normal)
    ;; Ensure Nerd Font for icons
    ;;(set-fontset-font t 'unicode "Symbols Nerd Font Mono" nil 'prepend);
    ))

(defun setup-other-keybindings-and-faces ()
  "Set up additional keybindings and faces."
  (interactive)
  (global-set-key (kbd "\C-x y") 'previous-window-any-frame)
  (global-set-key (kbd "\C-c 8") "•")
  (global-set-key "\M-=" 'just-one-space)
  (global-set-key "\C-x\C-b" 'electric-buffer-list)
  ;;(global-set-key (kbd "C-x &") 'cycle-slime-repl-buffers)
  (global-set-key (kbd "C-c M-q") 'unfill-paragraph)
  (global-set-key (kbd "C-c x") 'server-shutdown))

(defun enable-mouse ()
  "Enable mouse interaction in terminal mode."
  (interactive)
  (unless window-system
    (require 'mouse)
    (xterm-mouse-mode t)
    (defun track-mouse (e))
    ;; (setq mouse-sel-mode t) ;; what is this supposed to be 
    ))

(defun disable-mouse ()
  "Disable mouse interaction in terminal mode."
  (interactive)
  (xterm-mouse-mode -1))

(defun clear-themes ()
  "Clear all themes."
  (interactive)
  (dolist (theme custom-enabled-themes) (disable-theme theme)))

(defun set-cursor-bright ()
  "Set cursor to a bright magenta color."
  (interactive)
  (when (not (display-graphic-p))
    (send-string-to-terminal "\e]12;rgb:ff/00/ff\a"))
  (set-cursor-color "#ff00ff"))

(defun dark-theme (&optional theme-name)
  "Load a dark theme, defaulting to `modus-vivendi."
  (interactive
   (list (completing-read "Select dark theme: "
                          (mapcar #'car dark-theme-options)
                          nil t "modus-vivendi")))
  (let* ((selected-theme (or theme-name "modus-vivendi"))
         (theme-symbol (cdr (assoc selected-theme dark-theme-options))))
    (unless theme-symbol
      (error "Unknown theme: %s" selected-theme))
    (clear-themes)
    (load-theme theme-symbol t)
    (my/update-paren-and-delimiter-faces)
    (when (not (display-graphic-p))
      (send-string-to-terminal "\e]12;rgb:ff/00/ff\a"))
    (set-cursor-color "#ff00ff")
    (setq cursor-type 'bar)
    (message "Loaded dark theme: %s" selected-theme)))

(defun light-theme (&optional theme-name)
  "Load a light theme, defaulting to `doom-feather-light`."
  (interactive
   (list (completing-read "Select light theme: "
                          (mapcar #'car light-theme-options)
                          nil t "doom-feather-light")))
  (let* ((selected-theme (or theme-name "doom-feather-light"))
         (theme-symbol (cdr (assoc selected-theme light-theme-options))))
    (unless theme-symbol
      (error "Unknown theme: %s" selected-theme))
    (clear-themes)
    (load-theme theme-symbol t)
    (my/update-paren-and-delimiter-faces)
    (when (not (display-graphic-p))
      (send-string-to-terminal "\e]12;rgb:00/00/ff\a"))
    (set-cursor-color "#0000ff")
    (setq cursor-type 'bar)
    (message "Loaded light theme: %s" selected-theme)))

(defun setup-input-methods ()
  "Set up additional input methods."
  (let ((file (concat emacs-config-directory "/etc/sa-translit.el")))
    (when (file-exists-p file)
      (load-file file)
      (register-input-method
       "sa-translit" "Sanskrit Transliteration" 'quail-use-package
       "sa-translit" "Converts Harvard-Kyoto and ITRANS scheme to IAST diacritics."
       file))))

(defun set-frame-size-and-position (frame)
  "Set the frame size of FRAME to half the screen width and full screen height."
  (let* ((screen-width (display-pixel-width))
         (screen-height (display-pixel-height))
         (decoration-width 42)
         (decoration-height 35)
         (frame-width (- (floor (/ screen-width 2)) decoration-width))
         (fudge 10)
         (frame-height (- (- screen-height decoration-height) fudge)))
    (set-frame-position frame 0 0)
    (set-frame-size frame frame-width frame-height t)))

(defun on-before-make-frame ()
  "Set up settings for new frame, e.g., turning off `tool-bar-mode`."
  (tool-bar-mode -1))

(defun on-after-make-frame (frame)
  "Configure settings for new FRAME."
  (select-frame frame)
  (set-default-settings)
  (my/update-paren-and-delimiter-faces)
  (when (display-graphic-p frame)
    (set-frame-size-and-position frame)))


(defun setup-themes ()
  "Set up my preferred default themes."
  (dark-theme))


(defun unfill-paragraph ()
  "Transform a filled paragraph into a single long line."
  (interactive)
  (let ((fill-column (point-max)))
    (fill-paragraph nil)))

(defun unfill-region (start end)
  "Transform the filled region from START to END into a single long line."
  (interactive "r")
  (let ((fill-column (point-max)))
    (fill-region start end nil)))

(defun unfill-buffer ()
  "Transform the filled buffer into single long lines."
  (interactive)
  (unfill-region (point-min) (point-max)))

(defun load-ai-tools ()
  "Load AI-related configurations."
  (message "FLAG - Load the Llama etc configs here from a separate file."))

(defun skewed-initialize ()
  "Main initialize."
  (let ((start-time (float-time)) curr-time elapsed)
    (setq curr-time start-time)

    (message "Starting skewed-initialize at %s."
	     start-time)
    
    (when (file-regular-p "~/.emacs-local-early")
      (load-file "~/.emacs-local-early"))

    (message "Calling main-setup at %s."
	     start-time)
    
    (main-setup)

    (message "Returned from main-setup at %s."
	     start-time)

    (let ((float-time (float-time)))
      (setq elapsed (- float-time curr-time))
      (setq curr-time float-time))

    (message "Done with main-setup in %s seconds."
	     elapsed)
    
    (when (file-exists-p custom-file)
      (load (file-name-sans-extension custom-file)))
    
    (setup-themes)

    (let ((float-time (float-time)))
      (setq elapsed (- float-time curr-time))
      (setq curr-time float-time))
    (message "Done with theme setups in %s seconds."
	     elapsed)
    
    (set-default-settings)

    (let ((float-time (float-time)))
      (setq elapsed (- float-time curr-time))
      (setq curr-time float-time))
    (message "Done with default settings setting in %s seconds."
	     elapsed)
    
    
    ;; bump this to load-and-compile
    (load-ai-tools)


    (require 'org) (require 'org-config)
    
    (when (file-regular-p "~/.emacs-local")
      (load-file "~/.emacs-local"))

    (message "Done with skewed-initialize in %s seconds."
	     (- (float-time) start-time))))


(skewed-initialize)


;; Custom Utility Functions callable via M-x


(defun generate-dev-lisp (&optional policy include-locals)
  "Generate a dev.lisp file based on Lisp-related files.
Do this according to the specified policy and 
optionally including locally modified/untracked files.
POLICY can be 1 (latest commit only) or 2 (unpushed changes, default).
INCLUDE-LOCALS is a boolean to include unstaged and untracked 
local changes (default t)."
  (interactive)
  (require 'magit)
  (require 'seq)
  (let* ((policy (or policy 2))
         (include-locals (if (null include-locals) t include-locals))
         (repo-dir (magit-toplevel))
         (current-branch (magit-get-current-branch))
         (upstream (or (magit-get-upstream-branch)
                       (format "origin/%s" current-branch)))
         (changes (if (= policy 1)
                      (magit-git-lines "diff-tree" "--no-commit-id" "--name-status" "-r" "HEAD")
                    (magit-git-lines "diff" "--name-status" upstream "HEAD")))
	 (strip-git-status
	  (lambda (str)
            (if (string-match "[ \t]*[AM][ \t]+" str)
                (substring str (match-end 0))
              (error "String does not start with uppercase letter followed by whitespace: %s" str))))
         (lisp-files (seq-filter (lambda (line)
                                   (when (string-match "^\\s-*\\([AMD]\\)\\s-+\\(.*\\)$" line)
                                     (let ((status (match-string 1 line))
                                           (file (match-string 2 line)))
                                       (and (not (string= status "D"))
                                            (string-match-p "\\.\\(lisp\\|gdl\\|gendl\\)$" file)
                                            file))))
                                 changes))
         (lisp-files (mapcar strip-git-status lisp-files))
         (local-changes (when include-locals
                          (magit-git-lines "status" "--porcelain")))
         (local-files (when include-locals
                        (seq-filter (lambda (line)
                                      (when (string-match "^\\(..\\) \\(.*\\)$" line)
                                        (let* ((xy (match-string 1 line))
                                               (x (substring xy 0 1))
                                               (y (substring xy 1 2))
                                               (file (match-string 2 line)))
                                          (and (or (and (string= x "?") (string= y "?"))
                                                   (string= y "M"))
                                               (not (string= y "D"))
                                               (string-match-p "\\.\\(lisp\\|gdl\\|gendl\\)$" file)
                                               file))))
                                    local-changes)))
	 (local-files (mapcar strip-git-status local-files))
         (lisp-files (if include-locals
                         (append lisp-files local-files)
                       lisp-files))
         (dev-lisp-path (expand-file-name "dev.lisp" repo-dir))
         (sexps `((in-package :gdl-user)

                  (defparameter *gendl-source-dir*
                                (make-pathname :defaults (glisp:source-pathname)
                                               :name nil :type nil))


                  (dolist (source-file '(,@lisp-files))
                    (load (compile-file
                           (merge-pathnames source-file
                                            *gendl-source-dir*) :external-format :utf-8))))))
    (unless repo-dir
      (error "Not in a Git repository"))
    (cl-block generate-dev-lisp
      (when (null lisp-files)
        (message "No relevant files found.")
        (cl-return-from generate-dev-lisp))
      (with-temp-file dev-lisp-path
        (dolist (sexp sexps)
          (pp sexp (current-buffer))))
      (message "Generated %s with %d files." dev-lisp-path (length lisp-files)))))


(provide 'init)

;;; init.el ends here
