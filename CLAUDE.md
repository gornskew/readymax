# Readymax (the Ready Room) — agent guidance

This file guides Claude Code (claude.ai/code) or other AI agents
working with this repo's environment, standalone or aboard a Basilisk
stack.  It is deliberately mixed-register: lore nouns are bound to
their referents in parentheses at first use, then used freely;
commands, identifiers, and warnings never take the voice.

Contents: the primer and the file helpers · the downstream fork · the
room and its neighbours · running the stack · keeping the daemon
answering · git · editing · Lisp-side notes · webshot · long-running
processes · showing the user a buffer.

## Before anything else: the primer and the file helpers

**Work through the Captain, not a shell.**  Reading, searching and
editing workspace files -- Lisp or not -- goes through the ready room's
`lisp_eval` and its file helpers: `(lisply-read FILE N M)`,
`(lisply-grep PATTERN DIR)`, `(lisply-replace FILE OLD NEW)`,
`(lisply-form-replace FILE NAME TEXT)`; `(lisply-help)` lists them all.
They are bounded, check Lisp balance, and edit through a buffer the
user has open rather than underneath it.  Why it matters: a file
changed underneath one of the daemon's buffers makes Emacs prompt, and
a prompt stops every MCP call.  The short guide is
`get_docs(id="primer")` (source:
`dot-files/emacs.d/sideloaded/lisply-backend/PRIMER.md`); the editing
reference behind it is `get_docs(id="claude-md")` (source:
`dot-files/emacs.d/sideloaded/lisply-backend/CLAUDE.md`).  Where this
file disagrees with the primer, the primer is current.  The helpers
live in `lisply-file-tools.el` beside the other lisply-backend sources,
with ERT tests in `lisply-file-tools-test.el`; a new helper goes there,
with a test, and into `lisply-help-groups`.

## The downstream fork: every edit here has a Readymacs analog

Readymacs (`/projects/gw/readymacs`, github.com/genworks/readymacs)
is the Genworks-maintained downstream of this repo: the same code
under Genworks naming, attribution and documentation voice.  **An
edit to Readymax is not finished until its Readymacs analog is made
in the same session** (the user, 2026-09-14) -- code files byte-
identical (copy them across and compare hashes), docs and comments
translated to that repo's register, one commit on each repo with the
same story.  Its own `CLAUDE.md` carries the register rules and the
identifiers that must never be renamed.  Do not wait for a merge to
carry a change down: the fork merges upstream only when chosen, and a
session that leaves the two apart leaves the next one to find out
which is right.

## The room and its neighbours

- **The ready room** (this repo's container, compose service
  `ready-room`): the Captain (a long-running Emacs daemon with the
  Readymax configuration) attended by the Protocol Officer (the
  lisply-mcp layer that receives arriving agents).  Reachable as
  `ready-room:7080` from the other rooms; the gangway (web terminal)
  on host port 6942.
- **The Gendl rooms** (`bridge`, `engine-room`): Gendl on Clozure CL
  and SBCL, answering the same lisply dialect.
- **The guild workshops** (`guild-workshop`, SMP; `guild-workshop-2`,
  non-SMP): licensed Genworks GDL on Allegro CL.  Not in the base
  articles: a licensed user clones the supplemental repo beside
  `basilisk/`, runs its `./install` (`BASILISK_DIR=` if the yard lives
  elsewhere), and `./basilisk up` picks the overlay up.

| Room (MCP server) | Lisp | HTTP | Swank |
|---|---|---|---|
| `ready-room` | Emacs Lisp | 7080 | -- |
| `bridge` | Gendl, CCL | 9080 | 4200 |
| `engine-room` | Gendl, SBCL | 9090 | 4210 |
| `guild-workshop` (overlay) | GDL, Allegro SMP | 9098 | 4218 |
| `guild-workshop-2` (overlay) | GDL, Allegro non-SMP | 9088 | 4208 |

