#!/bin/sh
# Copyright (C) 2026 Gornskew Enterprises
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.  Distributed WITHOUT
# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

# DEPRECATED path -- the installer moved to systemd/install
# (naming normalized with the *-stack repos' systemd/install, 2026-08-11).
# This shim keeps not-yet-updated callers working; update them to:
#   sh systemd/install
echo "NOTE: systemd-system/deploy-systemd.sh moved to systemd/install; forwarding..." >&2
exec sh "$(cd "$(dirname "$0")/.." && pwd)/systemd/install"
