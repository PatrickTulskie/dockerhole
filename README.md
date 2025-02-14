# Dockerhole - Pi-hole in Docker

A simple Docker setup for running Pi-hole locally with persistent storage and DNS-over-HTTPS support via cloudflared.

## Setup

1. Clone this repository
2. Copy the sample environment file:
   ```bash
   cp sample.env .env
   ```
3. Edit the `.env` file and update the following values:
   - `TZ`: Your timezone (e.g., America/Chicago, Europe/London)
   - `WEBPASSWORD`: Choose a secure password for the Pi-hole web interface
   - `DNS_TCP_PORT`/`DNS_UDP_PORT`: Change if port 5335 is already in use
   - `WEB_PORT`: Change if port 8080 is already in use

4. Start Pi-hole and cloudflared:
   ```bash
   docker-compose up -d
   ```

## Usage

- Access the Pi-hole web interface at `http://localhost:8080/admin` (or your configured port)
- To use Pi-hole as your DNS server:
  - For individual device: Set DNS server to your machine's IP address and port 5335
  - For testing: Use `nslookup example.com localhost:5335`

### Setting Up System-wide DNS

#### macOS
You can configure DNS settings in two ways:

1. Using System Settings (GUI):
   - Open System Settings > Network
   - Select your active network connection (e.g., Wi-Fi or Ethernet)
   - Click "Details..."
   - Go to the "DNS" tab
   - Click "+" to add a DNS server
   - Add `127.0.0.1:5335`
   - Click "OK" to save

2. Using Terminal (for specific interfaces):
   ```bash
   # List all network services/interfaces
   networksetup -listallnetworkservices
   
   # Set DNS for Wi-Fi
   sudo networksetup -setdnsservers "Wi-Fi" 127.0.0.1:5335
   
   # Set DNS for Ethernet
   sudo networksetup -setdnsservers "Ethernet" 127.0.0.1:5335
   ```

After changing DNS settings, flush the DNS cache:
```bash
sudo killall -HUP mDNSResponder
```

#### Linux (Network Manager)
1. Create a NetworkManager DNS configuration:
   ```bash
   sudo nano /etc/NetworkManager/conf.d/dns-servers.conf
   ```
   Add these lines:
   ```ini
   [global-dns-domain-*]
   servers=127.0.0.1:5335
   ```

2. Edit your connection to use this configuration:
   ```bash
   sudo nmcli connection modify YOUR_CONNECTION ipv4.ignore-auto-dns yes
   ```

3. Restart NetworkManager:
   ```bash
   sudo systemctl restart NetworkManager
   ```

Replace YOUR_CONNECTION with your connection name (find it using `nmcli connection show`)

#### Linux (systemd-resolved)
1. Edit /etc/systemd/resolved.conf:
   ```ini
   [Resolve]
   DNS=127.0.0.1:5335
   DNSStubListener=no
   ```
2. Restart systemd-resolved:
   ```bash
   sudo systemctl restart systemd-resolved
   ```

## Features

### DNS-over-HTTPS
The setup includes cloudflared as a DNS-over-HTTPS proxy, which automatically forwards DNS queries to Cloudflare's secure DNS servers (1.1.1.1 and 1.0.0.1). This provides:
- Encrypted DNS queries
- Protection against DNS spoofing
- Better privacy for your DNS queries

## Data Persistence

All Pi-hole configuration and data are stored in the `pihole-data` directory:
- `etc-pihole/`: Contains Pi-hole configuration files
- `etc-dnsmasq.d/`: Contains DNS configuration files

## Stopping Pi-hole

To stop all containers:
```bash
docker-compose down