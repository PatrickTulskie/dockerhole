# Dockerhole — Pi-hole + DNS-over-HTTPS on macOS

Pi-hole running in Docker Desktop on macOS, with encrypted upstream DNS via
[dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) and Pi-hole bound
to standard port 53 so it works as a normal system DNS server.

## Prerequisites

- macOS (tested on macOS Tahoe / macOS 26)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

## Quick Start

```bash
git clone https://github.com/PatrickTulskie/dockerhole
cd dockerhole
./scripts/setup.sh
```

`setup.sh` is idempotent — safe to run multiple times. On first run it creates
`.env` from `sample.env` and exits so you can set your password before the
containers start. Edit `.env`, then run the script again.

## Why the loopback alias approach?

On macOS, `mDNSResponder` (the system DNS daemon) holds port 53 on
`0.0.0.0`. Docker Desktop then layers its own port-forwarding on top, making it
impossible for a container to bind `0.0.0.0:53` on the host.

The fix: bind Pi-hole to a *loopback alias IP* (`127.0.0.2`) instead of
`0.0.0.0`. `mDNSResponder` only binds `127.0.0.1`, so `127.0.0.2` is free.
Docker maps the container's port 53 to `127.0.0.2:53` on the host with no
conflicts. `setup.sh` creates this alias and installs a LaunchDaemon plist at
`/Library/LaunchDaemons/com.dockerhole.loopback.plist` so it persists across
reboots.

## DNS configuration

After running `setup.sh`, point your Mac's DNS at `127.0.0.2`.

### Option A — System Settings (GUI)

1. System Settings → Wi-Fi (or Ethernet) → Details → DNS
2. Click **+** and add `127.0.0.2`
3. Remove any existing DNS entries
4. Click OK, then flush the cache:

```bash
sudo killall -HUP mDNSResponder
```

### Option B — /etc/resolver (all interfaces, command-line)

```bash
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.2" | sudo tee /etc/resolver/default
sudo killall -HUP mDNSResponder
```

### Verify it's working

```bash
dig @127.0.0.2 google.com
```

## Pi-hole admin UI

```
http://127.0.0.2/admin
```

## DNS-over-HTTPS via dnscrypt-proxy

This setup uses [`klutchell/dnscrypt-proxy`](https://github.com/klutchell/dnscrypt-proxy-docker)
as the upstream DoH provider, replacing the now-defunct `crazymax/cloudflared proxy-dns`
command (removed from cloudflared in February 2026). dnscrypt-proxy is configured
in `config/dnscrypt-proxy.toml` to use Cloudflare's DoH servers (`1.1.1.1`) and
listens on port 5053 on the internal Docker network. Pi-hole forwards all upstream
queries to it.

## Data persistence

Pi-hole configuration and blocklists are stored in `pihole-data/` on the host and
survive container restarts and image updates.

## Maintenance

### Update images

```bash
./scripts/update.sh
```

### Teardown

Stops all containers, unloads the LaunchDaemon, and removes the loopback alias:

```bash
./scripts/teardown.sh
```

## Troubleshooting

### Port 53 conflict on startup

If Pi-hole fails to bind port 53, verify the loopback alias exists:

```bash
ifconfig lo0 | grep 127.0.0.2
```

If missing, re-run `./scripts/setup.sh` to recreate it.

### UDP port binding fails (`command failed`)

If `docker compose up` errors with `ports are not available: exposing port UDP 127.0.0.2:53 ... command failed`, Docker Desktop's "Use kernel networking for UDP" setting is enabled. This routes UDP through the VM's kernel network stack, which cannot bind to macOS loopback aliases beyond `127.0.0.1`.

Fix: Docker Desktop → **Settings** → **General** → uncheck **"Use kernel networking for UDP"** → Apply & Restart.

### Container not starting

Check logs:

```bash
docker compose logs pihole
docker compose logs dnscrypt-proxy
```

### DNS queries not resolving

1. Confirm the alias is up: `ifconfig lo0 | grep 127.0.0.2`
2. Confirm Pi-hole is healthy: `docker compose ps`
3. Test upstream: `dig @127.0.0.2 google.com`
4. Check dnscrypt-proxy connected: `docker compose logs dnscrypt-proxy`

### After a macOS reboot

The LaunchDaemon recreates the loopback alias automatically. If for some reason
it doesn't, run `./scripts/setup.sh` again.
