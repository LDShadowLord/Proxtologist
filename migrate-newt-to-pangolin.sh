#!/usr/bin/env bash
# ==============================================================================
# migrate-newt-to-pangolin.sh
#
# Migrates a running Pangolin NEWT SystemD install to Pangolin CLI SystemD install
# by reading /etc/newt/newt.env and letting the Pangolin CLI install the service.
#
# Docs:
#   - https://docs.pangolin.net/manage/sites/install-newt
#   - https://docs.pangolin.net/manage/sites/install-site
#   - https://docs.pangolin.net/manage/sites/update-site
# ==============================================================================

set -euo pipefail

# 1. Require root privileges
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (or with sudo)." >&2
    exit 1
fi

NEWT_ENV="/etc/newt/newt.env"

# 2. Extract credentials from newt.env
echo "[INFO] Reading configuration from ${NEWT_ENV}..."
if [ ! -f "$NEWT_ENV" ]; then
    echo "[ERROR] ${NEWT_ENV} not found!" >&2
    exit 1
fi

# Source newt.env to import existing variables
set -a
# shellcheck source=/dev/null
. "$NEWT_ENV"
set +a

SITE_ID="${SITE_ID:-${NEWT_ID:-}}"
SITE_SECRET="${SITE_SECRET:-${NEWT_SECRET:-}}"
PANGOLIN_ENDPOINT="${PANGOLIN_ENDPOINT:-https://app.pangolin.net}"

if [ -z "$SITE_ID" ] || [ -z "$SITE_SECRET" ]; then
    echo "[ERROR] Failed to extract Site ID or Secret from ${NEWT_ENV}." >&2
    exit 1
fi

echo "[INFO] Found Site ID: ${SITE_ID}"
echo "[INFO] Using Endpoint: ${PANGOLIN_ENDPOINT}"

# 3. Stop and disable legacy newt service
echo "[INFO] Stopping and disabling newt systemd service..."
systemctl stop newt 2>/dev/null || true
systemctl disable newt 2>/dev/null || true

# Archive old unit file if present to avoid any future conflicts
if [ -f /etc/systemd/system/newt.service ]; then
    mv /etc/systemd/system/newt.service /etc/systemd/system/newt.service.bak
    systemctl daemon-reload
fi

# 4. Install / update Pangolin CLI
echo "[INFO] Installing latest Pangolin CLI binary..."
curl -fsSL https://static.pangolin.net/get-cli.sh | bash

PANGOLIN_BIN="$(command -v pangolin 2>/dev/null || echo /usr/local/bin/pangolin)"
if [ ! -x "$PANGOLIN_BIN" ]; then
    echo "[ERROR] Pangolin binary not found or not executable at ${PANGOLIN_BIN}." >&2
    exit 1
fi

# 5. Let Pangolin CLI installer create and manage the service
echo "[INFO] Installing site service via Pangolin CLI..."
"$PANGOLIN_BIN" service install site \
    --id "$SITE_ID" \
    --secret "$SITE_SECRET" \
    --endpoint "$PANGOLIN_ENDPOINT"

# 6. Ensure started and check status
"$PANGOLIN_BIN" service start site 2>/dev/null || true

echo ""
echo "[INFO] Checking service status:"
"$PANGOLIN_BIN" service status site || true

echo ""
echo "[SUCCESS] Migration complete!"
echo "View service logs anytime with:  pangolin service logs site"
echo "Or via systemd:                  journalctl -u pangolin-site -f"
