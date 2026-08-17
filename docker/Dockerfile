# Copyright © 2026 Gornskew Enterprises
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.  Distributed WITHOUT
# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

# Skewed Emacs — Additive Multi-Stage Build with Clean Layering
# Build tree (primary split: non-GUI vs GUI):
#   common-runtime-base (ttyd, Node.js, lisply-mcp, webshot, skewed-install)
#   ├── runtime-base (+ emacs-nox)                    → Tag: -lite
#   │   └── runtime-default (+ chrome-headless-shell + fonts)
#   │       │                     → Tags: -default, {branch}, latest (devo)
#   │       └── runtime-aituis (+ AI CLIs)             → Tags: -aituis, -tui
#   └── runtime-gui-base (+ emacs-gtk + fonts + chromium: full X workstation)
#       └── runtime-gui                               → Tag: -gui
#           └── runtime-gui-aituis (+ AI CLIs)
#                                     → Tags: -gui-aituis, -full
#
# The general-distribution default ({branch}/latest) is the non-GUI image
# with web-page snapshotting via chrome-headless-shell (Playwright's
# build: Chrome-for-Testing ships no linux/arm64).  AI TUIs install
# on demand via skewed-install (M-x skewed-install in Emacs); for them
# baked-in, pull -aituis or -full.  Size rationale and measurements:
# docs/SLIMMING_MEASUREMENTS.md.

FROM debian:stable-slim AS node
ARG DEBIAN_FRONTENT=noninteractive

ARG NODE_VERSION=24.13.0

SHELL ["/bin/bash","-lc"]

