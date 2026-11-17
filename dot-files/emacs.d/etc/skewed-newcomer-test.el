;;; skewed-newcomer-test.el --- tests for skewed-newcomer.el  -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Commentary:

;; Run from this directory, in an Emacs of its own:
;;
;;     emacs -Q --batch -L . -l skewed-newcomer-test.el \
;;           -f ert-run-tests-batch-and-exit
;;
;; A batch Emacs has one frame, so "another frame" is played by the
;; same frame with its `skewed-newcomer' parameter taken away while
;; the shared arrangements stay up.  Two real clients on one daemon,
;; the menus and the mouse need terminals, and are tested by hand or
;; through a browser terminal.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'skewed-newcomer)

(defvar which-key-inhibit)

(defmacro skewed-newcomer-test--clean (&rest body)
  "Run BODY, then leave the frame and the shared state as they were."
  (declare (indent 0))
  `(unwind-protect (progn ,@body)
     (skewed-newcomer-off)
     (set-frame-parameter nil 'skewed-newcomer nil)
     (set-frame-parameter nil 'environment nil)
     (skewed-newcomer--sync)))

(defmacro skewed-newcomer-test--in-window (text &rest body)
  "Run BODY in a buffer holding TEXT that the selected window shows."
  (declare (indent 1))
  `(save-window-excursion
     (with-temp-buffer
       (insert ,text)
       (set-window-buffer (selected-window) (current-buffer))
       ,@body)))

(defun skewed-newcomer-test--select (from to)
  "Make the region FROM..TO active in the current buffer."
  (transient-mark-mode 1)
  (goto-char to)
  (set-mark from)
  (activate-mark))

(ert-deftest skewed-newcomer-test-truthy ()
  (dolist (yes '("1" "t" "true" "YES" " on "))
    (should (skewed-newcomer--truthy-p yes)))
  (dolist (no '("0" "" "no" "off" "false" "2" nil))
    (should-not (skewed-newcomer--truthy-p no))))

(ert-deftest skewed-newcomer-test-the-client-decides ()
  "A client's environment wins either way; without it, the default."
  (skewed-newcomer-test--clean
    (let ((skewed-newcomer-default nil))
      (should-not (skewed-newcomer--wanted-p (selected-frame)))
      (set-frame-parameter nil 'environment '("HOME=/x" "TERM=xterm"))
      (should-not (skewed-newcomer--wanted-p (selected-frame)))
      (set-frame-parameter nil 'environment
                           '("HOME=/x" "SKEWED_EMACS_NEWCOMER=1"))
      (should (skewed-newcomer--wanted-p (selected-frame))))
    (let ((skewed-newcomer-default t))
      (set-frame-parameter nil 'environment '("HOME=/x"))
      (should (skewed-newcomer--wanted-p (selected-frame)))
      (set-frame-parameter nil 'environment
                           '("SKEWED_EMACS_NEWCOMER=0" "HOME=/x"))
      (should-not (skewed-newcomer--wanted-p (selected-frame))))))

(ert-deftest skewed-newcomer-test-loading-changes-nothing ()
  (should-not skewed-newcomer--active)
  (should-not (memq 'skewed-newcomer--map-alist emulation-mode-map-alists))
  (should-not (bound-and-true-p which-key-mode))
  (should-not (memq #'skewed-newcomer--sync
                    (default-value 'window-configuration-change-hook)))
  (should-not (memq #'skewed-newcomer--which-key-gate
                    (default-value 'post-command-hook)))
  (with-temp-buffer
    (should (eq (key-binding (kbd "C-v")) 'scroll-up-command))
    (should (eq (key-binding (kbd "C-s")) 'isearch-forward))
    (should (keymapp (key-binding (kbd "C-x"))))))

(ert-deftest skewed-newcomer-test-new-frame-reads-the-switch ()
  "The frame hook turns the setting on for a frame that asks, only."
  (skewed-newcomer-test--clean
    (let ((skewed-newcomer-default nil))
      (set-frame-parameter nil 'environment '("HOME=/x"))
      (skewed-newcomer--new-frame (selected-frame))
      (should-not (skewed-newcomer-frame-p))
      (should-not skewed-newcomer--active)
      (set-frame-parameter nil 'environment '("SKEWED_EMACS_NEWCOMER=1"))
      (skewed-newcomer--new-frame (selected-frame))
      (should (skewed-newcomer-frame-p))
      (should skewed-newcomer--active))))

(ert-deftest skewed-newcomer-test-on ()
  (skewed-newcomer-test--clean
    (let ((echo echo-keystrokes))
      (skewed-newcomer-on)
      (should (skewed-newcomer-frame-p))
      (should (eql (frame-parameter nil 'menu-bar-lines) 1))
      (should (memq 'skewed-newcomer--map-alist emulation-mode-map-alists))
      (should (bound-and-true-p which-key-mode))
      (should-not which-key-inhibit)
      (should (equal echo-keystrokes echo))
      (should (eq (window-parameter (frame-first-window) 'header-line-format)
                  skewed-newcomer--hint-format))
      (with-temp-buffer
        (insert "one two three")
        (should (eq (key-binding (kbd "C-v")) 'yank))
        (should (eq (key-binding (kbd "C-z")) 'undo))
        (should (eq (key-binding (kbd "C-s")) 'save-buffer))
        ;; No region: the prefix keys are the prefix keys.
        (should (keymapp (key-binding (kbd "C-x"))))
        (should (keymapp (key-binding (kbd "C-c"))))
        (should (eq (key-binding (kbd "C-x C-s")) 'save-buffer))
        (skewed-newcomer-test--select 1 4)
        (should (eq (key-binding (kbd "C-x")) 'skewed-newcomer-cut))
        (should (eq (key-binding (kbd "C-c")) 'skewed-newcomer-copy))))))

(ert-deftest skewed-newcomer-test-other-frames-untouched ()
  "With the arrangements up, a frame without the parameter sees none."
  (skewed-newcomer-test--clean
    (skewed-newcomer-on)
    (set-frame-parameter nil 'skewed-newcomer nil)
    (should skewed-newcomer--active)
    (with-temp-buffer
      (insert "one two three")
      (should (eq (key-binding (kbd "C-v")) 'scroll-up-command))
      (should (eq (key-binding (kbd "C-z")) 'suspend-frame))
      (should (eq (key-binding (kbd "C-s")) 'isearch-forward))
      (skewed-newcomer-test--select 1 4)
      (should (keymapp (key-binding (kbd "C-x"))))
      (should (keymapp (key-binding (kbd "C-c")))))
    (skewed-newcomer--which-key-gate)
    (should which-key-inhibit)
    (set-frame-parameter nil 'skewed-newcomer t)
    (skewed-newcomer--which-key-gate)
    (should-not which-key-inhibit)))

(ert-deftest skewed-newcomer-test-off-puts-everything-back ()
  (skewed-newcomer-test--clean
    (let ((echo echo-keystrokes)
          (menu-bar-mode nil)
          (position mouse-position-function))
      (skewed-newcomer-on)
      (skewed-newcomer-off)
      (should-not (skewed-newcomer-frame-p))
      (should (eql (frame-parameter nil 'menu-bar-lines) 0))
      (should-not skewed-newcomer--active)
      (should-not (memq 'skewed-newcomer--map-alist emulation-mode-map-alists))
      (should-not (bound-and-true-p which-key-mode))
      (should-not which-key-inhibit)
      (should (equal echo-keystrokes echo))
      (should (eq mouse-position-function position))
      (should-not (window-parameter (frame-first-window) 'header-line-format))
      (should-not (memq #'skewed-newcomer--sync
                        (default-value 'window-configuration-change-hook)))
      (should-not (memq #'skewed-newcomer--which-key-gate
                        (default-value 'post-command-hook)))
      (with-temp-buffer
        (should (eq (key-binding (kbd "C-v")) 'scroll-up-command))))))

(ert-deftest skewed-newcomer-test-which-key-left-alone-when-already-on ()
  "A which-key the user turned on is neither gated nor turned off."
  (skewed-newcomer-test--clean
    (unwind-protect
        (progn
          (which-key-mode 1)
          (skewed-newcomer-on)
          (should-not skewed-newcomer--which-key-ours)
          (set-frame-parameter nil 'skewed-newcomer nil)
          (skewed-newcomer--which-key-gate)
          (should-not which-key-inhibit)
          (set-frame-parameter nil 'skewed-newcomer t)
          (skewed-newcomer-off)
          (should (bound-and-true-p which-key-mode)))
      (which-key-mode -1))))

(ert-deftest skewed-newcomer-test-menu-bar-comes-back ()
  "A global `menu-bar-mode' call does not cost a newcomer frame its bar."
  (skewed-newcomer-test--clean
    (skewed-newcomer-on)
    (set-frame-parameter nil 'menu-bar-lines 0)
    (skewed-newcomer--sync)
    (should (eql (frame-parameter nil 'menu-bar-lines) 1))))

(ert-deftest skewed-newcomer-test-hint-follows-the-first-window ()
  (skewed-newcomer-test--clean
    (save-window-excursion
      (delete-other-windows)
      (skewed-newcomer-on)
      (let ((below (split-window nil nil 'below)))
        (should (eq (window-parameter (frame-first-window)
                                      'header-line-format)
                    skewed-newcomer--hint-format))
        (should-not (window-parameter below 'header-line-format))
        (delete-window (frame-first-window))
        ;; Redisplay runs `window-configuration-change-hook'; a batch
        ;; Emacs has none, so make the hook's call.
        (skewed-newcomer--sync)
        (should (eq (frame-first-window) below))
        (should (eq (window-parameter below 'header-line-format)
                    skewed-newcomer--hint-format))))
    (let ((skewed-newcomer-hint nil))
      (skewed-newcomer--sync)
      (should-not (window-parameter (frame-first-window)
                                    'header-line-format)))))

(ert-deftest skewed-newcomer-test-cut-copy-paste-undo ()
  (skewed-newcomer-test--clean
    (skewed-newcomer-on)
    (let ((skewed-newcomer-prefix-delay nil)
          (kill-ring nil)
          (kill-ring-yank-pointer nil)
          (select-enable-clipboard nil))
      (skewed-newcomer-test--in-window "one two three"
        (buffer-enable-undo)
        (undo-boundary)
        (skewed-newcomer-test--select 1 5)
        (execute-kbd-macro (kbd "C-x"))
        (should (equal (buffer-string) "two three"))
        (should (equal (car kill-ring) "one "))
        (goto-char (point-max))
        (execute-kbd-macro (kbd "C-v"))
        (should (equal (buffer-string) "two threeone "))
        (execute-kbd-macro (kbd "C-z"))
        (should (equal (buffer-string) "two three"))
        (skewed-newcomer-test--select 1 4)
        (execute-kbd-macro (kbd "C-c"))
        (should (equal (buffer-string) "two three"))
        (should (equal (car kill-ring) "two"))))))

(ert-deftest skewed-newcomer-test-a-following-key-keeps-the-prefix ()
  "C-x C-s with a region active saves; it does not cut."
  (skewed-newcomer-test--clean
    (skewed-newcomer-on)
    (let ((saved 0) (compiled 0) (kill-ring nil))
      (cl-letf (((symbol-function 'save-buffer)
                 (lambda (&rest _) (interactive) (cl-incf saved))))
        (skewed-newcomer-test--in-window "one two three"
          (local-set-key (kbd "C-c C-c")
                         (lambda () (interactive) (cl-incf compiled)))
          (skewed-newcomer-test--select 1 5)
          (execute-kbd-macro (kbd "C-x C-s"))
          (should (= saved 1))
          (should (equal (buffer-string) "one two three"))
          (should-not skewed-newcomer--bypass)
          (skewed-newcomer-test--select 1 5)
          (execute-kbd-macro (kbd "C-c C-c"))
          (should (= compiled 1))
          (should-not kill-ring)
          (should-not skewed-newcomer--bypass)
          ;; And with the bypass spent, C-s alone is save again.
          (deactivate-mark)
          (execute-kbd-macro (kbd "C-s"))
          (should (= saved 2)))))))

(provide 'skewed-newcomer-test)

;;; skewed-newcomer-test.el ends here
