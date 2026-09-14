;;; lisply-search-test.el --- Regression tests for lisply_search -*- lexical-binding: t; -*-

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;; Run:  emacs --batch -L . -l lisply-search.el -l lisply-search-test.el \
;;             -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'lisply-search)

(defun lisply-search-test--build-mock-index (file-count snippets-per-file)
  "Return a v4 index plist with FILE-COUNT files and SNIPPETS-PER-FILE snippets."
  (let (files)
    (dotimes (f file-count)
      (let ((snippets nil)
            (file (format "/tmp/example-%03d.lisp" f)))
        (dotimes (s snippets-per-file)
          (let* ((token (mod (+ (* f 31) s) 97))
                 (snippet (format "define-object wall-%d token-%d" f token)))
            (push (list :snippet snippet
                        :terms (list "define" "object" (format "wall-%d" f) (format "token-%d" token))
                        :start-line s
                        :end-line s)
                  snippets)))
        (push (list :path file
                    :source :test
                    :repo "test"
                    :repo-root "/tmp"
                    :snippets (nreverse snippets))
              files)))
    (list :version 4
          :files (nreverse files))))

(defun lisply-search-test--index-from-snippets (snippets)
  "Return an index whose single-snippet files carry SNIPPETS.
SNIPPETS is a list of (PATH TEXT); terms are extracted from TEXT."
  (list :version 4
        :files (mapcar (lambda (spec)
                         (list :path (car spec)
                               :source :test
                               :repo "test"
                               :repo-root "/tmp"
                               :snippets (list (list :snippet (cadr spec)
                                                     :terms (delete-dups (lisply-search--extract-terms (cadr spec)))
                                                     :start-line 0
                                                     :end-line 0))))
                       snippets)))

(defun lisply-search-test--with-mock-cache (index)
  "Return a cache plist using INDEX and a minimal config."
  (list :path "mock-index"
        :mtime nil
        :index index
        :config '(:sources ((:name "test"
                           :entries ((:root "/tmp"
                                      :repo "test"
                                      :repo-root "/tmp"))))
                  :extensions (:default (".lisp"))
                  :exclude-paths ())
        :snippet-map (lisply-search--build-snippet-map index)
        :snippet-count (lisply-search--count-snippets index)))