MCP server names are the room slugs (`mcp__ready-room__ready-room__lisp_eval`,
`mcp__bridge__bridge__lisp_eval`, ...), each with `lisp_eval`,
`ping_lisp`, `get_docs` and friends.  Every room mounts `~/projects` at
`/projects` and joins the ship's network, whose name is minted fresh at
each raising (`basilisk/.ship`, surfaced as `DOCKER_NETWORK_NAME` in
`basilisk/.env`).  **Containers wear minted keeper names that change at
every raising** -- look a room up by label
(`docker ps -qf label=basilisk.module=<room>`) or in `basilisk/.muster`,
never from memory.  The `*dashboard*` buffer shows current health, the
backends aboard and their Swank ports.

Each Gendl/GDL backend serves its own guide: `get_docs(id="claude-md")`
on that room.  The MCP services allow arbitrary evaluation: run them
only in trusted, containerized environments, never on an untrusted
network.

## Running the stack

The stack lives in the Basilisk repo, not this one:

```bash
cd ~/projects/basilisk
./basilisk up                  # raise (a fresh raising mints a new ship and crew)
./basilisk down                # stand down; removes the ship's network too
```

```bash
RR=$(docker ps -qf label=basilisk.module=ready-room | head -1)
docker exec -it "$RR" emacsclient -t        # or rmax from any host shell
docker logs -f "$RR"                         # watch what agents are doing
docker exec -it $(docker ps -qf label=basilisk.module=bridge | head -1) ccl
```

From inside Emacs, `M-x slime-connect RET bridge RET 4200 RET` reaches
the bridge's Swank.  When something does not answer: `docker ps` for
health, the room's `docker logs`, `docker network ls` for the ship's
network, and for SLIME, whether Swank listens on its port inside the
room.

## Keeping the daemon answering

Everything an agent does runs on the Captain's single event loop.  Four
things stop it, and while it is stopped every MCP call to the ready
room -- `ping_lisp` included -- times out.

