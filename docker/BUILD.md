# Skewed Emacs Docker Build System

## Branch-Prefixed Additive Naming Scheme

Images use a **branch-prefixed additive naming scheme**:

```
{branch}-{features}
```

Where:
- `{branch}` is the git branch (e.g., `devo`, `master`)
- `{features}` are additive feature suffixes (e.g., `lite`, `gui`, `aituis`)

### Examples

**devo branch:**
```
gornskew/skewed-emacs:devo-lite              # Base only
gornskew/skewed-emacs:devo-default           # Base + snapshotting (THE default)
gornskew/skewed-emacs:devo-aituis            # Default + AI TUIs
gornskew/skewed-emacs:devo-gui               # Base + GUI workstation
gornskew/skewed-emacs:devo-gui-aituis        # Everything
```

**master branch:** same pattern with the `master-` prefix.

## Feature Breakdown

The primary split is **non-GUI vs GUI** (see the build tree at the top
of `docker/Dockerfile`).  Measurements behind the layering:
`docs/SLIMMING_MEASUREMENTS.md`.

### Base (included in all variants)
- **Emacs configuration**: Full skewed-emacs config
- **lisply-mcp**: MCP server for Lisp evaluation
- **vterm**: Terminal emulator in Emacs
- **ttyd**: Web-based terminal
- **Node.js**: Required for lisply-mcp
- **skewed-install**: on-demand module installer (elisp-first:
  `M-x skewed-install`; modules: AI TUIs, copilot-language-server,
  headless-shell).  Installs are ephemeral — for baked-in persistence
  pull `-aituis` or `-full`.

### Snapshotting (`-default`, and the canonical `{branch}`/`latest` tags)
Adds web-page screenshot capability (`webshot`, `webshot-clip`) via
**chrome-headless-shell** (Playwright's build — Chrome-for-Testing has
no linux/arm64) plus its shared-library closure and fonts.  Software
WebGL via SwiftShader, so x3dom viewports render.  ~610MB extra vs
Debian chromium's ~1.1GB closure.

### GUI Support (`-gui`)
Adds an intentionally heavy full X workstation:
- **emacs-gtk**: GUI Emacs instead of emacs-nox (drive a full graphical
  workstation on your X terminal)
- **Fonts**: Noto, Font Awesome, Symbola, Powerline, Nerd Fonts
- **PDF support**: ghostscript, poppler, pdf-tools
- **chromium** (Debian package): also backs webshot in this branch

### AI TUIs (`-aituis`, `-gui-aituis`)
Adds (all also installable on demand via `skewed-install`):
- **Claude Code**: @anthropic-ai/claude-code
- **Codex**: @openai/codex
- **Gemini CLI**: @google/gemini-cli
- **Grok Build CLI**: binary from https://x.ai/cli/install.sh
  (optional pin: build-arg `GROK_VERSION=X.Y.Z`)
- **copilot-language-server**

## Image Variants (per branch)

| Tag Pattern | Features | Use Case |
|-------------|----------|----------|
| `{branch}-lite` | Base only | Headless servers, minimal deployments |
| `{branch}-default` | Base + snapshotting | **General distribution default** |
| `{branch}-aituis` | Default + AI CLIs | AI-assisted development (terminal only) |
| `{branch}-gui` | Base + GUI workstation | Visual Emacs workstation (no AI CLIs) |
| `{branch}-gui-aituis` | Everything | The kitchen-sink-plus-jacuzzi suite |

(Record real sizes from CI after each restructure; the historical
numbers and the measurement method live in
`docs/SLIMMING_MEASUREMENTS.md`.)

## Aliases (per branch)

Each branch has convenience aliases:

- `{branch}-tui` → `{branch}-aituis` (clarity alias)
- `{branch}-full` → `{branch}-gui-aituis` (everything)
- `{branch}` → `{branch}-default` (branch default is the slim
  snapshotting image, 2026-08-11 slimming initiative — NOT full)

