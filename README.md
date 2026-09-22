<!--
Copyright © 2026 Gornskew Enterprises

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.  Distributed WITHOUT
ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.
-->

> [!IMPORTANT]
> **Looking for Skewed Emacs?**  The plain-language "corporate" fork
> lives at [genworks/readymacs](https://github.com/genworks/readymacs).
>
> This repository (`readymax`) is the gaming-language upstream and is
> maintained separately.  A clone whose `origin` still points at
> `gornskew/skewed-emacs` lands here; to follow the fork instead:
>
> ```bash
> git remote set-url origin https://github.com/genworks/readymacs.git
> ```

# Readymax: a Ship's Ready Room, a land-side Lifepod, or a galaxy-traveling Space Suit — pre-crewed with a Captain

Aboard a [Basilisk](https://gornskew.com/basilisk/index.html)-class
vessel, the ready room is the quiet room off the bridge where the
ship's business gets thought through. The room comes with a Captain
and a Protocol Officer. The Captain — of the notoriously long-lived
Gnu Emacs species — keeps the room; the **Protocol Officer**
interviews arriving cyborgs, schools them in the ship's ways, and
dispatches each to the crew member it came to see, so that cyborgs may
call on the Captain himself, or the First Officer, Engineer, or any
other cyborg-capable crew.

Readymax is the module sku for that room when used either _aboard
ship_ or _grounded_. When _aboard ship_, the room slots into its
designed place in the Basilisk hull, off the bridge, and plugs
automatically into the ship's rune tube lattice.  When _grounded_,
this same readymax module sku sets down as the _captain's lifepod_:
siteable at any standard planet-side residential pod dock, no
prewiring to any neighbors, near or far.

Finally, the Captain can survive the galaxy entirely on his own —
**unhoused, but wearing his space suit**: yes, the chest of scrolls
can replicate and morph itself into the Captain's spacesuit, rather
than conjuring a lifepod or ship's ready room to house him. 


![Readymax Logo](img/skewed-colorful.png)

## Why Readymax? The Inversion

Elsewhere in the galaxy, the custom is to keep a cyborg *in* the
room: wired into a single scroll, speaking only through it, one
more fixture among the furnishings. The room is the world, and the
cyborg lives in a bottle on a shelf.

Readymax inverts the arrangement. This room keeps no cyborg; it
*receives* them. The Protocol Officer hands each arrival the room's
channels, and with them the room itself joins the visiting cyborg's
own kit: scrolls opened, incantations worked, scriveners set about
their copying — at the visitor's initiative, under the Captain's
command.

Nor is it only this room, nor only the Captain. It is the
*residents* who keep the channels: in the Gendl rooms, a First
Officer or a Ship's Engineer answers the lisply dialect the same
way, and offers a visiting cyborg the same reception — each
resident working his own rune arrangement.

And it matters not what vessel your cyborg arrives in: Claude
Desktop, Claude Code, Grok Build, Gemini CLI, Codex, LM
Studio, or any craft of your own that speaks MCP — the
Muster-and-Conduct Protocol, in which a Protocol Officer musters each
arriving cyborg and conducts it to the crew member it came to see.

This repository is the ready room's own scroll. The wider vision —
whole vessels raised and struck with a word, each with a full crew
of rune-working residents — lives with the
[Basilisk](https://github.com/gornskew/basilisk) shipyard.

<!-- demo GIF: record per docs/DEMO_GIF.md, save as img/demo.gif, then
     uncomment:
![30-second demo](img/demo.gif)
-->

## What Will I Find Here?

This Readymax repository holds two assets:

1.  the chest of scrolls itself: the complete fittings of the room,
    the Captain's own configuration, with the Protocol Officer's
    post (the lisply backend) among them. Worn on its own, this is
    the space suit — no part of (2) required.

2.  the shipwright's plans: a Dockerfile for casting the room as a
    residence, the chest of scrolls (as per (1) above)
    already stowed for the built-in `emacs-user` account.

Raising that image alongside Gendl rooms and the rest of a working
crew is a third thing with its own yard:
**[Basilisk](https://github.com/gornskew/basilisk)**. Basilisk is the
shipyard and the ship (`./basilisk up`, from a Basilisk clone);
**Readymax** is the ready room and the image that carries it.

Aboard, the room's Docker compose service name is `ready-room`, and
the residence itself wears a crew name minted fresh at each raising
of the ship. See **BASILISK.md in the Basilisk repo** for the rooms,
the crew postings, and the rest of the trope.

## The Captain's Three Postings

**Posting A — Aboard Ship (recommended):** fetch the Basilisk scrolls
and speak the incantation `./basilisk up` there. A whole vessel
comes up around the ready room.

That raises several residences from the vat and leaves the dock
untouched except for two hailing calls (`rmax`/`grmax`) made
available in your shell (bash, zsh, ksh, or plain sh). You need not
speak `./setup`. You do not need an Emacs of your own on the dock.
You do need a vat (Docker) fitted there.

**Posting B — The Lifepod, Ashore:** the readymax module sets down
at any residential pod dock with a vat (Docker) fitted — no prewiring to
any neighbors, near or far. From a clone of these scrolls, speak:

```bash
docker/run
```

The pod comes up freestanding: the Captain at his desk, the
Protocol Officer on watch (hatch 7081 on the dock by default; `-p`
chooses another), your `~/projects/` pouch stowed at `/projects`
when it exists.
No ship, no crew — just the pod, ashore.

**Posting C — Unhoused, in the Space Suit:** speak the incantation
`./setup`. The Readymax scrolls take their places in your account on
the dock (`~/.emacs.d`, `~/.bash_profile`, etc.) — the Captain's
survival gear, worn by an Emacs already living on the dock with
you. Raises nothing from the vat. The suit's hatch — the
lisply-backend endpoints — stays **sealed by default** until you open
it (`./setup --with-mcp` or, from inside Emacs,
`M-x lisply-enable-host-server`). Two things vary with a suited
Captain: whether the hatch is open, and whether a Protocol Officer is
within reach (he needs a Cyborg Whisperer post to stand). An open hatch
with no officer is not a closed one — cyborgs who know the way can
sneak in and reach the Captain unannounced, no interview, no
education packet; it has been seen done. An officer with no open
hatch admits nobody at all. **The hatch, not the officer, is the
lock.** Read
[docs/HOST_EMACS_MCP.md](docs/HOST_EMACS_MCP.md) first: on the dock
this grants arbitrary code execution on your machine and is not
sandboxed the way the shipboard path is. You do need an Emacs
already living on the dock for the suit to make any sense.

**Any combination:** the postings are independent and each
idempotent — a suit on the dock (`./setup`), a lifepod at the
dock (`docker/run`), and a full vessel raised alongside
(`./basilisk up`) can all coexist on one machine.

**Note:** The ./setup is meant for new Emacs installations where you
don't have or don't care about your personal setup. If you are an
experienced Emacs user with a preëxisting setup, then you can run
`./setup --dry-run` to see what it would do without touching your
own scrolls, then wire your own init scrolls into the standard
Readymax ones.

## What the room is fitted with

### The Captain's own scrolls

- **The day-board (`*dashboard*`)**, kept current by one of the
    room's scrivener 'bots: your project scrolls and their
    freshness, the health of every crew channel aboard, the day's
    orders (org-mode daily focus), and doors into slime with any
    rune-fluent resident aboard. Ashore or unhoused, the marquee flies
    READY MAX; aboard ship, the room hangs out its shipboard
    shingle instead: READY ROOM, with the Captain's sign beneath it.

- **Fittings already aboard, compiled to the Captain's native tongue**
    (examples):
  - [Slime](https://en.wikipedia.org/wiki/SLIME) for Common Lisp / Swank
  - Paredit-mode, Flycheck-mode, Company-mode
  - Magit, Org-mode
  - Doom Color Themes, theme switching functions

- **The Captain's hatch** (the Lisply backend) — where the Protocol
    Officer stands (the fine print: the Protocol Officer is a 'bot,
    not a biological):
  - lets cyborgs call on the Captain through any standard Officer.
  - Kept in the room's own pouch,
    `dot-files/emacs.d/sideloaded/lisply-backend/` (its own scroll
    says what the hatch answers)
  - See The Protocol Officer's Desk below — this is a
    configuration surface worth understanding, not furniture.

- **From the vat hall**: the room is cast from the plans in
    `docker/Dockerfile` by `docker/build`; castings from Gornskew
    HQ are pushed to the room's home planet, tagged
    `gornskew/readymax` versions on Docker Hub (the strains are
    listed in `docker/BUILD.md`).

### The Protocol Officer's Desk — the MCP configuration surface

The Protocol Officer is working gear, not decoration: his service
record is public ([Cyborg Whisperer](https://github.com/gornskew/cyborg-whisperer)),
he stands between arriving cyborgs and the Captain, and you should
know what crosses his desk.

**What he does.** He speaks MCP to the visitor on one side and
HTTP — the Hatch-To-hatch Transfer Protocol, a plain hail from one
hatch to another — to the room on the other. The Captain answers a
small dialect of it at hatch 7080 inside the room
(`/lisply/lisp-eval`, `/lisply/ping-lisp`, ...), and any resident
speaking that same dialect gets the same service — which is why one officer's
procedures serve the Captain and the Gendl rooms' residents alike,
each working his own rune arrangement.

**The tools he grants an arriving cyborg:**

| Tool | What it does |
|------|--------------|
| `lisp_eval` | an incantation worked in the resident's own rune arrangement — the working channel |
| `ping_lisp` | is anyone home |
| `get_docs` / `get_docs_list` | the ship's education packets, served on demand |
| `http_request` | reach the room's HTTP services through one gate |
| `lisply_search` | search the pre-packed Gendl index (Readymax rooms) — see The Chart Locker |

**Where he takes his orders.** Aboard ship, `./basilisk up`
generates the client registries (`mcp/claude_desktop_config.json`
for Claude Desktop, and the matching form for each translator
aboard). In the lifepod he stands watch just as he does aboard. In
the space suit he stands only where a Cyborg Whisperer post is within
reach — and either way, know that the officer is the reception, not
the lock. The lock is the **hatch**: the lisply endpoints
themselves, which a cyborg fluent in the backend dialect can call
at directly, no officer involved. Aboard and in the lifepod that
is fine — the room is the sandbox and the hatch opens inside it. In
the suit it is exactly why the hatch stays sealed by default (see
Posting C).

**What to understand before opening the gate.** `lisp_eval` is
arbitrary code execution, by design. In the room, that is the
point — the room is the sandbox. In the suit it is your own machine
on the dock; read [docs/HOST_EMACS_MCP.md](docs/HOST_EMACS_MCP.md)
before standing him up there.

### The Spyglass — page captures from inside the room

`webshot URL [out.png] [WxH] [--mobile] [--settle=MS]` captures any
web page from a **real emulated viewport** — page JS and CSS both
see exactly the width you asked for, and `--mobile` adds touch
emulation, so phone-size captures are honest rather than merely
plausible. `webshot-clip URL SELECTOR [out.png]` clips to the first
element matching a CSS selector, rendering below-the-fold elements
fully. Every run gets a throwaway browser profile (no stale cache
while you iterate on a live page), 3D viewports render and appear
in the captures, and a virtual host resolves in-browser with
`--host-resolver-rules="MAP somehost container"`.

The spyglass looks through **the glass**: the default strains carry
a lightweight glass ground for headless work; the workstation
strains carry the full glass with a GUI behind it. A lite room
takes the glass aboard while underway
(`M-x skewed-install` `headless-shell`).

### The Chart Locker — a Gendl search index, pre-packed

Every Readymax image comes pre-packed with a `lisply_search` index,
built at casting time: a lexical index over Readymax's own elisp and
configuration and, so a room works standalone, over the
[Gendl](https://gitlab.common-lisp.net/gendl/gendl) engine's source
and documentation. A cyborg that boards asks `lisply_search` before
it writes GDL and gets back whole `define-object` forms and
documentation sections, each with its file and line range — no
`/projects` mount required.

Aboard a ship the locker fills itself. Every species that carries its
own corpus in its image (Gendl does, under the `lisply.corpus` label)
has that one file copied out by the yard at each raising, and the
ship indexes whatever its articles name from its own hold (the live
Genworks demos, the training material at
[genworks.dev](https://genworks.dev)). The Captain merges them over
his baked index, a corpus aboard outranking a same-named baked one —
so the Gendl searched is the Gendl actually flying, not the one this
image was cast against. The contract every project follows to provide
its corpus, and the reference indexer (`lisply-index`, on the path in
every Readymax image), live with the protocol that promises the tool:
[Cyborg Whisperer `CORPUS.md`](https://github.com/gornskew/cyborg-whisperer/blob/devo/CORPUS.md).

What the baked index holds is public by construction: the sources are
listed in
`dot-files/emacs.d/sideloaded/lisply-backend/lisply-search-config.sexp`,
each marked for distribution, and a casting indexes only those, with
minified assets and vendored trees left out. How it matches and ranks
is written up in that directory's `CLAUDE.md`.

### What Else Is Aboard

Beyond the Captain and the Protocol Officer, the room carries working
gear — every piece of it real and reachable:

- **The chart locker** (`lisply_search`): a Gendl search index packed
  at casting time — see The Chart Locker above.

- **The gangway** (hatch 6942, answering to `webterm` from any shell
  aboard): how a biological walks aboard through a web browser
  when no terminal is to hand. Cyborgs beam in through the Protocol
  Officer; people take the gangway.

- **The spyglass** (`webshot` / `webshot-clip`): page captures from
  inside the room, through **the glass** — see The Spyglass section
  below.

- **Translators** (the `-aituis` strains, including `-full`): four
  translator sets through which passengers converse with cyborgs —
  a separate channel from the ready room's own, so a cyborg can
  talk with you in one window while it works the crew through the
  Ready Room's channels, set up by the Protocol Officer. See The
  Translators below.

- **Scrivener 'bots**: most ready rooms come with a bevvy of them —
  tireless copyists who hold the room's open scrolls (`C-x b` walks
  the shelf), keep the day-board fresh, take dictation from Captain
  and visitors alike, and mind long-running work in the background
  without wedging the room. Whenever anything aboard reads or
  writes a scroll, a scrivener is holding it.

- **`node`**: aboard for your own JavaScript work under
  `/projects` — builds and checks run inside the room rather than
  on the dock.

- **`M-x skewed-install`**: abilities arranged aboard while
  underway — on-demand fitting of the glass onto a lite room, or
  the translators onto any strain, without rebuilding the image.

## Aboard Ship (recommended)

Everything lives in residences raised from the vat — **you need not
speak `./setup`, install any scrolls, or touch an Emacs of your own
on the dock.** The dock stays clean. The only intentional side effect
is that `./basilisk up` makes `rmax` and `grmax` available in your
shell.

### Requirements

 - Git
 - A vat (Docker) — see [macOS-Specific Section](#macos-specific-section) if on a Mac

### Quickest Start — fetch the Basilisk scrolls and raise the ship

Speak these runes at any shell:

```bash
git clone https://github.com/gornskew/basilisk
cd basilisk
./basilisk up
```

Your `~/projects/` pouch becomes the dockside shelf, stowed at
`/projects` in every unsealed room, and is created if missing.

Once a cyborg is connected, paste
[`docs/PROJECT_INSTRUCTIONS.md`](docs/PROJECT_INSTRUCTIONS.md) into a
Claude Desktop Project's custom instructions (or your `CLAUDE.md` /
`AGENTS.md`) as standing orders for the session, and/or use
[`mcp/opening-prompt.md`](https://github.com/gornskew/basilisk/blob/devo/mcp/opening-prompt.md)
from the Basilisk clone as a ready-made first hail.

### The long way: your own copy of the scrolls

1. Copy this repo's scrolls home, anywhere you like — `~/readymax`
   is fine:

```bash

   cd
   git clone https://github.com/gornskew/readymax
   cd readymax

```

   Copying it under your own `~/projects/` instead is useful only if
   you want to refit the room from inside it (the dock's `~/projects/`
   is the shelf at `/projects` there). For just *using* Readymax to
   work on other projects, where the copy lies doesn't matter — the
   raised room never reads it.

2. Raise the default vessel:

```
   ./basilisk up
   
```

By default this pulls missing images only (no overwrites of local builds).
To force pulling the latest images, use:

```
   ./basilisk up --pull
```

After the ship is raised, `rmax` and `grmax` should be available
immediately and henceforth in any new bash shells on the dock —
these are the **only** commands you need from the dock to hail the
Captain aboard:

- `rmax` — hail the Captain in your current terminal (terminal emacsclient)
- `grmax` — the Captain receives you in a new window (graphical emacsclient)

With more than one ship on the box, name the one you mean with a
leading @-arg: `rmax @alpha my-proj.lisp`.

`./basilisk up` writes these to
`~/.config/skewed-emacs/shell-functions.sh` and adds a single source
line to your shell's RC file (`~/.bashrc`, `~/.zshrc`, `~/.kshrc`, or
`~/.profile`, depending on your login shell). This is the **only
modification** made to the dock. Open a new terminal (or
source that RC file) to activate them.

After you are in, see the "Getting Started" section near the top of
the default landing dashboard.

### A cyborg arriving from the dock (Claude Desktop and friends)

This is trivial to do with the generated
`mcp/claude_desktop_config.json`. Please see [The Basilisk
Repo](https://github.com/gornskew/basilisk) for details.

### The Translators (Claude Code, Gemini CLI, Codex, Grok)

The `-aituis` strains (including `-full`, which is an alias for
`gui-aituis`) fit four translators — terminal channels through which
a passenger converses with a cyborg, launched from any shell inside
the room (`M-x vterm`) — while that same cyborg reaches the
ship's crew through the Ready Room's channels, set up by the
Protocol Officer:

| Translator | Hail | First sign-in |
|-------|----------|-------------|
| Claude Code | `claudly` | OAuth URL to open in a browser |
| Gemini CLI | `geminly` | Google OAuth prompt |
| OpenAI Codex | `codexly` | Interactive login, or `OPENAI_API_KEY` |
| Grok Build (xAI) | `grokly` | `grok login`, or `GROK_DEPLOYMENT_KEY` |

They come up with the Protocol Officer's introductions already made
— every crew channel on the ship wired in: `./basilisk up` merges
the service configs and installs them in whatever form each
translator expects, so a cyborg you converse with in a terminal
here reaches the same crew an outside Claude Desktop would. Their
papers are kept on the dock and survive a relief and a fresh raising
alike.

A strain without them is not a dead end — `M-x skewed-install` fits
the translators on demand, though those fittings are ephemeral. And
an outside MCP client works identically against any strain, `lite`
included.

**Details** — which registry lands where, why the hails are shell
functions rather than binaries, the asymmetry in Grok's papers, and
the casting layout — are in [docker/README.md](docker/README.md).

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

### Emacs Through the Gangway (ttyd) on Windows

If you take the gangway — Emacs in a browser tab on hatch 6942, or a
hosted session — Edge and Chrome will steal a few chords before the
terminal sees them: `C-n` opens a new window, `C-p` prints, and `C-w`
closes the tab you are working in. No setting inside the page can
stop that. We bundle a second AutoHotkey config,
`autohotkey-config-for-emacs-in-ttyd.ahk`, which catches those chords
at the OS level and hands the terminal something Emacs understands
(the shipped Emacs config binds `M-]` to `kill-region` for exactly
this reason). Run that script before you open a ttyd tab; the
[instructions](windows-keybindings/README.md#emacs-in-a-browser-tab-ttyd)
walk through it, plus an Edge registry policy for anyone who wants the
genuine control characters back.

## macOS-Specific Section

### macOS Prerequisites

`basilisk` is pure POSIX sh — no special shell is required on macOS.
The only requirement is a vat: **Docker Desktop**.

#### Install Docker Desktop

Install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/)
if you haven't already, then confirm:

```bash
docker info   # should print engine info without errors
```

Once Docker is running, `./basilisk up` will work normally.

---

## The Space Suit (suiting up on the dock)

This section is for suiting up: installing the Readymax scrolls
**directly on the dock**, no vat — survival gear for a Captain with
no room around him at all. It is independent of
the other postings — do not speak `./setup` as part of a shipboard
or lifepod setup; it is not needed and not intended for those.

1. Make a `~/projects/` directory if you don't already have one:

```bash

    cd
    mkdir -p projects/
    cd projects/
    
```

2. Clone this repo into `~/projects/`:

```bash

   git clone https://github.com/gornskew/readymax
   cd readymax

```

3. Speak the setup incantation:
   ```bash
   
   cd ~/projects/readymax
   ./setup
   
   ```
   
   The setup script will create symbolic links of the salient
   "dot-files" (hidden files starting with `.` pointing to the
   corresponding files in the cloned repo, for example:
   
    `~/.emacs.d -> ~/readymax/dot-files/emacs.d`
   
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

Readymax includes a flexible icon system for the day-board and the
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






## Where the scrolls lie

 - `dot-files/` - the chest of scrolls: everything that ends up linked
   into your home pouch when you speak `./setup`
  - `emacs.d/` - the Captain's scrolls, linked to ~/.emacs.d/
    - `init.el` - the first scroll he reads at every waking
    - `etc/` - the rest, one scroll per fitting
    - `sideloaded/` - fittings carried aboard from elsewhere: the
      Captain's hatch (`lisply-backend/`), SLIME
  - `bash_profile` - the shell's scroll (bash)
  - `zshrc` - the same for zsh

## Customization

For personal customizations that shouldn't be committed to this
repository, keep a scroll of your own — `~/.emacs-local` — read
last at every waking of the room.

## License

AGPL-3.0-or-later, © 2026 Gornskew Enterprises — see [LICENSE](LICENSE).
The vendored SLIME under `dot-files/emacs.d/sideloaded/slime-v2.28/` is
third-party and keeps its own terms; see [its
LOCAL-CHANGES.md](dot-files/emacs.d/sideloaded/slime-v2.28/LOCAL-CHANGES.md).

## Where the room is listed

- [MCPHub](https://mcphub.com/mcp-servers/gornskew/readymax)
