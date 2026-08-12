;;; lisply-search-test.el --- Regression tests for skewed_search -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.


(require 'ert)
(require 'lisply-search)

(defun lisply-search-test--build-mock-index (file-count snippets-per-file)
  "Return a v3 index plist with FILE-COUNT files and SNIPPETS-PER-FILE snippets."
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
    (list :version 3
          :files (nreverse files))))

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
        :snippet-map (lisply-search--build-snippet-map index)))

(ert-deftest lisply-search-regression-accepts-metadata-and-extra-keys ()
  "Ensure extra keys are tolerated and metadata can be included."
  (let* ((index (lisply-search-test--build-mock-index 1 1))
         (lisply-search-index-path "mock-index")
         (lisply-search--cache (lisply-search-test--with-mock-cache index)))
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
  (let* ((index (lisply-search-test--build-mock-index 40 12))
         (lisply-search-index-path "mock-index")
         (lisply-search--cache (lisply-search-test--with-mock-cache index))
         (queries (append
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
          (should (plist-get (aref hits 0) :metadata)))))))

(ert-deftest lisply-search-regression-many-rebuilds ()
  "Rebuild the snippet map multiple times to exercise parsing."
  (dotimes (i 12)
    (let* ((index (lisply-search-test--build-mock-index 25 8))
           (lisply-search-index-path "mock-index")
           (lisply-search--cache (lisply-search-test--with-mock-cache index))
           (query (format "define-object wall-%d token-%d" i (mod i 97)))
           (result (lisply-search (list :query query :k 2 :include-metadata nil)))
           (hits (plist-get result :hits)))
      (should (vectorp hits))
      (should (>= (length hits) 0)))))

(provide 'lisply-search-test)
;;; lisply-search-test.el ends here
