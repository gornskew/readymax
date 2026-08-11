#!/bin/sh
# Install skewed-emacs as a systemd service on the current machine.
#
# Substitutes %%USER%% with the invoking user and derives SKEWED_DIR
# from the script's own location (../ relative to systemd-system/).
#
# Usage (run as the user who will own the service, with sudo available):
#
#   cd /path/to/skewed-emacs
#   sh systemd-system/deploy-systemd.sh
#
# Or, to override user/dir explicitly:
#
#   SKEWED_USER=dave SKEWED_DIR=/home/dave/projects/skewed-emacs \
#     sh systemd-system/deploy-systemd.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# TEMPLATE override lets stack repos install their host-specific unit
# (variant-pinned) under the same service name, replacing any legacy
# install:  TEMPLATE=/path/to/stack/systemd/skewed-emacs.service \
#             sh systemd-system/deploy-systemd.sh
TEMPLATE="${TEMPLATE:-${SCRIPT_DIR}/skewed-emacs.service}"
SERVICE_NAME="skewed-emacs"
SYSTEMD_DIR="/etc/systemd/system"

# ---- Resolve user and skewed-emacs directory --------------------------------

SKEWED_USER="${SKEWED_USER:-$(logname 2>/dev/null || echo "${USER:-$(id -un)}" )}"
SKEWED_DIR="${SKEWED_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

echo "=== Skewed Emacs systemd deploy ==="
echo "  User       : ${SKEWED_USER}"
echo "  Skewed dir : ${SKEWED_DIR}"
echo "  Service    : ${SYSTEMD_DIR}/${SERVICE_NAME}.service"
echo ""

# ---- Preflight checks -------------------------------------------------------

if [ ! -f "${TEMPLATE}" ]; then
    echo "ERROR: Template not found: ${TEMPLATE}"; exit 1
fi

if [ ! -x "${SKEWED_DIR}/compose-dev" ]; then
    echo "ERROR: compose-dev not found/executable at ${SKEWED_DIR}/compose-dev"; exit 1
fi

if ! id "${SKEWED_USER}" > /dev/null 2>&1; then
    echo "ERROR: User ${SKEWED_USER} does not exist"; exit 1
fi

if ! groups "${SKEWED_USER}" 2>/dev/null | grep -qw docker; then
    echo "WARNING: ${SKEWED_USER} is not in the docker group."
    echo "         Add with: usermod -aG docker ${SKEWED_USER}"
fi

# ---- Substitute template and install ----------------------------------------

UNIT_CONTENT=$(sed \
    -e "s|%%USER%%|${SKEWED_USER}|g" \
    -e "s|/home/%%USER%%/projects/skewed-emacs|${SKEWED_DIR}|g" \
    "${TEMPLATE}")

if [ -f "${SYSTEMD_DIR}/${SERVICE_NAME}.service" ]; then
    echo "--- Existing service (will be replaced) ---"
    cat "${SYSTEMD_DIR}/${SERVICE_NAME}.service"
    echo ""
fi

printf '%s\n' "${UNIT_CONTENT}" | sudo tee "${SYSTEMD_DIR}/${SERVICE_NAME}.service" > /dev/null
echo "Wrote ${SYSTEMD_DIR}/${SERVICE_NAME}.service"

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
echo "Enabled ${SERVICE_NAME} (starts on boot)"

# ---- Optionally start now ---------------------------------------------------

if systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
    echo ""
    echo "Service is already running. To apply changes:"
    echo "  sudo systemctl restart ${SERVICE_NAME}"
else
    echo ""
    printf "Start %s now? [y/N] " "${SERVICE_NAME}"
    read -r answer
    case "$answer" in
        [Yy]*)
            sudo systemctl start "${SERVICE_NAME}"
            echo "Waiting for containers..."
            sleep 10
            sudo systemctl status "${SERVICE_NAME}" --no-pager || true
            echo ""
            echo "Verify enterprise container health:"
            echo "  docker exec genworks-gdl-enterprise-smp curl -sf http://localhost:9098/lisply/ping-lisp"
            ;;
        *)
            echo "Start when ready: sudo systemctl start ${SERVICE_NAME}"
            ;;
    esac
fi

echo ""
echo "=== Done ==="
echo "Useful commands:"
echo "  sudo systemctl status ${SERVICE_NAME}"
echo "  sudo journalctl -u ${SERVICE_NAME} -f"
echo "  sudo systemctl stop|restart ${SERVICE_NAME}"
