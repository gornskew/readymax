;;; lisply-search-config.sexp - corpus configuration for lisply_search
;;; -*- mode: lisp-data; -*-
;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;;
;;; Consumed by lisply-search.el (`lisply-search-services-path').
;;;
;;; This lived inside the stack's services.sexp until 2026-08-15, purely
;;; because that file was the only single-source-of-truth around.  It never
;;; belonged there: nothing in the stack generator ever read it, and its
;;; only consumer has always been lisply-search.el, which ships here.
;;; Renamed 2026-09-09 together with the tool (skewed_search ->
;;; lisply_search); the old file name and top-level key stopped being read
;;; on 2026-09-10.
;;;
;;; Each source entry:
;;;   :root      where the corpus lives, relative to /projects (the host
;;;              mount in dev; cloned into the image at build time)
;;;   :repo-url  cloned when :root is missing -- so a private repository
;;;              needs a credential at build time (docker/build
;;;              CORPUS_NETRC); without one that corpus is skipped and the
;;;              build logs SOURCE MISSING
;;;   :repo-root the repository's own directory when the corpus is only a
;;;              subdirectory of it (the clone lands here; hits are
;;;              reported relative to it)
;;;   :sparse    subdirectories to check out when the corpus is a small
;;;              part of a large repository
;;;   :branch    overrides the build's branch for that clone (optional)

(:lisply-search-config
 (:index-path "~/.emacs.d/sideloaded/lisply-backend/lisply-search-index.sexp"
  :preextract-snippets t
  :preextract-max-lines 24
  :preextract-max-chars 1200
  :sources ((:name "gendl"
             :entries ((:root "gendl"
                        :repo "gendl"
                        :repo-url "https://gitlab.common-lisp.net/gendl/gendl"
                        :repo-root "gendl")))
            (:name "readymax"
             :entries ((:root "readymax"
                        :repo "readymax"
                        :repo-url "https://github.com/gornskew/readymax"
                        :repo-root "readymax")))
            ;; The Genworks training material -- the successor of the
            ;; retired github.com/gornskew/training corpus, whose
            ;; disappearance (2026-08-20) left every console image without
            ;; an index until 2026-09-09.  It is one directory of the
            ;; PRIVATE genworks/apps repository: fetched as a sparse
            ;; checkout when the build has a credential, skipped otherwise.
            (:name "genworks-learn"
             :entries ((:root "gw/apps/genworks-learn"
                        :repo "apps"
                        :repo-url "https://gitlab.genworks.com/genworks/apps.git"
                        :repo-root "gw/apps"
                        :sparse ("genworks-learn")))))

  :ignore-dirs (".git" "node_modules" "dist" "build" "vendor" "target" ".cache" "logs" "tmp" "docker")

  :exclude-paths ("**/elpa/**" )
  :extensions (:default (".lisp" ".lsp" ".cl" ".gdl" ".gendl" ".asd" ".isc"
				 ".md" ".markdown" ".org" ".txt" ".rst"
				 ".el" ".js" ".ts" ".json" ".yml" ".yaml" ".html" ".css")
               :lisp (".lisp" ".lsp" ".cl" ".asd" ".el")
               :gendl (".gendl")
               :gdl (".gdl" ".gendl" ".lisp" ".lsp" ".cl")
               :markdown (".md" ".markdown" ".org" ".rst"))))
