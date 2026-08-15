# BASILISK — the stack, and who sails in it

`eyes-only/THEMES.md` is the canon for how the *board* tells this
fleet's story.  This document is the canon for the fleet itself: what
the stack is called, why, and who is aboard.  The two are meant to be
read together — the board only renders what this file names.

## The problem this name solves

"Skewed Emacs" had been doing three jobs at once, and the README has
always admitted it (see *What Will I Find Here?* — three assets):

1. **an Emacs configuration** — the elisp, the packages, the
   native-compiled user config.  Usable on a bare machine with no
   Docker anywhere in sight.
2. **a container image** — that configuration, containerized, plus the
   lisply-mcp middleware and (in the fuller variants) the terminal AI
   CLIs.
3. **a batteries-included multi-container stack** — the compose overlay
   framework that brings up that image *alongside* Gendl CCL, Gendl
   SBCL, Cyclops, the GDL Enterprise images, and autoheal, wires them
   onto one network, mints their identities, validates them, and merges
   the MCP client configs.

One name for three things is one name too few, and it bit hardest at
(3): "restart skewed-emacs" is genuinely ambiguous between *the emacs*
and *the whole fleet on this box*, and those are very different
requests at 2am.

**Only (3) gets a new name.**  (1) and (2) keep `skewed-emacs`, because
the image is just the configuration containerized — one thing wearing a
box — and because in-world that container is the ship's Captain, which
is a role, not a fleet.  Naming the third thing collapses the collision
without renaming anything that already works.

## Why "Basilisk"

The name was not invented for the occasion; it fills a vacancy the canon
already had.  `THEMES.md` records that the fleet "now flies one class of
ridged bio-hull," crewed by something that isn't human — and that class
has never been named.  Meanwhile the stack is precisely the thing that
turns a bare box into a crewed vessel: `basilisk up` mints the
complement, wires it, and validates it, and THEMES.md already says
"every ship can crew up the same way."

So the stack **is** the hull class, and two sentences become one:

> `narad` is a Basilisk-class ship.
> `narad` runs Basilisk.

Three things recommend the specific word:

- **It is a lizard**, which is what this crew already is — scale-teal
  hide and slit pupils, walking through the door Dark Angel's transgenic
  line left open (THEMES.md, *The Manticore thread*).
- **It kills with a look**, which completes an ocular product line
  nobody planned: Cyclops has one eye, Eyes Only has two, and the fleet
  they run on is the thing whose gaze is the weapon.  Gornskew sells
  *watching*.
- **It reads as a hull class and as a command.**  "Basilisk-class" is
  the idiom of every navy that ever named a ship, and `basilisk up` is
  three syllables at a prompt.

Names the canon has already spent, and which were therefore unavailable:
`muster` (the crew log), `roster` (the server-side crew table), `watch`
(a `docker restart`), `yard` (a host reboot), `relief` and `tour` (what
a recreate does to a complement).

## What the name does and does not rename

Deliberately narrow.  Basilisk is the name of the *stack* — the thing
`./basilisk up` brings into being — and nothing else:

| stays as it is | why |
|---|---|
| the `skewed-emacs` repository | it houses all three assets; the config is the biggest of them |
| the `genworks/skewed-emacs` images (and `--lite/--default/--tui/--gui/--full`) | the image is asset (2), the Captain's own hull, not the fleet |
| the `skewed-emacs` container / hostname | the Captain answers to its own name |
| the `skewed-emacs-network` Docker network | renaming a live network breaks every running overlay for no gain |
| `eskew` / `egskew` | they attach to the *emacs*, which is exactly what they say |
| `services.sexp`, the overlay `.yml` files | generated plumbing; the conceit is presentation |

`./basilisk` is the stack's entry point.  `./compose-dev` remains and
always will — the same script under its original name, so every script,
runbook, muscle memory and CLAUDE.md that says `compose-dev` keeps
working.  Prefer `basilisk` in new writing.

## Who is aboard

The roles are canonical and server-side; only their rendered titles
change per skin (THEMES.md, *Ship & Crew Iconography*).  What follows is
what the stack actually starts, and who that makes them:

| container | post | in-world |
|---|---|---|
| `skewed-emacs` | **Captain** | the ship's console, and the one process that outlives the others' restarts |
| `cyclops` | **Pilot** | at the conn: every packet enters through it |
| `gendl-ccl`, `gendl-sbcl`, `genworks-gdl-*` | **Engineers** | the KBE engines — designing ships from aboard one |
| `autoheal` | **Medic** | rated `:doctor`; watches for the wedged and revives them |
| anything else an overlay adds | **Crew** | unknown species still muster in, by design |

Identity is minted per **container**, not per process: `compose-dev`'s
`mint_crew_identities()` writes NAME / SPECIES / ROLE into
`/tmp/skewed-crew-identity` inside each one, and `metrics.lisp` reads
that file in preference to minting its own.  Species comes from the
container's *image*, not its service name, so renaming a service in an
overlay does not change what someone is.

That binding is what makes the lifetimes in THEMES.md's *Tours of duty*
table true rather than decorative: a Lisp restart or a `docker restart`
keeps the same officer aboard, `basilisk down && basilisk up` is a
**relief in place** (whole complement swapped, hull untouched), and a
host reboot is a **yard period**.  Do not re-derive that table here —
it lives in THEMES.md and one copy is enough.

## Where Basilisk sits in the lineup

**Gornskew Enterprises** ships three things:

| product | terms | what it is |
|---|---|---|
| **Basilisk** (with `skewed-emacs` and `lisply-mcp`) | open source, AGPL | the stack, the editor config, and the MCP middleware — the whole crewed vessel |
| **Cyclops** | $99, binary, closed source | the reverse proxy, on an Allegro CL runtime |
| **Eyes Only** | open core under the **Eyes Only License**; $69 for the binary + the extra skins | the board that watches the fleet |

The seam between the last two is one the code already has rather than
one the marketing invented: Cyclops exposes `/_cyclops/vitals` and
carries no UI at all; Eyes Only probes it.  A customer who wants
telemetry *UI* for Cyclops buys Eyes Only, and core Cyclops stays
uncluttered by it (Dave, 2026-08-14).

Basilisk being the free tier is the point of the shape: the fleet is
what you give away, and what you sell is the eyes.

### The Eyes Only License (not yet written)

Eyes Only's open core is to ship under a license of its own, named for
the product, and it **must be GPL-compatible** (Dave, 2026-08-15).  The
name appears to be free: no such identifier exists on the SPDX license
list, and no software license by that name turns up in general use.

Two things to settle before anyone drafts prose, because they decide how
much prose there is to draft:

- **Compatible how.**  The cheap and safe construction is not a new
  license at all but **GPLv3 with additional terms under its §7**, badged
  as the Eyes Only License.  That is compatible by construction, and §7
  is the clause written for exactly this purpose.  The catch worth
  knowing up front: §7 lets you add *permissions* freely but only an
  enumerated set of *requirements* — attribution, marking modified
  versions, trademark limits and a few others.  Anything outside that
  list is not a GPL-compatible term no matter what the document is
  called.  A genuinely bespoke license is the expensive path: it needs a
  lawyer, it earns a `LicenseRef-` in every corporate scanner until SPDX
  accepts it, and license proliferation is a real cost to adopters.
- **Which copyleft.**  The rest of the free tier is AGPL, and Eyes Only
  is a *network-served board* — the precise case AGPL's §13 exists for.
  Basing it on AGPLv3 rather than GPLv3 keeps the family consistent and
  closes the hosted-dashboard hole; AGPLv3 and GPLv3 are written to
  interoperate.  If "GPL-compatible" was meant strictly as *GPLv3*, say
  so, because it changes the base document.

Not legal advice, in the same spirit as THEMES.md's note on the ship
silhouettes.  What is being flagged is that "GPL-compatible" is a
technical property that a name cannot confer — the base license does.

The paid split stays mechanical, as THEMES.md already describes: the
free build simply ships fewer `eyes-only-*.css` files and the THEME menu
shortens by itself.  Which means the licensing decision above and the
build split are independent — the skins are a packaging boundary, not a
licensing one, and they will need their own answer.