**A prompt.**  Anything that can ask a question in the minibuffer waits
for a person who is not there: "File changed on disk", a lock-file
steal, a mode hook calling `slime-connect`, `revert-buffer` without
NOCONFIRM (observed live with `revert-buffer-with-coding-system`).
Before driving an interactive-capable command from `lisp_eval`, find
its prompt paths (`yes-or-no-p`, `y-or-n-p`, `map-y-or-n-p`) and bind
the documented suppressor or call the non-interactive variant
(`(let ((revert-without-query '("."))) ...)`, `(revert-buffer t t t)`);
if there is none, do not call it from an eval.  Never open a project
file with `find-file-noselect` from an eval (2026-08-07: a `.gdl`
file's mode hooks prompted and the transport went dark); read with
`lisply-read` or `insert-file-contents`.  If calls start failing with
connectivity errors, the daemon may be waiting on such a prompt: tell
the user.

**A synchronous child process** (2026-07-26 incident).
`shell-command-to-string`, `call-process` and `process-file` block the
loop until the child exits -- timers, `with-timeout`, network filters
and the lisply httpd all starve.  One `(shell-command-to-string "sleep
60")` blacked out the transport for 60 s, and an unbounded `curl`
against a stalled server is exactly as fatal.  The backend's pre-eval
lint (`lisply-shell-guard.el`) refuses such payloads without a visible
bound (`LISPLY-GUARD REFUSED`); use `(lisply-shell-bounded CMD SECS)`
(default 25 s, returns `:exit-code`/`:output`/`:timed-out`) and keep it
under 20 s, or `(lisply-shell-async CMD)` and poll
`(lisply-shell-async-result TOKEN)`.  `curl` always gets `--max-time`;
`ssh` gets both `-o ConnectTimeout=N` and a `timeout N` wrapper
(ConnectTimeout does not bound the remote command).  The override is
the comment `;; lisply:allow-unbounded`.

**Calling the room's own port.**  `(lisply-shell-bounded "curl
http://localhost:7080/lisply/...")` deadlocks (2026-09-09): curl waits
on the httpd, which runs on the loop waiting for curl.  Probe the
room's own endpoints with `lisply-shell-async`, from another room, or
from the host.

**A loop that does not advance** -- see the reference, section 6.

Time budgets.  The MCP layer drops an eval after about 30 s of socket
silence; the claude.ai relay gives up at 35-40 s and reports a bare
"Tool execution failed" (Claude Desktop waits about 240 s).  The eval
still runs to the end.  Split long work into short calls and poll, and
after any timeout check whether an edit half-applied
(`buffer-modified-p`, git status) before retrying.

Multi-line string literals in a payload hung the backend twice on
2026-08-11 (single-line `\n` equivalents went through); never
root-caused, and later sessions (2026-10-04) sent multi-line strings
throughout without trouble.  If a payload with real newlines times out
for no visible reason, try the `\n` spelling before anything else.

**Recovery (host side).**

```bash
RR=$(docker ps -qf label=basilisk.module=ready-room | head -1)
docker exec "$RR" ps -ef --forest           # a stuck child under emacs?
docker exec "$RR" pkill -f '<child pattern>' # transport returns at once
```

With no child to kill, `docker exec "$RR" sh -c 'kill -USR2 $(pgrep -o
emacs)'` and `docker logs "$RR"` show a backtrace of what the loop is
doing.  Do not combine that with killing emacsclient processes: the
pair killed the daemon once.  The last resort is
`docker restart "$RR"` (back in about 20 s; then restart any
Emacs-managed watchers, which die with the daemon).  The autoheal
sidecar restarts an unhealthy room on its own in about 2 minutes, and
the mcp-exec supervisor reconnects the wrappers about 30 s later; if
calls still fail after that, the client has stopped routing to the
server -- reconnect the session.  A session started while the rooms
were restarting loses its transports for good: start a fresh one.

## Git

Through magit's plumbing from `lisp_eval`, not host-side `git` (the
same rule as file operations):

```elisp
(progn
  (require 'magit)    ; only the interactive commands are autoloaded
  (let ((default-directory "/projects/cyclops/"))
    (magit-git-output "show" "af5e39e" "--" "source/functions.lisp")))
```

- `magit-git-output` (all of stdout), `magit-git-lines` (a list of
  lines), `magit-git-string` (the first line), `magit-rev-verify`,
  `magit-get-current-branch`; all honour `default-directory` (the repo
  root, with a trailing slash).  Raw output: no pager, no ANSI.
- Prefer these to `(magit-status)` in an eval: status pops a buffer
  the user shares.  Narrow big diffs with `-- <path>` rather than
  filtering one giant string.
- **Commits**: the container has no git identity and no ssh keys.
  Write the message with `write-region`, then
  `(magit-git-output "-c" "user.name=..." "-c" "user.email=..." "commit" "-F" FILE)`.
  Pushes happen on the host.

## Editing

The primer and the reference cover the method; the points that are
specific to working in this room:

- **Prefer Emacs to the shell** for everything with an Emacs form:
  `lisply-grep` over `grep`, `rename-file` / `copy-file` /
  `delete-file` over `mv` / `cp` / `rm`, `dired-noselect` over `ls`
  (revert a dired buffer before trusting it).  Host-side line tools
  are out of bounds for `/projects` files; a Basilisk yard's
  `mcp/install-claude-code-config` installs a Claude Code hook
  (`mcp/emacs-first-guard`) that refuses them.
- **Paths**: the user's files are under `/projects/` in this room
  (`~/projects/` on the host).  A cloud agent's own sandbox
  (`/mnt/project`, `/home/claude`) is not the user's workspace: if you
  are creating files there, you are working in the wrong place.
- **New files** from an agent that cannot write `/projects` itself:
  `write-region` from a temp buffer, which also avoids layers of shell
  escaping.  `append-to-file` only to a file no buffer visits.