RUN set -euxo pipefail; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates curl xz-utils; \
  rm -rf /var/lib/apt/lists/*; \
  arch="$(dpkg --print-architecture)"; \
  case "$arch" in \
    amd64) node_arch="x64" ;; \
    arm64) node_arch="arm64" ;; \
    *) echo "Unsupported arch: $arch" >&2; exit 1 ;; \
  esac; \
  cd /tmp; \
  curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
  curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"; \
  grep "node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" SHASUMS256.txt | sha256sum -c -; \
  tar -C /usr/local --strip-components=1 -xJf "node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
  rm -rf /tmp/*


FROM debian:stable-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_BRANCH=master
ARG LISPLY_MCP_REVISION=latest
ARG SKEWED_BUILD_SKEWED_INDEX=true


SHELL ["/bin/bash", "-lc"]

# ============================================================
# Builder: Build ALL artifacts (GUI + AI CLIs)
# ============================================================

# Install ALL build dependencies (both GUI and non-GUI)
RUN set -euxo pipefail; \
   apt-get update; \
   apt-get install -y --no-install-recommends \
     emacs-gtk \
     ncurses-term \
     curl wget git ca-certificates openssh-client \
     ghostscript poppler-utils \
     unzip gnupg \
     fontconfig \
     fonts-noto fonts-noto-color-emoji fonts-noto-mono \
     fonts-font-awesome fonts-symbola fonts-powerline \
     automake autoconf make gcc g++ pkg-config \
     libpng-dev \
     libpoppler-glib-dev libpoppler-private-dev \
     cmake libtool \
     libvterm-dev \
   ; \
   rm -rf /var/lib/apt/lists/*

# Install Nerd Fonts (for GUI builds)
RUN set -euxo pipefail; \
   mkdir -p /usr/share/fonts/truetype/nerd-fonts; \
   curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/NerdFontsSymbolsOnly.zip \
     -o /tmp/NerdFontsSymbolsOnly.zip; \
   unzip -q /tmp/NerdFontsSymbolsOnly.zip -d /usr/share/fonts/truetype/nerd-fonts; \
   rm -f /tmp/NerdFontsSymbolsOnly.zip; \
   fc-cache -fv

# Create user
RUN set -euxo pipefail; \
   groupadd -g 1000 emacs-user; \
   useradd -m -s /bin/bash -u 1000 -g emacs-user emacs-user; \
   mkdir -p /projects; \
   chown emacs-user:emacs-user /projects; \
   ln -s /projects /home/emacs-user/projects

# Copy only what package install + native compilation need (dot-files,
# setup). The rest of the repo is copied later, so edits to README,
# docs/, etc. do NOT invalidate the expensive compile layers below.
COPY --chown=emacs-user:emacs-user dot-files/ /home/emacs-user/skewed-emacs/dot-files/
COPY --chown=emacs-user:emacs-user setup /home/emacs-user/skewed-emacs/setup

USER emacs-user
WORKDIR /home/emacs-user

# Setup skewed-emacs config
RUN set -euxo pipefail; \
   cd skewed-emacs; \
   SKEWED_EMACS_DOCKER_BUILD=true ./setup --force

# Initial package load
RUN set -euxo pipefail; \
   START_HTTP=false SKEWED_EMACS_DOCKER_BUILD=true emacs --batch \
     --load "~/.emacs.d/init.el"

# Build vterm (needed for all variants)
RUN set -euxo pipefail; \
   START_HTTP=false SKEWED_EMACS_DOCKER_BUILD=true emacs --batch \
     --load "~/.emacs.d/init.el" \
     --eval "(vterm-module-compile)"

# Build pdf-tools (for GUI variants)
RUN set -euxo pipefail; \
   PDFDIR="$(ls -d /home/emacs-user/.emacs.d/elpa/pdf-tools-* 2>/dev/null | head -n1)"; \
   if [ -n "$PDFDIR" ]; then \
     cd "$PDFDIR"; \
     ./build/server/autobuild -i "$PDFDIR"; \
     cd /home/emacs-user; \
     START_HTTP=false SKEWED_EMACS_DOCKER_BUILD=true emacs --batch \
       --load "~/.emacs.d/init.el" \
       --eval "(require 'pdf-tools)"; \
   else \
     echo "pdf-tools not found, skipping build"; \
   fi

# Recompile packages
RUN set -euxo pipefail; \
   START_HTTP=false SKEWED_EMACS_DOCKER_BUILD=true emacs --batch \
     --load "~/.emacs.d/init.el" \
     --eval "(recompile-all-packages)"

# Install nerd-icons fonts (for GUI variants)
RUN set -euxo pipefail; \
   START_HTTP=false SKEWED_EMACS_DOCKER_BUILD=true emacs --batch \
     --load "~/.emacs.d/init.el" \
     --eval "(when (package-installed-p 'nerd-icons) (nerd-icons-install-fonts t))"; \
   fc-cache -fv

USER root

# copy in node.js in /usr/local/
COPY --from=node /usr/local/ /usr/local/



USER emacs-user

RUN set -euxo pipefail; \
    if [ ! -d "lisply-mcp" ]; then \
      git clone --depth 1 --branch "${GIT_BRANCH}" https://github.com/gornskew/lisply-mcp.git || \
      { echo "Error: Failed to clone lisply-mcp on branch ${GIT_BRANCH}. Does the branch exist in the remote repo?"; exit 1; }; \
    fi; \
    cd lisply-mcp/scripts; \
    npm ci --omit=dev; \
    npm cache clean --force || true; \
    echo "lisply-mcp revision: ${LISPLY_MCP_REVISION}"
    
ENV PATH="/home/emacs-user/.local/bin:${PATH}"

# Install AI TUI CLIs (for -aituis variants)
RUN set -euxo pipefail; \
   mkdir -p ~/.claude/local ~/.local/bin; \
   npm install --omit=dev @anthropic-ai/claude-code --prefix ~/.claude/local; \
   ln -sf ~/.claude/local/node_modules/.bin/claude ~/.local/bin/claude; \
   npm cache clean --force || true

RUN set -euxo pipefail; \
   mkdir -p ~/.codex/local; \
   npm install --omit=dev @openai/codex --prefix ~/.codex/local; \
   ln -sf ~/.codex/local/node_modules/.bin/codex ~/.local/bin/codex; \
   npm cache clean --force || true

RUN set -euxo pipefail; \
   mkdir -p ~/.gemini/local; \
   npm install --omit=dev @google/gemini-cli --prefix ~/.gemini/local; \
   ln -sf ~/.gemini/local/node_modules/.bin/gemini ~/.local/bin/gemini; \
   npm cache clean --force || true

# Grok Build CLI (xAI) — binary installer (not npm). Optional pin via
# GROK_VERSION=X.Y.Z; default is latest stable from https://x.ai/cli.
ARG GROK_VERSION=
RUN set -euxo pipefail; \
   mkdir -p ~/.grok/bin ~/.grok/downloads ~/.local/bin; \
   if [ -n "${GROK_VERSION}" ]; then \
     curl -fsSL https://x.ai/cli/install.sh | bash -s "${GROK_VERSION}"; \
   else \
     curl -fsSL https://x.ai/cli/install.sh | bash; \
   fi; \
   ln -sfn ~/.grok/bin/grok ~/.local/bin/grok; \
   ln -sfn ~/.grok/bin/agent ~/.local/bin/agent; \
   ~/.local/bin/grok --version

# Copy the remainder of the repo (README, docs/, docker/, ...).
# Kept late deliberately: changes to these files are cheap and rebuild in
# seconds.  No longer carries generate-configs.el or services.sexp -- the
# stack machinery moved to the Basilisk repo (2026-08-15).
COPY --chown=emacs-user:emacs-user . /home/emacs-user/skewed-emacs/

# copilot-language-server is NOT baked into any image (2026-08-16).  It
# used to be a 65MB pkg-built binary committed at docker/copilot-language-
# server and copied here.  Two reasons it went away: it is GitHub's to
# distribute, not ours to commit; and that binary was x86-64 ELF, copied
# unchanged into the arm64 images, where it could never have run.
# Install it on demand instead -- `skewed-install copilot-language-server`
# -- which resolves the right per-platform package from npm.

# Start daemon to settle async init
RUN set -euxo pipefail; \
   START_HTTP=true SKEWED_EMACS_DOCKER_BUILD=true emacs --daemon --load "~/.emacs.d/init.el"; \
   sleep 8; \
   emacsclient --eval "(load \"~/skewed-emacs/docker/wait-for-async.el\")"

# Build skewed_search index inside the image (no host mounts).
# Uses lisply-search.el which handles cloning repos if /projects/ is empty.
RUN set -euxo pipefail; \
   if [ "${SKEWED_BUILD_SKEWED_INDEX}" = "true" ]; then \
     mkdir -p /projects; \
     ln -sfn /home/emacs-user/skewed-emacs /projects/skewed-emacs; \
     cd /home/emacs-user/skewed-emacs; \
     emacs --batch \
       --eval "(add-to-list 'load-path \"/home/emacs-user/skewed-emacs/dot-files/emacs.d/sideloaded/lisply-backend/source\")" \
       --eval "(setq lisply-search-services-path \"/home/emacs-user/skewed-emacs/dot-files/emacs.d/sideloaded/lisply-backend/skewed-search-config.sexp\")" \
       --eval "(setq lisply-search-index-path \"~/.emacs.d/sideloaded/lisply-backend/skewed-search-index.sexp\")" \
       -l lisply-search.el \
       --eval "(lisply-search-build-index-with-clone \"${GIT_BRANCH}\")"; \
   fi

# Cleanup builder caches.
RUN set -euxo pipefail; \
   rm -rf ~/.cache /tmp/*; \
   rm -rf ~/.emacs.d/elpa/*/.git 2>/dev/null || true


