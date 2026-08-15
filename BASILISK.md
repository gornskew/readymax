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
| `eyes-only` | **Comm** | the Communications Officer: runs the board any ship can project on its bridge viewscreen or other display |
| `autoheal` | **Medic** | rated `:doctor`; watches for the wedged and revives them |
| anything else an overlay adds | **Crew** | unknown species still muster in, by design |

### Runtimes are not Engineers

Pilot and Comm are both Lisp applications shipped as **runtime** images.
The Engineers carry compilers, and that is precisely what makes them
Engineers: they can design a ship from inside one.  A runtime stands a
watch and runs the system it was built for, competently and
indefinitely, but it does not fabricate anything new — a few yards short
of a full-blown Engineer.  The distinction is the licensing story as
much as the fiction: a compiler is a development seat, a runtime is a
deployment.

### Allegro CL is the supported platform

Every binary product **builds and tests on Allegro CL**, whatever it
eventually ships on.  That is not inertia and not a vendor box ticked on
a form — it is where the support actually is, a real relationship with
Franz Inc. and the people behind it.  Allegro is also where "no compiler
aboard" is literal rather than aspirational: the runtime license and the
image give you exactly that.

Shipping on another CL is not ruled out, and Eyes Only may well be
CCL-shippable sooner rather than later — CCL carries no runtime royalty,
which is a live consideration at a $69 price point.  But an *additional*
delivery target does not displace the *reference* one.  The Allegro build
stays the one that is supported and the one everything else is validated
against; a second target is measured against it, not instead of it.
Concretely, for a GWL application that means native aserve on Allegro is
the reference behavior and a zacl/zaserve delivery is the thing being
checked.

Note also that on some alternatives the compiler is physically present
because it cannot be removed — CCL's `save-application` carries one
whether or not you want it.  That does not promote anything to Engineer.
The invariant is the ROLE, not the vendor and not the byte count: Pilot
and Comm are shipped to run one system, not to develop new ones.

So Comm is not a passenger on an Engineer.  Cyclops already ships this
way (`:lisp-impl "AllegroCL-Runtime"`), and Eyes Only is headed there as
the $69 binary.  That it currently arrives on sally by `ql:quickload`
into `gendl-ccl` is a convenience of the pre-binary era, not what the
post is: it is the one crew member still billeted in someone else's
quarters because its own have not been built yet.

Neither Comm nor any future runtime post appears in `fittings.sexp` yet
— a `:post` needs an image to name, and Eyes Only does not have one
until the binary exists.  Cyclops is the worked example of what Comm's
entry will look like when it does.

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
| **Eyes Only** | $69, binary + base skins, closed source | the board that watches the fleet, plus a skins marketplace |

The seam between the last two is one the code already has rather than
one the marketing invented: Cyclops exposes `/_cyclops/vitals` and
carries no UI at all; Eyes Only probes it.  A customer who wants
telemetry *UI* for Cyclops buys Eyes Only, and core Cyclops stays
uncluttered by it (Dave, 2026-08-14).

Basilisk being the free tier is the point of the shape: the fleet is
what you give away, and what you sell is the eyes.

### Eyes Only ships closed, like Cyclops

Decided 2026-08-15: Eyes Only stays **closed source for now**, sold the
same way Cyclops is — a $69 binary the customer plugs in, carrying the
base skins — with a **skins marketplace** alongside it that Gornskew
seeds.  An earlier plan for an open core under a bespoke "Eyes Only
License" is dropped; the source headers already say proprietary, and now
the packaging agrees with them.

Two consequences worth carrying, because they are structural rather than
marketing:

- **A binary means a Lisp image, and Eyes Only is a GWL application.**
  It is built from `define-object` and talks to `gwl:with-all-servers`,
  so the artifact shipped to a customer is a Gendl/GDL image with Eyes
  Only inside it.  That makes the licensing question about the *engine*,
  not the app: stock Gendl is AGPL, and an AGPL engine in the same image
  as a closed product is a combined work.  Shipping closed therefore
  requires the engine under commercial terms — which Genworks, as the
  copyright holder, is entitled to grant.  The runtime choice follows
  from that grant, not the other way round; see the org item.
- **The marketplace needs skins to live outside the image.**  A skin is
  one client-side `eyes-only-<name>.css` (THEMES.md, *Mechanics*), and
  the theme *discovery* change already means the menu is built from what
  is present rather than a hardcoded list — so a marketplace is closer
  than it looks.  What a sealed binary breaks is the assumption that
  skins arrive by rebuilding: a customer cannot rebuild, so the image
  must read skins from a customer-writable directory, and the CSS custom
  properties skins target (`--rank-*`, `--ink`, `THEME_BASE`,
  `DARK_ONLY`/`LIGHT_ONLY`, the `CONCEITS` table) stop being internal
  details and become a **public contract with a version**.
