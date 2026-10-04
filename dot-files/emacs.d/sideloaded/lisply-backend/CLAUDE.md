# Emacs Lisply Backend - Reference

**Start with the primer** (`get_docs(id="primer")`).  It is the short
guide, and where it and this file disagree, the primer is current.  This
file is the reference behind it, one topic per section:

1. [Evaluating code](#1-evaluating-code)
2. [Reading and editing files](#2-reading-and-editing-files)
3. [Structural editing of Lisp](#3-structural-editing-of-lisp)
4. [Unbalanced files](#4-unbalanced-files)
5. [Writing a whole Lisp file from data](#5-writing-a-whole-lisp-file-from-data)
6. [Loops that cannot wedge the daemon](#6-loops-that-cannot-wedge-the-daemon)
7. [GDL define-object helpers](#7-gdl-define-object-helpers)
8. [Org buffers](#8-org-buffers)
9. [SLIME and Swank](#9-slime-and-swank)
10. [Working on this backend itself](#10-working-on-this-backend-itself)
11. [The lisply_search tool](#11-the-lisply_search-tool)

Examples are the elisp you pass as `lisp_eval`'s `code`.

## 1. Evaluating code

`lisp_eval` reads **one** top-level form and evaluates it in the
daemon.  The result comes back printed with `%s`; anything the form
prints to `standard-output` comes back as Stdout.

- **Only the first form runs.**  Later forms in the payload are
  silently ignored -- there is no error, you just get the first form's
  value.  Wrap several in `progn`.
- **Read before eval.**  The whole form is read before any of it runs,
  so a form naming a package or reader construct that an earlier part
  of the same form defines fails at read time.  Load in one call, use
  in the next.
- **The guard.**  A payload mentioning `shell-command`, `call-process`,
  `process-file` or `sleep-for` without a visible bound is refused with
  `LISPLY-GUARD REFUSED`.  Use `(lisply-shell-bounded CMD SECS)` (under
  20 s), or `(lisply-shell-async CMD)` and later
  `(lisply-shell-async-result TOKEN)`.  `;; lisply:allow-unbounded` in
  the payload overrides it, deliberately.
- **Time.**  The transport drops a call after about 30 s without an
  answer; the daemon keeps running it, single-threaded.  Split long work
  into short calls.

Shared state.  You share the daemon with a person: current buffer,
point, windows, the kill ring.  Never rely on the current buffer: name
the one you mean with `with-current-buffer` and wrap motion in
`save-excursion`.

```elisp
(mapcar #'buffer-name (buffer-list))                    ; what is open
(with-current-buffer "*Messages*" (buffer-string))      ; read a buffer
(list emacs-version (fboundp 'paredit-mode))            ; state checks
```

## 2. Reading and editing files

Use the file helpers; `(lisply-help)` lists them with their signatures.

| Task | Helper |
|---|---|
| read lines N to M | `(lisply-read FILE N M)` |
| search a tree | `(lisply-grep "PATTERN" DIR :glob "*.lisp")` |
| exact-text edit | `(lisply-replace FILE OLD NEW)` (`:count N` for several) |
| a top-level Lisp form | `lisply-form-get`, `-replace`, `-delete`, `-insert` |
| balance check | `(lisply-check-parens FILE)` |

They are bounded, check Lisp balance before and after (writing nothing
if an edit would break it), go through the live buffer when one visits
the file, refuse a buffer with unsaved edits, and otherwise leave no
buffer behind.

**When no helper fits**, the rule is: never open a project file with
`find-file` or `find-file-noselect` from an eval -- mode hooks, lock
files and "changed on disk" can all prompt, and a prompt stops every
call until someone answers it.  Instead:

```elisp
;; Read without visiting: no hooks run.
(with-temp-buffer
  (insert-file-contents "/path/file")
  (buffer-substring-no-properties (point-min) (min (point-max) 4000)))

;; Edit a file NO buffer visits: temp buffer, then write it back.
(let ((f "/path/file.txt"))
  (unless (find-buffer-visiting f)
    (with-temp-buffer
      (insert-file-contents f)
      (goto-char (point-min))
      (while (search-forward "old" nil t) (replace-match "new" t t))
      (write-region nil nil f nil 'silent))))

;; Edit a file a buffer ALREADY visits: through that buffer, then save.
(let ((buf (find-buffer-visiting "/path/file.txt")))
  (with-current-buffer buf
    (unless (verify-visited-file-modtime buf) (revert-buffer t t t))
    (save-excursion
      (goto-char (point-min))
      (when (search-forward "old" nil t) (replace-match "new" t t)))
    (save-buffer)))
```

Prefer buffer operations (search, `replace-match`, `kill-sexp`) to
pulling the text into a string, rewriting it with
`replace-regexp-in-string` and writing it out: the buffer route edits
in place, keeps undo, and lets a Lisp mode check structure.

`(buffer-size)` counts characters; `file-attribute-size` and `ls -l`
count bytes.  In a file with multi-byte UTF-8 (`kṛṣṇa`, `→`, `—`) the
two differ, which is not a sign of damage.

## 3. Structural editing of Lisp

The helpers in section 2 cover whole forms and exact text.  For finer
edits inside a form, work structurally: in a temp buffer for a file no
buffer visits, in the live buffer otherwise, with paredit on
(`(when (fboundp 'paredit-mode) (paredit-mode 1))`) and a balance check
before saving.

### Think in structures, not lines

Lisp source is a tree of s-expressions, not a list of lines.  The edits
that break files come from line thinking: "insert this after line 15".
Before any edit, ask: *which s-expression am I changing* (a binding
list, a call, a defun body), *what relation should the new code have to
it* (sibling, child, replacement), and *which structural move does that*.

Adding `(z 3)` to `(let ((x 1) (y 2)) ...)` is "add a sibling after
`(y 2)` inside the binding list", not "insert after line 2":

```elisp
(search-forward "(let ")
(down-list)            ; into the binding list
(forward-sexp 2)       ; past (x 1) and (y 2)
(insert "\n      (z 3)")
```

When paredit refuses an operation, your model of the structure is
wrong.  Do not turn paredit off or reach for a shell to force the edit
through (a December 2025 session did both, and left a file that
balanced but no longer meant anything); stop, reconsider the structure,
and ask if it is still unclear.

### Footgun: `search-forward "(name"` does not leave you on the `(`

After `(search-forward "(body-class")` point is past the `s` of
`class`; `(backward-char)` lands on that `s`, and `forward-sexp` from
there only walks to the end of the symbol.  Land on the paren with the
match data:

```elisp
(re-search-forward "(body-class\\_>")
(goto-char (match-beginning 0))   ; on the (
(forward-sexp)                    ; over the whole (body-class ...) form
```

The same family: after `(re-search-forward ":computed-slots ((")` point
is INSIDE the first slot spec, not in the slot list; after
`(re-search-forward "^(define-object foo")` point is inside the form,
and `forward-sexp` moves over the next element, not the form.  Go to
`(match-beginning 0)` before any structural navigation.  The commentary
in `lisply-edit-helpers.el` works through all three.

### Paredit, the commands that matter

| Task | Command | Effect |
|---|---|---|
| pull the next form in | `paredit-forward-slurp-sexp` | `(a b) c` → `(a b c)` |
| push the last form out | `paredit-forward-barf-sexp` | `(a b c)` → `(a b) c` |
| pull the previous form in | `paredit-backward-slurp-sexp` | `a (b c)` → `(a b c)` |
| wrap | `paredit-wrap-round` | `a` → `(a)` |
| unwrap | `paredit-splice-sexp` | `(a b)` → `a b` |
| kill to the end of the list | `paredit-kill` | `(a b c d)` → `(a b)` from `b` |
| kill a word, balanced | `paredit-kill-word` | `(old-name x)` → `( x)` |
| move over / into / out of | `forward-sexp`, `down-list`, `up-list` | |

Do not edit Lisp with `delete-char`, `kill-line` or `replace-regexp`
over parentheses; they are blind to structure.  An exact-text edit is
different: renaming `(if c x)` to `(when c x)` needs no paredit,
because `(lisply-replace FILE "(if c" "(when c")` takes the parenthesis
out and puts it back, and the helper checks balance anyway.

### Big inserts

paredit protects incremental edits, not an `(insert "...")` of a whole
block: a string can carry an imbalance straight into the buffer.  The
form helpers check the text for you.  By hand, stage it first:

```elisp
(with-temp-buffer
  (lisp-mode)
  (insert block-text)
  (check-parens)      ; signals before anything real is touched
  block-text)
```

## 4. Unbalanced files

`(lisply-check-parens FILE)` returns `t` or names the line where
balance fails; the editing helpers refuse to touch a Lisp file that is
already unbalanced.

How a file gets there:

1. **Edits that bypass Emacs** -- a shell `sed`, a string rewrite
   written out with `write-region`.  (The Claude Code hook a Basilisk
   yard installs refuses the shell forms.)
2. **A bulk `insert` of an unbalanced string**, paredit on or not
   (section 3, *Big inserts*).
3. **A change on disk** that an auto-reverted buffer picked up.

A person cannot normally produce "paredit on, buffer unbalanced";
paredit refuses to turn on in an unbalanced buffer.  An agent can, by
the routes above, and every structural command after that misbehaves.

If you find an unbalanced file: **stop, do not try to repair it by
guesswork, and report** -- the file, the line `lisply-check-parens`
gives, and what last touched it -- then back off.  When the file is
under git, `git diff` on it (through magit plumbing) usually shows the
damage, and restoring it is the user's call.

## 5. Writing a whole Lisp file from data

For a new file, or a wholesale rewrite, build the code as elisp data and
let `lisply-write-sexp-file` serialize it.  A quoted elisp list is
balanced by construction (the reader will not build an unbalanced one),
and Common Lisp shares enough surface syntax that the form round-trips:
keywords, strings and Unicode survive.

```elisp
(lisply-write-sexp-file
 "/path/my-app/source/widget.lisp"
 "my-package"
 '((define-object widget (base-html-page)
     :computed-slots
     ((title "Hello")
      (body (with-lhtml-string ()
              ((:h1 :class "text-2xl") "Hello, world"))))
     :objects
     ((sub-widget :type 'other-widget)))))
```

It writes `(in-package :my-package)`, pretty-prints each form with a
wide `fill-column`, restores `()` for the empty-argument idioms
(`with-lhtml-string`, `with-cl-who-string`), puts each define-object
section keyword on its own line, reindents under `lisp-mode`, checks
balance and saves.

| Situation | Use |
|---|---|
| brand-new file, boilerplate (package defs, ASDF stubs) | `lisply-write-sexp-file` |
| wholesale rewrite with no comments to keep | `lisply-write-sexp-file` |
| a change inside an existing file | the form helpers, or section 3 |
| comments inside the form, `#+`/`#-` reader conditionals | the form helpers (`pp` drops comments and may not keep reader macros) |

A very large form in one payload can run into the transport's time
limit.  Split it: store the heavy part in a variable in one call, then
splice it in with backquote in a small second call.

```elisp
;; call 1
(progn (defvar my-page-body nil)
       (setq my-page-body '((:main ...) ...))
       (length my-page-body))
;; call 2
(lisply-write-sexp-file "/path/file.lisp" "my-package"
  (list `(define-object foo (base-html-page)
           :computed-slots ((body (with-lhtml-string () ,my-page-body))))))
```

What can still go wrong is semantic, not syntactic: a symbol or package
the Common Lisp side does not know when it loads the file.

## 6. Loops that cannot wedge the daemon

Every loop in a payload runs synchronously on the daemon's one thread.
A loop that stops making progress wedges the daemon and every MCP call
until the stack is restarted -- `ping_lisp` goes dark too, and a signal
does not always free it.

Two field incidents:

- **August 2026**: a blank-line collapser,
  `(while (and (looking-at "^[ \t]*$") ...) (delete-region (line-beginning-position) (min (point-max) (1+ (line-end-position)))))`.
  At the end of the buffer the `min` clamp made the delete zero-width,
  the condition stayed true, and it spun for ever -- twice, in two
  sessions, before anyone saw why.
- **2026-10-04**: a `while (re-search-forward ...)` whose body ended on
  `(forward-line 0)`, which moved point back before the match, so the
  search found it again for ever.

The rules:

1. **Prove progress.**  Each pass must advance point or shrink the
   buffer.  Zero-width deletes at `point-min`/`point-max` and moving
   point backwards inside a search loop are the classic traps.
2. **Tie the loop to a search.**  `(while (search-forward "x" nil t) ...)`
   ends because each search advances or returns nil -- as long as the
   body leaves point past the match (`replace-match` does).
3. **Prefer built-ins** for whitespace work: `delete-blank-lines`,
   `delete-trailing-whitespace`, `just-one-space`, `fixup-whitespace`;
   and `keep-lines` / `flush-lines` to filter lines.
4. **Bound what you cannot prove**: `(cl-loop repeat 1000 while COND do ...)`.
   A wrong answer beats a wedged daemon.
5. **Try the degenerate shapes** before a routine runs over many files:
   the target at the end of the buffer, at the start, an empty file, no
   trailing newline.

After a hard restart, a dead process's `.#` lock file makes the next
visit of that file ask whether to steal the lock -- another prompt.
The file helpers do not lock; anything that visits a file should bind
`create-lockfiles` to nil.

## 7. GDL define-object helpers

`lisply-edit-helpers` (loaded at boot) does the define-object edits
that come up in refactors.  These take a BUFFER, not a file: use them
in a temp buffer you write back, or in a buffer that already visits the
file.  Each checks balance on entry and exit.

| Function | Does |
|---|---|
| `lisply-insert-slot-spec` | insert a spec as the first entry of `:computed-slots`, `:input-slots`, `:objects`... |
| `lisply-kill-named-slot` | remove a `(slot-name ...)` spec and its line |
| `lisply-replace-parent-class` | swap the mixin list of `(define-object NAME (...) ...)` |
| `lisply-add-keyword-to-object-spec` | add ` :keyword value` to a child spec |

The GDL side -- when to use these, pseudo-inputs, the
`(the landing-page ...)` idiom -- is in the Gendl lisply backend's own
guide, `get_docs(id="claude-lisply-md")` on any Gendl backend.

## 8. Org buffers

Org functions (`org-end-of-subtree`, `org-entry-get`, `org-entry-put`,
`org-map-entries`) need a buffer in `org-mode`; in a fundamental-mode
temp buffer they warn or misbehave.

- If a buffer already visits the org file, work in it and
  `save-buffer`; never write the file underneath it.
- To read an org file nobody has open, put the temp buffer in org mode
  without its hooks: `(with-temp-buffer (insert-file-contents F)
  (delay-mode-hooks (org-mode)) ...)`.
- Find the files from Emacs rather than hard-coding them:
  `org-directory`, `org-agenda-files`.

```elisp
;; Set a property on a heading in an open agenda file
(let ((buf (find-buffer-visiting (car org-agenda-files))))
  (with-current-buffer buf
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward "^\\*+ .*My Task Heading" nil t)
        (org-entry-put nil "HOST" "gendl-ccl")
        (save-buffer)
        (org-entry-properties nil 'standard)))))
```

Clocking from outside (`org-clock-in`) hangs the daemon if org decides
to ask about a dangling clock: close open `CLOCK:` lines first and bind
`org-clock-auto-clock-resolution` to nil around the call.

## 9. SLIME and Swank

The Gendl backends also run Swank (ports in the `*dashboard*` buffer's
SWANK section), so you can reach them through SLIME from this Emacs as
well as through their own `lisp_eval`.

```elisp
(slime-connect "bridge" 4200)       ; host and port from the Dashboard
(slime-eval '(+ 1 2 3))             ; => 6
```

SLIME is the better road for debugger work, inspection and completion;
the backend's own `lisp_eval` is simpler for plain evaluation.  A SLIME
connection may be the person's own REPL session: check for an existing
`*slime-repl ...*` buffer, treat it as theirs, and say so before
driving it.

## 10. Working on this backend itself

The running daemon loads the copy of Readymax baked into the image
(`/home/emacs-user/skewed-emacs/`), not the git checkout in the
workspace.  Edit the checkout (that is what persists and is committed),
then load the edited file into the daemon to try it without a rebuild:

```elisp
(let ((load-path (cons "/path/to/checkout/dot-files/emacs.d/sideloaded/lisply-backend/source/"
                       load-path)))
  (load "/path/to/checkout/.../source/endpoints.el" nil t))
```

The image copy is replaced at the next rebuild.  Do not edit it as a
way to make a change last.  New helpers go in `lisply-file-tools.el`,
with an ERT test in `lisply-file-tools-test.el` and an entry in
`lisply-help-groups`; run the tests in batch (`emacs --batch -L . -l
lisply-file-tools.el -l lisply-file-tools-test.el -f
ert-run-tests-batch-and-exit`, through `lisply-shell-async`).

## 11. The lisply_search tool

`lisply_search` is lexical search over curated Gendl/GDL source and
documentation, this console's own configuration, and the Genworks
training material.  Search before writing `define-object` code,
explaining a GDL concept, or debugging GDL: the corpus usually holds a
canonical example.  (It was `skewed_search` until 2026-09-09.)

### How it matches and ranks

The query is split into terms (`hidden-objects` → `hidden`, `objects`;
stopwords such as "how", "the", "from" are dropped) and *phrases*, the
hyphenated tokens kept whole.  By default every term must appear in one
snippet (`match_mode="all"`); when nothing holds every term, the search
retries with any-term matching and says so in `warning`
(`match_fallback` true).  Candidates are scored by IDF-weighted term
coverage (rare terms count for more), term density, verbatim phrase
hits, whether the snippet *defines* the queried name (`(define-object
wall ...` outranks ten mentions of `wall`) and whether the file name
carries it.  Snippets are cut at top-level forms in Lisp and at
headings in Markdown and Org, so a hit is a whole `define-object` or
section.  Each hit reports `match_line`, the first line holding a query
term; a snippet longer than `max_snippet_tokens` is excerpted from just
above it.  There is no embedding model: a `search_mode` other than
`lexical` is answered lexically, with a warning.

### Sources

The corpus has three tiers (the contract is lisply-mcp's `CORPUS.md`:
file format, image label, merge):

1. **The baked index** -- `lisply-search-config.sexp` beside this file
   lists `readymax` (this console's configuration and lisply backend)
   and `gendl` as a fallback for standalone use.  `docker/build` builds
   it into the image; no private repository is cloned for it.
2. **Project corpora** -- each project builds its own with the
   reference indexer (`lisply-index`, on the path in every Readymax
   image) and ships it in its image under the `lisply.corpus` label
   (Gendl: `/opt/gendl/lisply-corpus/gendl.sexp`).  A Basilisk yard
   copies them out of the images aboard into the corpora directory.
3. **Workspace corpora** -- built at raise from the mounted workspace
   (the live demos, the training material, internal applications on
   internal ships) and written into the same directory.

The console loads the baked index plus every `*.sexp` in
`LISPLY_SEARCH_CORPORA` (default `/lisply/corpora`); a corpus there
REPLACES a same-named baked source, so aboard a ship the Gendl corpus is
the Gendl actually flying.  The response's `sources` lists what is
loaded, and `corpora` names each file with its `generated_at`.

**Distribution.**  The baked index ships in a public Docker Hub image,
so each source carries `:distribution` `:public` (the default) or
`:internal`, and an image build indexes the public sources only
(`LISPLY_INDEX_DISTRIBUTION=all`, or `lisply-search-build-index` by
hand, indexes everything present).  The training material is public (it
is served at genworks.dev under the AGPL); internal applications are
not, and reach a console only as workspace corpora on internal ships.
Minified files and vendored static trees are excluded
(`:exclude-paths`), and every snippet is capped at the configured
character budget.

A source that cannot be fetched at build time is skipped with a
`SOURCE MISSING` line; the build fails only if no index results (or
with `--strict-index`).

### Queries

```
lisply_search(query="define-object hidden-objects", k=5)
lisply_search(query="base-html-page computed-slots body", k=3)
lisply_search(query="base-html-page computed-slots body", k=3, match_mode="any", any_max_candidates=800)
lisply_search(query="hidden-objects pseudo-inputs", sources=["gendl"], k=5)
lisply_search(query="define-object first example", sources=["genworks-learn"], k=3)
lisply_search(query="fixed-url-prefix", k=5)
lisply_search(query="with-format pdf cad-output", k=5)
```

`genworks-learn` (the training material) walks through the concepts in
order and suits a newcomer; `gendl` is the engine's own source and
documentation.  The more specific the query, the better the hits, and a
hit's `path` says where it came from.

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `query` | string | (required) | keywords or natural language |
| `k` | integer | 8 | max hits |
| `sources` | array | all | logical sources to restrict to |
| `path_filters` | array | none | repo-relative prefixes or globs (`*` within a directory, `**` across), e.g. `geom-base/wire/*` |
| `language` | string | none | hint: lisp, gdl, markdown |
| `match_mode` | string | `all` | `all` (retried as `any` when nothing matches) or `any` |
| `any_max_candidates` | integer | none | candidate cap for `any` |
| `search_mode` | string | lexical | the only mode in this build |
| `max_snippet_tokens` | integer | 512 | soft cap; longer snippets are excerpted above the first match |
| `include_metadata` | boolean | true | include metadata in hits |

### Response

```json
{
  "query": "define-object computed-slots",
  "search_mode": "lexical",
  "match_mode": "all",
  "match_fallback": false,
  "terms": ["define", "object", "computed", "slots"],
  "phrases": ["define-object", "computed-slots"],
  "sources": ["readymax", "gendl", "demos"],
  "corpora": [{"corpus": "baked", "generated_at": "2026-09-14T14:51:02Z"},
              {"corpus": "gendl", "generated_at": "2026-09-14T20:10:00Z"}],
  "total_candidates": 41,
  "warning": null,
  "hits": [
    {"id": "hit-001", "score": 0.93, "source": "genworks-learn", "repo": "apps",
     "path": "genworks-learn/t1/source/first-object.lisp",
     "start_line": 11, "end_line": 34, "match_line": 11, "excerpt_start_line": 11,
     "snippet": "...", "preview": "the first line holding a query term",
     "metadata": {"language": "lisp", "section": "...", "tags": ["define", "object"]}}
  ]
}
```

### Rebuilding the index

The index is built during the image build, and a copy of the
configuration is embedded in it.  To rebuild inside a running console
against the mounted workspace (sources already present are used as they
are; nothing is cloned): `(lisply-search-build-index-with-clone)`.  It
logs `SOURCE MISSING` for any source it cannot find, and the runtime
cache reloads on the next query once the file's mtime changes.