- **Whole new Lisp files**: `lisply-write-sexp-file` (reference,
  section 5), not a heredoc string of the whole file.
- **When a structural edit will not come out right**, ask the user to
  revert the file (`git checkout`) or to leave a placeholder comment
  where the new code goes, and replace the placeholder with a
  balanced form.
- **Verify bulk edits by presence, with warnings visible** (2026-08-13
  production incident).  A `remhash -> remhash-scrubbed` replace-all
  glued 12 of 17 arglists (`(remhash-scrubbed fd*request-registry*)`)
  and shipped to the production cyclops fleet, past two checks that
  lied: an absence-grep whose exclusion pattern also matched the broken
  lines, and `ql:quickload ... :silent t`, which hid the very warnings
  that named every broken site.  So: grep the edited call sites and
  READ the resulting lines; compile with warnings visible (never
  `:silent` for a verification build; on Allegro capture compiler
  output and scan for undefined-variable and arity warnings); prefer
  whole-expression OLD/NEW strings to token splices, so whitespace is
  never load-bearing; keep verification builds at zero warnings, so the
  next real one is not scrolled past.
- **Large tool results** that the client saved to a file are not to be
  searched with host-side python or grep: ask again with a narrower
  request, or work the text in an elisp temp buffer.  Content that
  originated in the container's world is worked there.

## Lisp-side notes

- **SLIME REPL buffers** (`*slime-repl allegro<N>*`): read them with
  `(buffer-string)` -- `buffer-substring-no-properties` returns empty
  strings there.  Send a form with `(goto-char (point-max))`, `insert`,
  `(slime-repl-return)`; read and abort the debugger in
  `*sldb allegro<N>/M*` with `buffer-substring-no-properties` and
  `(sldb-abort)`.  Do not `sleep-for` between send and read; read the
  buffer and look for the prompt.
- **Modern-mode Allegro** (the guild workshops): `(readtable-case
  *readtable*)` is `:preserve`, so keywords are case-sensitive (`:email`
  ≠ `:EMAIL`); intern strings as keywords without upcasing.  This
  bites JSON parsing and any dynamic symbol creation.
- **AllegroServe names**: `*response-method-not-allowed*` (not
  `*response-not-allowed*`); `gwl:with-all-servers` iterates over
  `gwl:*http-server*` and `gwl:*https-server*`; use `gwl:*http-server*`,
  not `net.aserve:*wserver*` (Franz took the default for their web
  IDE).  `do-external-symbols` when unsure.
- **`*print-readably*` in error handlers**: Allegro's `dumplisp` and
  build processes can signal conditions holding unprintable objects;
  bind `*print-readably*` to nil before printing a condition.
- **LHTML**: GDL's `with-lhtml-string` takes both the old htmlgen form
  `((:a :href "url") "Text")` and the native `(:a :href "url" "Text")`;
  write new code in the native form.
- **SLIME development in a Gendl room**: after `slime-connect`,
  `(load-quicklisp)`, push project directories onto
  `ql:*local-project-directories*`, `(setq gwl:*developing?* t)`, then
  `ql:quickload` the systems.

## webshot and webshot-clip: page captures

Baked into every image (sources `docker/webshot`, `docker/webshot-clip`;
node + Chrome DevTools Protocol, no puppeteer).  They resolve a browser
at run time: Debian chromium in the gui/full images,
chrome-headless-shell in the default ones (in -lite,
`skewed-install headless-shell` provides it).

```bash
webshot URL [out.png] [WxH] [--mobile] [--settle=MS] [--scale=N] [--no-viewport] [chromium flags]
webshot-clip URL SELECTOR [out.png] [WxH] [pad] [--mobile] [--settle=MS] [--scale=N] [chromium flags]
```

