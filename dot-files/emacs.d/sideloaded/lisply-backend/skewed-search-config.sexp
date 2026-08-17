;;; skewed-search-config.sexp - corpus configuration for skewed_search
;;; -*- mode: lisp-data; -*-
;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

;;;
;;; Consumed by lisply-search.el (`lisply-search-search-config-path').
;;;
;;; This lived inside the stack's services.sexp until 2026-08-15, purely
;;; because that file was the only single-source-of-truth around.  It never
;;; belonged there: nothing in the stack generator ever read it, and its
;;; only consumer has always been lisply-search.el, which ships here.  When
;;; the stack machinery moved out to the Basilisk repo it would have left
;;; this behind as the one key the yard carried on the Captain's behalf --
;;; and it broke the image build, because the Dockerfile was still reaching
;;; into services.sexp for it after that file was gone.
;;;
;;; The top-level shape is still a plist with a :skewed-search-config key,
;;; so the reader in lisply-search.el is unchanged.

(:skewed-search-config
 (:index-path "~/.emacs.d/sideloaded/lisply-backend/skewed-search-index.sexp"
  :preextract-snippets t
  :preextract-max-lines 24
  :preextract-max-chars 1200
  :sources ((:name "gendl"
             :entries ((:root "gendl"
                        :repo "gendl"
                        :repo-url "https://gitlab.common-lisp.net/gendl/gendl"
                        :repo-root "gendl")))
            (:name "skewed-emacs"
             :entries ((:root "skewed-emacs"
                        :repo "skewed-emacs"
                        :repo-url "https://github.com/gornskew/skewed-emacs"
                        :repo-root "skewed-emacs")))

	    (:name "training"
             :entries ((:root "training"
                        :repo "training"
                        :repo-url "https://github.com/gornskew/training"
                        :repo-root "training")
                       )))

  :ignore-dirs (".git" "node_modules" "dist" "build" "vendor" "target" ".cache" "logs" "tmp" "docker")

  :exclude-paths ("**/elpa/**" )
  :extensions (:default (".lisp" ".lsp" ".cl" ".gdl" ".gendl" ".asd" ".isc"
				 ".md" ".markdown" ".org" ".txt" ".rst"
				 ".el" ".js" ".ts" ".json" ".yml" ".yaml" ".html" ".css")
               :lisp (".lisp" ".lsp" ".cl" ".asd" ".el")
               :gendl (".gendl")
               :gdl (".gdl" ".gendl" ".lisp" ".lsp" ".cl")
               :markdown (".md" ".markdown" ".org" ".rst"))))
