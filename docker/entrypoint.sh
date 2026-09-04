#!/bin/bash
# Copyright © 2026 Gornskew Enterprises
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.  Distributed WITHOUT
# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

# Combined entrypoint for skewed-emacs with MCP middleware
# Starts Emacs daemon in background, presents MCP interface on stdio

cleanup() {
    echo "Received signal, shutting down..."
    # Kill emacs daemon if running
    emacsclient -e "(kill-emacs)" 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

set -e

# Check for batch mode (build time)
BATCH_MODE=false
if [ "$1" = "--batch" ]; then
    BATCH_MODE=true
    echo "=== Build-Time Package Installation ==="
    echo "Running emacs once to install packages via init.el..."
fi

# Runtime configuration
HTTP_PORT=${HTTP_PORT:-7080}
START_HTTP=${START_HTTP:-true}
START_SWANK=${START_SWANK:-false}
SWANK_PORT=${SWANK_PORT:-4200}

if [ "$BATCH_MODE" = "false" ]; then
    echo "=== Skewed Emacs + MCP Container Startup ==="
    echo "HTTP_PORT: $HTTP_PORT"
    echo "START_HTTP: $START_HTTP"
    echo "START_SWANK: $START_SWANK"
    echo "SWANK_PORT: $SWANK_PORT"
fi

# Start Emacs daemon in background
echo "Starting Emacs daemon..."
SHELL=/bin/bash TERM=${TERM} COLORTERM=${COLORTERM} emacs --daemon --load /home/emacs-user/.emacs.d/init.el > /tmp/emacs-daemon.log 2>&1 &
EMACS_PID=$!

# Wait for daemon to be ready
echo "Waiting for daemon to start..."
for i in {1..30}; do
    if emacsclient --eval "t" > /dev/null 2>&1; then
        echo "Emacs daemon ready"
        break
    elif [ $i -eq 30 ]; then
        echo "Daemon failed to start"
        echo "Daemon log:"
        cat /tmp/emacs-daemon.log
        exit 1
    else
        sleep 1
    fi
done

# === Optionally start web terminal in background ===
# WEBTERM_ARGS: extra flags for the terminal server, e.g. for ttyd
#   "-b /hack -a -m 8" (base path behind a reverse proxy, URL-arg
#   passing, client cap).  WEBTERM_ENTRY: the command every new
#   browser connection runs, default "emacsclient -t" -- a fresh tty
#   frame on the shared daemon.  With ttyd's -a among WEBTERM_ARGS,
#   the URL's ?arg=... values arrive as its positional arguments.
if [ -n "${WEBTERM:-}" ] && [ "${WEBTERM}" != "none" ]; then
    case "${WEBTERM}" in
      ttyd)
        WEBTERM_CMD="/usr/local/bin/ttyd -W -p ${WEBTERM_PORT:-6942} -6 ${WEBTERM_ARGS:-}"
        ;;
      gotty-soren)
        WEBTERM_CMD="/usr/local/bin/gotty-soren -w --port ${WEBTERM_PORT:-6942}"
        ;;
      none)
        echo "Web terminal explicitly disabled"
        exit 0
        ;;
      *)
        echo "Invalid WEBTERM: $WEBTERM (supported: ttyd, gotty-soren, none)" >&2
        exit 1
        ;;
    esac

    echo "Starting web terminal in background: $WEBTERM on port ${WEBTERM_PORT:-6942}${WEBTERM_ARGS:+ ($WEBTERM_ARGS)}"
    $WEBTERM_CMD /bin/bash -c "exec ${WEBTERM_ENTRY:-emacsclient -t} \"\$@\"" _ &
else
    echo "No web terminal requested — only interactive REPL on stdio"
fi

# === Always run Emacs REPL in foreground on stdio (your invariant) ===
echo "Starting interactive Emacs REPL on container stdio..."
exec /home/emacs-user/emacs-repl.sh
