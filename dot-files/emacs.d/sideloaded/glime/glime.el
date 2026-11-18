;;; glime.el --- Gendl message completion, documentation and checking for SLIME  -*- lexical-binding: t; -*-

;; Copyright © 2026 Genworks International
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;; Commentary:
;;
;; Glime is Gendl's extension of SLIME.  Its Lisp half (glime.lisp, beside
;; this file) knows what messages an object answers at any point of a
;; reference chain: inside (the ...), (the-child ...) and (the-object ...)
;; it reads the define-object form around point, and the classes it
;; mixes in, from the running image.  This file is the Emacs half:
;;
;; - It loads the Lisp half into a Gendl image when SLIME connects to one
;;   that does not have it, or has an older one.  The source is sent over
;;   the connection, so Emacs and Lisp need not share a file system.
;;   `glime-load-lisp-side' does it by hand.
;;
;; - `glime-completion-at-point' is a completion-at-point function, put
;;   first on `slime-completion-at-point-functions'.  Because it answers
;;   with a completion table (SLIME's own answers with a command), the
;;   completion front ends that read such tables work in Lisp buffers:
;;   company through its capf backend, corfu, and plain C-M-i.  Each
;;   message is annotated with its kind and the class that defines it,
;;   and its documentation is offered to the front end.  Where there are
;;   no messages to offer it completes symbols as SLIME does.
;;
;; - SLIME's autodoc already shows the messages in the echo area once the
;;   Lisp half is loaded; nothing here is needed for that.
;;
;; - With flycheck, the checker `glime' marks the first message of a
;;   (the ...) or (the-child ...) reference that the object, as written
;;   in the buffer, and its mixins, as the image knows them, do not
;;   answer.  The level is `glime-check-level'.  A slot that reaches an
;;   object by trickling down from its parent cannot be seen from the
;;   definition, so such a reference is marked too; that is why the
;;   default level is `info'.
;;
;; `glime-mode' is global and on once this file is loaded; turning it
;; off takes all of it away again.

;;; Code:

(require 'cl-lib)
(require 'slime)
(require 'slime-parse nil t)

(declare-function flycheck-error-new-at-pos "flycheck")
(declare-function flycheck-define-generic-checker "flycheck")
(declare-function company-doc-buffer "company")
(declare-function slime-parse-form-upto-point "slime-parse")
(defvar flycheck-checkers)

(defgroup glime nil
  "Gendl extensions to SLIME."
  :group 'slime
  :prefix "glime-")

(defvaralias '*enable-glime* 'glime-enabled)

(defcustom glime-enabled t
  "When nil, Glime's completion and checker stand aside."
  :type 'boolean)

(defconst glime-directory
  (file-name-directory (or load-file-name buffer-file-name default-directory))
  "The directory this file was loaded from.")

(defcustom glime-lisp-file (expand-file-name "glime.lisp" glime-directory)
  "The source of Glime's Lisp half, sent to an image that lacks it."
  :type 'file)

(defcustom glime-check-level 'info
  "The flycheck level of a reference to a message no definition shows."
  :type '(choice (const info) (const warning) (const error)))

(slime-def-connection-var glime-connection-state nil
  "What is known of Glime's Lisp half on this connection.
nil: not asked yet; `ready'; `loading'; `absent': not a Gendl image,
or the Lisp half would not load.")

;;;; The Lisp half

(defun glime--file-release ()
  "The release the Lisp source beside this file declares, or nil."
  (when (file-readable-p glime-lisp-file)
    (with-temp-buffer
      (insert-file-contents glime-lisp-file nil 0 6000)
      (when (re-search-forward "\\*gendl-slime-release\\* +\"\\([^\"]+\\)\"" nil t)
        (match-string 1)))))

(defun glime-setup-connection ()
  "Ask the connected Lisp for its Glime, and load ours if it is newer."
  (let ((connection (slime-connection)))
    (slime-eval-async
        '(cl:cond ((cl:not (cl:find-package :gendl)) :no-gendl)
                  ((cl:find-package :gendl-swank)
                   (cl:let ((release (cl:find-symbol (cl:string 'glime-release)
                                                     :gendl-swank)))
                     (cl:if (cl:and release (cl:fboundp release))
                            (cl:funcall release)
                            "0")))
                  (cl:t :not-loaded))
      (lambda (answer)
        (let ((slime-dispatching-connection connection))
          (cond ((eq answer :no-gendl)
                 (setf (glime-connection-state) 'absent))
                ((and (stringp answer)
                      (not (version< answer (or (glime--file-release) "0"))))
                 (setf (glime-connection-state) 'ready))
                (t (glime-load-lisp-side))))))))

(defun glime-load-lisp-side ()
  "Send Glime's Lisp half to the connected Lisp and load it there."
  (interactive)
  (let ((connection (slime-connection)))
    (if (not (file-readable-p glime-lisp-file))
        (progn (setf (glime-connection-state) 'absent)
               (message "Glime: %s is not readable" glime-lisp-file))
      (let ((source (with-temp-buffer
                      (insert-file-contents glime-lisp-file)
                      (buffer-string))))
        (setf (glime-connection-state) 'loading)
        (slime-rex (connection)
            (`(cl:progn
                (cl:with-input-from-string (glime-source ,source)
                  (cl:load glime-source))
                cl:t)
             "COMMON-LISP-USER")
          ((:ok _)
           (let ((slime-dispatching-connection connection))
             (setf (glime-connection-state) 'ready))
           (message "Glime loaded into the Lisp"))
          ((:abort condition)
           (let ((slime-dispatching-connection connection))
             (setf (glime-connection-state) 'absent))
           (message "Glime did not load: %s" condition)))))))

