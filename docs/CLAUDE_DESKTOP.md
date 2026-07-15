# Claude Desktop Integration (Linux, macOS, Windows)

If you want to use Claude Desktop with the Skewed Emacs MCP servers,
this guide walks you through the setup. This assumes you have already
completed the basic [Containerized Runnings](../README.md#containerized-runnings-recommended)
setup.

## Prerequisites

- Docker running (Docker Desktop on macOS/Windows, Docker Engine on Linux)
- [Claude Desktop](https://claude.ai/download) installed
- skewed-emacs cloned and stack started at least once (see main README)
- Windows only: [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install)
  with Docker Desktop using the WSL2 backend

## Setup

1. **Start the stack** (if not already running):

   ```bash
   cd ~/projects/skewed-emacs
   ./compose-dev up
   ```

   Wait for the `[SUCCESS] Claude Desktop config ready` message.
   `compose-dev` detects your platform and writes the appropriate
   config to `mcp/claude_desktop_config.json` — on Linux and macOS it
   invokes `mcp/mcp-exec` directly; on Windows it goes through `wsl`.

2. **Copy the generated config to Claude Desktop's config location:**

   **Linux:**
   ```bash
   cp mcp/claude_desktop_config.json ~/.config/Claude/claude_desktop_config.json
   ```

   **macOS:**
   ```bash
   cp mcp/claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

   **Windows (from inside WSL):**
   ```bash
   cp mcp/claude_desktop_config.json /mnt/c/Users/YOUR_USERNAME/AppData/Roaming/Claude/claude_desktop_config.json
   ```

   Replace `YOUR_USERNAME` with your Windows username. Alternatively,
   from Windows Explorer:
   - Source: `\\wsl$\Ubuntu\home\YOUR_WSL_USER\projects\skewed-emacs\mcp\claude_desktop_config.json`
   - Destination: `%APPDATA%\Claude\claude_desktop_config.json`

3. **Restart Claude Desktop** — you should see three MCP servers connect:
   - `skewed-emacs` — Emacs Lisp evaluation
   - `gendl-sbcl` — Common Lisp (SBCL) with Gendl
   - `gendl-ccl` — Common Lisp (CCL) with Gendl

   (Plus any additional backends from overlay repos you have installed.)

4. **Optional — prime your first session**: paste the contents of
   [`mcp/opening-prompt.md`](../mcp/opening-prompt.md) as your first
   message so the agent bootstraps itself with the Emacs environment.

## Daily Usage

The Docker stack must be running for Claude Desktop to use the MCP servers:

```bash
cd ~/projects/skewed-emacs
./compose-dev up -d   # -d for daemon mode (no interactive shell)
```

To stop the stack:

```bash
cd ~/projects/skewed-emacs
./compose-dev down
```

## What You Can Do

With these MCP servers, Claude Desktop can:

- Evaluate Emacs Lisp code and interact with the Emacs environment
- Evaluate Common Lisp code in SBCL or CCL
- Work with the Gendl geometry kernel for CAD/knowledge-based engineering
- Access documentation and run HTTP requests against the backend services

## Other MCP Clients

Claude Desktop is just one consumer. The same generated configs work for:

- **Claude Code**: from the repo root, `claude mcp add` each server from
  `mcp/claude_desktop_config.json`, or copy its `mcpServers` block into
  a `.mcp.json` in your project
- **Codex CLI**: `compose-dev up` maintains `~/.codex/config.toml`
  inside the container automatically; for a host-side Codex, adapt
  `mcp/mcp.toml`
- **Any MCP-capable client**: point it at `mcp/mcp-exec` with the args
  shown in `mcp/claude_desktop_config.json`

## Merging with Existing MCP Configuration

If you already have other MCP servers configured in Claude Desktop, you will
need to manually merge the `mcpServers` entries from the generated
`claude_desktop_config.json` into your existing configuration file.

## Cloning to a Different Location

The generated `claude_desktop_config.json` contains the absolute path to
your skewed-emacs clone. It is determined at `./compose-dev up` time
based on where you run the command, so a non-default clone location
works automatically.

## Troubleshooting

**MCP servers not connecting:**
- Ensure the Docker stack is running (`docker ps` should show the containers)
- Check that the paths in `claude_desktop_config.json` match your clone location
- Restart Claude Desktop after copying the config

**`mcp/claude_desktop_config.json` missing or stale:**
- It is generated (not committed); run `./compose-dev up` and wait for
  the `[SUCCESS] Claude Desktop config ready` message
- If the message doesn't appear, the Emacs daemon may still be starting —
  run `./compose-dev up` again

**"emacsclient not ready" warning on first start:**
- This is normal — the Emacs daemon takes a few seconds to initialize
- Run `./compose-dev up` again and the MCP config will generate successfully