(defmacro lisply-search-test--with-index (index &rest body)
  "Run BODY with INDEX installed as the live cache."
  (declare (indent 1))
  `(let* ((lisply-search-index-path "mock-index")
          (lisply-search--cache (lisply-search-test--with-mock-cache ,index)))
     ,@body))

(defun lisply-search-test--paths (result)
  "The hit paths of RESULT in rank order."
  (mapcar (lambda (h) (plist-get h :path)) (append (plist-get result :hits) nil)))

(ert-deftest lisply-search-regression-accepts-metadata-and-extra-keys ()
  "Ensure extra keys are tolerated and metadata can be included."
  (lisply-search-test--with-index (lisply-search-test--build-mock-index 1 1)
    (let* ((result (lisply-search (list :query "define-object wall"
                                        :k 1
                                        :include-metadata t
                                        :repo "ignored")))
           (hits (plist-get result :hits)))
      (should (vectorp hits))
      (should (> (length hits) 0))
      (should (plist-get (aref hits 0) :metadata)))))

(ert-deftest lisply-search-regression-battery ()
  "Stress basic search with a small battery of queries."
  (lisply-search-test--with-index (lisply-search-test--build-mock-index 40 12)
    (let ((queries (append
                    (mapcar (lambda (n) (format "define-object wall-%d" n))
                            (number-sequence 0 39))
                    (mapcar (lambda (n) (format "token-%d" (mod n 97)))
                            (number-sequence 0 79))
                    '("define-object" "object wall" "token"))))
      (dolist (q queries)
        (let* ((result (lisply-search (list :query q :k 3 :include-metadata t)))
               (hits (plist-get result :hits)))
          (should (vectorp hits))
          (should (>= (length hits) 0))
          (when (> (length hits) 0)
            (should (plist-get (aref hits 0) :metadata))))))))

(ert-deftest lisply-search-regression-many-rebuilds ()
  "Rebuild the snippet map multiple times to exercise parsing."
  (dotimes (i 12)
    (lisply-search-test--with-index (lisply-search-test--build-mock-index 25 8)
      (let* ((query (format "define-object wall-%d token-%d" i (mod i 97)))
             (result (lisply-search (list :query query :k 2 :include-metadata nil)))
             (hits (plist-get result :hits)))
        (should (vectorp hits))
        (should (>= (length hits) 0))))))

;;;; Query parsing

(ert-deftest lisply-search-query-terms-drop-stopwords-and-keep-phrases ()
  "Stopwords go, hyphenated tokens survive as phrases, and an all-stopword
query keeps its words rather than matching nothing."
  (let ((parsed (lisply-search--query-terms
                 "how does a child object inherit input-slots from its parent")))
    (should (equal (car parsed) '("child" "object" "inherit" "input" "slots" "parent")))
    (should (equal (cdr parsed) '("input-slots"))))
  (should (equal (car (lisply-search--query-terms "the of")) '("the" "of"))))

(ert-deftest lisply-search-query-terms-underscore-note ()
  "Terms split on anything but [a-z0-9_]; a hyphen splits, so the phrase
list is what carries `hidden-objects' as a unit."
  (let ((parsed (lisply-search--query-terms "hidden-objects")))
    (should (equal (car parsed) '("hidden" "objects")))
    (should (equal (cdr parsed) '("hidden-objects")))))

;;;; Matching

(ert-deftest lisply-search-all-mode-falls-back-to-any ()
  "When no snippet holds every term, the search retries with any-term
matching and says so."
  (lisply-search-test--with-index
      (lisply-search-test--index-from-snippets
       '(("/tmp/a.lisp" "(define-object foo (base-object))")
         ("/tmp/b.lisp" "(define-object bar (base-object))")))
    (let ((result (lisply-search (list :query "foo bar" :k 5))))
      (should (eq (plist-get result :match-mode) :any))
      (should (plist-get result :match-fallback))
      (should (= (length (plist-get result :hits)) 2))
      (should (string-match-p "any-term" (plist-get result :warning))))
    ;; An explicit :any never reports a fallback.
    (let ((result (lisply-search (list :query "foo bar" :k 5 :match-mode :any))))
      (should-not (plist-get result :match-fallback)))
    ;; A single unknown term stays empty: nothing to fall back to.
    (let ((result (lisply-search (list :query "quux" :k 5))))
      (should (= (length (plist-get result :hits)) 0))
      (should-not (plist-get result :match-fallback)))))

(ert-deftest lisply-search-path-filters ()
  "path_filters narrow hits by repo-relative prefix or glob."
  (lisply-search-test--with-index (lisply-search-test--build-mock-index 40 2)
    (let* ((glob (lisply-search (list :query "define-object" :k 100
                                      :path-filters '("example-00*"))))
           (prefix (lisply-search (list :query "define-object" :k 100
                                        :path-filters '("example-01"))))
           (none (lisply-search (list :query "define-object" :k 100
                                      :path-filters '("nothing/here")))))
      (should (> (length (plist-get glob :hits)) 0))
      (should (cl-every (lambda (p) (string-prefix-p "example-00" p))
                        (lisply-search-test--paths glob)))
      (should (cl-every (lambda (p) (string-prefix-p "example-01" p))
                        (lisply-search-test--paths prefix)))
      (should (= (length (plist-get none :hits)) 0)))))

(ert-deftest lisply-search-search-mode-warns-when-not-lexical ()
  "Any search_mode but lexical is answered lexically with a warning."
  (lisply-search-test--with-index (lisply-search-test--build-mock-index 2 1)
    (let ((result (lisply-search (list :query "define-object" :search-mode "semantic"))))
      (should (eq (plist-get result :search-mode) :lexical))
      (should (string-match-p "semantic" (plist-get result :warning))))
    (should-not (plist-get (lisply-search (list :query "define-object" :search-mode "lexical"))
                           :warning))))

;;;; Ranking

(ert-deftest lisply-search-phrase-hit-outranks-split-words ()
  "A snippet carrying the hyphenated query token verbatim beats one that
merely holds both halves."
  (lisply-search-test--with-index
      (lisply-search-test--index-from-snippets
       '(("/tmp/split.lisp" "the hidden objects of the assembly are objects too")
         ("/tmp/verbatim.lisp" ":hidden-objects ((box :type 'box))")))
    (should (equal (lisply-search-test--paths (lisply-search (list :query "hidden-objects" :k 2)))
                   '("verbatim.lisp" "split.lisp")))))

(ert-deftest lisply-search-definition-outranks-mentions ()
  "The snippet that DEFINES the queried name ranks above snippets that
only mention it, however often."
  (lisply-search-test--with-index
      (lisply-search-test--index-from-snippets
       '(("/tmp/uses.lisp" "(the wall) (the wall height) wall wall wall")
         ("/tmp/defines.lisp" "(define-object wall (base-object) :input-slots (height))")))
    (should (equal (car (lisply-search-test--paths (lisply-search (list :query "wall" :k 2))))
                   "defines.lisp"))))

(ert-deftest lisply-search-rare-terms-weigh-more ()
  "Coverage is IDF-weighted: matching the rare term counts for more than
matching the common one."
  (lisply-search-test--with-index
      (lisply-search-test--index-from-snippets
       '(("/tmp/c1.lisp" "common alpha")
         ("/tmp/c2.lisp" "common beta")
         ("/tmp/c3.lisp" "common gamma")
         ("/tmp/c4.lisp" "common delta")
         ("/tmp/rare.lisp" "rareword epsilon")))
    (let ((paths (lisply-search-test--paths
                  (lisply-search (list :query "common rareword" :k 5 :match-mode :any)))))
      (should (equal (car paths) "rare.lisp")))))

(ert-deftest lisply-search-excerpt-centres-on-the-match ()
  "A long snippet is excerpted from just above the first matching line,
and the preview is that line."
  (let* ((header (mapconcat (lambda (i) (format ";; licence line %d" i)) (number-sequence 1 20) "\n"))
         (text (concat header "\n(define-object needle (base-object))\n;; trailing")))
    (lisply-search-test--with-index
        (lisply-search-test--index-from-snippets (list (list "/tmp/long.lisp" text)))
      (let* ((result (lisply-search (list :query "needle" :k 1 :max-snippet-tokens 20)))
             (hit (aref (plist-get result :hits) 0)))
        (should (= (plist-get hit :match-line) 21))
        (should (= (plist-get hit :excerpt-start-line) 19))
        (should (string-prefix-p ";; licence line 19" (plist-get hit :snippet)))
        (should (string-match-p "define-object needle" (plist-get hit :preview)))))))

;;;; Chunking

(ert-deftest lisply-search-chunks-begin-at-forms ()
  "Lisp files chunk at top-level forms: a licence header stands alone,
small forms pack together, an oversized form is windowed."
  (let* ((header (mapcar (lambda (i) (format ";; header %d" i)) (number-sequence 1 10)))
         (form-a '("(defun a ()" "  1)" ""))
         (form-b '("(defun b ()" "  2)" ""))
         (big (cons "(define-object big (base-object)" (mapcar (lambda (i) (format "  :slot-%d 1" i)) (number-sequence 1 30))))
         (lines (append header form-a form-b big))
         (boundaries (lisply-search--chunk-boundaries lines :lisp ".lisp"))
         (chunks (lisply-search--extract-snippets lines 12 1200 boundaries)))
    (should (equal boundaries '(10 13 16)))
    (should (equal (mapcar (lambda (c) (cons (plist-get c :start) (plist-get c :end))) chunks)
                   '((0 . 9) (10 . 15) (16 . 27) (28 . 39) (40 . 46))))
    ;; Every line lands in exactly one chunk.
    (should (= (apply #'+ (mapcar (lambda (c) (length (plist-get c :lines))) chunks))
               (length lines)))))

(ert-deftest lisply-search-chunks-markdown-at-headings ()
  "Markdown chunks at headings; a short preamble merges with the first section."
  (let* ((lines '("intro" "" "# One" "a" "b" "# Two" "c"))
         (boundaries (lisply-search--chunk-boundaries lines :markdown ".md"))
         (chunks (lisply-search--extract-snippets lines 6 1200 boundaries)))
    (should (equal boundaries '(2 5)))
    (should (equal (mapcar (lambda (c) (cons (plist-get c :start) (plist-get c :end))) chunks)
                   '((0 . 4) (5 . 6))))))

(ert-deftest lisply-search-fixed-windows-lose-no-lines ()
  "A window cut short by the character budget hands the leftover lines
to the next window instead of dropping them (the pre-v4 behaviour)."
  (let* ((lines (mapcar (lambda (i) (concat (format "%d:" i) (make-string 500 ?x))) (number-sequence 0 4)))
         (chunks (lisply-search--extract-snippets lines 24 1200)))
    (should (equal (mapcar (lambda (c) (cons (plist-get c :start) (plist-get c :end))) chunks)
                   '((0 . 1) (2 . 3) (4 . 4))))))

(ert-deftest lisply-search-snippets-are-capped-by-chars ()
  "A line longer than the character budget -- a minified asset -- is
stored truncated to the budget; the cap holds whatever the line count
(2026-09-14: a 15 KB one-line v4-shims.min.css topped a ranking)."
  (let ((file (make-temp-file "lisply-search-min" nil ".css")))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert (make-string 15000 ?x) "\n" ".a{color:red}\n"))
          (let ((snippets (lisply-search--extract-file-snippets file 24 1200)))
            (should (> (length snippets) 0))
            (should (cl-every (lambda (s) (<= (length (plist-get s :snippet)) 1200))
                              snippets))
            (should (cl-every (lambda (s) (<= (length (plist-get s :preview)) 1200))
                              snippets))))
      (delete-file file))))

(ert-deftest lisply-search-index-round-trips-non-ascii ()
  "An index written and read back keeps its strings multibyte, so a
snippet's length is its character count and © survives the trip
(2026-09-14: a locale-less batch build and daemon read the index as
raw bytes)."
  (let ((file (make-temp-file "lisply-search-index" nil ".sexp"))
        (text "©  ▓▓▓  (define-object naïve-box (box))"))
    (unwind-protect
        (let ((coding-system-for-read nil) (coding-system-for-write nil))
          (lisply-search--write-sexp-file
           (list :version 4 :files (list (list :path "/tmp/x.lisp" :snippets (list (list :snippet text)))))
           file)
          (let* ((back (lisply-search--read-sexp-file file))
                 (snippet (plist-get (car (plist-get (car (plist-get back :files)) :snippets)) :snippet)))
            (should (multibyte-string-p snippet))
            (should (equal snippet text))
            (should (= (length snippet) (length text)))))
      (delete-file file))))

(ert-deftest lisply-search-distribution-keeps-internal-sources-out ()
  "A :public build carries only sources marked :public (the default);
an :all build carries everything; a build that does not say is public."
  (let* ((config '(:sources ((:name "open" :entries ((:root "/tmp/open" :repo "open" :repo-root "/tmp/open")))
                             (:name "shop" :distribution :internal
                              :entries ((:root "/tmp/shop" :repo "shop" :repo-root "/tmp/shop"))))))
         (sources (lisply-search--config-sources config))
         (names (lambda (l) (mapcar (lambda (s) (plist-get s :name)) l))))
    (should (equal (mapcar (lambda (s) (plist-get s :distribution)) sources) '(:public :internal)))
    (should (equal (funcall names (lisply-search--sources-for-distribution sources :public)) '(:open)))
    (should (equal (funcall names (lisply-search--sources-for-distribution sources :all)) '(:open :shop)))
    (should (equal (funcall names (lisply-search--sources-for-distribution sources nil)) '(:open)))))

(ert-deftest lisply-search-subdirs-restrict-the-scan-and-the-checkout ()
  "With :subdirs, only those directories under the root are indexed, and
they double as the sparse checkout list (prefixed by the root's place
in the repository when the root is not the repository)."
  (let* ((root (make-temp-file "lisply-search-subdirs" t)))
    (unwind-protect
        (progn
          (dolist (d '("live" "stale"))
            (make-directory (expand-file-name d root))
            (with-temp-file (expand-file-name (concat d "/x.lisp") root)
              (insert "(define-object x ())\n")))
          (let* ((config `(:sources ((:name "t" :entries ((:root ,root :repo "t" :repo-root ,root
                                                          :subdirs ("live")))))))
                 (source (car (lisply-search--config-sources config)))
                 (files (lisply-search--source-files source '(".lisp") '(".git") nil)))
            (should (equal (plist-get source :sparse) '("live")))
            (should (= (length files) 1))
            (should (string-suffix-p "/live/x.lisp" (car files))))
          (let* ((config `(:sources ((:name "t" :entries ((:root ,(expand-file-name "sub" root) :repo "t"
                                                          :repo-root ,root :subdirs ("a" "b")))))))
                 (source (car (lisply-search--config-sources config))))
            (should (equal (plist-get source :sparse) '("sub/a" "sub/b")))))
      (delete-directory root t))))

(ert-deftest lisply-search-shipped-config-is-distributable ()
  "Every source in the shipped config is public, and the demos source
names the live demos only (2026-09-14 ruling: the stale ones stay out
of any public corpus until they are brought up to date)."
  (let* ((config-file (expand-file-name
                       "../lisply-search-config.sexp"
                       (file-name-directory (or (locate-library "lisply-search")
                                                load-file-name
                                                buffer-file-name))))
         (config (plist-get (lisply-search--read-sexp-file config-file) :lisply-search-config))
         (sources (lisply-search--config-sources config))
         (demos (cl-find :demos sources :key (lambda (s) (plist-get s :name)))))
    (should (cl-every (lambda (s) (eq (plist-get s :distribution) :public)) sources))
    (should demos)
    (should (equal (plist-get demos :subdirs)
                   '("demos-common" "gear" "naca-nurbs" "staircase" "robot" "bus" "brick-wall")))
    (should (equal (plist-get demos :sparse) (plist-get demos :subdirs)))))

(ert-deftest lisply-search-exclude-patterns-drop-minified-and-vendored ()
  "The shipped config keeps minified assets and vendored static trees
out of the index, and `**/*.min.css' does not reach an ordinary
stylesheet."
  (let* ((config-file (expand-file-name
                       "../lisply-search-config.sexp"
                       (file-name-directory (or (locate-library "lisply-search")
                                                load-file-name
                                                buffer-file-name))))
         (config (plist-get (lisply-search--read-sexp-file config-file)
                            :lisply-search-config))
         (excludes (lisply-search--config-exclude-paths config)))
    (should (member "**/*.min.css" excludes))
    (should (member "**/*.min.js" excludes))
    (should (member "**/3rdpty/**" excludes))
    (dolist (path '("/projects/gw/gendl/gwl/static/3rdpty/fa/css/v4-shims.min.css"
                    "/projects/gw/gendl/gwl/static/3rdpty/x_ite/x_ite.js"
                    "/projects/gw/demos/gorg/static/js/jquery-1.8.3.min.js"
                    "/projects/gw/demos/timer/static/plugins/hideseek/demo/index.html"))
      (should (lisply-search--path-excluded-p path excludes)))
    (dolist (path '("/projects/gw/gendl/gwl/static/gwl/style.css"
                    "/projects/gw/gendl/gwl/static/gwl/gdlajax.js"
                    "/projects/gw/demos/demos-common/source/cad-export.lisp"))
      (should-not (lisply-search--path-excluded-p path excludes)))))

(provide 'lisply-search-test)
;;; lisply-search-test.el ends here
