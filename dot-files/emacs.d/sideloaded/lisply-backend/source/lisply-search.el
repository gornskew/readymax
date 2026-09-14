;;; lisply-search.el --- lisply_search: corpus search for GDL/Gendl and the console -*- lexical-binding: t; -*-

;; Copyright © 2026 Genworks
;; SPDX-License-Identifier: AGPL-3.0-or-later

;;; Commentary:
;;
;; Plist-native search system for GDL/Gendl documentation and source code.
;; Build-time index generation and runtime search in a single file.
;;
;; Index format uses keyword keys throughout for idiomatic Elisp:
;;   (:version 4
;;    :generated-at "2026-..."
;;    :config (:sources ... :extensions ...)
;;    :files [(:source :gendl :path "..." :snippets [...]) ...])
;;
;; Version 4 (2026-09-10): snippets are cut at top-level form boundaries
;; in Lisp-family files and at headings in Markdown/Org, packed up to the
;; configured size, instead of blind 24-line windows that started
;; mid-form.  Older indexes (1-3) still load; the runtime ranking below
;; does not depend on the chunking.
;;
;; A snippet is capped by characters regardless of its line count
;; (2026-09-14): the chunker respects its character budget line by line,
;; so the only way past it was a single line longer than the budget -- a
;; minified asset, a one-line data file -- and one such line (a 15 KB
;; v4-shims.min.css) topped a ranking with nothing readable in it.
;; Minified files and vendored static trees are also kept out of the
;; index by the config's :exclude-paths.
;;
;; Ranking is lexical: an inverted term index over the snippets, scored
;; by IDF-weighted term coverage, term density, verbatim phrase hits
;; (hyphenated query tokens such as `hidden-objects'), whether the
;; snippet DEFINES a queried name, and whether the file name carries one.
;; There is no embedding model in this build: `search_mode' other than
;; lexical is answered lexically with a warning rather than silently.
;;
;; Symbol prefix: lisply-search-- (avoiding global collisions)

;;; Code:

(require 'cl-lib)
(require 'subr-x)

;;;; ============================================================
;;;; Customization
;;;; ============================================================

(defgroup lisply-search nil
  "lisply_search: corpus search for GDL/Gendl and the console."
  :group 'tools)

(defcustom lisply-search-services-path
  (expand-file-name "sideloaded/lisply-backend/lisply-search-config.sexp"
                    (file-truename user-emacs-directory))
  "Path to the file carrying the `:lisply-search-config' plist.

Until 2026-08-15 this pointed at the stack's services.sexp, because that
was the only single-source-of-truth file around.  The search corpus
config never belonged there -- nothing in the stack generator ever read
it, and the only consumer has always been this file -- so when the stack
machinery moved out to the Basilisk repo it went to a config file that
ships beside lisply-search.el.

The variable name is kept for compatibility with callers that set it
explicitly."
  :type 'string
  :group 'lisply-search)

(defcustom lisply-search-index-path
  (expand-file-name "~/.emacs.d/sideloaded/lisply-backend/lisply-search-index.sexp")
  "Path to the search index file."
  :type 'string
  :group 'lisply-search)

;;;; ============================================================
;;;; Constants
;;;; ============================================================

(defconst lisply-search--index-version 4
  "Index format version. Increment when format changes.")

(defconst lisply-search--supported-index-versions '(1 2 3 4)
  "Index versions the runtime can load.")

(defconst lisply-search--max-file-bytes (* 1024 1024)
  "Skip files larger than this.")

(defconst lisply-search--default-snippet-lines 24)
(defconst lisply-search--default-snippet-chars 1200)
(defconst lisply-search--default-k 8)
(defconst lisply-search--default-max-tokens 512)
(defconst lisply-search--default-match-mode :all)
(defconst lisply-search--default-any-max-candidates nil)

(defconst lisply-search--header-segment-min-lines 8
  "A leading comment block at least this long (a licence header) is
indexed as its own chunk rather than merged into the first form.")

(defconst lisply-search--stopwords
  '("a" "an" "and" "are" "as" "at" "be" "by" "can" "could" "did" "do"
    "does" "for" "from" "has" "have" "how" "if" "in" "into" "is" "it"
    "its" "of" "on" "or" "our" "should" "than" "that" "the" "their"
    "then" "there" "these" "this" "to" "via" "was" "we" "what" "when"
    "where" "which" "while" "will" "with" "would" "you" "your")
  "Query words that carry no signal in a code corpus.  Dropped from the
term list unless nothing else remains.")

(defconst lisply-search--default-extensions
  '(".lisp" ".lsp" ".cl" ".gdl" ".gendl" ".asd" ".isc"
    ".md" ".markdown" ".org" ".txt" ".rst"
    ".el" ".js" ".ts" ".json" ".yml" ".yaml" ".html" ".css"))

(defconst lisply-search--language-extensions
  '((:lisp ".lisp" ".lsp" ".cl" ".asd" ".el")
    (:gendl ".gendl")
    (:gdl ".gdl" ".gendl" ".lisp" ".lsp" ".cl")
    (:markdown ".md" ".markdown" ".org" ".rst")))

(defconst lisply-search--default-ignore-dirs
  '(".git" "node_modules" "dist" "build" "vendor" "target" ".cache" "logs" "tmp" "docker"))

;;;; ============================================================
;;;; Runtime State
;;;; ============================================================

(defvar lisply-search--cache nil
  "Cached index: (:path PATH :mtime MTIME :index INDEX :snippet-map HASH
:snippet-count N).")

;;;; ============================================================
;;;; Utilities
;;;; ============================================================

(defun lisply-search--log (fmt &rest args)
  "Log message with FMT and ARGS."
  (apply #'message (concat "[lisply-search] " fmt) args))

(defun lisply-search--read-sexp-file (path)
  "Read a single s-expression from PATH, or nil if not found.
The file is decoded as UTF-8 whatever the locale: the index is written
that way (`lisply-search--write-sexp-file'), and left to detection a
locale-less daemon read a 23 MB index as raw bytes, so every snippet
came back unibyte -- lengths in bytes, and © or box-drawing art
handed to the client as octal escapes (2026-09-14)."
  (when (file-exists-p path)
    (with-temp-buffer
      (let ((coding-system-for-read 'utf-8-unix))
        (insert-file-contents path))
      (goto-char (point-min))
      (read (current-buffer)))))

(defun lisply-search--write-sexp-file (sexp path)
  "Write SEXP to PATH as UTF-8, unabridged.
Pinning the coding system means a build in a locale-less container
(Docker, CI) writes the same bytes as a developer's Emacs, and the
reader above can decode them without guessing."
  (let ((coding-system-for-write 'utf-8-unix))
    (with-temp-file path
      (set-buffer-multibyte t)
      (let ((print-length nil)
            (print-level nil)
            (print-escape-multibyte nil)
            (print-escape-nonascii nil))
        (prin1 sexp (current-buffer))))))

(defun lisply-search--pget (plist key &optional default)
  "Get KEY from PLIST, returning DEFAULT if missing or nil.
Note: Cannot distinguish between nil value and missing key."
  (let ((val (plist-get plist key)))
    (if val val default)))

(defun lisply-search--normalize-path (path)
  "Normalize PATH separators to forward slashes."
  (replace-regexp-in-string "\\\\" "/" path))

(defun lisply-search--file-ext (path)
  "Return lowercase file extension including dot."
  (downcase (or (file-name-extension path t) "")))

(defun lisply-search--to-list (thing)
  "Coerce THING to list (handle vectors)."
  (cond ((vectorp thing) (append thing nil))
        ((listp thing) thing)
        (t nil)))

(defun lisply-search--to-vector (list)
  "Convert LIST to vector, or empty vector if nil."
  (if list (vconcat list) []))


;;;; ============================================================
;;;; Config Handling (lisply-search-config.sexp)
;;;; ============================================================

(defun lisply-search--read-config ()
  "Read the search config from `lisply-search-services-path'.
Returns plist: (:sources ... :extensions ... :ignore-dirs ...).  The
top-level key is `:lisply-search-config'."
  (let* ((services (lisply-search--read-sexp-file lisply-search-services-path))
         (cfg (plist-get services :lisply-search-config)))
    (when cfg
      ;; Pass through as-is: the config file already uses plists
      cfg)))

(defun lisply-search--config-sources (config)
  "Extract sources from CONFIG as a flat list of entry plists.
Each entry carries :name :root :repo :repo-root :repo-url, plus the
optional :sparse (paths for a sparse checkout when the corpus is one
directory of a larger repo), :subdirs (the directories under :root that
make up the corpus -- the scan is limited to them, and they double as
the sparse checkout when no :sparse is given) and :branch (overriding
the build's default branch for that clone).

A source's :distribution, :public (the default) or :internal, says
whether it may be baked into a distributed image.  An :internal source
exists for a console working from a /projects mount and is never
indexed for a :public build (2026-09-14: the training material is
public, the rest of the private apps repository is not, and an index
inside a Docker Hub image must never carry the latter)."
  (let ((sources (lisply-search--pget config :sources)))
    (mapcan
     (lambda (source)
       (cl-destructuring-bind (&key name entries distribution &allow-other-keys) source
         (mapcar
          (lambda (entry)
            (cl-destructuring-bind (&key root repo repo-root repo-url sparse branch subdirs
                                         &allow-other-keys)
                entry
              (let* (;; Expand relative paths from /projects
                     (abs-root (if (and root (not (file-name-absolute-p root)))
                                   (expand-file-name root "/projects")
                                 root))
                     (abs-repo-root (if (and repo-root (not (file-name-absolute-p repo-root)))
                                        (expand-file-name repo-root "/projects")
                                      (or repo-root abs-root)))
                     (subdirs (lisply-search--to-list subdirs))
                     (root-in-repo (and abs-root abs-repo-root
                                        (file-relative-name abs-root abs-repo-root)))
                     (sparse (or (lisply-search--to-list sparse)
                                 (mapcar (lambda (d)
                                           (if (member root-in-repo '(nil "." ""))
                                               d
                                             (concat (file-name-as-directory root-in-repo) d)))
                                         subdirs))))
                (list :name (intern (concat ":" name))  ; keyword-ify
                      :root abs-root
                      :repo repo
                      :repo-root abs-repo-root
                      :repo-url repo-url
                      :sparse sparse
                      :subdirs subdirs
                      :branch branch
                      :distribution (or distribution :public)))))
          entries)))
     sources)))

(defun lisply-search--sources-for-distribution (sources distribution)
  "The SOURCES an index built for DISTRIBUTION may carry.
DISTRIBUTION :all keeps every source; :public keeps only those whose
:distribution is :public and logs each one left out.  Any other value
is treated as :public: the safe reading of a build that did not say."
  (if (eq distribution :all)
      sources
    (cl-remove-if-not
     (lambda (s)
       (or (eq (plist-get s :distribution) :public)
           (progn
             (lisply-search--log "INTERNAL source left out of the %s index: %s (%s)"
                                 distribution (plist-get s :name) (plist-get s :root))
             nil)))
     sources)))

(defun lisply-search--config-extensions (config &optional language)
  "Get allowed extensions for LANGUAGE from CONFIG, or default."
  (let* ((exts (lisply-search--pget config :extensions))
         (lang-key (and language (if (keywordp language) language
                                   (intern (concat ":" (downcase (format "%s" language)))))))
         (lang-exts (and lang-key (plist-get exts lang-key))))
    (or lang-exts
        (plist-get exts :default)
        lisply-search--default-extensions)))

(defun lisply-search--config-ignore-dirs (config)
  "Get ignore-dirs list from CONFIG."
  (or (lisply-search--pget config :ignore-dirs)
      lisply-search--default-ignore-dirs))

(defun lisply-search--config-exclude-paths (config)
  "Get exclude-paths patterns from CONFIG."
  (lisply-search--to-list (lisply-search--pget config :exclude-paths)))


;;;; ============================================================
;;;; File Scanning
;;;; ============================================================

(defun lisply-search--path-excluded-p (path excludes)
  "Check if PATH matches any pattern in EXCLUDES."
  (cl-some (lambda (pattern)
             (let ((normalized (lisply-search--normalize-path pattern)))
               (if (string-match-p "[*?]" normalized)
                   (string-match-p (wildcard-to-regexp normalized)
                                   (lisply-search--normalize-path path))
                 (string-prefix-p normalized (lisply-search--normalize-path path)))))
           excludes))

(defun lisply-search--list-files (root extensions ignore-dirs excludes)
  "Recursively list files under ROOT matching EXTENSIONS.
Skip IGNORE-DIRS and paths matching EXCLUDES patterns."
  (let (results)
    (when (file-exists-p root)
      (dolist (entry (directory-files root t "\\`[^.]"))
        (cond
         ((file-directory-p entry)
          (unless (member (file-name-nondirectory entry) ignore-dirs)
            (setq results (nconc results
                                 (lisply-search--list-files
                                  entry extensions ignore-dirs excludes)))))
         ((and (file-regular-p entry)
               (member (lisply-search--file-ext entry) extensions)
               (not (lisply-search--path-excluded-p entry excludes)))
          (push entry results)))))
    results))

(defun lisply-search--guess-language (path)
  "Guess language keyword from PATH extension."
  (let ((ext (lisply-search--file-ext path)))
    (cond
     ((member ext (cdr (assq :lisp lisply-search--language-extensions))) :lisp)
     ((member ext (cdr (assq :gendl lisply-search--language-extensions))) :gendl)
     ((member ext (cdr (assq :gdl lisply-search--language-extensions))) :gdl)
     ((member ext (cdr (assq :markdown lisply-search--language-extensions))) :markdown)
     (t nil))))

;;;; ============================================================
;;;; Snippet Extraction
;;;; ============================================================
;;
;; A file becomes a sequence of chunks.  Where the file has a structure
;; we understand -- top-level forms in Lisp (a `(' in column 0), headings
;; in Markdown and Org -- chunks begin at those boundaries and adjacent
;; small forms are packed together up to the configured size, so a hit
;; is a whole define-object or a whole section, not the tail of one and
;; the head of the next.  A form larger than the budget is split into
;; fixed windows.  Files with no recognised structure get fixed windows.

(defun lisply-search--chunk-boundaries (lines language ext)
  "Return the ascending line indices in LINES where a chunk may begin.
LANGUAGE is the guessed language keyword, EXT the lowercase extension."
  (let ((rx (cond ((memq language '(:lisp :gendl :gdl)) "\\`(")
                  ((string= ext ".org") "\\`\\*+ ")
                  ((member ext '(".md" ".markdown")) "\\`#+ ")
                  (t nil)))
        (i 0)
        out)
    (when rx
      (dolist (line lines)
        (when (string-match-p rx line)
          (push i out))
        (setq i (1+ i))))
    (nreverse out)))

(defun lisply-search--fixed-windows (lv start end max-lines max-chars)
  "Cut lines START..END (exclusive) of vector LV into fixed windows.
Each window holds at most MAX-LINES lines and about MAX-CHARS
characters; a window cut short by the character budget is followed by a
window starting at the first line it left out, so no line of the file
goes unindexed.  Returns a list of (:start S :end E :lines L) plists."
  (let ((pos start)
        out)
    (while (< pos end)
      (let* ((limit (min end (+ pos max-lines)))
             (len 0)
             (kept 0))
        (cl-loop for i from pos below limit
                 for next = (+ len (length (aref lv i)) 1)
                 do (if (and (> next max-chars) (> kept 0))
                        (cl-return)
                      (setq len next
                            kept (1+ kept))))
        (push (list :start pos
                    :end (+ pos kept -1)
                    :lines (append (cl-subseq lv pos (+ pos kept)) nil))
              out)
        (setq pos (+ pos kept))))
    (nreverse out)))

(defun lisply-search--extract-snippets (lines max-lines max-chars &optional boundaries)
  "Split LINES into snippet chunks of at most MAX-LINES and about MAX-CHARS.
With BOUNDARIES (ascending line indices from
`lisply-search--chunk-boundaries'), chunks begin only at a boundary:
consecutive segments are packed while they fit, an oversized segment is
cut into fixed windows, and a leading segment of at least
`lisply-search--header-segment-min-lines' lines (a licence header)
stands alone.  Without BOUNDARIES the whole file is cut into fixed
windows.  Returns a list of (:start S :end E :lines L) plists with
0-based inclusive line numbers."
  (let* ((lv (vconcat lines))
         (total (length lv)))
    (if (or (null boundaries) (zerop total))
        (lisply-search--fixed-windows lv 0 total max-lines max-chars)
      (let* ((starts (if (zerop (car boundaries)) boundaries (cons 0 boundaries)))
             (segments (cl-loop for (s . rest) on starts
                                collect (cons s (if rest (car rest) total))))
             (first-is-header (and (not (zerop (car boundaries)))
                                   (>= (car boundaries)
                                       lisply-search--header-segment-min-lines)))
             (cur-start nil) (cur-end nil) (cur-chars 0)
             (first t)
             out)
        (cl-flet ((seg-chars (s e)
                    (let ((n 0))
                      (cl-loop for i from s below e
                               do (cl-incf n (1+ (length (aref lv i)))))
                      n))
                  (flush ()
                    (when cur-start
                      (push (list :start cur-start
                                  :end (1- cur-end)
                                  :lines (append (cl-subseq lv cur-start cur-end) nil))
                            out)
                      (setq cur-start nil cur-end nil cur-chars 0))))
          (dolist (seg segments)
            (let* ((s (car seg)) (e (cdr seg))
                   (n (- e s))
                   (c (seg-chars s e)))
              (cond
               ((or (> n max-lines) (> c max-chars))
                (flush)
                (dolist (w (lisply-search--fixed-windows lv s e max-lines max-chars))
                  (push w out)))
               ((and cur-start
                     (<= (+ (- cur-end cur-start) n) max-lines)
                     (<= (+ cur-chars c) max-chars))
                (setq cur-end e
                      cur-chars (+ cur-chars c)))
               (t
                (flush)
                (setq cur-start s cur-end e cur-chars c)))
              (when (and first first-is-header)
                (flush))
              (setq first nil)))
          (flush))
        (nreverse out)))))

(defun lisply-search--find-section-heading (lines start-line path)
  "Find nearest markdown/org heading above START-LINE in LINES."
  (let ((ext (lisply-search--file-ext path)))
    (when (member ext '(".md" ".markdown" ".org" ".rst"))
      (cl-loop for i from start-line downto (max 0 (- start-line 50))
               for line = (nth i lines)
               when (and (string= ext ".org")
                         (string-match "^\\*+\\s-+\\(.+\\)$" line))
               return (string-trim (match-string 1 line))
               when (and (not (string= ext ".org"))
                         (string-match "^#+\\s-+\\(.+\\)$" line))
               return (string-trim (match-string 1 line))))))

(defun lisply-search--cap-text (text max-chars)
  "TEXT cut to at most MAX-CHARS characters.
The chunker keeps every chunk within its character budget line by
line, so the only text that arrives here over budget is a single line
longer than the whole budget: a minified asset, a one-line data file.
Such a line is stored truncated -- a snippet is a few hundred
characters of context, and a 15 KB one-liner is a hit with nothing to
read in it."
  (if (and max-chars (> (length text) max-chars))
      (substring text 0 max-chars)
    text))

(defun lisply-search--extract-file-snippets (path max-lines max-chars)
  "Extract snippets from file at PATH.
Each snippet holds at most MAX-LINES lines and MAX-CHARS characters;
the character cap holds whatever the line count (see
`lisply-search--cap-text')."
  (with-temp-buffer
    (insert-file-contents path)
    (let* ((all-lines (split-string (buffer-string) "\n" nil))
           (language (lisply-search--guess-language path))
           (boundaries (lisply-search--chunk-boundaries
                        all-lines language (lisply-search--file-ext path)))
           (raw-snippets (lisply-search--extract-snippets
                          all-lines max-lines max-chars boundaries)))
      (mapcar
       (lambda (snip)
         (cl-destructuring-bind (&key lines start end) snip
           (let* ((text (lisply-search--cap-text (string-join lines "\n") max-chars))
                  (lines (split-string text "\n"))
                  (preview (or (cl-find-if (lambda (l) (> (length (string-trim l)) 0)) lines) "")))
             (list :start-line start
                   :end-line end
                   :snippet text
                   :preview (string-trim preview)
                   :section (lisply-search--find-section-heading all-lines start path)
                   :language language
                   :terms (lisply-search--to-vector
                           (delete-dups (lisply-search--extract-terms text)))))))
       raw-snippets))))


;;;; ============================================================
;;;; Index Building
;;;; ============================================================

(defun lisply-search--build-file-entry (source-info path config)
  "Build index entry for PATH from SOURCE-INFO using CONFIG."
  (cl-destructuring-bind (&key name repo repo-root &allow-other-keys) source-info
    (let* ((attrs (file-attributes path))
           (size (file-attribute-size attrs))
           (language (lisply-search--guess-language path))
           (preextract (lisply-search--pget config :preextract-snippets))
           (max-lines (or (lisply-search--pget config :preextract-max-lines)
                          lisply-search--default-snippet-lines))
           (max-chars (or (lisply-search--pget config :preextract-max-chars)
                          lisply-search--default-snippet-chars))
           (snippets (when (and preextract size (< size lisply-search--max-file-bytes))
                       (lisply-search--extract-file-snippets path max-lines max-chars))))
      (list :source name
            :path (lisply-search--normalize-path path)
            :repo repo
            :repo-root repo-root
            :language language
            :mtime (format-time-string "%Y-%m-%dT%H:%M:%SZ"
                                       (file-attribute-modification-time attrs) t)
            :snippets (when snippets (lisply-search--to-vector snippets))))))

(defun lisply-search--compute-checksum (file-entries)
  "Compute simple checksum from FILE-ENTRIES."
  (let ((count (length file-entries))
        (total-size 0))
    (dolist (entry file-entries)
      (let ((path (plist-get entry :path)))
        (when (and path (file-exists-p path))
          (cl-incf total-size (or (file-attribute-size (file-attributes path)) 0)))))
    (format "%d-%d" count total-size)))

(defun lisply-search--source-files (source extensions ignore-dirs excludes)
  "The files of SOURCE to index: those under its :root, or under each of
its :subdirs when it names some.  A missing root or subdirectory is
logged and yields nothing."
  (let* ((root (plist-get source :root))
         (subdirs (plist-get source :subdirs))
         (roots (if subdirs
                    (mapcar (lambda (d) (expand-file-name d root)) subdirs)
                  (list root)))
         files)
    (dolist (r roots)
      (if (not (file-exists-p r))
          (lisply-search--log "WARNING: Source %s missing: %s"
                              (if subdirs "subdirectory" "root") r)
        (setq files (nconc files (lisply-search--list-files r extensions ignore-dirs excludes)))))
    files))

(defun lisply-search-build-index (&optional distribution)
  "Build search index from the lisply-search-config.sexp sources.
DISTRIBUTION is :all (the default here: every source present on the
host is indexed, for a console working from a /projects mount) or
:public (only sources marked for distribution, for an image)."
  (interactive)
  (let* ((config (lisply-search--read-config))
         (distribution (or distribution :all))
         (sources (lisply-search--sources-for-distribution
                   (lisply-search--config-sources config) distribution))
         (extensions (lisply-search--config-extensions config))
         (ignore-dirs (lisply-search--config-ignore-dirs config))
         (excludes (lisply-search--config-exclude-paths config))
         entries)
    (unless sources
      (error "lisply-search: no sources configured under :lisply-search-config in %s"
             lisply-search-services-path))
    ;; Scan each source
    (dolist (source sources)
      (dolist (path (lisply-search--source-files source extensions ignore-dirs excludes))
        (push (lisply-search--build-file-entry source path config) entries)))
    (when (null entries)
      (error "lisply-search: nothing to index -- every configured source root is missing"))
    ;; Build index plist
    (let* ((files (nreverse entries))
           (index (list :version lisply-search--index-version
                        :generated-at (format-time-string "%Y-%m-%dT%H:%M:%SZ" nil t)
                        :distribution distribution
                        :checksum (lisply-search--compute-checksum files)
                        :config config
                        :files (lisply-search--to-vector files))))
      ;; Write index
      (lisply-search--write-sexp-file index lisply-search-index-path)
      (lisply-search--log "Index written: %s (%d files, %d snippets)"
                          lisply-search-index-path (length files)
                          (cl-reduce #'+ files
                                     :key (lambda (f) (length (plist-get f :snippets)))
                                     :initial-value 0))
      index)))


;;;; ============================================================
;;;; Clone Support (for Docker builds with empty /projects/)
;;;; ============================================================

(defun lisply-search--git (dir &rest args)
  "Run git with ARGS (in DIR when non-nil), logging to *lisply-search-clone*.
Returns the exit status."
  (apply #'process-file "git" nil "*lisply-search-clone*" t
         (append (when dir (list "-C" dir)) args)))

(defun lisply-search--clone-entry (source-info branch)
  "Make the :root of SOURCE-INFO exist, cloning its :repo-url if needed.
The clone lands in :repo-root -- the repository's own directory, which
may be an ancestor of :root -- so a corpus that is one directory of a
larger repository can be fetched as a sparse checkout of just that
directory (:sparse, a list of paths).  An entry's own :branch overrides
BRANCH, which defaults to master.  Returns non-nil when :root exists
afterwards."
  (let* ((root (plist-get source-info :root))
         (repo-root (or (plist-get source-info :repo-root) root))
         (repo-url (plist-get source-info :repo-url))
         (sparse (plist-get source-info :sparse))
         (branch (or (plist-get source-info :branch) branch "master")))
    (cond
     ((or (null root) (string-empty-p root))
      (lisply-search--log "Skip clone: no root path")
      nil)
     ((file-exists-p root)
      (lisply-search--log "Exists, skip clone: %s" root)
      t)
     ((or (null repo-url) (string-empty-p repo-url))
      (lisply-search--log "SOURCE MISSING (local-only, no repo-url): %s" root)
      nil)
     ((and sparse (file-exists-p repo-root))
      ;; The repository is already here but not our directory: widen it.
      (lisply-search--log "Widening sparse checkout %s by %s" repo-root sparse)
      (apply #'lisply-search--git repo-root "sparse-checkout" "add" sparse)
      (if (file-exists-p root)
          (progn (lisply-search--log "Sparse checkout widened: %s" root) t)
        (lisply-search--log "SOURCE MISSING after widening: %s" root)
        nil))
     (t
      (lisply-search--log "Cloning %s -> %s (branch: %s%s)" repo-url repo-root branch
                          (if sparse (format ", sparse: %s" sparse) ""))
      (make-directory (file-name-directory (directory-file-name repo-root)) t)
      (let ((exit (apply #'lisply-search--git nil
                         (append (list "clone" "--depth" "1" "--branch" branch)
                                 (when sparse (list "--filter=blob:none" "--sparse"))
                                 (list repo-url repo-root)))))
        (when (and sparse (integerp exit) (zerop exit))
          (setq exit (apply #'lisply-search--git repo-root "sparse-checkout" "set" sparse)))
        (cond
         ((not (and (integerp exit) (zerop exit)))
          (lisply-search--log "Clone FAILED: %s (exit %s)" repo-root exit)
          nil)
         ((file-exists-p root)
          (lisply-search--log "Clone succeeded: %s" root)
          t)
         (t
          (lisply-search--log "Clone landed but SOURCE MISSING inside it: %s" root)
          nil)))))))

(defun lisply-search--clone-all-sources (config branch &optional sources)
  "Make every source in CONFIG present, cloning where needed.
SOURCES, when given, is the subset to make present (the sources of one
distribution); otherwise every configured source.  Returns the list of
source roots still missing afterwards; nil means every source is
present."
  (let ((sources (or sources (lisply-search--config-sources config)))
        missing)
    (if (null sources)
        (progn
          (lisply-search--log "No sources configured, nothing to clone")
          nil)
      (dolist (source sources)
        (unless (lisply-search--clone-entry source branch)
          (push (plist-get source :root) missing)))
      (setq missing (nreverse missing))
      (lisply-search--log "Source summary: %d configured, %d present, %d missing%s"
                          (length sources)
                          (- (length sources) (length missing))
                          (length missing)
                          (if missing (format " -- %s" (string-join missing ", ")) ""))
      missing)))

(defun lisply-search-build-index-with-clone (&optional branch strict distribution)
  "Clone corpora as needed, then build the index from every source present.
BRANCH is the default git branch for clones (master); an entry's own
:branch wins.  In Docker builds /projects/ is empty and the repos are
cloned fresh; in dev the existing repos are used as-is.

DISTRIBUTION is :public (the default, and what an image build must
use: sources marked :internal are neither cloned nor indexed) or :all
(every source, for an index built on a host that holds the internal
corpora).  The environment variable LISPLY_INDEX_DISTRIBUTION
(\"public\" or \"all\") sets it when the argument is nil.

A source that cannot be fetched is logged as SOURCE MISSING and
skipped, and the index is still built from the rest: a partial corpus
beats none.  (From 2026-08-20 to 2026-09-09 every shipped console image
carried no index at all, because one corpus repository had gone away
and a failed clone used to skip the whole build -- silently, since the
build step still exited 0.)  When STRICT is non-nil, or the environment
variable LISPLY_INDEX_STRICT is \"true\", a missing source is an error
instead, so a CI build cannot go green with a short corpus."
  (interactive)
  (let* ((config (lisply-search--read-config))
         (strict (or strict (equal (getenv "LISPLY_INDEX_STRICT") "true")))
         (distribution (or distribution
                           (if (equal (getenv "LISPLY_INDEX_DISTRIBUTION") "all") :all :public))))
    (if (not config)
        (error "lisply-search: no config found at %s" lisply-search-services-path)
      (let* ((sources (lisply-search--sources-for-distribution
                       (lisply-search--config-sources config) distribution))
             (missing (lisply-search--clone-all-sources config branch sources)))
        (lisply-search--log "Building the %s index" distribution)
        (when missing
          (lisply-search--log "SOURCE MISSING: %s" (string-join missing ", ")))
        (if (and missing strict)
            (error "lisply-search: %d source(s) missing in strict mode: %s"
                   (length missing) (string-join missing ", "))
          (lisply-search-build-index distribution))))))


;;;; ============================================================
;;;; Runtime: Index Loading & Caching
;;;; ============================================================

(defun lisply-search--validate-index (index)
  "Validate INDEX format. Return error string or nil if valid."
  (cond
   ((null index) "Index is nil")
   ((not (plist-get index :version)) "Index missing :version")
   ((not (memq (plist-get index :version) lisply-search--supported-index-versions))
    (format "Index version unsupported: %s (expected one of %s)"
            (plist-get index :version)
            lisply-search--supported-index-versions))
   ((not (plist-get index :files)) "Index missing :files")
   (t nil)))

(defun lisply-search--build-snippet-map (index)
  "Build inverted term index from INDEX.
Returns hash-table: term -> list of (:snippet S :file F :source SRC :entry E)."
  (let ((snippet-map (make-hash-table :test 'equal))
        (files (lisply-search--to-list (plist-get index :files))))
    (dolist (file-entry files)
      (cl-destructuring-bind (&key path source snippets &allow-other-keys) file-entry
        (dolist (snippet (lisply-search--to-list snippets))
          (let ((snippet-plist snippet))
            (cl-destructuring-bind (&key ((:snippet snippet-text)) terms &allow-other-keys) snippet-plist
              (let* ((text (or snippet-text ""))
                     ;; Use pre-computed terms (v3+) or fall back to extraction (v2)
                     (term-list (or (lisply-search--to-list terms)
                                    (lisply-search--extract-terms text)))
                     (candidate (list :snippet snippet-plist
                                      :file path
                                      :source source
                                      :entry file-entry)))
                (dolist (term term-list)
                  (push candidate (gethash term snippet-map)))))))))
    snippet-map))

(defun lisply-search--count-snippets (index)
  "Total number of snippets in INDEX."
  (cl-reduce #'+ (lisply-search--to-list (plist-get index :files))
             :key (lambda (f) (length (plist-get f :snippets)))
             :initial-value 0))

(defun lisply-search--load-index ()
  "Load and cache index. Returns cache plist or nil."
  (let* ((path lisply-search-index-path)
         (attrs (and (file-exists-p path) (file-attributes path)))
         (mtime (and attrs (file-attribute-modification-time attrs))))
    ;; Check cache validity
    (if (and lisply-search--cache
             (equal (plist-get lisply-search--cache :path) path)
             (equal (plist-get lisply-search--cache :mtime) mtime))
        lisply-search--cache
      ;; Reload
      (let* ((raw (lisply-search--read-sexp-file path))
             (index raw))
        (when index
          (let ((err (lisply-search--validate-index index)))
            (when err
              (lisply-search--log "WARNING: %s" err)
              (setq index nil))))
        (setq lisply-search--cache
              (when index
                (list :path path
                      :mtime mtime
                      :index index
                      :config (plist-get index :config)
                      ;; The sources the index actually carries: a
                      ;; :public build leaves the :internal ones out.
                      :present-sources
                      (let (names)
                        (dolist (f (lisply-search--to-list (plist-get index :files)))
                          (cl-pushnew (plist-get f :source) names))
                        (nreverse names))
                      :snippet-map (lisply-search--build-snippet-map index)
                      :snippet-count (lisply-search--count-snippets index))))
        lisply-search--cache))))


;;;; ============================================================
;;;; Search Logic
;;;; ============================================================

(defun lisply-search--extract-terms (text)
  "Extract search terms from TEXT. Returns list of lowercase terms."
  (let* ((lower (downcase (format "%s" text)))
         (parts (split-string lower "[^a-z0-9_]+" t)))
    (cl-remove-if (lambda (term) (< (length term) 2)) parts)))

(defun lisply-search--query-terms (query)
  "Split QUERY into (TERMS . PHRASES).
TERMS are the index terms of the query with stopwords removed (kept when
nothing else remains).  PHRASES are the whitespace-separated tokens that
contain a hyphen -- `hidden-objects', `base-html-page' -- which the
index cannot see as units and which are matched verbatim at scoring
time."
  (let* ((all (delete-dups (lisply-search--extract-terms query)))
         (kept (cl-remove-if (lambda (term) (member term lisply-search--stopwords)) all))
         (terms (or kept all))
         (tokens (split-string (downcase query) "[][ \t\n\r\"',()]+" t))
         (phrases (delete-dups
                   (cl-remove-if-not (lambda (tok)
                                       (and (>= (length tok) 3)
                                            (string-match-p "[a-z0-9]-[a-z0-9]" tok)))
                                     tokens))))
    (cons terms phrases)))

(defun lisply-search--count-term-occurrences (text term)
  "Count occurrences of TERM in TEXT."
  (let ((count 0) (start 0) (needle (regexp-quote term)))
    (while (string-match needle text start)
      (cl-incf count)
      (setq start (match-end 0)))
    count))

(defun lisply-search--idf-table (terms snippet-map total)
  "Return an alist (TERM . IDF) for TERMS over SNIPPET-MAP of TOTAL snippets.
A term with no postings gets nil, so it neither helps nor hurts."
  (mapcar (lambda (term)
            (let ((df (length (gethash term snippet-map))))
              (cons term (when (> df 0)
                           (log (1+ (/ (float (max total 1)) (1+ df))))))))
          terms))

(defun lisply-search--name-regexp (name)
  "Regexp matching NAME as a whole identifier in downcased text."
  (concat "\\(?:\\`\\|[^a-z0-9_-]\\)" (regexp-quote name) "\\(?:[^a-z0-9_-]\\|\\'\\)"))

(defun lisply-search--defines-p (text names)
  "Non-nil when TEXT (downcased) contains a definition of one of NAMES:
a `(def...' form whose defined name is that identifier."
  (cl-some (lambda (name)
             (string-match-p (concat "(def[a-z*-]*[ \t]+\\(?:([ \t]*\\)?"
                                     (regexp-quote name)
                                     "\\(?:[^a-z0-9_-]\\|\\'\\)")
                             text))
           names))

(defun lisply-search--score-candidate (candidate terms phrases idfs)
  "Score CANDIDATE for TERMS and PHRASES using the IDFS alist.  Returns 0.0-1.0.
The score weighs IDF-weighted coverage of the query terms (0.55), term
density (0.15), verbatim phrase hits (0.15), whether the snippet defines
a queried name (0.10, half that for a matching section heading) and
whether the file name carries one (0.05)."
  (let* ((snippet (plist-get candidate :snippet))
         (text (downcase (or (plist-get snippet :snippet) "")))
         (section (downcase (or (plist-get snippet :section) "")))
         (file (or (plist-get candidate :file) ""))
         (fname (downcase (file-name-nondirectory file)))
         (idf-total 0.0)
         (idf-hit 0.0)
         (total-matches 0))
    (dolist (term terms)
      (let ((w (cdr (assoc term idfs))))
        (when w
          (let ((occ (lisply-search--count-term-occurrences text term)))
            (cl-incf idf-total w)
            (when (> occ 0)
              (cl-incf idf-hit w)
              (cl-incf total-matches occ))))))
    (let* ((coverage (if (> idf-total 0.0) (/ idf-hit idf-total) 0.0))
           (density (min 1.0 (/ (float total-matches) 8.0)))
           (phrase (if phrases
                       (/ (float (cl-count-if
                                  (lambda (p) (string-match-p (regexp-quote p) text))
                                  phrases))
                          (length phrases))
                     0.0))
           (names (append phrases terms))
           (definition (cond ((lisply-search--defines-p text names) 1.0)
                             ((and (> (length section) 0)
                                   (cl-some (lambda (n) (string-match-p (regexp-quote n) section))
                                            names))
                              0.5)
                             (t 0.0)))
           (path (if (cl-some (lambda (n) (string-match-p (regexp-quote n) fname)) names)
                     1.0 0.0)))
      (min 1.0 (+ (* 0.55 coverage)
                  (* 0.15 density)
                  (* 0.15 phrase)
                  (* 0.10 definition)
                  (* 0.05 path))))))

(defun lisply-search--display-path (candidate)
  "The path of CANDIDATE as reported in hits: relative to its repo root."
  (let* ((file (plist-get candidate :file))
         (repo-root (plist-get (plist-get candidate :entry) :repo-root)))
    (lisply-search--normalize-path
     (if repo-root (file-relative-name file repo-root) file))))

(defun lisply-search--glob-to-regexp (glob)
  "Regexp for GLOB anchored at the start: `**' spans directories, `*' and
`?' stay within one path component."
  (let ((i 0) (n (length glob)) (out "\\`"))
    (while (< i n)
      (let ((c (aref glob i)))
        (cond
         ((and (eq c ?*) (< (1+ i) n) (eq (aref glob (1+ i)) ?*))
          (setq out (concat out ".*") i (+ i 2)))
         ((eq c ?*) (setq out (concat out "[^/]*") i (1+ i)))
         ((eq c ??) (setq out (concat out "[^/]") i (1+ i)))
         (t (setq out (concat out (regexp-quote (string c))) i (1+ i))))))
    out))

(defun lisply-search--path-filter-p (candidate filters)
  "Non-nil when CANDIDATE's path passes FILTERS (nil FILTERS pass everything).
A filter with `*' or `?' is a glob against the repo-relative path; any
other filter is a prefix of the repo-relative path or of the absolute
one."
  (or (null filters)
      (let ((rel (lisply-search--display-path candidate))
            (abs (lisply-search--normalize-path (or (plist-get candidate :file) ""))))
        (cl-some (lambda (f)
                   (let ((f (lisply-search--normalize-path f)))
                     (if (string-match-p "[*?]" f)
                         (string-match-p (lisply-search--glob-to-regexp f) rel)
                       (or (string-prefix-p f rel) (string-prefix-p f abs)))))
                 filters))))

(defun lisply-search--candidate-matches-p (candidate sources extensions excludes &optional path-filters)
  "Return non-nil if CANDIDATE passes SOURCES, EXTENSIONS, EXCLUDES and
PATH-FILTERS."
  (cl-destructuring-bind (&key file source &allow-other-keys) candidate
    (and file
         (or (null sources) (memq source sources))
         (member (lisply-search--file-ext file) extensions)
         (not (lisply-search--path-excluded-p file excludes))
         (lisply-search--path-filter-p candidate path-filters))))

(defun lisply-search--filter-candidates (snippet-map terms sources extensions excludes match-mode any-max-candidates &optional path-filters)
  "Get matching candidates from SNIPPET-MAP for TERMS.
Filter by SOURCES, EXTENSIONS, EXCLUDES and PATH-FILTERS.  MATCH-MODE is
:all or :any."
  (let* ((terms (delete-dups terms)))
    (cond
     ((or (null terms) (null snippet-map)) nil)
     ((eq match-mode :any)
      ;; OR semantics: union of term hits, optionally capped.
      (let* ((seen (make-hash-table :test 'eq))
             (count 0)
             (term-lists
              (delq nil
                    (mapcar (lambda (term)
                              (let ((lst (gethash term snippet-map)))
                                (when lst
                                  (list term lst (length lst)))))
                            terms)))
             (sorted (sort term-lists (lambda (a b) (< (nth 2 a) (nth 2 b)))))
             candidates)
        (catch 'done
          (dolist (pair sorted)
            (dolist (candidate (nth 1 pair))
              (unless (gethash candidate seen)
                (when (lisply-search--candidate-matches-p candidate sources extensions excludes path-filters)
                  (puthash candidate t seen)
                  (push candidate candidates)
                  (when any-max-candidates
                    (setq count (1+ count))
                    (when (>= count any-max-candidates)
                      (throw 'done nil))))))))
        (nreverse candidates)))
     (t
      ;; AND semantics: intersect rarest term postings first.  A term
      ;; with no postings anywhere makes the intersection empty.
      (let* ((term-lists
              (mapcar (lambda (term)
                        (let ((lst (gethash term snippet-map)))
                          (list term lst (length lst))))
                      terms)))
        (unless (cl-some (lambda (tl) (null (nth 1 tl))) term-lists)
          (let* ((sorted (sort term-lists (lambda (a b) (< (nth 2 a) (nth 2 b)))))
                 (seed (nth 1 (car sorted)))
                 (candidate-set (make-hash-table :test 'eq))
                 results)
            (dolist (candidate seed)
              (when (lisply-search--candidate-matches-p candidate sources extensions excludes path-filters)
                (puthash candidate t candidate-set)))
            (dolist (pair (cdr sorted))
              (let ((present (make-hash-table :test 'eq)))
                (dolist (candidate (nth 1 pair))
                  (when (gethash candidate candidate-set)
                    (puthash candidate t present)))
                (setq candidate-set present)))
            (maphash (lambda (candidate _)
                       (push candidate results))
                     candidate-set)
            (nreverse results))))))))

(defun lisply-search--first-match-line (lines terms phrases)
  "Index of the first line in LINES containing a phrase or term, or nil."
  (let ((names (append phrases terms))
        (i 0)
        found)
    (while (and (not found) lines)
      (let ((l (downcase (car lines))))
        (when (cl-some (lambda (n) (string-match-p (regexp-quote n) l)) names)
          (setq found i)))
      (setq i (1+ i) lines (cdr lines)))
    found))

(defun lisply-search--format-hit (candidate score terms phrases index include-metadata max-chars)
  "Format CANDIDATE with SCORE as search hit number INDEX.
The snippet is excerpted around the first line that matches the query
when it is longer than MAX-CHARS; `:match-line' and
`:excerpt-start-line' say where (1-based, absolute in the file)."
  (cl-destructuring-bind (&key snippet &allow-other-keys) candidate
    (cl-destructuring-bind (&key repo &allow-other-keys) (plist-get candidate :entry)
      (cl-destructuring-bind (&key start-line end-line preview language section &allow-other-keys) snippet
        (let* ((text (or (plist-get snippet :snippet) ""))
               (lines (split-string text "\n"))
               (match-idx (lisply-search--first-match-line lines terms phrases))
               (start (1+ (or start-line 0)))
               (excerpt-start-idx (if (and match-idx max-chars (> (length text) max-chars))
                                      (max 0 (- match-idx 2))
                                    0))
               (excerpt (if (zerop excerpt-start-idx)
                            text
                          (string-join (nthcdr excerpt-start-idx lines) "\n")))
               (excerpt (if (and max-chars (> (length excerpt) max-chars))
                            (substring excerpt 0 max-chars)
                          excerpt)))
          (list :id (format "hit-%03d" index)
                :score (/ (fround (* score 1000.0)) 1000.0)
                :source (plist-get candidate :source)
                :repo repo
                :path (lisply-search--display-path candidate)
                :start-line start
                :end-line (1+ (or end-line 0))
                :match-line (when match-idx (+ start match-idx))
                :excerpt-start-line (+ start excerpt-start-idx)
                :snippet excerpt
                :preview (if match-idx
                             (string-trim (nth match-idx lines))
                           (or preview ""))
                :metadata (when include-metadata
                            (list :language language
                                  :section section
                                  :tags (lisply-search--to-vector
                                         (cl-subseq terms 0 (min 8 (length terms))))))))))))


;;;; ============================================================
;;;; Main Search API
;;;; ============================================================

(defun lisply-search (params)
  "Execute search with PARAMS plist.
PARAMS: (:query Q :k K :sources [S...] :language L :path-filters [P...]
:match-mode :all|:any :any-max-candidates N :max-snippet-tokens N
:search-mode M :include-metadata BOOL).
Returns plist: (:query Q :search-mode :lexical :match-mode M
:match-fallback BOOL :sources [S...] :hits [H...] :warning W)."
  (cl-destructuring-bind (&key query k max-snippet-tokens match-mode
                               any-max-candidates language sources
                               path-filters search-mode
                               include-metadata &allow-other-keys)
      params
    (let* ((k (or k lisply-search--default-k))
           (max-tokens (or max-snippet-tokens lisply-search--default-max-tokens))
           (explicit-mode match-mode)
           (match-mode (or match-mode lisply-search--default-match-mode))
           (any-max-candidates (or any-max-candidates lisply-search--default-any-max-candidates))
           (include-metadata (if (plist-member params :include-metadata)
                                 include-metadata
                               t))
           (requested-sources (lisply-search--to-list sources))
           (path-filters (cl-remove-if-not #'stringp (lisply-search--to-list path-filters)))
           ;; Load index
           (cache (lisply-search--load-index))
           (config (and cache (plist-get cache :config)))
           (snippet-map (and cache (plist-get cache :snippet-map)))
           (snippet-count (or (and cache (plist-get cache :snippet-count)) 0))
           warnings)
      (cond
       ((not cache)
        (list :error (format "Index not found: %s" lisply-search-index-path)))
       ((not snippet-map)
        (list :error "Index has no snippet map"))
       (t
        (when (and search-mode
                   (not (member (downcase (format "%s" search-mode)) '("lexical" ":lexical"))))
          (push (format "search_mode %s is not available in this build; answered lexically"
                        search-mode)
                warnings))
        ;; Determine which sources to search
        (let* ((all-sources (or (plist-get cache :present-sources)
                                (mapcar (lambda (s) (plist-get s :name))
                                        (lisply-search--config-sources config))))
               (requested (when requested-sources
                            (mapcar (lambda (s)
                                      (if (keywordp s) s
                                        (intern (concat ":" s))))
                                    requested-sources)))
               (matched (when requested
                          (cl-remove-if-not (lambda (s) (memq s all-sources))
                                            requested)))
               (unknown (when requested
                          (cl-remove-if (lambda (s) (memq s all-sources))
                                        requested)))
               (sources (if matched matched all-sources))
               (extensions (lisply-search--config-extensions config language))
               (excludes (lisply-search--config-exclude-paths config))
               (parsed (lisply-search--query-terms query))
               (terms (car parsed))
               (phrases (cdr parsed))
               (idfs (lisply-search--idf-table terms snippet-map snippet-count))
               (max-chars (* max-tokens 4))
               (fallback nil))
          (when unknown
            (push (format "Unknown sources ignored: %s"
                          (mapconcat (lambda (s) (substring (symbol-name s) 1))
                                     unknown ", "))
                  warnings))
          ;; Filter, score, rank
          (let* ((candidates (lisply-search--filter-candidates
                              snippet-map terms sources extensions excludes
                              match-mode any-max-candidates path-filters))
                 (candidates (if (and (null candidates)
                                      (eq match-mode :all)
                                      (> (length terms) 1))
                                 ;; Nothing holds every term: rank by any term instead.
                                 (progn
                                   (setq fallback t
                                         match-mode :any)
                                   (push (format "no snippet contains every term (%s); ranked by any-term match instead"
                                                 (string-join terms ", "))
                                         warnings)
                                   (lisply-search--filter-candidates
                                    snippet-map terms sources extensions excludes
                                    :any any-max-candidates path-filters))
                               candidates))
                 (scored (mapcar (lambda (c)
                                   (cons (lisply-search--score-candidate c terms phrases idfs) c))
                                 candidates))
                 (sorted (sort scored (lambda (a b)
                                        (or (> (car a) (car b))
                                            (and (= (car a) (car b))
                                                 (string< (lisply-search--display-path (cdr a))
                                                          (lisply-search--display-path (cdr b))))))))
                 (top-k (cl-subseq sorted 0 (min k (length sorted))))
                 (final (cl-loop for (score . c) in top-k
                                 for i from 1
                                 collect (lisply-search--format-hit
                                          c score terms phrases i include-metadata max-chars))))
            (ignore explicit-mode)
            (list :query query
                  :search-mode :lexical
                  :match-mode match-mode
                  :match-fallback fallback
                  :terms (lisply-search--to-vector terms)
                  :phrases (lisply-search--to-vector phrases)
                  :sources (lisply-search--to-vector sources)
                  :total-candidates (length candidates)
                  :hits (lisply-search--to-vector final)
                  :warning (when warnings (string-join (nreverse warnings) "; "))
                  :known-sources (when unknown
                                   (lisply-search--to-vector all-sources))))))))))

;;;; ============================================================
;;;; HTTP Endpoint (when simple-httpd loaded)
;;;; ============================================================

(require 'simple-httpd nil t)
(require 'lisply-http-setup nil t)

(defun lisply-search--plist-to-alist (plist)
  "Convert PLIST to alist with string keys for JSON."
  (let (result)
    (while plist
      (let* ((key (pop plist))
             (val (pop plist))
             ;; Convert :keyword-name to "keyword_name" for JSON compatibility
             (str-key (let ((raw (if (keywordp key)
                                     (substring (symbol-name key) 1)
                                   (format "%s" key))))
                        (replace-regexp-in-string "-" "_" raw))))
        (push (cons str-key
                    (cond
                     ((and (listp val) (keywordp (car val)))
                      (lisply-search--plist-to-alist val))
                     ((vectorp val)
                      (vconcat (mapcar (lambda (v)
                                         (if (and (listp v) (keywordp (car v)))
                                             (lisply-search--plist-to-alist v)
                                           v))
                                       val)))
                     (t val)))
              result)))
    (nreverse result)))

(defun lisply-search--json-get (json-input &rest keys)
  "The value of the first of KEYS present in the parsed JSON alist JSON-INPUT."
  (cl-some (lambda (key) (cdr (assoc key json-input))) keys))

(defun lisply-search--serve-http-query (json-input)
  "Answer one lisply_search HTTP request whose parsed JSON body is JSON-INPUT."
  (let* ((query (and json-input (cdr (assoc 'query json-input)))))
    (if (not (and query (stringp query) (not (string-empty-p query))))
        (emacs-lisply-send-response '(("error" . "Missing required parameter: query")))
      (condition-case err
          (let* ((raw-match (lisply-search--json-get json-input 'match_mode 'match-mode))
                 (raw-any-max (lisply-search--json-get json-input 'any_max_candidates 'any-max-candidates))
                 (raw-filters (lisply-search--json-get json-input 'path_filters 'path-filters))
                 (raw-search-mode (lisply-search--json-get json-input 'search_mode 'search-mode))
                 (match-mode (cond
                              ((or (eq raw-match :all) (equal raw-match "all")) :all)
                              ((or (eq raw-match :any) (equal raw-match "any")) :any)
                              (t nil)))
                 (any-max-candidates (cond
                                      ((numberp raw-any-max) raw-any-max)
                                      ((and (stringp raw-any-max)
                                            (string-match-p "\\`[0-9]+\\'" raw-any-max))
                                       (string-to-number raw-any-max))
                                      (t nil)))
                 (path-filters (cond ((stringp raw-filters) (list raw-filters))
                                     (t (lisply-search--to-list raw-filters))))
                 (params (list :query query
                               :k (cdr (assoc 'k json-input))
                               :sources (cdr (assoc 'sources json-input))
                               :language (cdr (assoc 'language json-input))
                               :path-filters path-filters
                               :search-mode (and (stringp raw-search-mode) raw-search-mode)
                               :match-mode match-mode
                               :any-max-candidates any-max-candidates
                               :max-snippet-tokens (cdr (assoc 'max_snippet_tokens json-input))
                               :include-metadata (not (eq (cdr (assoc 'include_metadata json-input))
                                                          :json-false))))
                 (result (lisply-search params))
                 (json-result (lisply-search--plist-to-alist result)))
            (emacs-lisply-send-response json-result))
        (error
         (emacs-lisply-send-response
          `(("error" . ,(format "%s" err)))))))))

(when (featurep 'simple-httpd)
  (defservlet* lisply/lisply-search application/json ()
    "Handle the lisply_search endpoint."
    (lisply-search--serve-http-query
     (and (fboundp 'emacs-lisply-parse-json-body)
          (emacs-lisply-parse-json-body)))))

(provide 'lisply-search)
;;; lisply-search.el ends here
