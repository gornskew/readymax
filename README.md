<!--
Copyright © 2026 Gornskew Enterprises

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.  Distributed WITHOUT
ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.
-->

# Readymax: A packaged Emacs Environment that can make your Emacs a Model Context Protocol (MCP) Server

> **Renaming in progress (2026-08-24):** Skewed Emacs is becoming
> **Readymax**. The prose here uses the new name; repository URLs and
> image coordinates (`gornskew/skewed-emacs`) keep the old name until
> the registry renames land.

Readymax is a containerized software development environment with
a package-rich user configuration, that comes preconfigured with MCP
support for enabling AI agents to interact directly with your
container-sandboxed Emacs. 


Readymax works best as the ready room of a
[Basilisk](https://gornskew.com/basilisk/index.html)-class "space
vessel," with your Emacs daemon serving as the ship's Captain.

![Readymax Logo](img/skewed-colorful.png)

## Why Readymax? The Inversion

Most Emacs+AI projects put the agent *inside* Emacs: Emacs is the UI,
and an LLM is wired into a buffer. Readymax inverts that: it puts
**Emacs inside the agent** — Emacs (and any other Lisply-compliant
Lisp environment, such as Gendl/Common Lisp) becomes a set of MCP
tools that *any* agent can drive: Claude Desktop, Claude Code, Cursor,
Grok Build, Gemini CLI, Codex, LM Studio, or your own MCP client.

This repository is the Emacs part of that wider vision for overall
container stack management, and that wider vision lives with the
[Basilisk](https://github.com/gornskew/basilisk) project.


<!-- demo GIF: record per docs/DEMO_GIF.md, save as img/demo.gif, then
     uncomment:
![30-second demo](img/demo.gif)
-->


## What Will I Find Here?

This Readymax repository houses two assets:

1.  a ready-to-setup local Emacs configuration, including the lisply
    backend that makes Emacs answerable over MCP. This can be used on
    its own, on your host, without (2) if desired.

2.  a Dockerfile for building a containerized emacs server with the
    Readymax configuration (as per (1) above) preïnstalled for the
    built-in `emacs-user` user account.

Running that image alongside Gendl backends and other helper
containers is a third thing with its own repo:
**[Basilisk](https://github.com/gornskew/basilisk)**.  So Basilisk is
the stack (`./basilisk up`, from a Basilisk clone), and **Readymax**
refers to the Emacs configuration and the image that carries it.

In Basilisk's terms, a live container built from this repo is
typically the ship's **ready room** (Docker compose service name
`ready-room`), with the Emacs daemon inside serving as the ship's
Captain. The container itself wears a crew name minted fresh at each
raising of the ship.

See **BASILISK.md in the Basilisk repo** for more behind the rooms,
crew postings, and naming trope.


## Two Ways to Use This

**Option A — Containerized Runnings (recommended):** clone Basilisk and
run `./basilisk up` there.

That pulls and spins up several Docker containers and leaves your host
machine untouched except for two shell functions (`eskew`/`egskew`)
made available in your shell (bash, zsh, ksh, or plain sh). You do not
need to run `./setup`. You do not need Emacs installed on your
host. You do need docker installed on your host.

**Option B — Local Installation:** run `./setup`.  Installs the
Readymax dot-files and Emacs configuration directly into your host
account (`~/.emacs.d`, `~/.bash_profile`, etc.). Use this if you want
the Readymax configuration in your own personal host Emacs. Does
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

**Note:** The ./setup is meant for new Emacs installations where you
don't have or don't care about your personal setup. If you are an
experienced Emacs user with a preëxisting setup, then you can run
`./setup --dry-run` to see what it would do without touching your own
files, then wire your own init files into the standard Readymax
ones.



## Features

### Native Emacs Config

- **Pre-populated landing `*dashboard*` detecting and reporting on
    project files, services stati, links to org-mode daily-focus,
    launch slime against available CL backends etc.

- **Preïnstalled, pre-native-compiled third-party packages** (examples):
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



## Containerized Runnings (recommended)

Everything runs inside Docker containers — **you do not run `./setup`,
install dot-files, or modify your Emacs configuration on the host.**
Your host machine stays clean. The only intentional side effect is that
`./basilisk up` makes `eskew` and `egskew` available in your shell.

### Requirements

 - Git
 - Docker — see [macOS-Specific Section](#macos-specific-section) if on a Mac

### Quickest Start — clone Basilisk and bring the stack up


```bash
git clone https://github.com/gornskew/basilisk
cd basilisk
./basilisk up
```

Your `~/projects/` directory will become mounted at `/projects` in the
stack containers and will be created if missing.

Once an AI client is connected, paste
[`docs/PROJECT_INSTRUCTIONS.md`](docs/PROJECT_INSTRUCTIONS.md) into a
Claude Desktop Project's custom instructions (or your `CLAUDE.md` /
`AGENTS.md`) as standing session instructions, and/or use
[`mcp/opening-prompt.md`](https://github.com/gornskew/basilisk/blob/devo/mcp/opening-prompt.md)
from the Basilisk clone as a ready-made first message.



### Initial Setup (full clone)

1. Clone this repo anywhere you like — `~/skewed-emacs` is fine:

```bash

   cd
   git clone https://github.com/gornskew/skewed-emacs
   cd skewed-emacs

```

   Cloning under your own `~/projects/` instead is useful only if you
   want to hack on Readymax internals from inside the container
   (the host `~/projects/` directory is mounted at `/projects`
   there). For just *using* Readymax to work on other projects,
   the clone location doesn't matter — the running container never
   needs the clone.

2. Start the default container orchestra:

```
   ./basilisk up
   
```

By default this pulls missing images only (no overwrites of local builds).
To force pulling the latest images, use:

```
   ./basilisk up --pull
```

After the stack composition starts, `eskew` and `egskew` should be
available immediately and henceforth in any new bash shells on your
host — these are the **only** commands you need from the host to drive
the containerized Emacs:

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

### Connecting an out-of-stack MCP client (Claude Desktop and friends)

This is trivial to do with the generated
`mcp/claude_desktop_config.json`. Please see [The Basilisk
Repo](https://github.com/gornskew/basilisk) for details. 


### AI Terminal Agents (Claude Code, Gemini CLI, Codex, Grok)

The `-aituis` image variants (including `-full`, which is an alias for
`gui-aituis`) carry four AI terminal agents, launched from any shell
inside the container — `M-x vterm`:

| Agent | Launcher | First login |
|-------|----------|-------------|
| Claude Code | `claudly` | OAuth URL to open in a browser |
| Gemini CLI | `geminly` | Google OAuth prompt |
| OpenAI Codex | `codexly` | Interactive login, or `OPENAI_API_KEY` |
| Grok Build (xAI) | `grokly` | `grok login`, or `GROK_DEPLOYMENT_KEY` |

They come up already wired to every MCP server on the stack:
`./basilisk up` merges the service configs and installs them in
whatever format each agent expects, so an agent you talk to in a
terminal here reaches the same services an external Claude Desktop
would. Credentials are volume-mounted from your host and survive
restarts and recreates.

A variant without them is not a dead end — `M-x skewed-install` adds
the AI TUIs on demand, though those installs are ephemeral. And an
external MCP client works identically against any variant, `lite`
included.

**Details** — which config lands where, why the launchers are shell
functions rather than binaries, the Grok credential-mount asymmetry,
and the build-stage layout — are in
[docker/README.md](docker/README.md).


## Windows-Specific Section

### Emacs-slanted Keyboard Tweaks for Windows

Readymax uses the traditional Emacs keybindings by default, which
make heavy use of the Control key ("C-" in emacs parlance). For this
reason, it can be convenient to bind a more ergonomic key such as
CapsLock to Control, on modern keyboards. (Older keyboards had Control
in the place of current CapsLock). This repository
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

This section is for users who want to install the Readymax dot-files
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

Readymax includes a flexible icon system for the dashboard and
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

4. **Enable nerd icons in Readymax** by adding to your config or running:
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

AGPL-3.0-or-later, © 2026 Gornskew Enterprises — see [LICENSE](LICENSE).
The vendored SLIME under `dot-files/emacs.d/sideloaded/slime-v2.28/` is
third-party and keeps its own terms; see [its
LOCAL-CHANGES.md](dot-files/emacs.d/sideloaded/slime-v2.28/LOCAL-CHANGES.md).

## MCP Server Registries

- [MCPHub](https://mcphub.com/mcp-servers/gornskew/skewed-emacs)