(defun glime--ready-p ()
  "True when Glime may ask the connected Lisp something now."
  (and glime-enabled
       (slime-connected-p)
       (eq (glime-connection-state) 'ready)
       (not (slime-busy-p))))

(defun glime--eval (form &optional package)
  "Evaluate FORM in the Lisp, answering nil if anything goes wrong there."
  (condition-case nil
      (slime-eval `(cl:ignore-errors ,form) package)
    (error nil)))

;;;; Completion

(defun glime--message-name (candidate)
  "CANDIDATE without package prefix or colon, in lower case."
  (downcase (replace-regexp-in-string "\\`.*:" "" candidate)))

(defun glime--candidates (prefix package form infos)
  "The completions of PREFIX in the context FORM, noting the messages in INFOS."
  (let ((result (glime--eval
                 `(gendl-swank:glime-completions-info ,prefix ',package ',form))))
    (dolist (info (nth 2 result))
      (puthash (car info) (cdr info) infos))
    (car result)))

(defun glime--annotation (candidate infos)
  "What to show beside CANDIDATE: a message's kind and defining class."
  (let ((info (gethash (glime--message-name candidate) infos)))
    (when info
      (concat "  " (string-remove-suffix "s" (or (nth 0 info) "message"))
              (if (nth 1 info) (concat "  " (nth 1 info)) "")))))

(defun glime--kind (candidate infos)
  "A company kind for CANDIDATE, from its message category."
  (let ((category (car (gethash (glime--message-name candidate) infos))))
    (cond ((null category) nil)
          ((string-match-p "function" category) 'method)
          ((string-match-p "object" category) 'class)
          ((string-match-p "input" category) 'property)
          (t 'field))))

(defun glime--documentation (candidate infos docs)
  "The documentation of CANDIDATE, a message or a symbol; cached in DOCS."
  (let ((cached (gethash candidate docs 'unasked)))
    (if (not (eq cached 'unasked))
        cached
      (let* ((name (glime--message-name candidate))
             (info (gethash name infos)))
        (puthash candidate
                 (cond ((and info (nth 2 info))
                        (glime--eval `(gendl-swank:glime-message-documentation
                                       ,name ,(nth 2 info))))
                       (info nil)
                       (t (glime--eval `(swank:documentation-symbol ,candidate))))
                 docs)))))

(defun glime-completion-at-point ()
  "Complete the symbol at point, as a message where the context has any.
A function for `slime-completion-at-point-functions'."
  (when (and (glime--ready-p)
             (fboundp 'slime-parse-form-upto-point)
             (not (nth 8 (syntax-ppss))))
    (let* ((beg (slime-symbol-start-pos))
           (end (point)))
      (unless (string-prefix-p "#\\" (buffer-substring-no-properties beg end))
        (let* ((form (save-excursion
                       (goto-char beg)
                       (slime-parse-form-upto-point)))
               (package (slime-current-package))
               (infos (make-hash-table :test 'equal))
               (docs (make-hash-table :test 'equal)))
          (list beg end
                (completion-table-with-cache
                 (lambda (prefix)
                   (glime--candidates prefix package form infos)))
                :exclusive 'no
                :annotation-function
                (lambda (candidate) (glime--annotation candidate infos))
                :company-kind
                (lambda (candidate) (glime--kind candidate infos))
                :company-docsig
                (lambda (candidate)
                  ;; Messages only: a symbol's arglist is autodoc's to show.
                  (when (gethash (glime--message-name candidate) infos)
                    (let ((doc (glime--documentation candidate infos docs)))
                      (and (stringp doc)
                           (car (split-string (string-trim doc) "\n"))))))
                :company-doc-buffer
                (lambda (candidate)
                  (let ((doc (glime--documentation candidate infos docs)))
                    (and (stringp doc)
                         (fboundp 'company-doc-buffer)
                         (company-doc-buffer doc))))))))))

;;;; Reading define-object forms for the checker

(defconst glime--defining-form-regexp
  "^(\\(?:[[:alnum:]-]+::?\\)?\\(define-object\\(?:-amendment\\)?\\)\\_>"
  "The opening of a defining form at the start of a line.")

(defconst glime--sections
  '(":input-slots" ":computed-slots" ":objects" ":hidden-objects"
    ":functions" ":methods" ":trickle-down-slots")
  "The sections of a defining form whose items are messages.")

(defun glime--skip ()
  "Move point past whitespace and comments."
  (forward-comment (buffer-size)))

(defun glime--symbol-at (pos)
  "The symbol starting at POS as (NAME . END), NAME in message form; or nil."
  (save-excursion
    (goto-char pos)
    (when (looking-at "\\(?:\\sw\\|\\s_\\)+")
      (let ((text (match-string-no-properties 0)))
        (unless (string-match-p "\\`[-+.0-9]+\\'" text)
          (cons (glime--message-name text) (match-end 0)))))))

(defun glime--parse-child (name pos item-beg item-end)
  "Read the child spec ITEM-BEG..ITEM-END whose NAME ends before POS."
  (let (type pseudo)
    (save-excursion
      (goto-char pos)
      (forward-sexp 1)
      (glime--skip)
      (while (< (point) (1- item-end))
        (let ((key (downcase (buffer-substring-no-properties
                              (point) (scan-sexps (point) 1)))))
          (forward-sexp 1)
          (glime--skip)
          (when (< (point) (1- item-end))
            (cond ((and (equal key ":type")
                        (looking-at "'\\(\\(?:\\sw\\|\\s_\\)+\\)"))
                   (setq type (match-string-no-properties 1)))
                  ((and (equal key ":pseudo-inputs") (eq (char-after) ?\())
                   (let ((end (scan-sexps (point) 1)))
                     (save-excursion
                       (forward-char 1)
                       (glime--skip)
                       (while (< (point) (1- end))
                         (let ((symbol (glime--symbol-at (point))))
                           (when symbol (push (car symbol) pseudo)))
                         (forward-sexp 1)
                         (glime--skip))))))
            (forward-sexp 1)
            (glime--skip)))))
    (list :name name :type (or type name) :pseudo pseudo
          :beg item-beg :end item-end)))

(defun glime--parse-form (form-beg amendment)
  "Read the defining form at FORM-BEG; AMENDMENT says it is an amendment.
Answer a plist of its :name, :mixins (as written), :own message names,
:children (see `glime--parse-child'), :beg and :end."
  (let ((form-end (scan-sexps form-beg 1))
        name mixins own children)
    (save-excursion
      (goto-char (1+ form-beg))
      (forward-sexp 1)
      (glime--skip)
      (setq name (buffer-substring-no-properties (point) (scan-sexps (point) 1)))
      (forward-sexp 1)
      (glime--skip)
      (when (eq (char-after) ?\()
        (let ((mixins-end (scan-sexps (point) 1)))
          (save-excursion
            (forward-char 1)
            (glime--skip)
            (while (< (point) (1- mixins-end))
              (push (buffer-substring-no-properties
                     (point) (progn (forward-sexp 1) (point)))
                    mixins)
              (glime--skip)))
          (goto-char mixins-end)))
      (glime--skip)
      (while (< (point) (1- form-end))
        (let ((key (and (eq (char-after) ?:)
                        (downcase (buffer-substring-no-properties
                                   (point) (scan-sexps (point) 1))))))
          (forward-sexp 1)
          (glime--skip)
          (when (and key (< (point) (1- form-end)))
            (let ((value-beg (point))
                  (value-end (scan-sexps (point) 1)))
              (when (and (member key glime--sections)
                         (eq (char-after value-beg) ?\())
                (save-excursion
                  (goto-char (1+ value-beg))
                  (glime--skip)
                  (while (< (point) (1- value-end))
                    (let ((item (point))
                          (item-end (scan-sexps (point) 1)))
                      (cond ((eq (char-after item) ?\"))
                            ((eq (char-after item) ?\()
                             (goto-char (1+ item))
                             (glime--skip)
                             (while (eq (char-after) ?\")
                               (forward-sexp 1)
                               (glime--skip))
                             (let ((slot (glime--symbol-at (point))))
                               (when slot
                                 (push (car slot) own)
                                 (when (member key '(":objects" ":hidden-objects"))
                                   (push (glime--parse-child (car slot) (point)
                                                             item item-end)
                                         children)))))
                            (t (let ((slot (glime--symbol-at item)))
                                 (when slot (push (car slot) own)))))
                      (goto-char item-end)
                      (glime--skip)))))
              (goto-char value-end)
              (glime--skip))))))
    (list :name name :mixins (nreverse mixins) :own own :children children
          :beg form-beg :end form-end :amendment amendment)))

(defun glime--parse-buffer ()
  "Every defining form of the buffer that reads, as `glime--parse-form' plists."
  (let ((case-fold-search t) forms)
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward glime--defining-form-regexp nil t)
          (let ((form-beg (match-beginning 0))
                (amendment (string-suffix-p "amendment" (match-string 1) t)))
            (unless (nth 8 (syntax-ppss form-beg))
              (condition-case nil
                  (let ((form (glime--parse-form form-beg amendment)))
                    (push form forms)
                    (goto-char (plist-get form :end)))
                (scan-error nil)))))))
    (nreverse forms)))

(defun glime--references (form)
  "The reference chains in FORM, each as (OPERATOR MESSAGE BEG END).
MESSAGE is the first message of a (the ...) or (the-child ...)."
  (let ((case-fold-search t) references)
    (save-excursion
      (goto-char (plist-get form :beg))
      (while (re-search-forward "(\\(the\\|the-child\\)\\_>" (plist-get form :end) t)
        (let ((operator (downcase (match-string-no-properties 1)))
              (open (match-beginning 0)))
          (unless (or (save-excursion (nth 8 (syntax-ppss open)))
                      (memq (char-before open) '(?\' ?` ?#)))
            (save-excursion
              (glime--skip)
              (when (eq (char-after) ?\()
                (forward-char 1)
                (glime--skip))
              (let ((symbol (glime--symbol-at (point))))
                (when (and symbol (not (equal (car symbol) "evaluate")))
                  (push (list operator (car symbol) (point) (cdr symbol))
                        references))))))))
    (nreverse references)))

(defun glime--classes-to-ask (forms)
  "The class names the checker needs the messages of, for FORMS."
  (let ((classes (list "gendl::vanilla-mixin*")))
    (dolist (form forms)
      (when (plist-get form :amendment)
        (push (plist-get form :name) classes))
      (dolist (mixin (plist-get form :mixins))
        (push mixin classes))
      (dolist (child (plist-get form :children))
        (push (plist-get child :type) classes)))
    (delete-dups classes)))

(defun glime--findings (forms answer)
  "What the checker reports for FORMS, given the Lisp's ANSWER.
ANSWER is `gendl-swank:glime-class-messages' of `glime--classes-to-ask'.
Each finding is (BEG END TEXT)."
  (let (findings)
    (cl-flet ((messages (class) (cdr (assoc class answer))))
      (dolist (form forms)
        (let* ((name (plist-get form :name))
               (parents (append (plist-get form :mixins)
                                (and (plist-get form :amendment) (list name))
                                (list "gendl::vanilla-mixin*")))
               (known (cl-every (lambda (class) (listp (messages class))) parents))
               (own (cl-loop for other in forms
                             when (string-equal (plist-get other :name) name)
                             append (plist-get other :own))))
          (pcase-dolist (`(,operator ,message ,beg ,end) (glime--references form))
            (if (equal operator "the")
                (when (and known
                           (not (member message own))
                           (not (cl-some (lambda (class)
                                           (member message (messages class)))
                                         parents)))
                  (push (list beg end
                              (format "`%s' is not a message of %s or its mixins (a slot trickling down from a parent object is not seen here)"
                                      message name))
                        findings))
              (let ((child (cl-find-if (lambda (child)
                                         (< (plist-get child :beg) beg
                                            (plist-get child :end)))
                                       (plist-get form :children))))
                (when child
                  (let ((of-type (messages (plist-get child :type))))
                    (when (and (listp of-type) of-type
                               (not (member message of-type))
                               (not (member message (plist-get child :pseudo))))
                      (push (list beg end
                                  (format "`%s' is not a message of %s, the type of %s, nor one of its pseudo-inputs"
                                          message (plist-get child :type)
                                          (plist-get child :name)))
                            findings))))))))))
    (nreverse findings)))

(defun glime-check-buffer ()
  "Echo how many references in this buffer name a message no definition shows.
The same check the flycheck checker `glime' runs."
  (interactive)
  (if (not (glime--ready-p))
      (message "Glime is not ready on this connection")
    (let* ((forms (glime--parse-buffer))
           (answer (glime--eval
                    `(gendl-swank:glime-class-messages ',(glime--classes-to-ask forms))
                    (slime-current-package)))
           (findings (glime--findings forms answer)))
      (message "Glime: %d reference%s to check%s"
               (length findings)
               (if (= (length findings) 1) "" "s")
               (if findings
                   (format "; first at line %d: %s"
                           (line-number-at-pos (car (car findings)))
                           (nth 2 (car findings)))
                 ""))
      findings)))

;;;; Flycheck

(defun glime--flycheck-start (checker callback)
  "Start the flycheck CHECKER `glime', answering through CALLBACK."
  (let* ((buffer (current-buffer))
         (tick (buffer-chars-modified-tick))
         (forms (glime--parse-buffer)))
    (if (null forms)
        (funcall callback 'finished nil)
      (slime-rex (buffer tick forms checker callback)
          (`(cl:ignore-errors
              (gendl-swank:glime-class-messages ',(glime--classes-to-ask forms)))
           (slime-current-package))
        ((:ok answer)
         (funcall callback 'finished
                  (when (and (buffer-live-p buffer)
                             (= tick (buffer-chars-modified-tick buffer)))
                    (with-current-buffer buffer
                      (mapcar (lambda (finding)
                                (flycheck-error-new-at-pos
                                 (nth 0 finding) glime-check-level (nth 2 finding)
                                 :end-pos (nth 1 finding)
                                 :checker checker :buffer buffer))
                              (glime--findings forms answer))))))
        ((:abort _)
         (funcall callback 'finished nil))))))

(with-eval-after-load 'flycheck
  (flycheck-define-generic-checker 'glime
    "Mark Gendl reference chains whose first message no definition shows.
The object's own messages are read from the buffer; its mixins' and its
children's types' come from the Lisp SLIME is connected to."
    :start #'glime--flycheck-start
    :modes '(lisp-mode)
    :predicate (lambda ()
                 (and (glime--ready-p)
                      (save-excursion
                        (goto-char (point-min))
                        (let ((case-fold-search t))
                          (re-search-forward glime--defining-form-regexp nil t))))))
  (add-to-list 'flycheck-checkers 'glime t))

;;;; The mode

;;;###autoload
(define-minor-mode glime-mode
  "Gendl message completion, documentation and checking in SLIME buffers."
  :global t
  :group 'glime
  (cond
   (glime-mode
    (add-hook 'slime-completion-at-point-functions #'glime-completion-at-point)
    (add-hook 'slime-connected-hook #'glime-setup-connection)
    (when (slime-connected-p)
      (glime-setup-connection)))
   (t
    (remove-hook 'slime-completion-at-point-functions #'glime-completion-at-point)
    (remove-hook 'slime-connected-hook #'glime-setup-connection))))

(glime-mode 1)

(provide 'glime)

;;; glime.el ends here