- **WxH is a real viewport**, set with `Emulation.setDeviceMetricsOverride`
  before navigation, so page JS and CSS both see the width asked for;
  `--mobile` also flags the viewport mobile and emulates touch.
  (Before 2026-08-15 webshot was `chromium --screenshot --window-size`,
  which gave a 500x701 viewport when asked for 390x844: the PNG looked
  right and pure CSS mostly resolved, but load-time JS measured 500 px
  and touch was never emulated.  JS-driven responsive layouts captured
  before then deserve a second look.  `--no-viewport` reproduces the
  old geometry; `docker/webshot-viewport-probe.html` shows what a
  capture sees.)
- Captures wait for the load event, then settle (3.5 s default) so
  x3dom and ajax finish; WebGL renders through SwiftShader, so 3D
  viewports appear.
- Every run gets a throwaway profile, no disk cache and a DevTools port
  of its own (port 0 + `DevToolsActivePort`), so a file you are editing
  is never served stale and two runs never attach to each other's
  browser.
- `webshot-clip` captures the first element matching SELECTOR, below
  the fold included (`captureBeyondViewport`), PAD px around it.  Exit
  codes: 1 bad arguments, 2 selector not found or zero area, 3 capture
  failure, 4 no browser.
- **Virtual hosts**: resolve them inside chromium:
  ```bash
  webshot "http://genworks.localhost/demo/staircase" /projects/tmp-shots/s.png 1440x2200 \
    --host-resolver-rules="MAP genworks.localhost cyclops"
  ```
- **Write captures under `/projects`** (`/projects/tmp-shots/` by
  convention) and read them from the host's `~/projects/...`: no
  `docker cp`, no base64 round trip.
- Reach for these before hand-rolling `chromium --headless`.  They
  capture any web page, not only Gendl's; for Gendl geometry itself the
  Gendl rooms have native emitters (`render_png`, `with-format` to
  PDF/PNG/SVG/DXF) -- "Geometry & Image Output Channels" in the bridge's
  `get_docs(id="claude-gendl-md")`.
- Still open: driving a real pointer or touch drag over CDP `Input`
  events and asserting the resulting geometry (`/projects/tmp/split-drag-test.js`
  is the start of it), to prove a page responds rather than only renders.

## Long-running dev processes

Watchers (the tailwind CSS watcher, for one) run as asynchronous Emacs
processes, visible to the user and never blocking the loop:

```elisp
(start-process "tailwind-demos-watch" "*tailwind-demos-watch*"
               "sh" "-c" "cd /projects/apps/tailwind && exec npm run dev:demos")
```

They die with the daemon: restart them after any restart.  Node and npm
live only in the ready room, never in the Gendl or GDL rooms, which
consume compiled artifacts from `/projects`; prefer the room's node to
the host's for `/projects` JS (`(lisply-shell-bounded "node --check FILE" 15)`).

## Showing the user a buffer

When something deserves reading in Emacs rather than in chat -- a
draft, a review skeleton, a diff -- put it in a buffer and raise it in
the user's attached client frame.  An rmax session is an emacsclient
frame on the shared daemon, so the buffer is already in their Emacs;
the trick is selecting THEIR frame, not the daemon's initial one:

```elisp
(let ((buf (get-buffer-create "*name the user will recognize*")))
  (with-current-buffer buf
    (erase-buffer)
    (org-mode)                          ; org outlines fold nicely
    (insert "..."))
  (with-selected-frame
      (seq-find (lambda (f) (frame-parameter f 'client)) (frame-list))
    (switch-to-buffer buf)
    (goto-char (point-min))))
```

- The daemon's own frame has `client` nil; an attached emacsclient
  frame has `client` set and a `tty` parameter.  If no client frame
  exists, create the buffer and say so -- the user can `C-x b` to it
  after attaching.
- With several client frames, prefer the one whose `tty` matches where
  the user says they are, or tell them the buffer name.
- Give buffers stable, greppable names (`*canon rebuild: ...*`).
