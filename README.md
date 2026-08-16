# Skewed Emacs: Ready-to-go, Opinionated Emacs Environment that supports MCP for elisp and Common Lisp

Skewed Emacs is a containerized Emacs development environment with a
package-rich, native-compiled emacs elisp user configuration, that
comes preconfigured and ready to use with the lisply-mcp Model Context
Protocol (MCP) middleware, enabling AI agents to interact directly
with Emacs and other compliant Lisp REPLs for automated development
workflows.

The Emacs configuration part could arguably be decomposed into a
separate repository, but on the other hand, in the interest of
one-stop-shopping, here we are.

![Skewed Emacs Logo](img/skewed-colorful.png)

## Why Skewed Emacs? The Inversion

Most Emacs+AI projects put the agent *inside* Emacs: Emacs is the UI,
and an LLM is wired into a buffer. Skewed Emacs inverts that: it puts
**Emacs inside the agent** — Emacs (and any other Lisply-compliant
Lisp environment, such as Gendl/Common Lisp) becomes a set of MCP
tools that *any* agent can drive: Claude Desktop, Claude Code, Cursor,
Grok Build, Gemini CLI, Codex, LM Studio, or your own MCP client.

This repo is the Emacs half of that: the configuration, and the lisply
backend, that make Emacs answerable as a tool in the first place. The
delivery vehicle — containerized Emacs and Lisp backends, a fleet, and
generated client configs, one command — is **Basilisk**, and the same
inversion argued as a *systems* claim rather than an Emacs one lives in
[the Basilisk README](https://github.com/gornskew/basilisk). The table
below is the Emacs-side comparison; neither page restates the other.

| | Where the agent lives | Emacs's role | MCP role | What ships in the box |
|---|---|---|---|---|
| [claude-code-ide.el](https://github.com/manzaltu/claude-code-ide.el) | In Emacs (Claude Code CLI) | UI / IDE for the agent | Emacs↔Claude bridge for IDE features | elisp package |
| [agent-shell](https://github.com/xenodium/agent-shell) | In an Emacs buffer (via ACP) | UI hosting agent sessions | n/a (uses ACP) | elisp packages |
| [aidermacs](https://github.com/MatthewZMD/aidermacs) | In Emacs (Aider subprocess) | UI for pair-programming | n/a | elisp package (+ aider) |
| [emigo](https://github.com/MatthewZMD/emigo) | In Emacs (agentic elisp+python) | UI + agent host | n/a | elisp package |
| [gptel](https://github.com/karthink/gptel) + [mcp.el](https://github.com/lizqwerscott/mcp.el) | In Emacs | UI; Emacs is the MCP *client* | consumes external MCP servers | elisp packages |
| **skewed-emacs + lisply-mcp** | **Anywhere — any MCP client** | **Emacs is the MCP *server* (a tool the agent uses)** | **serves `lisp_eval`/`http_request`/`ping` for Emacs *and* Common Lisp backends** | **full stack: containers, backends, client configs, terminal AI CLIs** |

These are complementary, not rivals: the in-Emacs tools give *you* an
agent while you edit; skewed-emacs gives *agents* a live Lisp machine
to think with. You can run both at once — the full container images
even ship Claude Code, Gemini CLI, and Codex preconfigured against the
in-container MCP servers, so the agent you talk to in a terminal is
itself wired to the Emacs and Gendl images it lives beside. See a real
first session in
[docs/FIRST_SESSION_TRANSCRIPT.md](docs/FIRST_SESSION_TRANSCRIPT.md),
where a fresh agent builds a parametric staircase in Gendl through MCP.

<!-- demo GIF: record per docs/DEMO_GIF.md, save as img/demo.gif, then
     uncomment:
![30-second demo](img/demo.gif)
-->



## What Will I Find Here?

This Skewed Emacs repository houses two assets:

1.  a ready-to-setup local Emacs configuration, including the lisply
    backend that makes Emacs answerable over MCP. This can be used on
    its own, on your host, without (2) if desired.

2.  a Dockerfile for building a containerized emacs server with the
    skewed-emacs configuration (as per (1) above) preïnstalled for the
    built-in `emacs-user` user account.

There used to be a third: the container composition framework that
spins this image up alongside Gendl backends and other helper
containers. It is now **Basilisk**, in [its own
repository](https://github.com/gornskew/basilisk).

It got its own name because one name for three things was one name too
few: "restart skewed-emacs" is genuinely ambiguous between *the editor*
and *the whole fleet on this box*, and those are very different
requests. As of 2026-08-15 it has its own repo to match, which is what
the naming was always pointing at. **Basilisk** is the stack —
`./basilisk up`, from a Basilisk clone — while `skewed-emacs` keeps
meaning the Emacs configuration and the image that carries it.

In Basilisk's terms this repo is the **Captain**: one fitting among
several, referenced by image name exactly as `cyclops` is. A Basilisk
carries a Captain by default and it is recommended that the Captain be
skewed-emacs or a derived species — but the catalogue references fittings
by image, not by repo, and nothing here has to be present for a stack to
come up.

See **BASILISK.md in the Basilisk repo** for the naming, the crew, and
where this sits in the Gornskew Enterprises lineup.


## Two Ways to Use This

**Option A — Containerized Runnings (recommended):** clone Basilisk and
run `./basilisk up` there.

This pulls and spins up several Docker containers and leaves your host
machine untouched except for two shell functions (`eskew`/`egskew`)
made available in your shell (bash, zsh, ksh, or plain sh). You do not need to run `./setup`. You
do not need Emacs installed on your host. You do need docker installed
on your host.

**Option B — Local Installation:** run `./setup`.  Installs the Skewed
Emacs dot-files and Emacs configuration directly into your host
account (`~/.emacs.d`, `~/.bash_profile`, etc.). Use this if you want
the Skewed Emacs configuration in your own personal host Emacs. Does
not start any containers. MCP support is **off by default** on the host,
but you can opt in — either with `./setup --with-mcp` or, from inside
Emacs, `M-x lisply-enable-host-server` — to let an MCP client (and thus an
LLM) drive your host Emacs. Read [docs/HOST_EMACS_MCP.md](docs/HOST_EMACS_MCP.md)
first: on the host this grants arbitrary code execution on your machine and
is not sandboxed the way the container path is. You do need
emacs already installed on your host for it to make sense to use this.

**Both together:** you can do both — run `./setup` to get the
configuration in your host Emacs, *and* run `./basilisk up` to also
have the full container orchestra with Gendl backends and MCP
integration. They are each idempotent as well as independent from each
other.

---


## Features

### Native Emacs Config

- **Pre-populated landing `*dashboard*` detecting and reporting on
    project files, services stati, links to org-mode daily-focus,
    launch slime against available CL backends etc.

- **Preïnstalled, pre-native-compiled third-party packages:**
  - [Slime](https://en.wikipedia.org/wiki/SLIME) for Common Lisp / Swank
  - Paredit-mode, Flycheck-mode, Company-mode
  - Magit, Org-mode
  - Doom Color Themes, theme switching functions

- **Lisply-MCP (Model Context Protocol) Elisp Backend:**
  - allows AI agents to drive your contained emacs thru standard lisply-mcp.
  - Defined & sideloaded locally from
    `dot-files/emacs.d/sideloaded/lisply-backend/`


- **Additional Container-defined Infrastructure** (see Containerized Runnings below)
  - Local container image defined in `docker/Dockerfile` and `docker/build`.
    Images built by Gornskew HQ are pushed to tagged `gornskew/skewed-emacs` versions at Dockerhub.
  - Running that image alongside Common Lisp backends and other helper
    containers is Basilisk's job, not this repo's — see
    [Basilisk](https://github.com/gornskew/basilisk).
  - Docker Compose orchestration includes built-in lisply-mcp
    middleware to provide consumer-facing MCP services for
    skewed-emacs itself plus any other lisply-compliant backends.


## Containerized Runnings (recommended)

Everything runs inside Docker containers — **you do not run `./setup`,
install dot-files, or modify your Emacs configuration on the host.**
Your host machine stays clean. The only intentional side effect is that
`./basilisk up` makes `eskew` and `egskew` available in your shell.

### Requirements

 - Git
 - Docker — see [macOS-Specific Section](#macos-specific-section) if on a Mac

### Quickest Start — clone Basilisk and bring the stack up

**The stack lives in its own repo now.** Running a skewed-emacs container
— even a single-container one with nothing but the Captain aboard — goes
through **Basilisk**, and that is the only supported way. This repo no
longer carries compose files or startup scripts.

```bash
git clone <basilisk>          # gitlab.genworks.com:gornskew/basilisk
cd basilisk
./basilisk up
```

Your `~/projects/` directory is mounted at `/projects` in the container
and created if missing.

There used to be a no-clone path here: `basilisk` downloaded on its
own would create a container from the skewed-emacs image and extract
`docker-compose.yml`, `generate-env.sh` and `mcp/` out of the repo
snapshot baked inside it. That is **gone** (2026-08-15). It only ever
existed because the stack machinery lived in this repo and therefore in
this image; now that the shipyard is its own repo, cloning it is both
simpler and honest. An image is a crew member's quarters, not a delivery
vehicle for the shipyard.

Once an AI client is connected, paste
[`docs/PROJECT_INSTRUCTIONS.md`](docs/PROJECT_INSTRUCTIONS.md) into a
Claude Desktop Project's custom instructions (or your `CLAUDE.md` /
`AGENTS.md`) as standing session instructions, and/or use
[`mcp/opening-prompt.md`](https://github.com/gornskew/basilisk/blob/devo/mcp/opening-prompt.md)
from the Basilisk clone as a ready-made first message.

(That link goes to Basilisk deliberately. An `mcp/` still exists in this
repo, left behind by the split and slated for removal — it is a stale
copy, and its `claude_desktop_config.json` already points at a
`mcp-exec` path that no longer exists. The live one is Basilisk's.)



### Initial Setup (full clone)

1. Clone this repo anywhere you like — `~/skewed-emacs` is fine:

```bash

   cd
   git clone https://github.com/gornskew/skewed-emacs
   cd skewed-emacs

```

   Cloning under `~/projects/` instead is useful only if you want to
   hack on skewed-emacs internals from inside the container (the host
   `~/projects/` directory is mounted at `/projects` there). For just
   *using* skewed-emacs to work on other projects, the clone location
   doesn't matter — the running container never needs the clone.

2. Start the default container orchestra:

```
   ./basilisk up
   
```

By default this pulls missing images only (no overwrites of local builds).
To force pulling the latest images, use:

```
   ./basilisk up --pull
```

Services are defined in `docker-compose.yml` and any other `.yml` files
**in the Basilisk clone** — `docker-compose.yml` is generated there from
`services.sexp`, Basilisk's single source of truth, while additional
`.yml` overlays are installed alongside it by each host stack's
`./install`.

After the stack starts, `eskew` and `egskew` should be available
immediately and henceforth in any new bash shells on your host — these
are the **only** commands you need from the host to drive the
containerized Emacs:

- `eskew` — terminal emacsclient (attaches in your current terminal)
- `egskew` — graphical emacsclient (opens a new window)

`./basilisk up` writes these to
`~/.config/skewed-emacs/shell-functions.sh` and adds a single source
line to your shell's RC file (`~/.bashrc`, `~/.zshrc`, `~/.kshrc`, or
`~/.profile`, depending on your login shell). This is the **only
modification** made to your host environment. Open a new terminal (or
source that RC file) to activate them.


After you are in, see the "Getting Started" section near the top of
the default landing dashboard.

### Connecting an MCP client (Claude Desktop and friends)

**This belongs to Basilisk, not here.** The generated client config
registers *every* server on the roster — `skewed-emacs`, `gendl-ccl`,
`gendl-sbcl`, and whatever the overlays add — and this repo knows about
exactly one of those. `./basilisk up` writes the configs into the
Basilisk clone's `mcp/`; see **docs/CLAUDE_DESKTOP.md in the Basilisk
repo** for the walkthrough on Linux, macOS and Windows.

If MCP went quiet on you around the 2026-08-15 repo split, the usual
cause is a config generated before it, still pointing at
`…/skewed-emacs/mcp/mcp-exec` — a path that no longer exists.
Regenerate from a Basilisk clone and re-copy.

The MCP story that *does* belong to this repo is the host one: running
the lisply backend in your own Emacs, no containers involved. See
[docs/HOST_EMACS_MCP.md](docs/HOST_EMACS_MCP.md), and read it before
enabling — on the host this grants arbitrary code execution and is not
sandboxed the way the container path is.

### Pulling Updates

Keep the image fresh with `./basilisk up --pull` (or `PULL_ALWAYS=1`)
from your **Basilisk** clone; plain `./basilisk up` pulls missing images
only. Bring the composition down before pulling either repo, in case the
pull changes compose config that a running stack would shut down
against. The full recipe is in the Basilisk README.



### AI Terminal Agents (Claude Code, Gemini CLI, Codex, Grok)

The `full` image variant includes four AI terminal agents, accessible
from any shell inside the container (e.g. via `M-x vterm`):

| Agent | Launch Command | Auth Method |
|-------|---------------|-------------|
| Claude Code | `claudly` | Interactive OAuth (opens URL to paste in browser) |
| Gemini CLI | `geminly` | Interactive OAuth (opens URL to paste in browser) |
| OpenAI Codex | `codexly` | Interactive login or `OPENAI_API_KEY` env var |
| Grok Build (xAI) | `grokly` | Interactive login (`grok login`) or `GROK_DEPLOYMENT_KEY` |

**First-time authentication:**

Each agent requires a one-time login. Launch the agent from a
terminal inside the container and follow the prompts — typically
you'll be given a URL to open in your browser.

```bash
# In an eat or vterm shell inside skewed-emacs:
claudly    # Follow the OAuth URL prompt
geminly    # Follow the Google OAuth prompt
codexly    # Follow the login prompt, or set OPENAI_API_KEY
grokly     # Follow the login prompt (stores ~/.grok/auth.json)
```

**MCP wiring (automatic):**

`./basilisk up` merges service MCP configs and installs them for
each agent:

- Claude / Gemini: `/tmp/merged-mcp-config.json` (JSON `mcpServers`)
- Codex: managed block in `~/.codex/config.toml`
- Grok: managed block in `~/.grok/config.toml` (`[mcp_servers.*]`)

In-container servers use `node …/mcp-wrapper.js` against the compose
network hostnames (e.g. `skewed-emacs:7080`, `gendl-ccl:9080`).

**Credential persistence:**

Your credentials are stored in dotfiles that are volume-mounted from
your host, so they survive container restarts:

- Claude Code: `~/.claude/.credentials.json`
- Gemini CLI: `~/.gemini/oauth_creds.json`, `~/.gemini/google_accounts.json`
- Codex: `~/.codex/auth.json`
- Grok: `~/.grok/auth.json` (only auth is mounted — not the whole
  `~/.grok` tree, so the image-baked CLI binary stays intact)

The `basilisk` script should automatically create these as empty
placeholder files on your host if they don't exist yet.

**Using the `lite` image:**

If you use `EMACS_IMAGE_VARIANT=lite`, these agents are not installed.
An external host MCP consumer such as Claude Desktop can still be
used, via the MCP config generated at `./basilisk up` time and
written to the Basilisk clone's `mcp/`.


### Language Stack Policy (Bring Your Own Runtimes)

The shipped containers deliberately keep a lean, Lisp-centric runtime:
Emacs (Emacs Lisp), Common Lisp (free Gendl kernels on CCL and SBCL),
and Node.js (which powers the lisply-mcp middleware and the bundled AI
TUIs). Notably, **no Python ships in any skewed-emacs image** — the
Docker build uses it transiently in the builder stage (a GLib
dev-header dependency of pdf-tools), but runtime images are
Python-free by design.

Need Python, Ruby, or any other runtime? Bring it in as a sidecar
container via a Docker Compose overlay: drop an additional `.yml` file
beside `docker-compose.yml` defining your service, and `./basilisk
up` merges it into the stack automatically, on the shared network,
visible to Emacs and the other containers. For example:

```yaml
# python-overlay.yml — any extra .yml in this directory is merged
services:
  python-sidecar:
    image: python:3-slim
    container_name: python-sidecar
    command: sleep infinity
    volumes:
      - ${PROJECTS_DIR}:/projects
    networks:
      - skewed-network
```

Files matching `*-overlay.yml` are gitignored, so local additions
never collide with repo updates. The same mechanism supports
additional Lisply backends — alternative Lisp or Scheme
implementations speaking the lisply protocol plug in as peer services,
just as the commercial GDL overlays below do.

### Stack operation lives in Basilisk

Everything about running, extending and unwedging a stack is documented
where the stack now lives — the [Basilisk
README](https://github.com/gornskew/basilisk), under **Running it**:

- **Supplemental service overlays** — commercial Genworks GDL (NURBS, on
  Allegro CL) for licensed users; clone the overlay repo, `./install`
  into the Basilisk clone, `./basilisk up`
- **Custom projects directory** — `PROJECTS_DIR=/path ./basilisk up`
- **Several instances on one box** — `BASILISK_INSTANCE` / `BASILISK_PORT_OFFSET`
- **Pulling updates**, and **troubleshooting** dangling containers and
  networks

It is documented there rather than duplicated here on purpose: the
instructions that used to live in this section told you to `cd
~/projects/skewed-emacs` and run `./basilisk`, which has not been
possible since the split.

## Windows-Specific Section

### Emacs-slanted Keyboard Tweaks for Windows

Skewed-emacs uses the traditional Emacs keybindings by default, which
make heavy use of the Control key ("C-" in emacs parlance). For this
reason, it can be convenient to bind a more ergonomic key such as
CapsLock to Control, on modern keyboards. (Older keyboards had Control
in the place of current CapsLock). The Skewed Emacs repository
contains [instructions](windows-keybindings/README.md) for mapping
CapsLock to Control (with or without WSL) using a free program called
SharpKeys.

If you enjoy the traditional emacs keychords and want more of them in
your life, you can replicate those across most Windows programs using
the free AutoHotkey program, for which we bundle a config, also
described in the [instructions](windows-keybindings/README.md).

## macOS-Specific Section

### macOS Prerequisites

`basilisk` is pure POSIX sh — no special shell is required on macOS.
The only requirement is **Docker Desktop**.

#### Install Docker Desktop

Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
if you haven't already, then confirm:

```bash
docker info   # should print engine info without errors
```

Once Docker is running, `./basilisk up` will work normally.

---




## Local Installation

This section is for users who want to install the Skewed Emacs dot-files
and Emacs configuration **directly on their host machine**, without
Docker. It is independent of Containerized Runnings — do not run
`./setup` as part of a container-based setup; it is not needed and
not intended for that use case.


1. Make a `~/projects/` directory if you don't already have one:

```bash

    cd
    mkdir -p projects/
    cd projects/
    
```

2. Clone this repo into `~/projects/`:

```bash

   git clone https://github.com/gornskew/skewed-emacs 
   cd skewed-emacs

```


3. Run the setup script:
   ```bash
   
   cd ~/projects/skewed-emacs
   ./setup
   
   ```
   
   The setup script will create symbolic links of the salient
   "dot-files" (hidden files starting with `.` pointing to the
   corresponding files in the cloned repo, for example:
   
    `~/.emacs.d -> ~/skewed-emacs/dot-files/emacs.d`
   
   If you already have any of these dot files existing (as links or
   actual files/directories), the existing files will be backed up
   with names appended with `-pre-skewed-emacs`.


### Optional options for `setup`

- `--dry-run`: Shows what would happen without making any changes
- `--shadow-suffix=NAME` or `--shadow-suffix NAME`: Creates symlinks with a "-NAME" suffix
     (e.g., with `--shadow-suffix=test` or `--shadow-suffix test` creates ~/.emacs.d-test instead of ~/.emacs.d)
- `--scrub-shadow-suffix=NAME` or `--scrub-shadow-suffix NAME`: Removes all symlinks with the "-NAME" suffix
     (e.g., `--scrub-shadow-suffix=test` removes ~/.emacs.d-test, ~/.bash_profile-test, etc.)
- `--scrub-shadow-suffix=""` or `--scrub-shadow-suffix=`: Removes all default symlinks without a suffix (e.g., removes ~/.emacs.d, ~/.bash_profile, etc.)

The setup script will automatically detect and replace broken symlinks
and handle existing dotfiles by backing them up with a
`-pre-skewed-emacs` suffix. It also skips backup files ending with
tilde (~) in the dot-files directory.

####   Example with options:

```bash
   # Preview changes without modifying anything
   ./setup --dry-run
   
   # Install configuration files with regular names
   ./setup
   
   # Install configuration files with "-shadow" suffix
   # (useful for testing or for maintaining multiple configurations)
   ./setup --shadow-suffix=shadow
   
   # Install with a custom suffix
   ./setup --shadow-suffix=work
   
   # Preview shadow installation without making changes
   ./setup --dry-run --shadow-suffix=shadow
   
   # Preview custom suffix installation without making changes
   ./setup --dry-run --shadow-suffix=test
   
   # Remove all symlinks with the "-test" suffix
   ./setup --scrub-shadow-suffix=test
   
   # Preview removal of all symlinks with the "-shadow" suffix without making changes
   ./setup --dry-run --scrub-shadow-suffix=shadow
   
   # Remove all symlinks with the "-test" suffix and create new ones with "-work" suffix
   ./setup --scrub-shadow-suffix=test --shadow-suffix=work
   
   
```


⚠️ **Warning**: In case of malfunctions, the setup script may
               overwrite your existing `~/.emacs.d/` and
               `~/.bash_profile`. It is designed to back up this data,
               but it would still be wise to back up your existing dot
               files before running the `./setup` script.
	       


## Terminal Icons Setup 

Skewed Emacs includes a flexible icon system for the dashboard and
org-mode agenda. By default we use colorful Unicode icons. If these do
not work in your terminal, or you'd like a more muted experience, we
recommend installing a **Nerd Font** in your terminal.

### Why Nerd Fonts?

With a Nerd Font installed, you can get flat professional looking
icons rather than loud colorful gaudy ones.

### Quick Setup

1. **Download a Nerd Font** from [nerdfonts.com](https://www.nerdfonts.com/font-downloads)
   - Popular choices: **Hack**, **FiraCode**, **JetBrainsMono**, **Meslo**
   - Download the "Nerd Font" version (not the regular font)

2. **Install the font** on your system:
   - **Windows**: Right-click the `.ttf` files → "Install"
   - **macOS**: Double-click the `.ttf` files → "Install Font"
   - **Linux**: Copy to `~/.local/share/fonts/` and run `fc-cache -fv`

3. **Configure your terminal** to use the Nerd Font:
   - **Windows Terminal**: Settings → Profiles → Defaults → Appearance → Font face
   - **iTerm2**: Preferences → Profiles → Text → Font
   - **GNOME Terminal**: Preferences → Profile → Custom font
   - **Alacritty**: Edit `font.normal.family` in config

4. **Enable nerd icons in Skewed Emacs** by adding to your config or running:
   ```elisp
   (setq skewed-icons-style 'nerd)
   ```
   Or interactively: `M-x skewed-icons-set-style RET nerd RET`

### Available Icon Styles

| Style | Description | When to Use |
|-------|-------------|-------------|
| `ascii` | Pure ASCII characters | Dumb terminals, serial consoles |
| `unicode` | Safe geometric symbols | Default, works everywhere |
| `unicode-fancy` | Colorful Unicode + VS15 | Experimental, terminal support varies |
| `nerd` | Nerd Font icons | **Recommended** with Nerd Font installed |


### Troubleshooting Icons

- **Question marks in diamonds (�)**: Nerd Font not installed or not selected in terminal
- **Misaligned columns**: Switch from `unicode-fancy` to `unicode` or `nerd`
- **Icons look plain**: Install a Nerd Font and set `skewed-icons-style` to `'nerd`





## Configuration Structure

 - `dot-files/` - all dotfiles that will end up symlinked to
   your home directory if you run `./setup`
  - `emacs.d/` - Emacs configuration, to be linked to ~/.emacs.d/
    - `init.el` - Main Emacs configuration entry point
    - `etc/` - Modular configuration files
    - `sideloaded/` - Second-party packages
  - `bash_profile` - Bash configuration
  - `zshrc` - ZSH configuration


## Customization

For personal customizations that shouldn't be committed to this
repository, add them to a `~/.emacs-local` file, which will be loaded
at the end of the Emacs initialization process.




## License

This package is licensed under the GNU Affero General Public License
v3.0 (AGPL-3.0) which presumably is compatible with Gnu Emacs's GPL.

## MCP Server Registries

- [MCPHub](https://mcphub.com/mcp-servers/gornskew/skewed-emacs)
