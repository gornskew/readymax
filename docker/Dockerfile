# Skewed Emacs — Additive Multi-Stage Build with Clean Layering
# Build tree:
#   common-runtime-base (ttyd, Node.js, lisply-mcp) - shared foundation
#   ├── runtime-base (+ emacs-nox)        → Tag: lite
#   │   └── runtime-aituis                → Tags: -aituis, -tui
#   └── runtime-gui-base (+ emacs-gtk + fonts + headless chromium)
#       └── runtime-gui                   → Tag: -gui
#           └── runtime-gui-aituis        → Tags: -gui-aituis, full, latest

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
# docs/, mcp/, etc. do NOT invalidate the expensive compile layers below.
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

# Copy the remainder of the repo (README, docs/, mcp/, docker/,
# generate-configs.el, services.sexp, ...). Kept late deliberately:
# changes to these files are cheap and rebuild in seconds.
COPY --chown=emacs-user:emacs-user . /home/emacs-user/skewed-emacs/

USER root
RUN set -euxo pipefail; \
   ln -sf /home/emacs-user/skewed-emacs/docker/copilot-language-server /usr/local/bin/copilot-language-server
USER emacs-user

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
     emacs --batch -l generate-configs.el -f skewed-generate-all-configs; \
     emacs --batch \
       --eval "(add-to-list 'load-path \"/home/emacs-user/skewed-emacs/dot-files/emacs.d/sideloaded/lisply-backend/source\")" \
       --eval "(setq lisply-search-services-path \"/home/emacs-user/skewed-emacs/services.sexp\")" \
       --eval "(setq lisply-search-index-path \"~/.emacs.d/sideloaded/lisply-backend/skewed-search-index.sexp\")" \
       -l lisply-search.el \
       --eval "(lisply-search-build-index-with-clone \"${GIT_BRANCH}\")"; \
   fi

# Cleanup builder caches
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

# Install minimal common runtime deps (NO Emacs yet)
RUN set -euxo pipefail; \
   apt-get update; \
   apt-get install -y --no-install-recommends \
     ncurses-term \
     curl wget git ca-certificates openssh-client \
     libvterm-dev \
     gnupg \
   ; \
   rm -rf /var/lib/apt/lists/*


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

# Copy common artifacts from builder (Emacs config, lisply-mcp, vterm)
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/skewed-emacs /home/emacs-user/skewed-emacs
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/lisply-mcp /home/emacs-user/lisply-mcp
COPY --from=builder /usr/local/bin/copilot-language-server /usr/local/bin/copilot-language-server

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

# Regenerate configs
RUN set -euxo pipefail; \
   cd ~/skewed-emacs; \
   emacs --batch -l generate-configs.el -f skewed-generate-all-configs


COPY --chown=emacs-user:emacs-user mcp/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=emacs-user:emacs-user docker/emacs-repl.sh /home/emacs-user/emacs-repl.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /home/emacs-user/emacs-repl.sh

RUN set -euxo pipefail; \
    /home/emacs-user/skewed-emacs/setup --force


ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


# ============================================================
# Runtime AI TUIs: Base + AI CLIs
# Tagged as: {branch}-aituis, {branch}-tui
# ============================================================
FROM runtime-base AS runtime-aituis

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

# Screenshot helper for headless chromium
COPY docker/webshot /usr/local/bin/webshot
RUN chmod +x /usr/local/bin/webshot

USER emacs-user

# Regenerate configs
RUN set -euxo pipefail; \
   cd ~/skewed-emacs; \
   emacs --batch -l generate-configs.el -f skewed-generate-all-configs


COPY --chown=emacs-user:emacs-user mcp/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=emacs-user:emacs-user docker/emacs-repl.sh /home/emacs-user/emacs-repl.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /home/emacs-user/emacs-repl.sh

RUN set -euxo pipefail; \
    /home/emacs-user/skewed-emacs/setup --force

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]


# ============================================================
# Runtime GUI: Alias for runtime-gui-base
# Tagged as: {branch}-gui
# ============================================================
FROM runtime-gui-base AS runtime-gui


# ============================================================
# Runtime GUI + AI TUIs: Everything
# Tagged as: {branch}-gui-aituis, {branch}-full, {branch}, latest
# ============================================================
FROM runtime-gui-base AS runtime-gui-aituis

# Copy AI CLI installations from builder
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.claude /home/emacs-user/.claude
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.codex /home/emacs-user/.codex
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.gemini /home/emacs-user/.gemini
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.grok /home/emacs-user/.grok
COPY --from=builder --chown=emacs-user:emacs-user /home/emacs-user/.local/bin /home/emacs-user/.local/bin
