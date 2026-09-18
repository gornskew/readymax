# The Suit's Hatch: the Lisply backend in your own host Emacs

This is the *space suit* posting with the hatch open: no ship, no
lifepod, no vat. A Captain already living on your own machine — your
own running Emacs, wearing the Readymax scrolls — opens his Lisply
hatch, and a cyborg (through the Protocol Officer, and so any MCP
client) drives him directly.

It is powerful and it is a footgun. Read the warning before opening
the hatch.

## ⚠️ Security: this hands an LLM your machine

The Lisply server evaluates **arbitrary Emacs Lisp** sent by any MCP
client that can reach it. Emacs Lisp can read and write your files,
run shell commands, and control your desktop. So enabling this on
your host Emacs effectively grants the connected LLM **full access to
your machine with your user privileges** — closer to handing an
autonomous agent the keys to your computer than to a scoped,
read-only tool.

The shipboard path (`./basilisk up`) and the lifepod (`docker/run`)
exist precisely to sandbox this: the agent gets a throwaway Emacs in
a container with only the directories you chose to mount. **The host
path does not sandbox anything.** Enable it only on a machine and
account where that trade-off is acceptable, keep the listener on
loopback unless you have a specific reason not to, and prefer the
container path whenever it will do.

By default the host server binds to `127.0.0.1` (loopback), so it is
not reachable from other machines — only from MCP clients running on
the same host.

## Opening the hatch

Two ways, both sealed by default.

### For one session, from inside Emacs

`M-x lisply-enable-host-server`. The first time, the Captain shows
the warning above and asks you to confirm; he then offers to remember
your acknowledgment so he does not ask again. On confirmation he
makes sure `simple-httpd` is installed, opens the hatch on
`127.0.0.1:7080`, and echoes a ready-to-use hail for the Officer in
the minibuffer and `*Messages*`.

To open it at every waking without the prompt, set the
acknowledgment in your own scroll:

```elisp
(setq lisply-host-server-enable t
      lisply-host-server-risk-acknowledged t)
```

### Standing, at suit-up

```bash
./setup --with-mcp
```

This prints the same warning at the shell and requires you to type
`YES` before it does anything. On confirmation it appends the two
settings above to `~/.emacs-local` (your own scroll, read last at
every waking, never committed), so your host Emacs opens the hatch on
its own from then on. It is idempotent and honors `--dry-run`.

To seal it again later, delete those two lines from `~/.emacs-local`
(or set `lisply-host-server-enable` to nil) and restart Emacs.

## Posting an Officer

The steps above open the Captain's side. The Officer — the
[Cyborg Whisperer](https://github.com/gornskew/cyborg-whisperer)
middleware that an MCP client actually launches — is a **separate
scroll chest**. The room's castings carry him aboard already; in the
suit you keep your own copy, checked out to the **branch matching
your Readymax checkout** (the casting does exactly this, cloning by
branch). Mismatched branches can mean mismatched dialect or flags, so
keep them aligned.

`./setup --with-mcp` does this for you: it clones the Cyborg Whisperer
next to your Readymax clone (into a sibling directory named
`lisply-mcp`, the middleware's elder name, which its own defaults
still answer to), checks out the branch matching your current
Readymax branch (falling back to `master` when that branch does not
exist upstream), and runs `npm ci --omit=dev`.

By hand:

```bash
# from the directory that contains your readymax checkout
branch="$(git -C readymax rev-parse --abbrev-ref HEAD)"   # e.g. devo
git clone --depth 1 --branch "$branch" \
  https://github.com/gornskew/cyborg-whisperer.git lisply-mcp \
  || git clone --depth 1 --branch master https://github.com/gornskew/cyborg-whisperer.git lisply-mcp
cd lisply-mcp/scripts && npm ci --omit=dev
```

You need Node.js (the castings build against v24; any recent LTS with
npm works) and the `commander` dependency that `npm ci` installs.

## Hailing the hatch from an MCP client

Point the Officer at the open hatch — the loopback host and the
hatch number. He connects to the Captain directly; he starts nothing
himself:

```bash
node /path/to/lisply-mcp/scripts/mcp-wrapper.js \
  --server-name emacs-host \
  --backend-host 127.0.0.1 --http-host-port 7080
```

Note the flag: the Officer dials `--http-host-port` (default 9081)
when the backend host is loopback, and `--http-port` only for a
resident reached across the ship's lines. The suit's hatch is 7080,
so `--http-host-port 7080` is the one.

In a Claude Desktop registry that becomes, for example:

```json
{
  "mcpServers": {
    "emacs-host": {
      "command": "node",
      "args": [
        "/path/to/lisply-mcp/scripts/mcp-wrapper.js",
        "--server-name", "emacs-host",
        "--backend-host", "127.0.0.1",
        "--http-host-port", "7080"
      ]
    }
  }
}
```

On Windows with the Captain living in WSL, set `"command": "wsl"` and
make the node binary the first arg, e.g.
`"args": ["/usr/bin/node", "/home/you/projects/lisply-mcp/scripts/mcp-wrapper.js", ...]`.

## Is anyone home

With the hatch open, a plain hail should answer:

```bash
curl http://127.0.0.1:7080/lisply/ping-lisp
```

## Sealing it

`M-x emacs-lisply-stop-server` closes the hatch for the current
session. Removing the opt-in from `~/.emacs-local` (or unsetting
`lisply-host-server-enable`) keeps it sealed at the next waking.

## Settings

- `lisply-host-server-bind-address` (default `"127.0.0.1"`) — the
  address the hatch opens on. A routable address exposes arbitrary
  code execution to your network; change it only if you understand
  that.
- `emacs-lisply-port` (default `7080`) — the hatch number.
- `lisply-host-server-enable` / `lisply-host-server-risk-acknowledged`
  — the opt-in and the acknowledgment described above.
