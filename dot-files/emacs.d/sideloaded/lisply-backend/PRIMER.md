# Ready Room primer: Emacs first

Read this before your first edit.  It is short on purpose; the longer
references (`get_docs(id="claude-md")`, `get_docs(id="main-claude-md")`)
are for when something here does not cover your case.

## What you are connected to

`lisp_eval` evaluates Emacs Lisp in one long-running Emacs daemon, the
ready room.  A person may be working in that same Emacs while you are,
and the daemon serves every agent's tool calls on a single thread.  The
ready room mounts the workspace (in a standard Basilisk rig,
`/projects`), so it can read and edit every file you are likely to
work on.

**Use it as your main tool for workspace files, not only for Lisp.**
Read, search and edit them through the helpers below rather than
through `cat`, `sed -n`, `grep`, `sed -i`, `awk`, `perl -i` or
redirection in a shell.  The reason is concrete: a file written
underneath a buffer the daemon has open makes Emacs ask "changed on
disk?" the next time anything touches that buffer, and a question in
this daemon stops every tool call until someone answers it.  Hand-rolled
search loops and unbounded child processes stop it the same way.  The
helpers are bounded and buffer-aware, so you do not have to be careful
every time.

## The toolkit

`(lisply-help)` lists every helper with its signature, generated from
the docstrings, so it is always current.  `(lisply-help 'lisply-replace)`
gives one in full.  The ones you will use most:

| Instead of | Use |
|---|---|
| `cat -n`, `sed -n 'N,Mp'` | `(lisply-read FILE N M)` |
| `grep -rn` | `(lisply-grep "PATTERN" DIR :glob "*.lisp")` |
| `sed -i`, an exact-text edit | `(lisply-replace FILE OLD NEW)` |
| rewriting a defun by hand | `(lisply-form-replace FILE "name" TEXT)` |
| appending a defun | `(lisply-form-insert FILE TEXT :after "name")` |
| deleting a defun | `(lisply-form-delete FILE "name")` |
| `check-parens` on a file | `(lisply-check-parens FILE)` |

What every editing helper guarantees:

- **Exactly once.** `lisply-replace` writes nothing unless OLD occurs
  exactly once (or exactly `:count N` times), and its error says how
  many times it did occur.  Give OLD enough context to be unique.
- **Balanced.** A Lisp file must balance before the edit and after it,
  or nothing is written.
- **Through the live buffer.** If a buffer visits the file, the edit
  goes into that buffer and is saved, so the person's Emacs never sees
  the file change underneath it.  A buffer with unsaved edits is
  refused: those edits are someone's work.  Otherwise the file is
  edited in a temp buffer and no buffer is left behind.
- **Verbatim.** Text goes in as you wrote it.  Nothing is re-indented,
  so indent new code as it should read.
- **Bounded.** `lisply-read` returns at most 400 lines a call;
  `lisply-grep` stops at 200 hits or 15 seconds and says so.

`lisply-grep` takes a POSIX extended regexp (as `grep -E` does), not an
Emacs regexp; pass `:fixed t` for a literal string.  Inside a git tree
it is `git grep`, so `.gitignore`d files are skipped.

The form helpers find a top-level form (one whose `(` is in column 0,
outside strings and comments) by its second element, so `"alpha"`
finds `(defun alpha ...)`, `(define-object alpha ...)` and
`(defparameter alpha ...)` alike.  When several forms share a name
(methods), pass `:kind "defmethod"` or `:line N`.

For GDL `define-object` sections there are older, finer helpers that
take a BUFFER: `lisply-insert-slot-spec`, `lisply-kill-named-slot`,
`lisply-replace-parent-class`, `lisply-add-keyword-to-object-spec`.  To
author a whole new Lisp file from s-expression data, use
`lisply-write-sexp-file`.

## Rules that bite

1. **One form per eval.** `lisp_eval` evaluates only the FIRST
   top-level form of its payload; wrap several in `(progn ...)`.  A
   payload that names a package or function its own earlier form
   defines fails at read time: load in one eval, call in the next.
2. **Nothing that can prompt.** No `find-file` or `find-file-noselect`
   on project files (mode hooks and "changed on disk" both prompt), no
   `yes-or-no-p`, no `revert-buffer` without NOCONFIRM.  To read a file
   use `lisply-read`, or `(with-temp-buffer (insert-file-contents F)
   ...)`, which runs no hooks.
3. **Bounded child processes.** The backend refuses a payload calling
   `shell-command`, `call-process` or `process-file` without a visible
   bound.  Use `(lisply-shell-bounded CMD SECS)` and keep it under 20
   seconds: the transport drops an eval after 30 seconds of silence and
   the daemon keeps running it.  Anything longer goes through
   `(lisply-shell-async CMD)` and `(lisply-shell-async-result TOKEN)`.
4. **Every loop advances.** A `while (re-search-forward ...)` whose body
   moves point backwards finds the same match for ever and wedges the
   daemon for good.  Prefer a helper; if you must loop, end each pass
   past the match (`replace-match` does).
5. **Explicit buffers.** You share the current buffer with the person.
   Never rely on it: `(with-current-buffer BUF (save-excursion ...))`.
6. **Never call the ready room's own HTTP port from inside an eval**
   (curl to `localhost:7080`): the request waits on the loop it is
   blocking.

## Git

Use Magit's plumbing from elisp rather than a shell, so nothing is
quoted twice:

```elisp
(progn
  (require 'magit)
  (let ((default-directory "/projects/some-repo/"))
    (list (magit-git-output "status" "--short")
          (magit-git-output "log" "--oneline" "-5"))))
```

For a commit, write the message to a file with `write-region` and run
`(magit-git-output "commit" "-F" FILE)`.

## When no helper fits

Edit in a temp buffer and write the file back, but only when no buffer
visits it:

```elisp
(let ((f "/projects/some-repo/notes.txt"))
  (if (find-buffer-visiting f)
      "a buffer visits it: edit in that buffer and save-buffer instead"
    (with-temp-buffer
      (insert-file-contents f)
      ;; ... edit, keeping every loop advancing ...
      (write-region nil nil f nil 'silent))))
```

For structural Lisp edits inside a form, paredit and `kill-sexp` work
in that temp buffer as they do interactively; check balance with
`(lisply-check-parens F)` afterwards.  The claude-md reference covers
paredit in depth.

## If the ready room stops answering

`ping_lisp` timing out with everything else means the daemon is
blocked: a prompt, a stuck child process, or a loop.  You cannot fix
that from `lisp_eval`.  Tell the person; the recovery runbook is in
the main-claude-md reference ("Event-Loop Blocking").
