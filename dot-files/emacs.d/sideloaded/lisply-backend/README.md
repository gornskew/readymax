# The Captain's Hatch — the Emacs Lisply backend

This pouch holds the ready room's own **Lisply backend**: the hatch
through which the Captain (the long-running Emacs daemon that keeps
the room) answers callers who speak the Lisply dialect. Open the
hatch and any caller may hand the Captain an incantation in his own
rune arrangement (Emacs Lisp), have it worked, and read back what
came of it. The **Protocol Officer** (the
[Cyborg Whisperer](https://github.com/gornskew/cyborg-whisperer)
middleware) stands at this hatch and speaks MCP — the
Muster-and-Conduct Protocol, in which he musters each arriving cyborg
and conducts it to the crew member it came to see — on the far side;
this pouch is the near side, the room's own dialect.

The dialect itself is small: HTTP, the Hatch-To-hatch Transfer
Protocol, a plain hail from one hatch to another, carrying JSON. Any
resident who answers the same dialect — the First Officer and the
Ship's Engineer in the Gendl rooms do — gets the same Officer and the
same reception. What a compliant hatch must answer is written in the
Officer's own scroll,
[BACKEND-REQS.md](https://github.com/gornskew/cyborg-whisperer/blob/devo/BACKEND-REQS.md).

## What the hatch answers

The Captain listens on hatch 7080 inside the room (hatch 7081 on the
dock when the lifepod is set down with `docker/run`; see below). The
paths, all under the `/lisply/` prefix:

| path | what it does |
|------|--------------|
| `/lisply/ping-lisp` | is anyone home — answers `pong` |
| `/lisply/lisp-eval` | POST an incantation; the Captain works it and answers with the result and whatever it printed |
| `/lisply/tools/list` | the tools the Officer will grant a cyborg: `ping_lisp`, `lisp_eval`, and `lisply_search` (the chart locker, when a corpus is aboard) |
| `/lisply/lisply-search` | POST a query against the chart locker — the pre-packed search index (see the Readymax README, *The Chart Locker*) |
| `/lisply/docs/list`, `/lisply/docs/<id>` | the ship's education packets, served on demand (`claude-md` is this backend's own; `main-claude-md` the repository's) |
| `/lisply/specs` | what this hatch supports, for the Officer's briefing |
| `/lisply/resources/list`, `/lisply/prompts/list` | on the books, empty for now |

The prefix and the two main path names are settings
(`emacs-lisply-endpoint-prefix`, `emacs-lisply-ping-endpoint`,
`emacs-lisply-eval-endpoint`) so a hatch can be renamed to match an
Officer configured differently; leave them alone unless you have.

## Hailing the hatch yourself

The Officer is the usual caller, but the hatch answers a plain hail
from anyone aboard. From a shell inside the room:

```bash
# is anyone home
curl http://localhost:7080/lisply/ping-lisp

# an incantation
curl -X POST http://localhost:7080/lisply/lisp-eval \
  -H "Content-Type: application/json" \
  -d '{"code": "(+ 1 2 3)"}'

# one that also prints
curl -X POST http://localhost:7080/lisply/lisp-eval \
  -H "Content-Type: application/json" \
  -d '{"code": "(progn (princ \"a message\") (* 6 7))"}'
```

From the dock, with the lifepod set down, hail hatch 7081 instead.
Never hail the room's own hatch from *inside* an incantation the
Captain is working: he is waiting on you, and you on him.

## What comes back

Every answer is JSON. A worked incantation answers

```json
{"success": true, "result": "6", "stdout": ""}
```

and one that failed answers

```json
{"success": false, "error": "the message"}
```

Results are what `format "%s"` makes of them: strings keep their
text, lists their printed form, `t` and `nil` are themselves. There
is no debugger on this hatch — Emacs Lisp has nothing like the Common
Lisp restarts a Gendl room can offer — so an error is the whole story.

## Where the hatch stands, posting by posting

- **Aboard ship** (`./basilisk up` in a Basilisk clone): nothing to
  do. The room comes up with the hatch open on the ship's lines and
  the Officer at his post, and `./basilisk up` writes the client
  registries that tell an arriving cyborg where he stands.

- **In the lifepod** (`docker/run` from a clone of these scrolls):
  the same, freestanding — the hatch is open inside the pod and
  reachable from the dock on hatch 7081 (`-p` chooses another). The
  Officer is not in the pod; point one at the dock's hatch:

  ```bash
  node /path/to/cyborg-whisperer/scripts/mcp-wrapper.js \
    --server-name readymax --backend-host 127.0.0.1 --http-host-port 7081
  ```

- **In the space suit** (`./setup`, the Readymax scrolls worn by a
  Captain living on your own machine): the hatch is **sealed by
  default**, and for good reason. Read
  [docs/HOST_EMACS_MCP.md](../../../../docs/HOST_EMACS_MCP.md)
  before opening it: on your own machine an open hatch grants
  arbitrary code execution with your user's rights, and nothing
  sandboxes it. `M-x lisply-enable-host-server` opens it for one
  session after a warning you must answer; `./setup --with-mcp`
  makes the opening standing. Either way it binds to loopback only
  (`lisply-host-server-bind-address`).

> **Warning:** wherever the hatch stands, `lisp_eval` is arbitrary
> code execution by design. In the room that is the point — the room
> is the sandbox, and nothing valuable is stowed aboard unless you
> mount it. On a host it is your machine.

Loading the hatch by hand, in any Emacs with `simple-httpd`
installed (`M-x package-install RET simple-httpd RET`):

```elisp
(add-to-list 'load-path "/path/to/lisply-backend/source/")
(load "http-setup")
(load "endpoints")
(emacs-lisply-start-server)   ; opens `httpd-host':`emacs-lisply-port' (7080)
```

`emacs-lisply-stop-server` closes it; `emacs-lisply-server-status`
says which. In Readymax none of this is typed: `etc/lisply-config.el`
wraps it behind `lisply-enable-host-server` and the warning.

## The scrolls in this pouch

- `source/http-setup.el` — the hatch itself: the listener, the
  request and answer plumbing
- `source/endpoints.el` — every path above, and the pre-eval lint
  that refuses an unbounded child process (see `CLAUDE.md`, *the
  guard*)
- `source/lisply-shell-guard.el` — that guard, and
  `lisply-shell-bounded` / `lisply-shell-async`, the sanctioned ways
  to run a child from an incantation
- `source/lisply-search.el`, `lisply-search-config.sexp` — the chart
  locker: the index, and the list of what a casting packs into it
- `source/lisply-edit-helpers.el`, `source/lisply-sexp-write.el` —
  helpers for cyborgs editing scrolls through the hatch
- `CLAUDE.md` — the education packet a cyborg is handed: how to read
  and edit scrolls safely in a room it shares with a biological, the
  shared-buffer footgun, paredit, the guard, and the search tool's
  parameters

## License

AGPL-3.0-or-later, © 2026 Gornskew Enterprises — the same terms as
the Readymax repository this pouch belongs to, compatible with GNU
Emacs's own GPL-3.0. The AGPL adds one thing to the GPL: a
modification used over a network must be offered to those it serves.
