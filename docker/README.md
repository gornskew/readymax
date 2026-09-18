# The Translators

Four translators ride in the room's castings and come up already
introduced to every crew channel on the ship: terminal channels
through which a biological converses with a cyborg, launched from any
shell inside the room, while that same cyborg reaches the ship's
residents through the Protocol Officer. This scroll is the detail;
the [Readymax README](../README.md) carries the summary, and
[BUILD.md](BUILD.md) owns the castings and their strains.

| Translator | Hail | Its home package |
|---|---|---|
| Claude Code | `claudly` | `@anthropic-ai/claude-code` (npm) |
| Gemini CLI | `geminly` | `@google/gemini-cli` (npm) |
| OpenAI Codex | `codexly` | `@openai/codex` (npm) |
| Grok Build (xAI) | `grokly` | binary installer from `https://x.ai/cli` |

## Which strains carry them

The feature suffix is **`aituis`**, not `full`. `full` is an *alias*
for `gui-aituis` (BUILD.md), which is why both names are heard:

| tag | translators aboard? |
|---|---|
| `{branch}-lite` | no |
| `{branch}-default` — the canonical `{branch}`/`latest` tag | no |
| `{branch}-gui` | no |
| `{branch}-aituis` | **yes** |
| `{branch}-gui-aituis`, aliased `{branch}-full` | **yes** |

A strain without them is not a dead end: `M-x skewed-install` fits
them while underway, one at a time — the names are `claude-code`,
`codex`, `gemini-cli` and `grok` (beside `copilot-language-server`
and `headless-shell`), not one bundled "translators" module. Such
fittings are **ephemeral**: they live in the residence's own
writable layer and are gone at the next raising. Pull `-aituis` or
`-full` for translators cast in.

`copilot-language-server` is the exception: it is cast into **no**
strain and only ever fitted on demand (2026-08-16). It is GitHub's to
distribute, and its npm package now weighs ~260MB where it used to be
a 65MB single binary.

## The hails are shell functions, not binaries

`claudly`, `geminly`, `codexly` and `grokly` are bash functions
defined in [`dot-files/bash_profile`](../dot-files/bash_profile).
Two consequences worth knowing before you go looking for them:

- **`which claudly` returns nothing**, and neither does any `sh -c`
  invocation. They exist only in an interactive bash that has read
  the profile — an `M-x vterm`, an `rmax` session, a `docker exec
  -it`.
- They are **not** thin aliases. Each does real work before exec'ing
  its translator: `claudly` and `geminly` first `npm update` their
  own package, `geminly` copies the merged registry into
  `~/.gemini/settings.json`, and every one of them `cd /projects`
  first so the cyborg opens on the dockside shelf rather than `$HOME`.

`codexly`'s self-update is deliberately commented out — it hits
permission problems in the room. A known limitation, not an
oversight.

## How the introductions are made

None of this is configured by hand. `./basilisk up` runs
`merge-mcp-configs.el`, which merges the ship's base and stack-pouch
MCP registries and installs them per translator, in the form each one
expects:

| translator | written to | form |
|---|---|---|
| Claude Code | `/tmp/merged-mcp-config.json` | JSON `mcpServers`, passed via `--mcp-config` |
| Gemini CLI | `~/.gemini/settings.json` (copied by `geminly`) | the same JSON |
| Codex | `~/.codex/config.toml` | `[mcp_servers.*]` tables in a managed block |
| Grok | `~/.grok/config.toml` | the same tables, without Codex's nested tool-approval sections |

The Codex and Grok blocks are fenced by `BEGIN SKEWED-EMACS MCP`
markers, so the merge can be re-run without disturbing anything else
in those scrolls. `grokly` checks for that marker and warns you to
run `./basilisk up` if it is missing — a far better failure than a
cyborg that arrives with no channels and does not say so.

The generated entries name the rooms by their type on the ship's
lines (`ready-room:7080`, `bridge:9080`, `engine-room:9090`, …)
through `node …/mcp-wrapper.js`. That is why a cyborg in a terminal
here reaches exactly the same crew an outside Claude Desktop would:
same roster, same Officer, a different door.

Because the registry is generated from the whole roster, it must
come from **Basilisk** rather than from this repository — a Captain's
casting cannot know what else is aboard. This repository casts the
translators; Basilisk tells them whom to hail.

## Papers

Each translator signs in once, interactively, and its papers are kept
on the dock — mounted from your home directory — so they survive a
relief and a fresh raising alike:

| translator | papers, kept on the dock | first sign-in |
|---|---|---|
| Claude Code | `~/.claude/.credentials.json` | an OAuth URL to open in a browser |
| Gemini CLI | `~/.gemini/oauth_creds.json`, `~/.gemini/google_accounts.json` | a Google OAuth prompt |
| Codex | `~/.codex/auth.json` | interactive sign-in, or `OPENAI_API_KEY` |
| Grok | `~/.grok/auth.json` | `grok login`, or `GROK_DEPLOYMENT_KEY` |

Note the asymmetry on Grok: **only `~/.grok/auth.json` is mounted,
not the whole `~/.grok` tree.** That is deliberate — the translator
itself is cast in at `~/.grok/bin/grok`, and mounting the parent
pouch would shadow it with an empty one from the dock and break the
translator. If you are fitting a fifth translator, mount the papers,
not their pouch.

`./basilisk up` creates these as empty placeholders on the dock if
they do not exist, so the mounts always resolve.

## Casting notes

The three npm-based translators install into per-translator prefixes
in the builder stage (`~/.claude/local`, `~/.gemini/local`,
`~/.codex/local`) and are copied into the strain stages; Grok
installs via its own script to `~/.grok/bin` with symlinks into
`~/.local/bin`. `GROK_VERSION=X.Y.Z` pins it, defaulting to latest
stable — the only one of the four not pinnable through npm.

See [BUILD.md](BUILD.md) for the strain tree and [CI.md](CI.md) for
the vat hall's line.
