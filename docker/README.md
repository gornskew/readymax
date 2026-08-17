# In-container AI terminal agents

Four terminal AI CLIs ride in the image and come up already wired to
every MCP server on the stack. This file is the detail; the
[repository README](../README.md) carries the summary, and
[BUILD.md](BUILD.md) owns the image variants themselves.

| Agent | Launcher | Upstream package |
|---|---|---|
| Claude Code | `claudly` | `@anthropic-ai/claude-code` (npm) |
| Gemini CLI | `geminly` | `@google/gemini-cli` (npm) |
| OpenAI Codex | `codexly` | `@openai/codex` (npm) |
| Grok Build (xAI) | `grokly` | binary installer from `https://x.ai/cli` |

## Which images have them

The feature suffix is **`aituis`**, not `full`. `full` is an *alias* for
`gui-aituis` (BUILD.md), which is why both names appear in circulation:

| tag | AI TUIs? |
|---|---|
| `{branch}-lite` | no |
| `{branch}-default` — the canonical `{branch}`/`latest` tag | no |
| `{branch}-gui` | no |
| `{branch}-aituis` | **yes** |
| `{branch}-gui-aituis`, aliased `{branch}-full` | **yes** |

A variant without them is not a dead end: `M-x skewed-install` adds
them on demand, one module at a time — the names are `claude-code`,
`codex`, `gemini-cli` and `grok` (alongside `copilot-language-server`
and `headless-shell`), not a single bundled "AI TUIs" module. Those
installs are **ephemeral**: they live in the container's writable layer
and are gone on a recreate. Pull `-aituis` or `-full` for the baked-in
version.

`copilot-language-server` is the exception: it is baked into **no**
image and is only ever installed on demand (2026-08-16). It is GitHub's
to distribute, and its npm package now weighs ~260MB rather than the
65MB single binary it used to be.

## The launchers are shell functions, not binaries

`claudly`, `geminly`, `codexly` and `grokly` are bash functions defined
in [`dot-files/bash_profile`](../dot-files/bash_profile). Two
consequences worth knowing before debugging:

- **`which claudly` returns nothing**, and neither does any `sh -c`
  invocation. They only exist in an interactive bash that has sourced
  the profile — an `M-x vterm`, an `eskew` session, `docker exec -it`.
- They are **not** thin aliases. Each one does real work before exec'ing
  its CLI: `claudly` and `geminly` first `npm update` their own package,
  `geminly` copies the merged config into `~/.gemini/settings.json`,
  and every one of them `cd /projects` first so the agent opens on the
  mounted work tree rather than `$HOME`.

`codexly`'s self-update is deliberately commented out — it hits
permission problems in-container. That is a known limitation, not an
oversight.

## How the MCP wiring gets there

None of this is configured by hand. `./basilisk up` runs
`merge-mcp-configs.el`, which merges the base and overlay MCP configs
and installs them per agent, in the format each one expects:

| agent | written to | format |
|---|---|---|
| Claude Code | `/tmp/merged-mcp-config.json` | JSON `mcpServers`, passed via `--mcp-config` |
| Gemini CLI | `~/.gemini/settings.json` (copied by `geminly`) | same JSON |
| Codex | `~/.codex/config.toml` | `[mcp_servers.*]` tables in a managed block |
| Grok | `~/.grok/config.toml` | same tables, without Codex's nested tool-approval sections |

The Codex and Grok blocks are delimited by `BEGIN SKEWED-EMACS MCP`
markers, so the merge can be re-run without disturbing anything else in
those files. `grokly` checks for that marker and warns you to run
`./basilisk up` if it is missing — a much better failure than an agent
that starts with no tools and does not say so.

The generated entries point at **compose network hostnames**
(`captain:7080`, `jr-eng-human:9080`, …) through
`node …/mcp-wrapper.js`. That is why an agent in a terminal here
reaches exactly the same services an external Claude Desktop would:
same roster, same wrapper, different transport.

Because the config is generated from the whole roster, it necessarily
comes from **Basilisk** rather than from this repo — a Captain's image
cannot know what else is aboard. This repo builds the agents; Basilisk
tells them what to talk to.

## Credentials

Each agent authenticates once, interactively, and the credential file is
volume-mounted from the host so it survives restarts *and* recreates:

| agent | host-mounted file | first login |
|---|---|---|
| Claude Code | `~/.claude/.credentials.json` | OAuth URL to open in a browser |
| Gemini CLI | `~/.gemini/oauth_creds.json`, `~/.gemini/google_accounts.json` | Google OAuth prompt |
| Codex | `~/.codex/auth.json` | interactive login, or `OPENAI_API_KEY` |
| Grok | `~/.grok/auth.json` | `grok login`, or `GROK_DEPLOYMENT_KEY` |

Note the asymmetry on Grok: **only `~/.grok/auth.json` is mounted, not
the whole `~/.grok` tree.** That is deliberate — the CLI binary itself
is baked into the image at `~/.grok/bin/grok`, and mounting the parent
directory would shadow it with an empty host directory and break the
agent. If you are adding a fifth agent, mount the credential file, not
its directory.

`./basilisk up` creates these as empty placeholder files on the host if
they do not exist, so the mounts always resolve.

## Build notes

The npm-based three install into per-agent prefixes in the builder stage
(`~/.claude/local`, `~/.gemini/local`, `~/.codex/local`) and are copied
into the variant stages; Grok installs via its own script to
`~/.grok/bin` with symlinks into `~/.local/bin`. `GROK_VERSION=X.Y.Z`
pins it, defaulting to latest stable — the only one of the four not
version-pinnable through npm.

See [BUILD.md](BUILD.md) for the variant tree and [CI.md](CI.md) for the
multi-arch pipeline.
