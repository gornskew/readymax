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
;;;   :subdirs   the directories under :root that make up the corpus: the
;;;              scan stays inside them, and they are the sparse checkout
;;;              when no :sparse is given
;;;   :branch    overrides the build's branch for that clone (optional)
;;;
;;; Each source (the level above the entries) may say :distribution
;;; :public (the default) or :internal.  THE INDEX SHIPS INSIDE A PUBLIC
;;; DOCKER HUB IMAGE: an image build indexes the :public sources only,
;;; whatever credentials it holds, and an :internal source is for a
;;; console working from a /projects mount (docker/build and the
;;; Dockerfile pass :public; LISPLY_INDEX_DISTRIBUTION=all or
;;; `lisply-search-build-index' by hand indexes everything present).
;;; The rule, 2026-09-14: the training material is public, the rest of
;;; the private apps repository (invoicing, letterheads, the sites) is
;;; not, and no distributed index may reflect an internal app.
;;;
;;; WHAT THIS FILE BAKES IS THE CONSOLE'S OWN CORPUS AND ONE FALLBACK.
;;; Since 2026-09-14 the corpora of the other projects travel with those
;;; projects (lisply-mcp CORPUS.md): a species image carries its own
;;; corpus file under the `lisply.corpus' label, the yard copies the
;;; files out of the images aboard into the ready room's corpora
;;; directory (LISPLY_SEARCH_CORPORA), and the console merges them,
;;; a corpus there replacing a same-named source here.  So this file
;;; names readymax itself and a gendl FALLBACK for standalone use (the
;;; lifepod, the space suit), nothing else; aboard a ship the Gendl
;;; corpus comes from the Gendl actually flying.  The demos and the
;;; training material are mount corpora the ship builds itself.

(:lisply-search-config
 (:index-path "~/.emacs.d/sideloaded/lisply-backend/lisply-search-index.sexp"
  :preextract-snippets t
  :preextract-max-lines 24
  :preextract-max-chars 1200
  :sources ((:name "gendl"
             :distribution :public
             :entries ((:root "gendl"
                        :repo "gendl"
                        :repo-url "https://gitlab.common-lisp.net/gendl/gendl"
                        :repo-root "gendl")))
            (:name "readymax"
             :distribution :public
             :entries ((:root "readymax"
                        :repo "readymax"
                        :repo-url "https://github.com/gornskew/readymax"
                        :repo-root "readymax"))))
            ;; Retired from this file 2026-09-14, now corpora of their
            ;; own (CORPUS.md): the Genworks training material
            ;; (gw/apps/genworks-learn, public at genworks.dev) and the
            ;; live demos (gw/demos: demos-common, gear, naca-nurbs,
            ;; staircase, robot, bus, brick-wall; the older applications
            ;; there stay out until brought up to date) are built by the
            ;; ship from its /projects mount into the corpora directory.
            ;; No private repository is cloned to build this image.

  :ignore-dirs (".git" "node_modules" "dist" "build" "vendor" "target" ".cache" "logs" "tmp" "docker")

  ;; Globs match the absolute path (`*' crosses directories in Emacs
  ;; wildcards, so `**' is spelled for the reader).  Minified assets and
  ;; vendored static trees stay out (2026-09-14): a 15 KB one-line
  ;; v4-shims.min.css under gwl/static/3rdpty topped the ranking for
  ;; "involute gear export" with nothing readable in it, and nothing in
  ;; a vendored jquery, x_ite or font-awesome tree is ours to search.
  :exclude-paths ("**/elpa/**"
                  "**/*.min.js" "**/*.min.css"
                  "**/3rdpty/**" "**/static/plugins/**")
  :extensions (:default (".lisp" ".lsp" ".cl" ".gdl" ".gendl" ".asd" ".isc"
				 ".md" ".markdown" ".org" ".txt" ".rst"
				 ".el" ".js" ".ts" ".json" ".yml" ".yaml" ".html" ".css")
               :lisp (".lisp" ".lsp" ".cl" ".asd" ".el")
               :gendl (".gendl")
               :gdl (".gdl" ".gendl" ".lisp" ".lsp" ".cl")
               :markdown (".md" ".markdown" ".org" ".rst"))))
