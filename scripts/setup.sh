#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST_PATH="/Library/LaunchDaemons/com.dockerhole.loopback.plist"

cd "$PROJECT_DIR"

# ---------------------------------------------------------------------------
# Resolve LOOPBACK_IP: .env takes precedence over the default
# ---------------------------------------------------------------------------
LOOPBACK_IP="127.0.0.2"
if [ -f ".env" ]; then
  _val=$(grep '^LOOPBACK_IP=' .env 2>/dev/null | cut -d'=' -f2- | tr -d ' "' || true)
  [ -n "$_val" ] && LOOPBACK_IP="$_val"
fi

echo "==> Using loopback alias IP: ${LOOPBACK_IP}"

# ---------------------------------------------------------------------------
# 1. Check Docker Desktop is running
# ---------------------------------------------------------------------------
echo "==> Checking Docker..."
if ! docker info >/dev/null 2>&1; then
  echo ""
  echo "Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi
echo "    Docker is running."

# ---------------------------------------------------------------------------
# 2. Create loopback alias if not present
# ---------------------------------------------------------------------------
echo "==> Checking loopback alias ${LOOPBACK_IP} on lo0..."
if ifconfig lo0 | grep -qF "${LOOPBACK_IP}"; then
  echo "    Alias already exists — skipping."
else
  echo "    Creating alias (no sudo required for ifconfig on macOS)..."
  sudo ifconfig lo0 alias "${LOOPBACK_IP}"
  echo "    Done."
fi

# ---------------------------------------------------------------------------
# 3. Install LaunchDaemon so the alias survives reboots
# ---------------------------------------------------------------------------
echo "==> Checking LaunchDaemon at ${PLIST_PATH}..."
if [ -f "$PLIST_PATH" ]; then
  echo "    LaunchDaemon already installed — skipping."
else
  echo "    Installing LaunchDaemon (requires sudo)..."
  sudo tee "$PLIST_PATH" > /dev/null <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dockerhole.loopback</string>
    <key>ProgramArguments</key>
    <array>
        <string>/sbin/ifconfig</string>
        <string>lo0</string>
        <string>alias</string>
        <string>${LOOPBACK_IP}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST
  sudo launchctl load "$PLIST_PATH"
  echo "    LaunchDaemon installed and loaded."
fi

# ---------------------------------------------------------------------------
# 4. Copy sample.env to .env if .env doesn't exist yet
# ---------------------------------------------------------------------------
if [ ! -f ".env" ]; then
  echo "==> Creating .env from sample.env..."
  cp sample.env .env
  echo "    Done. Edit .env to set TZ and WEBPASSWORD before continuing."
  echo "    Then re-run this script."
  exit 0
fi

# ---------------------------------------------------------------------------
# 5. Start containers
# ---------------------------------------------------------------------------
echo "==> Starting containers..."
docker compose up -d
echo "    Containers started."

# ---------------------------------------------------------------------------
# 6. Wait for Pi-hole to become healthy
# ---------------------------------------------------------------------------
echo "==> Waiting for Pi-hole to be healthy..."
ATTEMPTS=0
MAX_ATTEMPTS=30
until [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; do
  STATUS=$(docker inspect --format '{{.State.Health.Status}}' pihole 2>/dev/null || echo "starting")
  if [ "$STATUS" = "healthy" ]; then
    echo "    Pi-hole is healthy!"
    break
  fi
  ATTEMPTS=$((ATTEMPTS + 1))
  printf "    [%d/%d] status=%s — waiting 3s...\n" "$ATTEMPTS" "$MAX_ATTEMPTS" "$STATUS"
  sleep 3
done

if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
  echo ""
  echo "    Warning: Pi-hole did not report healthy within the timeout."
  echo "    Check logs with:  docker compose logs pihole"
fi

# ---------------------------------------------------------------------------
# 7. Print next steps
# ---------------------------------------------------------------------------
cat <<EOF

============================================================
  Dockerhole is up and running!
============================================================

  Pi-hole admin:  http://${LOOPBACK_IP}/admin
  Verify DNS:     dig @${LOOPBACK_IP} google.com

  ── Set ${LOOPBACK_IP} as your DNS server ──────────────────

  Option A — System Settings (GUI, affects one interface):
    System Settings > Wi-Fi (or Ethernet) > Details > DNS
    Click +, add:  ${LOOPBACK_IP}
    Remove any other DNS entries, then click OK.

  Option B — /etc/resolver (all interfaces, no GUI needed):
    sudo mkdir -p /etc/resolver
    echo "nameserver ${LOOPBACK_IP}" | sudo tee /etc/resolver/default

  Then flush the DNS cache:
    sudo killall -HUP mDNSResponder

============================================================
EOF
