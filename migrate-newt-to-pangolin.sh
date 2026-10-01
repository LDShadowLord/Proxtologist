#!/usr/bin/env bash
# ==============================================================================
# migrate-newt-to-pangolin.sh
#
# Migrates a running Pangolin NEWT SystemD install to Pangolin CLI SystemD install
# by reading /etc/newt/newt.env (or falling back to /etc/systemd/system/newt.service)
# and letting the Pangolin CLI install the service.
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
NEWT_SERVICE="/etc/systemd/system/newt.service"

SITE_ID=""
SITE_SECRET=""
PANGOLIN_ENDPOINT=""

# 2. Extract credentials: check newt.env first, then fallback to newt.service
if [ -f "$NEWT_ENV" ]; then
    echo "[INFO] Reading configuration from ${NEWT_ENV}..."
    set -a
    # shellcheck source=/dev/null
    . "$NEWT_ENV"
    set +a

    SITE_ID="${SITE_ID:-${NEWT_ID:-}}"
    SITE_SECRET="${SITE_SECRET:-${NEWT_SECRET:-}}"
    PANGOLIN_ENDPOINT="${PANGOLIN_ENDPOINT:-}"
elif [ -f "$NEWT_SERVICE" ]; then
    echo "[INFO] ${NEWT_ENV} not found. Inspecting ${NEWT_SERVICE} for configuration..."

    # Check if newt.service points to another EnvironmentFile
    ENV_FILE_REF=$(grep -E '^[[:space:]]*EnvironmentFile=' "$NEWT_SERVICE" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d '"'\''-' | xargs || true)
    if [ -n "$ENV_FILE_REF" ] && [ -f "$ENV_FILE_REF" ]; then
        echo "[INFO] Found referenced EnvironmentFile: ${ENV_FILE_REF}"
        set -a
        # shellcheck source=/dev/null
        . "$ENV_FILE_REF"
        set +a
        SITE_ID="${SITE_ID:-${NEWT_ID:-}}"
        SITE_SECRET="${SITE_SECRET:-${NEWT_SECRET:-}}"
        PANGOLIN_ENDPOINT="${PANGOLIN_ENDPOINT:-}"
    fi

    # Check for inline Environment= directives
    if [ -z "$SITE_ID" ]; then
        SITE_ID=$(grep -E '^[[:space:]]*Environment=' "$NEWT_SERVICE" 2>/dev/null | grep -o -E '(NEWT_ID|SITE_ID)=[^ ]+' | head -n1 | cut -d= -f2- | sed -E "s/^[[:space:]]*[\"']?//; s/[\"']?[[:space:]]*$//" || true)
    fi
    if [ -z "$SITE_SECRET" ]; then
        SITE_SECRET=$(grep -E '^[[:space:]]*Environment=' "$NEWT_SERVICE" 2>/dev/null | grep -o -E '(NEWT_SECRET|SITE_SECRET)=[^ ]+' | head -n1 | cut -d= -f2- | sed -E "s/^[[:space:]]*[\"']?//; s/[\"']?[[:space:]]*$//" || true)
    fi
    if [ -z "$PANGOLIN_ENDPOINT" ]; then
        PANGOLIN_ENDPOINT=$(grep -E '^[[:space:]]*Environment=' "$NEWT_SERVICE" 2>/dev/null | grep -o -E 'PANGOLIN_ENDPOINT=[^ ]+' | head -n1 | cut -d= -f2- | sed -E "s/^[[:space:]]*[\"']?//; s/[\"']?[[:space:]]*$//" || true)
    fi

    # Check for CLI flags in ExecStart (handles single or multiline flags)
    if [ -z "$SITE_ID" ] || [ -z "$SITE_SECRET" ]; then
        EXEC_CONTENT=$(grep -A 5 -E '^[[:space:]]*ExecStart=' "$NEWT_SERVICE" 2>/dev/null || true)
        [ -z "$SITE_ID" ] && SITE_ID=$(echo "$EXEC_CONTENT" | sed -n -E "s/.*--id[ =]+([^ \"'\\\ ]+).*/\1/p" | head -n1)
        [ -z "$SITE_SECRET" ] && SITE_SECRET=$(echo "$EXEC_CONTENT" | sed -n -E "s/.*--secret[ =]+([^ \"'\\\ ]+).*/\1/p" | head -n1)
        [ -z "$PANGOLIN_ENDPOINT" ] && PANGOLIN_ENDPOINT=$(echo "$EXEC_CONTENT" | sed -n -E "s/.*--endpoint[ =]+([^ \"'\\\ ]+).*/\1/p" | head -n1)
    fi
else
    echo "[ERROR] Neither ${NEWT_ENV} nor ${NEWT_SERVICE} were found!" >&2
    exit 1
fi

PANGOLIN_ENDPOINT="${PANGOLIN_ENDPOINT:-https://app.pangolin.net}"

if [ -z "$SITE_ID" ] || [ -z "$SITE_SECRET" ]; then
    echo "[ERROR] Failed to extract Site ID or Secret from ${NEWT_ENV} or ${NEWT_SERVICE}." >&2
    exit 1
fi

echo "[INFO] Found Site ID: ${SITE_ID}"
echo "[INFO] Using Endpoint: ${PANGOLIN_ENDPOINT}"

# 3. Stop and disable legacy newt service
echo "[INFO] Stopping and disabling newt systemd service..."
systemctl stop newt 2>/dev/null || true
systemctl disable newt 2>/dev/null || true

# Archive old unit file if present to avoid conflicts
if [ -f "$NEWT_SERVICE" ]; then
    mv "$NEWT_SERVICE" "${NEWT_SERVICE}.bak"
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