**Special alias:**
- `latest` → `devo` (tracks the devo branch's default build)

### Tag Hierarchy Example (devo branch)

```
devo-lite                    [canonical]
devo-default                 [canonical]
  └─ devo                   [alias]
     └─ latest              [special: devo branch only]
devo-aituis                  [canonical]
  └─ devo-tui               [alias]
devo-gui                     [canonical]
devo-gui-aituis              [canonical]
  └─ devo-full              [alias]
```

## Building

### Single Unified Build Script

All build operations use `docker/build`:

```bash
# Show help
docker/build --help

# Build all variants for current branch (auto-detected)
docker/build --all

# Build specific variants
docker/build --lite --gui              # Just lite and gui
docker/build --full                     # Just gui-aituis
docker/build --aituis --tui             # Just aituis (tui is alias)

# Specify branch explicitly
docker/build --all --branch=master
docker/build --full --branch=devo

# Build and push to registry
docker/build --all --push
docker/build --full --push --branch=master

# Build for local development only (no push)
docker/build --all --no-push
```

### Common Usage Patterns

```bash
# Development workflow: Build everything for current branch
cd /projects/skewed-emacs
docker/build --all

# CI/CD: Build and push master branch
docker/build --all --push --branch=master

# Quick iteration: Build just lite variant
docker/build --lite

# Production release: Build full and push to devo
docker/build --full --push --branch=devo
```

## Build Architecture

The Dockerfile uses a multi-stage build:

```
builder (builds everything once)
  ↓
runtime-base ({branch}-lite)
  ├─→ runtime-aituis ({branch}-aituis)
  └─→ runtime-gui ({branch}-gui)
       └─→ runtime-gui-aituis ({branch}-gui-aituis)
```

Each stage is a valid Docker target. The build script maps targets to stages:
- `--lite` → `runtime-base`
- `--aituis` → `runtime-aituis`
- `--gui` → `runtime-gui`
- `--gui-aituis` / `--full` → `runtime-gui-aituis`

## Push Behavior

The script auto-detects whether to push based on:

1. **Environment variable** `PUSH_IMAGE=true|false` (highest priority)
2. **CLI flags** `--push` or `--no-push` (overrides auto-detect)
3. **Auto-detection**: Checks for `~/.docker-dockerhub-gornskew/config.json` with valid auth

For public repo clones (no credentials), defaults to `--no-push` and tags as `localbuild/*`.

## Extensibility

### Adding a New Feature

To add a new optional feature (e.g., `newfeature`):

1. **Build artifacts in builder stage**:
   ```dockerfile
   # In builder stage
   RUN set -euxo pipefail; \
       # ... build newfeature ...
   ```

2. **Create runtime stage**:
   ```dockerfile
   FROM runtime-base AS runtime-newfeature
   COPY --from=builder --chown=emacs-user:emacs-user /path/to/newfeature /path/to/newfeature
   ```

3. **Add to build script**:
   ```bash
   # In docker/build, add to STAGE_MAP:
   [newfeature]="runtime-newfeature"
   ```

4. **Add CLI flag**:
   ```bash
   # In docker/build argument parsing:
   --newfeature)
     TARGETS="$TARGETS newfeature"
     shift
     ;;
   ```

5. **Use it**:
   ```bash
   docker/build --newfeature --branch=devo
   # Creates: devo-newfeature
   ```

### Combining Features

To combine features, create a new stage:

```dockerfile
FROM runtime-gui AS runtime-gui-newfeature
COPY --from=builder --chown=emacs-user:emacs-user /path/to/newfeature /path/to/newfeature
```

Then:
```bash
docker/build --gui-newfeature
# Creates: devo-gui-newfeature
```

## Migration Notes

### From Old Build System

- `docker/build-all.sh` → `docker/build --all`
- `docker/push-all.sh` → `docker/build --all --push`
- `--variant=full` → `--full` or `--gui-aituis`
- `--variant=lite` → `--lite`

### From Old Tags

- `devo-full` (old 2.13GB) → `devo-gui-aituis` (new ~1.7GB)
- `devo-lite` (old 1.32GB) → `devo-lite` (new ~800MB)
- `latest` → Still points to `devo`

### Removed Features

- **Docker client**: No longer included in any variant
- **Dockerfile.full**: Removed - use multi-stage Dockerfile
- **Separate build scripts**: Consolidated into `docker/build`

## Authenticated Docker Hub Pulls (rate limits)

Docker Hub limits unauthenticated pulls to 10/hour per IPv4 address (and the
limit is shared by everything behind that IP). An authenticated free Personal
account gets 100 pulls/hour, counted per account instead of per IP.

Every host that pulls `gornskew/*` images (dev machines, production servers,
CI runners) should therefore be logged in:

```bash
# One-time per host, per user that runs docker/compose:
docker login -u gornskew   # paste a read-only access token, not the password
```

Notes:

- Create tokens at hub.docker.com → Account Settings → Personal access
  tokens. Use **read-only** tokens on pull-only hosts (production servers,
  runners); only the build/push machine needs read/write.
- Credentials land in `~/.docker/config.json` for the logged-in user. If a
  systemd unit runs compose as a different user (e.g. root), that user needs
  its own `docker login`.
- Once logged in, everything is covered: `docker pull`, `docker compose
  pull/up`, classic `docker build` base-image pulls, and `docker buildx`
  multi-arch builds (buildx forwards credentials from the client's
  `~/.docker/config.json` to the builder).
- `compose-dev` exports `DOCKER_CONFIG="$HOME/.docker"`, so compose finds
  the credentials regardless of invocation context.
- GitLab CI: for shell executors, `docker login` once as the runner's user;
  for docker executors, set the `DOCKER_AUTH_CONFIG` CI/CD variable instead.

## Troubleshooting

### Build fails with "Unknown target"
Make sure you're using valid target flags:
- `--lite`, `--aituis`/`--tui`, `--gui`, `--gui-aituis`/`--full`

### Images not pushing
Check:
1. Valid Docker Hub credentials in `~/.docker-dockerhub-gornskew/config.json`
2. Using `--push` flag
3. Not using `DOCKER_USERNAME=localbuild`

### Wrong branch detected
Explicitly specify: `docker/build --all --branch=master`

## Quick Reference

```bash
# Build everything for current branch
docker/build --all

# Build specific variant
docker/build --lite
docker/build --full

# Build for different branch
docker/build --all --branch=master

# Build and push
docker/build --all --push

# Get help
docker/build --help
```
