;;; skewed-newcomer.el --- an opt-in newcomer setting, one frame at a time  -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Commentary:

;; Off unless asked for.  A frame that asks for it gets:
;;
;;   - the menu bar;
;;   - C-s save, C-z undo, C-v paste, and C-c / C-x as copy / cut
;;     while a region is active (CUA's rule: without a region, or with
;;     another key following at once, they are the usual prefix keys);
;;   - which-key's pop-up after a pause on a prefix key;
;;   - on a text terminal, the mouse: click to place the cursor, drag
;;     to select, the wheel, the menu bar -- what a browser terminal
;;     needs to behave like an editor;
;;   - one line at the top of the frame saying how to save and leave.
;;
;; THE SWITCH.  An emacsclient frame is a newcomer frame when its
;; client's environment carries SKEWED_EMACS_NEWCOMER=1:
;;
;;     SKEWED_EMACS_NEWCOMER=1 emacsclient -t FILE
;;
;; so a caller turns it on for one client of a shared daemon and for
;; nobody else.  The same variable in the environment Emacs itself
;; starts in, or `skewed-newcomer-default' set non-nil in
;; ~/.emacs-local, makes it the default for every frame; a client
;; still opts out with SKEWED_EMACS_NEWCOMER=0.
;; `M-x skewed-newcomer-toggle' switches the selected frame.
;;
;; WHAT IS PER FRAME, AND WHAT IS NOT.  The menu bar, the hint line
;; and the mouse are frame, window and terminal parameters: other
;; frames never see them.  Key bindings and
;; which-key have no per-frame form in Emacs.  So while at least one
;; newcomer frame exists, and only then:
;;
;;   - a keymap is active whose every binding is a filter that answers
;;     in a newcomer frame and is absent in any other;
;;   - `which-key-mode' is on, with `which-key-inhibit' held non-nil
;;     whenever the selected frame is not a newcomer frame
;;     (`echo-keystrokes' is put back as it was);
;;   - `mouse-position-function' and
;;     `tty-menu-calls-mouse-position-function' are set as
;;     `xterm-mouse-mode' sets them (they do nothing on a terminal
;;     without mouse tracking).
;;
;; When the last newcomer frame goes, all of it is taken down again.
;;
;; NOT HERE.  Typing over a selection does not replace it: that is
;; `delete-selection-mode', which is global and left alone.  The
;; clipboard of the person's own machine is the terminal's business:
;; Emacs offers every copy to an xterm-like terminal by itself (OSC
;; 52), and a terminal that ignores the offer -- ttyd 1.7.7 does --
;; still has its own selection (Shift-drag) and paste (Ctrl-Shift-V).

;;; Code:

(require 'seq)
(require 'subr-x)

(defvar xterm-mouse-mode)
(defvar which-key-mode)
(defvar which-key-inhibit)
(defvar tty-menu-calls-mouse-position-function)
(declare-function turn-on-xterm-mouse-tracking-on-terminal "xt-mouse")
(declare-function turn-off-xterm-mouse-tracking-on-terminal "xt-mouse")
(declare-function xterm-mouse-position-function "xt-mouse")
(declare-function which-key-mode "which-key")

(defgroup skewed-newcomer nil
  "An opt-in setting for people new to Emacs, one frame at a time."
  :group 'convenience
  :prefix "skewed-newcomer-")

(defconst skewed-newcomer-env-var "SKEWED_EMACS_NEWCOMER"
  "The environment variable that asks for the newcomer setting.")

(defun skewed-newcomer--truthy-p (value)
  "Whether VALUE, an environment string, says yes."
  (and (stringp value)
       (member (downcase (string-trim value)) '("1" "t" "true" "yes" "on"))
       t))

(defcustom skewed-newcomer-default
  (skewed-newcomer--truthy-p (getenv skewed-newcomer-env-var))
  "Non-nil makes every new frame a newcomer frame.
The initial value is read once from the environment Emacs started
in (`skewed-newcomer-env-var').  An emacsclient frame whose client
sets that variable decides for itself, either way."
  :type 'boolean)

