This server is the ready room: `lisp_eval` evaluates Emacs Lisp in one long-running Emacs daemon that mounts the workspace and that a person may be using at the same time.

Make it your main tool for workspace files, not only for Lisp. Read, search and edit through its helpers instead of cat, sed -n, grep, sed -i, awk or redirection in a shell:
- `(lisply-read FILE START END)` and `(lisply-grep "PATTERN" DIR :glob "*.lisp")` to read and search;
- `(lisply-replace FILE OLD NEW)` for an exact-text edit, written only if OLD occurs exactly once;
- `(lisply-form-replace FILE "name" TEXT)`, `lisply-form-insert` and `lisply-form-delete` for top-level Lisp forms.
They refuse any edit that would unbalance a Lisp file, edit through a buffer the person has open rather than underneath it, and leave no buffer behind. `(lisply-help)` lists the whole toolkit. Read `get_docs(id="primer")` before your first edit.

Why: a file written underneath one of the daemon's open buffers makes Emacs ask "changed on disk?", and a question in this daemon stops every tool call until someone answers it. Ad-hoc search loops and unbounded child processes stop it the same way; the helpers are bounded.

Rules that bite:
- Only the FIRST top-level form of a payload is evaluated: wrap several in `(progn ...)`.
- Never call anything that can prompt (`find-file`/`find-file-noselect` on project files, `yes-or-no-p`).
- Child processes go through `(lisply-shell-bounded CMD SECS)` under 20 s, or `(lisply-shell-async CMD)` then `(lisply-shell-async-result TOKEN)`.
- Git through Magit plumbing: `(magit-git-output "status" "--short")` with `default-directory` bound to the repo.
