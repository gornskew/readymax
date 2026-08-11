#!/bin/sh
# DEPRECATED path -- the installer moved to systemd/install
# (naming normalized with the *-stack repos' systemd/install, 2026-08-11).
# This shim keeps not-yet-updated callers working; update them to:
#   sh systemd/install
echo "NOTE: systemd-system/deploy-systemd.sh moved to systemd/install; forwarding..." >&2
exec sh "$(cd "$(dirname "$0")/.." && pwd)/systemd/install"