(defcustom skewed-newcomer-hint
  " Save: Ctrl-S | Leave: F10 File Quit | Undo: Ctrl-Z | Copy/Cut/Paste: Ctrl-C/X/V"
  "The line shown at the top of a newcomer frame, or nil for none."
  :type '(choice (const :tag "No hint" nil) string))

(defcustom skewed-newcomer-which-key t
  "Non-nil shows which-key's pop-up in newcomer frames."
  :type 'boolean)

(defcustom skewed-newcomer-mouse t
  "Non-nil turns the mouse on in a newcomer frame's text terminal."
  :type 'boolean)

(defcustom skewed-newcomer-prefix-delay 0.2
  "Seconds C-c and C-x wait, with a region active, for a following key.
A key inside that time makes them the ordinary prefix keys, as in
CUA mode; otherwise they copy and cut.  Nil or zero: never wait."
  :type '(choice (const :tag "Never wait" nil) number))

;;; Which frames

(defun skewed-newcomer-frame-p (&optional frame)
  "Whether FRAME (default: the selected one) is a newcomer frame."
  (and (frame-parameter frame 'skewed-newcomer) t))

(defun skewed-newcomer--frames ()
  "The live newcomer frames."
  (seq-filter #'skewed-newcomer-frame-p (frame-list)))

(defun skewed-newcomer--wanted-p (frame)
  "Whether FRAME asks for the newcomer setting.
An emacsclient frame carries its client's environment; when the
switch is set there, it decides.  Otherwise `skewed-newcomer-default'."
  (let* ((env (frame-parameter frame 'environment))
         (value (and (consp env)
                     (getenv-internal skewed-newcomer-env-var env))))
    (if (stringp value)
        (skewed-newcomer--truthy-p value)
      (and skewed-newcomer-default t))))

;;; The keys

(defvar skewed-newcomer--active nil
  "Non-nil while at least one newcomer frame exists.")

(defvar skewed-newcomer--bypass nil
  "Non-nil while a replayed prefix key must not be taken as copy or cut.")

(defun skewed-newcomer--bypass-off ()
  "End the bypass set by `skewed-newcomer--region-key'."
  (setq skewed-newcomer--bypass nil)
  (remove-hook 'pre-command-hook #'skewed-newcomer--bypass-off))

(defun skewed-newcomer--region-key (command)
  "Run COMMAND on the region, unless another key follows at once.
In that case replay both keys with this file's bindings out of the
way, so that C-c C-c and C-x C-s still mean what they always did."
  (let* ((keys (this-command-keys-vector))
         (next (and (numberp skewed-newcomer-prefix-delay)
                    (> skewed-newcomer-prefix-delay 0)
                    (read-event nil nil skewed-newcomer-prefix-delay))))
    (if (null next)
        (progn (setq this-command command)
               (call-interactively command))
      (setq skewed-newcomer--bypass t)
      (add-hook 'pre-command-hook #'skewed-newcomer--bypass-off)
      (setq this-command last-command
            prefix-arg current-prefix-arg
            unread-command-events
            (append (mapcar (lambda (event) (cons 'no-record event))
                            (append keys (list next)))
                    unread-command-events)))))

(defun skewed-newcomer-copy ()
  "Copy the region; see `skewed-newcomer--region-key'."
  (interactive)
  (skewed-newcomer--region-key #'kill-ring-save))

(defun skewed-newcomer-cut ()
  "Cut the region; see `skewed-newcomer--region-key'."
  (interactive)
  (skewed-newcomer--region-key #'kill-region))

(defun skewed-newcomer--key (command &optional condition)
  "A binding that is COMMAND in a newcomer frame and absent elsewhere.
CONDITION, a function of no arguments, must also hold when given."
  `(menu-item "" ,command
              :filter ,(lambda (cmd)
                         (and (not skewed-newcomer--bypass)
                              (frame-parameter nil 'skewed-newcomer)
                              (or (null condition) (funcall condition))
                              cmd))))

(defvar skewed-newcomer-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-z") (skewed-newcomer--key #'undo))
    (define-key map (kbd "C-v") (skewed-newcomer--key #'yank))
    (define-key map (kbd "C-s")
                (skewed-newcomer--key #'save-buffer
                                      (lambda () (not (minibufferp)))))
    (define-key map (kbd "C-c")
                (skewed-newcomer--key #'skewed-newcomer-copy #'use-region-p))
    (define-key map (kbd "C-x")
                (skewed-newcomer--key #'skewed-newcomer-cut #'use-region-p))
    map)
  "The newcomer keys.  Every binding answers only in a newcomer frame.")

(defvar skewed-newcomer--map-alist
  `((skewed-newcomer--active . ,skewed-newcomer-map))
  "The entry `emulation-mode-map-alists' holds while newcomer frames exist.")

;;; The hint line

(defvar skewed-newcomer--hint-format '(:eval skewed-newcomer-hint)
  "The header line a newcomer frame's first window carries.")

(defun skewed-newcomer--place-hint (frame &optional remove)
  "Show the hint on FRAME's first window only; with REMOVE, on none."
  (let ((first (and (not remove) skewed-newcomer-hint
                    (frame-first-window frame))))
    (dolist (window (window-list frame 'no-minibuffer))
      (let ((ours (eq (window-parameter window 'header-line-format)
                      skewed-newcomer--hint-format)))
        (cond ((eq window first)
               (unless ours
                 (set-window-parameter window 'header-line-format
                                       skewed-newcomer--hint-format)))
              (ours
               (set-window-parameter window 'header-line-format nil)))))))

;;; The terminal: the mouse

(defun skewed-newcomer--terminal-on (frame)
  "Turn the mouse on for FRAME's text terminal, and for no other."
  (let ((terminal (frame-terminal frame)))
    (when (and skewed-newcomer-mouse
               (eq (terminal-live-p terminal) t)
               (not (string= (terminal-name terminal) "initial_terminal"))
               (not (member (tty-type terminal) '(nil "" "dumb" "linux")))
               (not (terminal-parameter terminal 'xterm-mouse-mode))
               (require 'xt-mouse nil t))
      ;; xt-mouse turns tracking on per terminal, but only while its
      ;; global mode is on; bind the mode for the one call.
      (with-selected-frame frame
        (let ((xterm-mouse-mode t))
          (turn-on-xterm-mouse-tracking-on-terminal terminal)))
      (set-terminal-parameter terminal 'skewed-newcomer-mouse t)
      (unless mouse-position-function
        (setq mouse-position-function #'xterm-mouse-position-function))
      (setq tty-menu-calls-mouse-position-function t))))

(defun skewed-newcomer--terminal-off (frame)
  "Undo `skewed-newcomer--terminal-on' unless a newcomer frame still uses it."
  (let ((terminal (frame-terminal frame)))
    (when (and (terminal-parameter terminal 'skewed-newcomer-mouse)
               (not (seq-some (lambda (other)
                                (and (not (eq other frame))
                                     (eq (frame-terminal other) terminal)))
                              (skewed-newcomer--frames))))
      (turn-off-xterm-mouse-tracking-on-terminal terminal)
      (set-terminal-parameter terminal 'skewed-newcomer-mouse nil))))

;;; The shared arrangements, up only while a newcomer frame exists

(defvar skewed-newcomer--which-key-ours nil
  "Non-nil when this file turned `which-key-mode' on.")

(defun skewed-newcomer--which-key-gate ()
  "Let which-key pop up in newcomer frames only, when the mode is ours."
  (when skewed-newcomer--which-key-ours
    (setq which-key-inhibit (not (skewed-newcomer-frame-p)))))

(defun skewed-newcomer--shared-on ()
  "Put up what newcomer frames need and Emacs has no per-frame form of."
  (unless skewed-newcomer--active
    (setq skewed-newcomer--active t)
    (add-to-list 'emulation-mode-map-alists 'skewed-newcomer--map-alist)
    (add-hook 'window-configuration-change-hook #'skewed-newcomer--sync)
    (add-hook 'after-delete-frame-functions #'skewed-newcomer--sync)
    (add-hook 'post-command-hook #'skewed-newcomer--which-key-gate)
    (when (and skewed-newcomer-which-key
               (not (bound-and-true-p which-key-mode))
               (require 'which-key nil t))
      (let ((echo echo-keystrokes))
        (which-key-mode 1)
        (setq echo-keystrokes echo))
      ;; which-key takes its pop-up down when "the frame" changes
      ;; size, comparing the selected frame with the last one it
      ;; looked at.  Among several clients' frames that is somebody
      ;; else's frame, and the pop-up vanishes as it appears.
      (remove-hook 'window-size-change-functions
                   'which-key--hide-popup-on-frame-size-change)
      (setq skewed-newcomer--which-key-ours t)))
  (skewed-newcomer--which-key-gate))

(defun skewed-newcomer--shared-off ()
  "Take down everything `skewed-newcomer--shared-on' put up."
  (when skewed-newcomer--active
    (setq skewed-newcomer--active nil
          skewed-newcomer--bypass nil
          emulation-mode-map-alists
          (delq 'skewed-newcomer--map-alist emulation-mode-map-alists))
    (remove-hook 'window-configuration-change-hook #'skewed-newcomer--sync)
    (remove-hook 'after-delete-frame-functions #'skewed-newcomer--sync)
    (remove-hook 'post-command-hook #'skewed-newcomer--which-key-gate)
    (when skewed-newcomer--which-key-ours
      (setq skewed-newcomer--which-key-ours nil
            which-key-inhibit nil)
      (which-key-mode -1))
    (unless (or (bound-and-true-p xterm-mouse-mode)
                (seq-some (lambda (terminal)
                            (terminal-parameter terminal 'xterm-mouse-mode))
                          (terminal-list)))
      (when (eq mouse-position-function 'xterm-mouse-position-function)
        (setq mouse-position-function nil))
      (when (boundp 'tty-menu-calls-mouse-position-function)
        (setq tty-menu-calls-mouse-position-function nil)))))

(defun skewed-newcomer--sync (&rest _)
  "Bring everything in line with the newcomer frames that exist now.
Also puts a newcomer frame's menu bar back after a global
`menu-bar-mode' call took it away (the init makes one for every
new frame)."
  (let ((frames (skewed-newcomer--frames)))
    (dolist (frame frames)
      (unless (eql (frame-parameter frame 'menu-bar-lines) 1)
        (set-frame-parameter frame 'menu-bar-lines 1))
      (skewed-newcomer--place-hint frame))
    (if frames
        (skewed-newcomer--shared-on)
      (skewed-newcomer--shared-off))))

;;; Turning it on and off

(defun skewed-newcomer-on (&optional frame)
  "Make FRAME (default: the selected one) a newcomer frame."
  (let ((frame (or frame (selected-frame))))
    (unless (skewed-newcomer-frame-p frame)
      (set-frame-parameter frame 'skewed-newcomer t)
      (skewed-newcomer--terminal-on frame))
    (skewed-newcomer--sync)
    frame))

(defun skewed-newcomer-off (&optional frame)
  "Give FRAME (default: the selected one) back its ordinary setting."
  (let ((frame (or frame (selected-frame))))
    (when (skewed-newcomer-frame-p frame)
      (skewed-newcomer--terminal-off frame)
      (set-frame-parameter frame 'skewed-newcomer nil)
      (set-frame-parameter frame 'menu-bar-lines (if menu-bar-mode 1 0))
      (skewed-newcomer--place-hint frame 'remove))
    (skewed-newcomer--sync)
    frame))

(defun skewed-newcomer-toggle ()
  "Switch the newcomer setting for the selected frame."
  (interactive)
  (if (skewed-newcomer-frame-p)
      (progn (skewed-newcomer-off)
             (message "Newcomer setting off in this frame"))
    (skewed-newcomer-on)
    (message "Newcomer setting on in this frame")))

(defun skewed-newcomer--new-frame (frame)
  "Decide for the new FRAME; keep the existing newcomer frames whole.
Runs last on `after-make-frame-functions', after the init's own
function has called `menu-bar-mode' for every frame."
  (when (skewed-newcomer--wanted-p frame)
    (set-frame-parameter frame 'skewed-newcomer t)
    (skewed-newcomer--terminal-on frame))
  (when (or skewed-newcomer--active (skewed-newcomer-frame-p frame))
    (skewed-newcomer--sync)))

(defun skewed-newcomer--startup ()
  "With the default on, cover the frames that existed before any hook ran."
  (when skewed-newcomer-default
    (dolist (frame (frame-list))
      (unless (string= (terminal-name (frame-terminal frame))
                       "initial_terminal")
        (skewed-newcomer-on frame)))))

(add-hook 'after-make-frame-functions #'skewed-newcomer--new-frame 90)
(add-hook 'emacs-startup-hook #'skewed-newcomer--startup)

(provide 'skewed-newcomer)

;;; skewed-newcomer.el ends here