# ============================================================
# Common Runtime Base: Shared foundation (ttyd, Node.js, lisply-mcp)
# This layer is inherited by BOTH GUI and non-GUI branches
# ============================================================
FROM debian:stable-slim AS common-runtime-base

ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-lc"]

# Install minimal common runtime deps (NO Emacs yet).  sudo backs
# skewed-install's apt-using modules (e.g. headless-shell libs on lite):
# this is an explicitly trusted sandbox image, so emacs-user gets
# passwordless sudo for in-container on-demand installs.
RUN set -euxo pipefail; \
   apt-get update; \
   apt-get install -y --no-install-recommends \
     ncurses-term \
     curl wget git ca-certificates openssh-client \
     libvterm-dev \
     gnupg \
     sudo \
   ; \
   rm -rf /var/lib/apt/lists/*; \
   echo "emacs-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/emacs-user; \
   chmod 0440 /etc/sudoers.d/emacs-user


# copy in node.js in /usr/local/
COPY --from=node /usr/local/ /usr/local/


# Install ttyd (web terminal - needed for all variants)
ARG TARGETARCH=amd64  # default fallback
RUN set -euxo pipefail; \
    case "${TARGETARCH}" in \
      amd64)   TTYD_ARCH="x86_64" ;; \
      arm64)   TTYD_ARCH="aarch64" ;; \
      *)       echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    wget -O /usr/local/bin/ttyd "https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.${TTYD_ARCH}"; \
    chmod +x /usr/local/bin/ttyd; \
    ln -sf /usr/local/bin/ttyd /usr/local/bin/webterm

# Create user
RUN set -euxo pipefail; \
   groupadd -g 1000 emacs-user; \
   useradd -m -s /bin/bash -u 1000 -g emacs-user emacs-user; \
   mkdir -p /projects; \
   chown emacs-user:emacs-user /projects; \
   ln -s /projects /home/emacs-user/projects

# Copy common artifacts from builder (Emacs config, lisply-mcp, vterm).
# copilot-language-server is in no image at all: install it on demand
# with `skewed-install copilot-language-server`.
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/skewed-emacs /home/emacs-user/skewed-emacs
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/lisply-mcp /home/emacs-user/lisply-mcp

# Common tooling: entrypoint, repl helper, page-snapshot helpers (webshot
# resolves chromium OR chrome-headless-shell at runtime), on-demand
# module installer (elisp-first UI: M-x skewed-install).
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=emacs-user:emacs-user docker/emacs-repl.sh /home/emacs-user/emacs-repl.sh
COPY docker/webshot /usr/local/bin/webshot
COPY docker/webshot-clip /usr/local/bin/webshot-clip
COPY docker/skewed-install /usr/local/bin/skewed-install
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/webshot \
      /usr/local/bin/webshot-clip /usr/local/bin/skewed-install \
      /home/emacs-user/emacs-repl.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

USER emacs-user
WORKDIR /home/emacs-user

ENV TERM=xterm-256color
ENV COLORTERM=truecolor
ENV SKEWED_EMACS_CONTAINER=true
ENV PATH="/home/emacs-user/.local/bin:${PATH}"

RUN set -euxo pipefail; \
   /home/emacs-user/skewed-emacs/setup --force
   

# ============================================================
# Runtime Base: Common base + emacs-nox (TUI only)
# Tagged as: {branch}-lite
# ============================================================
FROM common-runtime-base AS runtime-base

USER root

# Install emacs-nox (terminal-only Emacs)
RUN set -euxo pipefail; \
   apt-get update; \
   apt-get install -y --no-install-recommends emacs-nox; \
   rm -rf /var/lib/apt/lists/*

USER emacs-user

# NO config regeneration here.  Generating stack configs is yard work and
# belongs to the Basilisk repo; this image is one crew member's quarters.
# Removed 2026-08-15 with the rip -- there were TWO of these, one per image
# variant stage, and fixing only the third call site in the search-index
# step left both of these to fail the next build.
RUN set -euxo pipefail; \
    /home/emacs-user/skewed-emacs/setup --force


# ============================================================
# Runtime Default: lite + web-page snapshotting.
# The general-distribution default image.
# Tagged as: {branch}-default, {branch}, latest (devo)
# ============================================================
FROM runtime-base AS runtime-default

USER root

# chrome-headless-shell's shared-library closure plus fonts for decent
# renders.  Measured 2026-08-11 (docs/SLIMMING_MEASUREMENTS.md): ~610MB
# all-in vs ~1.1GB for Debian's chromium package, which drags the full
# X/mesa/llvm stack even when only used headless.
RUN set -euxo pipefail; \
   apt-get update; \
   apt-get install -y --no-install-recommends \
     libx11-6 libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 \
     libasound2 libatk1.0-0 libatk-bridge2.0-0 libatspi2.0-0 \
     libdbus-1-3 libexpat1 libgbm1 libglib2.0-0 libnspr4 libnss3 \
     libxcb1 libxkbcommon0 \
     fontconfig fonts-liberation fonts-noto-core fonts-noto-color-emoji \
     fonts-noto-mono \
   ; \
   rm -rf /var/lib/apt/lists/*; \
   fc-cache -f

# Playwright's chromium-headless-shell build: unlike Chrome-for-Testing
# it ships linux/arm64, matching this image's native per-arch CI builds.
# Version pinned for reproducible provenance.
ARG PLAYWRIGHT_CORE_VERSION=1.62.1
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright
RUN set -euxo pipefail; \
   npx -y "playwright-core@${PLAYWRIGHT_CORE_VERSION}" install chromium-headless-shell; \
   shell_bin="$(find /opt/ms-playwright -type f \( -name chrome-headless-shell -o -name headless_shell \) | head -1)"; \
   test -n "${shell_bin}"; \
   ln -sf "${shell_bin}" /usr/local/bin/chrome-headless-shell; \
   chmod -R a+rX /opt/ms-playwright; \
   rm -rf /root/.npm /root/.cache; \
   /usr/local/bin/chrome-headless-shell --version

USER emacs-user


# ============================================================
# Runtime AI TUIs: Default + AI CLIs
# Tagged as: {branch}-aituis, {branch}-tui
# ============================================================
FROM runtime-default AS runtime-aituis

# Copy AI CLI installations from builder
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.claude /home/emacs-user/.claude
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.codex /home/emacs-user/.codex
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.gemini /home/emacs-user/.gemini
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.grok /home/emacs-user/.grok
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.local/bin /home/emacs-user/.local/bin


# ============================================================
# Runtime GUI Base: Common base + emacs-gtk + fonts
# This is the GUI equivalent of runtime-base
# ============================================================
FROM common-runtime-base AS runtime-gui-base

USER root

# Install GUI-specific packages (emacs-gtk, fonts, PDF support,
# headless chromium for page screenshots -- see docker/webshot)
RUN set -euxo pipefail; \
   apt-get update; \
   apt-get install -y --no-install-recommends \
     emacs-gtk \
     ghostscript poppler-utils libpoppler-glib8 \
     fontconfig \
     fonts-noto fonts-noto-color-emoji fonts-noto-mono \
     fonts-font-awesome fonts-symbola fonts-powerline \
     fonts-liberation \
     chromium \
   ; \
   rm -rf /var/lib/apt/lists/*

# Copy GUI-specific artifacts (Nerd Fonts)
COPY --from=builder /usr/share/fonts/truetype/nerd-fonts /usr/share/fonts/truetype/nerd-fonts
RUN fc-cache -fv

USER emacs-user

# NO config regeneration here.  Generating stack configs is yard work and
# belongs to the Basilisk repo; this image is one crew member's quarters.
# Removed 2026-08-15 with the rip -- there were TWO of these, one per image
# variant stage, and fixing only the third call site in the search-index
# step left both of these to fail the next build.
RUN set -euxo pipefail; \
    /home/emacs-user/skewed-emacs/setup --force


# ============================================================
# Runtime GUI: Alias for runtime-gui-base
# Tagged as: {branch}-gui
# ============================================================
FROM runtime-gui-base AS runtime-gui


# ============================================================
# Runtime GUI + AI TUIs: Everything (the kitchen-sink-plus-jacuzzi suite)
# Tagged as: {branch}-gui-aituis, {branch}-full
# ============================================================
FROM runtime-gui-base AS runtime-gui-aituis

# Copy AI CLI installations from builder
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.claude /home/emacs-user/.claude
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.codex /home/emacs-user/.codex
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.gemini /home/emacs-user/.gemini
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.grok /home/emacs-user/.grok
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.local/bin /home/emacs-user/.local/bin
