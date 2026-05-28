#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST_PATH="/Library/LaunchDaemons/com.dockerhole.loopback.plist"

cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# Resolve LOOPBACK_IP from .env or fall back to default
# ---------------------------------------------------------------------------
LOOPBACK_IP="127.0.0.2"
if [ -f ".env" ]; then
  _val=$(grep '^LOOPBACK_IP=' .env 2>/dev/null | cut -d'=' -f2- | tr -d ' "' || true)
  [ -n "$_val" ] && LOOPBACK_IP="$_val"
fi

echo "==> Using loopback alias IP: ${LOOPBACK_IP}"

# ---------------------------------------------------------------------------
# 1. Stop containers
# ---------------------------------------------------------------------------
echo "==> Stopping containers..."
docker compose down
echo "    Done."

# ---------------------------------------------------------------------------
# 2. Unload and remove the LaunchDaemon
# ---------------------------------------------------------------------------
echo "==> Checking LaunchDaemon at ${PLIST_PATH}..."
if [ -f "$PLIST_PATH" ]; then
  echo "    Unloading and removing (requires sudo)..."
  sudo launchctl unload "$PLIST_PATH"
  sudo rm -f "$PLIST_PATH"
  echo "    Done."
else
  echo "    Not found — skipping."
fi

# ---------------------------------------------------------------------------
# 3. Remove the loopback alias
# ---------------------------------------------------------------------------
echo "==> Removing loopback alias ${LOOPBACK_IP}..."
if ifconfig lo0 | grep -qF "${LOOPBACK_IP}"; then
  sudo ifconfig lo0 -alias "${LOOPBACK_IP}"
  echo "    Done."
else
  echo "    Alias not found — skipping."
fi

# ---------------------------------------------------------------------------
# 4. Remind user to restore DNS settings
# ---------------------------------------------------------------------------
cat <<EOF

============================================================
  Dockerhole has been torn down.
============================================================

  Remember to restore your DNS settings:

  System Settings > Wi-Fi (or Ethernet) > Details > DNS
  Remove ${LOOPBACK_IP} and add back a public resolver
  (e.g. 1.1.1.1 or 8.8.8.8).

  Or if you used /etc/resolver:
    sudo rm -f /etc/resolver/default

  Flush the DNS cache:
    sudo killall -HUP mDNSResponder

============================================================
EOF
