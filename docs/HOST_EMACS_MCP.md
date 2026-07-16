# Running the Lisply MCP Server in Your Host Emacs

This is the *native, no-Docker* path: instead of talking to a sandboxed
container, you let an MCP client (and therefore an LLM) drive **your own,
already-running Emacs** through the Lisply HTTP endpoint.

It is powerful and it is a footgun. Read the warning before enabling it.

## ⚠️ Security: this hands an LLM your machine

The Lisply server evaluates **arbitrary Emacs Lisp** sent by any MCP client
that can reach it. Emacs Lisp can read and write your files, run shell
commands, and control your desktop. So enabling this on your host Emacs
effectively grants the connected LLM **full access to your machine with your
user privileges** — closer to handing an autonomous agent the keys to your
computer than to a scoped, read-only tool.

The containerized path (`./compose-dev up`) exists precisely to sandbox this:
the agent gets a throwaway Emacs in a container with only the directories you
chose to mount. **The host path does not sandbox anything.** Enable it only on
a machine and account where that trade-off is acceptable, keep the listener on
loopback unless you have a specific reason not to, and prefer the container
path whenever it will do.

By default the host server binds to `127.0.0.1` (loopback), so it is not
reachable from other machines — only from MCP clients running on the same host.

## Enabling it

There are two supported ways, both off by default.

### One-off, from inside Emacs

Run `M-x lisply-enable-host-server`. The first time, Emacs shows the security
warning and asks you to confirm; it then offers to remember your acknowledgment
so it does not ask again. On confirmation it ensures `simple-httpd` is
installed, starts the server on `127.0.0.1:7080`, and echoes a ready-to-use
client command in the minibuffer/`*Messages*`.

To make it automatic in a session without the prompt, you can pre-set the
acknowledgment in your own config:

```elisp
(setq lisply-host-server-enable t
      lisply-host-server-risk-acknowledged t)
```

### At install time, via ./setup

```bash
./setup --with-mcp
```

This prints the same security warning in the terminal and requires you to type
`YES` before it does anything. On confirmation it appends the two settings
above to `~/.emacs-local` (a user-local file that is loaded on startup and is
never committed), so your host Emacs starts the server automatically from then
on. It is idempotent and honors `--dry-run`.

To disable later, delete those two lines from `~/.emacs-local` (or set
`lisply-host-server-enable` to nil) and restart Emacs.

## Getting the middleware (lisply-mcp)

The steps above start the Emacs-side *server*. The client side — the
[lisply-mcp](https://github.com/gornskew/lisply-mcp) Node.js middleware that an
MCP client actually launches — lives in a **separate repository**. The
container images bake it in; on the host you need your own copy, checked out to
the **branch that matches your skewed-emacs checkout** (the container build does
exactly this via `git clone --branch "${GIT_BRANCH}"`). Mismatched branches
can mean mismatched protocol/flags, so keep them aligned.

`./setup --with-mcp` does this for you: it clones `gornskew/lisply-mcp` next to
your skewed-emacs repo, checks out the branch matching your current skewed-emacs
branch (falling back to `master` if that branch does not exist upstream), and
runs `npm ci --omit=dev`.

To do it by hand:

```bash
# from the directory that contains your skewed-emacs checkout
branch="$(git -C skewed-emacs rev-parse --abbrev-ref HEAD)"   # e.g. devo
git clone --depth 1 --branch "$branch" \
  https://github.com/gornskew/lisply-mcp.git \
  || git clone --depth 1 --branch master https://github.com/gornskew/lisply-mcp.git
cd lisply-mcp/scripts && npm ci --omit=dev
```

You need Node.js (the images build against v24; any recent LTS with npm works)
and the `commander` dependency that `npm ci` installs.

## Connecting an MCP client

Point the [lisply-mcp](https://github.com/gornskew/lisply-mcp) middleware at
the running host server. Because the backend already exists, use
`--no-auto-start` so the wrapper does **not** try to spin up a container, and
give it the loopback host and port:

```bash
node /path/to/lisply-mcp/scripts/mcp-wrapper.js \
  --server-name emacs-host --no-auto-start \
  --backend-host 127.0.0.1 --http-host-port 7080
```

Note the port flag: lisply-mcp dials `--http-host-port` (default 9081) when the
backend host is loopback, and `--http-port` only for containerized/networked
backends. The host server listens on 7080, so `--http-host-port 7080` is
correct here.

In a Claude Desktop config that becomes, for example:

```json
{
  "mcpServers": {
    "emacs-host": {
      "command": "node",
      "args": [
        "/path/to/lisply-mcp/scripts/mcp-wrapper.js",
        "--server-name", "emacs-host",
        "--no-auto-start",
        "--backend-host", "127.0.0.1",
        "--http-host-port", "7080"
      ]
    }
  }
}
```

## Verifying

With the server running, a plain HTTP ping should answer:

```bash
curl http://127.0.0.1:7080/lisply/ping-lisp
```

## Stopping

`M-x emacs-lisply-stop-server` stops the listener for the current session.
Removing the opt-in from `~/.emacs-local` (or unsetting
`lisply-host-server-enable`) prevents it from starting next time.

## Customization

- `lisply-host-server-bind-address` (default `"127.0.0.1"`) — the address the
  host server binds to. A routable address exposes arbitrary code execution to
  your network; change it only if you understand that.
- `emacs-lisply-port` (default `7080`) — the listening port.
- `lisply-host-server-enable` / `lisply-host-server-risk-acknowledged` — the
  opt-in and acknowledgment flags described above.
