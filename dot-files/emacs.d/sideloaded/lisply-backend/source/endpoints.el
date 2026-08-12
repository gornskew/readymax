;;; lisply-endpoints.el --- Lisply protocol endpoints for Emacs integration

;; Copyright © 2026 Gornskew Enterprises
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.  Distributed WITHOUT
;; ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'simple-httpd)
(require 'lisply-http-setup)
(require 'lisply-search)
(require 'lisply-shell-guard)

;; Resolve skewed-emacs root from the real path of ~/.emacs.d.
(defun emacs-lisply--skewed-root ()
  (file-name-as-directory
   (expand-file-name "../.." (file-truename user-emacs-directory))))

;; Lisply Tool Definitions

(defvar emacs-lisply-tools nil
  "List of tool definitions for the Emacs Lisply server.")

(setq emacs-lisply-tools
  (vector
   ;; ping_lisp tool (generic name)
   `(("name" . "ping_lisp")
     ("description" . "Check if the Lisp server is pingable")
     ("inputSchema" . (("type" . "object")
                       ("properties" . ,(make-hash-table))
                       ("required" . []))))

   ;; lisp_eval tool (generic name for consistent with Gendl)
   `(("name" . "lisp_eval")
     ("description" . "Evaluate Emacs Lisp code")
     ("inputSchema" . (("type" . "object")
                       ("properties" . (("code" . (("type" . "string")
                                                 ("description" . "The Emacs Lisp code to evaluate")))
                                       ("package" . (("type" . "string")
                                                   ("description" . "Not used in Emacs Lisp but kept for protocol compatibility")))))
                       ("required" . ["code"]))))

   ;; skewed_search tool
   `(("name" . "skewed_search")
     ("description" . "Unified search over GDL/Gendl/skewed-emacs / related docs & code")
     ("inputSchema" . (("type" . "object")
                       ("properties" . (("query" . (("type" . "string")
                                                   ("description" . "Natural-language or keyword query")))
                                       ("k" . (("type" . "integer")
                                               ("description" . "Max number of hits to return (default 8)")))
                                       ("sources" . (("type" . "array")
                                                     ("items" . (("type" . "string")))
                                                     ("description" . "Logical sources to restrict search")))
                                       ("path_filters" . (("type" . "array")
                                                          ("items" . (("type" . "string")))
                                                          ("description" . "Prefix or glob-style path filters")))
                                       ("language" . (("type" . "string")
                                                     ("description" . "Language hint, e.g. lisp, gdl, gendl, markdown")))
                                       ("search_mode" . (("type" . "string")
                                                        ("description" . "lexical, semantic, or hybrid (default lexical)")))
                                       ("max_snippet_tokens" . (("type" . "integer")
                                                                ("description" . "Soft cap for snippet length")))
                                       ("include_metadata" . (("type" . "boolean")
                                                              ("description" . "Include metadata in hits (default true)")))))
                       ("required" . ["query"]))))


   ;;
   ;; FLAG -- http_request is implemented in middleware, not in this backend.
   ;;
   
   
   ))

(defun emacs-lisply-generate-tool-description ()
  "Generate a tool description for LLM integration."
  `(("tools" . ,emacs-lisply-tools)))

;; Lisply HTTP handlers

(defservlet* lisply/ping-lisp text/plain ()
  "Handle generic ping-lisp endpoint for Lisply."
  (emacs-lisply-log "Handling ping-lisp request")
  (insert "pong"))

;; Note: The defservlet* macro already constructs paths using emacs-lisply-endpoint-prefix
;; for prefix "lisply/" but we keep the variables for documentation and API alignment

(defservlet* lisply/resources/list application/json ()
  "Handle resources/list endpoint for Lisply."
  (emacs-lisply-log "Handling tools/resources request")
  (emacs-lisply-send-response nil)) ;; no resources for you yet.

(defservlet* lisply/prompts/list application/json ()
  "Handle prompts/list endpoint for Lisply."
  (emacs-lisply-log "Handling prompts/resources request")
  (emacs-lisply-send-response nil)) ;; no prompts for you yet.

(defservlet* lisply/tools/list application/json ()
  "Handle tools tools/list endpoint for Lisply."
  (emacs-lisply-log "Handling tools/list request")
  (emacs-lisply-send-response (emacs-lisply-generate-tool-description)))

(defservlet* lisply/lisp-eval application/json ()
  "Handle Emacs Lisp evaluation endpoint for Lisply."
  ;; This endpoint aligns with emacs-lisply-endpoint-prefix + emacs-lisply-eval-endpoint
  (emacs-lisply-log "Handling lisp-eval request")
  (let* ((json-input (emacs-lisply-parse-json-body))
         (code (and json-input (cdr (assoc 'code json-input))))
         (stdout-string "")
         (result nil)
         (error nil)
         (success nil))
    
    (emacs-lisply-log "Attempting to evaluate code: %s"
		      (or code "nil"))
    
    (cond
     ((null json-input)
      (setq error "Malformed or missing input. This endpoint needs a JSON object with {code: <elisp-expression>}.")
      (setq success nil))

     ((null code)
      (setq error "Missing required 'code' parameter")
      (setq success nil))

     ((and (fboundp 'lisply-payload-lint) (lisply-payload-lint code))
      ;; Refusal delivered as a *successful* result: the claude.ai
      ;; relay flattens success:nil to a bare "Tool execution failed",
      ;; hiding the steering message (see future.org: surface read/eval
      ;; errors as structured error results).
      (setq result (concat "LISPLY-GUARD REFUSED: " (lisply-payload-lint code)))
      (setq success t))

     (t
      (emacs-lisply-log
       "About to evaluate apparently valid code..")
      
      (condition-case err
          (progn
            (setq stdout-string
                  (with-temp-buffer
                    (let ((standard-output (current-buffer)))
                      (setq result (eval (read code)))
                      (buffer-string))))
            (setq success t))
        (error
         (setq error (format "%s" err))
         (setq success nil)))))

    
    (emacs-lisply-log
       "About to send response with result.. %S" (or result "nil"))

    (let ((response `(("success" . ,success)
		      ("result" . ,(format "%s" (or result "")))
		      ("stdout" . ,stdout-string)
		      ,@(when error `(("error" . ,error))))))

      (emacs-lisply-log "About to send lisply response %S"
			response)
    
      ;; Send as formatted string instead of JSON for testing
      (emacs-lisply-send-response  response))))

(defservlet* lisply/specs application/json ()
  "Handle suggested specs endpoint for MCP client configuration."
  (emacs-lisply-log "Handling specs request")
  (let ((local-endpoint (format "http://127.0.0.1:%d/lisply" emacs-lisply-port)))
    (insert (format "
{
  \"tools\": {
    \"emacs\": {
      \"url\": \"%s\"
    }
  }
}
" local-endpoint))))

;; Documentation endpoints

(defservlet* lisply/docs/list application/json ()
  "Handle docs/list endpoint for Lisply."
  (emacs-lisply-log "Handling docs/list request")
  (let* ((root (emacs-lisply--skewed-root))
         (claude-path (expand-file-name "dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md" root))
         (main-path (expand-file-name "CLAUDE.md" root))
         (docs-list
          `(("docs" . [
             (("id" . "claude-md")
              ("description" . "Skewed Emacs backend API and HTTP service documentation")
              ("path" . ,claude-path))
             (("id" . "main-claude-md")
              ("description" . "Main Skewed Emacs development environment guide")
              ("path" . ,main-path))]))))
    (emacs-lisply-send-response docs-list)))

(defservlet* lisply/docs/claude-md text/markdown ()
  "Handle claude-md documentation endpoint."
  (emacs-lisply-log "Handling claude-md docs request")
  (let ((doc-path (expand-file-name "dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md"
                                    (emacs-lisply--skewed-root))))
    (if (file-exists-p doc-path)
        (insert-file-contents doc-path)
      (insert "Documentation file not found: " doc-path))))

(defservlet* lisply/docs/main-claude-md text/markdown ()
  "Handle main-claude-md documentation endpoint."
  (emacs-lisply-log "Handling main-claude-md docs request")
  (let ((doc-path (expand-file-name "CLAUDE.md" (emacs-lisply--skewed-root))))
    (if (file-exists-p doc-path)
        (insert-file-contents doc-path)
      (insert "Documentation file not found: " doc-path))))

;; Initialize endpoints
(defun initialize-lisply-endpoints ()
  "Initialize all Lisply endpoints."
  (emacs-lisply-log "Initializing Lisply endpoints"))

;; Run initialization
(initialize-lisply-endpoints)

(provide 'lisply-endpoints)
;;; lisply-endpoints.el ends here
