;;; services.sexp - Single Source of Truth for skewed-emacs stack
;;; -*- mode: lisp-data; -*-
;;;
;;; This file defines the base services for the stack.
;;; Edit this file, then run (skewed-generate-all-configs) to regenerate:
;;;
;;;   - docker-compose.yml         (base compose config)
;;;   - mcp/mcp-container.json     (for claude/gemini/grok CLI inside container)
;;;   - mcp/mcp-windows.json       (for Claude Desktop on Windows via WSL)
;;;   - mcp/mcp.toml               (for Codex CLI)
;;;   - dot-files/emacs.d/etc/services-generated.el
;;;
;;; For overlays (e.g., betatest or commercial images):
;;;   - Create a separate services.sexp for the overlay
;;;   - Generate with prefix: (skewed-generate-configs "overlay.sexp" dir "betatest-")
;;;   - This produces betatest-compose.yml, betatest-mcp-container.json, etc.
;;;   - Docker Compose merges automatically (compose-dev picks up all .yml files)
;;;   - MCP configs merge via: mcp/merge-mcp-configs.sh
;;;
;;; DO NOT EDIT the generated files directly.

;;; BUILD VARIANTS
;;; ==============
;;; The skewed-emacs image supports build variants:
;;;
;;;   full  - Complete installation including TUI LLM CLIs (claude, codex, gemini)
;;;           Best for: Emacs power users, developers who use terminal-based AI tools
;;;
;;;   lite  - Core Emacs + MCP services only, no TUI LLM CLIs
;;;           Best for: Claude Desktop users, MCP-only workflows, smaller image size
;;;
;;; Image tag format: {branch}-{variant}
;;;   Examples: devo-full, devo-lite, master-full, master-lite
;;;
;;; To use lite variant, set EMACS_IMAGE_VARIANT=lite in your environment
;;; or in .env file before running compose-dev.
;;;
;;; The MCP configuration is identical for both variants - only the
;;; docker-compose.yml image tag changes based on variant.


(
 :meta
 (:version "2.0"
  :description "Skewed Emacs + Gendl development stack")

 :defaults
 (:network "skewed-network"
  :restart "unless-stopped"
  :volumes ((:source "${PROJECTS_DIR}" :target "/projects"))
  :timezone "${TZ:-Etc/UTC}"
  :network-ipv6 t
  :network-ipv4-subnet "172.20.0.0/16"
  :network-ipv6-subnet "fd00:cafe::/80")

 :mcp
 (:wrapper-path-container "/home/emacs-user/lisply-mcp/scripts/mcp-wrapper.js"
  :request-timeout-ms 30000)
 ;; :exec-path-wsl removed - now derived from SKEWED_CLONE_PATH env var at merge time

 :skewed-search-config
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
               :markdown (".md" ".markdown" ".org" ".rst")))

 :services
 (
  (:name "skewed-emacs"
   :type "emacs-lisp"
   :lisp-impl "Emacs"
   :mcp t
   :image "gornskew/${EMACS_IMAGE_BASE:-skewed-emacs}:${EMACS_IMAGE_BRANCH:-devo}-${EMACS_IMAGE_VARIANT:-full}"
   :ports ((:name "http" :container 7080)
           (:name "webterm" :container 6942 :host 6942 :external t))
   :environment (("WEBTERM" . "${WEBTERM:-ttyd}")
                 ("WEBTERM_PORT" . "6942")
                 ("TERM" . "xterm-256color")
                 ("COLORTERM" . "truecolor"))
   :volumes ((:source "${USER_HOME}/.claude/.credentials.json"
              :target "/home/emacs-user/.claude/.credentials.json")
             (:source "${USER_HOME}/.gemini/google_accounts.json"
              :target "/home/emacs-user/.gemini/google_accounts.json")
             (:source "${USER_HOME}/.gemini/oauth_creds.json"
              :target "/home/emacs-user/.gemini/oauth_creds.json")
             (:source "${USER_HOME}/.codex/auth.json"
              :target "/home/emacs-user/.codex/auth.json")
             (:source "${USER_HOME}/.grok/user-settings.json"
              :target "/home/emacs-user/.grok/user-settings.json")
             (:source "/tmp/.X11-unix" :target "/tmp/.X11-unix" :mode "rw")
             (:source "${EMACS_LOCAL_SRC:-/nonexistent}/.emacs-local"
              :target "/home/emacs-user/.emacs-local" :mode "ro")
             (:source "${EMACS_LOCAL_SRC:-/nonexistent}/.emacs-local-early"
              :target "/home/emacs-user/.emacs-local-early" :mode "ro"))

   :healthcheck (:endpoint "/lisply/ping-lisp" :interval "108s"))

  (:name "gendl-ccl"
   :type "common-lisp"
   :lisp-impl "CCL"
   :image "genworks/${GENDL_IMAGE_BASE:-gendl}:${GENDL_IMAGE_BRANCH:-devo}-ccl"
   :ports ((:name "http" :host 19080 :container 9080)
           (:name "swank" :container 4200))
   :user "root"
   ;;:environment (("HTTP_HOST" . "::"))
   :mcp t
   :healthcheck (:endpoint "/lisply/ping-lisp" :interval "72s"))

  (:name "gendl-sbcl"
   :type "common-lisp"
   :lisp-impl "SBCL"
   :image "genworks/${GENDL_IMAGE_BASE:-gendl}:${GENDL_IMAGE_BRANCH:-devo}-sbcl"
   :ports ((:name "http" :host 29080 :container 9090)
           (:name "swank" :container 4210))
   :user "root"
   ;;:environment (("HTTP_HOST" . "::"))
   :mcp t
   :healthcheck (:endpoint "/lisply/ping-lisp" :interval "90s"))
  )
 )
