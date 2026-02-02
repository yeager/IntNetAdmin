# IntNetAdmin

<p align="center">
  <img src="https://raw.githubusercontent.com/yeager/IntNetAdmin/main/static/logo.svg" alt="IntNetAdmin Logo" width="120">
</p>

<h3 align="center">Manage your internal network with ease</h3>

<p align="center">
  <a href="https://github.com/yeager/IntNetAdmin"><img src="https://img.shields.io/badge/GitHub-yeager/IntNetAdmin-181717?logo=github" alt="GitHub"></a>
  <a href="https://www.gnu.org/licenses/gpl-3.0"><img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="License: GPL v3"></a>
  <a href="https://www.python.org/downloads/"><img src="https://img.shields.io/badge/python-3.8+-blue.svg" alt="Python 3.8+"></a>
  <a href="https://flask.palletsprojects.com/"><img src="https://img.shields.io/badge/Flask-2.0+-green.svg" alt="Flask"></a>
</p>

---

IntNetAdmin is a web-based dashboard for managing DHCP and DNS services on your internal network. It provides a modern, dark-themed interface for configuring network services with real-time status monitoring and automatic network scanning.

<p align="center">
  <img src="https://github.com/user-attachments/assets/c9bab5c0-e734-4918-84e6-d7b4633e17e8" alt="IntNetAdmin Screenshot" width="100%">
</p>

## ✨ Features

### DHCP Management
- View, add, edit and delete static host reservations (MAC → IP mapping)
- DHCP lease monitoring with status indicators
- **Promote lease to static** – Convert dynamic leases to static reservations with one click
- Automatic DNS record creation when promoting leases

### DNS Management
- Browse and search DNS zones and records
- Add, edit and delete DNS records (A, AAAA, CNAME, MX, TXT, PTR, NS, SRV)
- Create new forward and reverse zones
- **Import zone files** – Upload or paste BIND zone files
- PTR record support for reverse DNS

### Network Configuration
- View, add, edit and delete subnet configurations
- DHCP range management per subnet
- Gateway and DNS server settings

### IP Scanner
- Automatic network scanning (configurable interval)
- Manual scan trigger
- Online/offline status for all hosts
- Network status history charts

### Dashboard
- Real-time statistics (static hosts, dynamic hosts, online count, DNS zones, active leases)
- Network status history visualization (Chart.js)
- Host distribution pie chart
- Service status monitoring (ISC DHCP, BIND)

### Security
- 🔐 **PAM authentication** – Uses system users for login
- ⏱️ **Session timeout** – 5-minute timeout with warning dialog (60 sec countdown)
- 🔒 **Staged changes** – Preview all modifications before writing to disk
- 🛡️ **Sudo on demand** – Write operations require sudo password (session-only, never saved)
- 🧹 **Input sanitization** – All inputs validated and sanitized

### User Experience
- 🌙 Dark/Light theme toggle
- 🌍 **10 languages** on login and in app: English, Svenska, Deutsch, Français, Español, Italiano, Nederlands, Português, Norsk, Dansk
- 📱 Responsive design

## 🚀 Quick Start

### Requirements

- Python 3.8+
- ISC DHCP Server (`isc-dhcp-server`)
- BIND DNS Server (`bind9`)
- Linux/FreeBSD with PAM

### One-Line Install

```bash
curl -sL https://github.com/yeager/IntNetAdmin/releases/latest/download/intnetadmin-1.1.0.tar.gz | tar xz && sudo ./install.sh
```

### Manual Installation

```bash
# Clone
git clone https://github.com/yeager/IntNetAdmin.git
cd IntNetAdmin

# Virtual environment
python3 -m venv venv
source venv/bin/activate

# Dependencies
pip install -r requirements.txt

# Run (development)
python app.py

# Run (production)
gunicorn -w 2 -b 0.0.0.0:5000 app:app
```

### Configuration

Set environment variables or edit defaults in `app.py`:

| Variable | Default | Description |
|----------|---------|-------------|
| `SECRET_KEY` | (generated) | Flask session key |
| `DHCP_CONF` | `/etc/dhcp/dhcpd.conf` | DHCP config file |
| `DHCP_LEASES` | `/var/lib/dhcp/dhcpd.leases` | DHCP leases file |
| `BIND_DIR` | `/etc/bind` | BIND zone directory |
| `NETWORK_CIDR` | `192.168.2.0/23` | Network to scan |
| `SCAN_INTERVAL` | `7200` | Scan interval (seconds) |

## 📡 API Reference

### DHCP Hosts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dhcp` | Get DHCP configuration |
| POST | `/api/dhcp/host` | Add static host |
| PUT | `/api/dhcp/host/<hostname>` | Edit host |
| DELETE | `/api/dhcp/host/<hostname>` | Delete host |

### DNS Zones & Records
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/dns` | Get zones and records |
| POST | `/api/dns/zone` | Create zone |
| POST | `/api/dns/zone/import` | Import zone file |
| POST | `/api/dns/zone/<zone>/record` | Add record |
| PUT | `/api/dns/zone/<zone>/record` | Edit record |
| DELETE | `/api/dns/zone/<zone>/record/<name>/<type>` | Delete record |

### Networks
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/networks` | Get subnets |
| POST | `/api/networks` | Add subnet |
| PUT | `/api/networks/<network>` | Edit subnet |
| DELETE | `/api/networks/<network>` | Delete subnet |

### Leases
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/leases` | Get DHCP leases |
| POST | `/api/leases/promote` | Promote lease to static + DNS |

### System
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/stats` | Dashboard statistics |
| GET | `/api/scan` | Scan results |
| POST | `/api/scan/start` | Trigger network scan |
| GET | `/api/services` | Service status |
| GET | `/api/changes` | Pending changes |
| POST | `/api/changes/apply` | Apply changes (requires sudo) |
| POST | `/api/changes/discard` | Discard changes |
| POST | `/api/session/keepalive` | Extend session timeout |

## 🐧 Systemd Service

Create `/etc/systemd/system/intnetadmin.service`:

```ini
[Unit]
Description=IntNetAdmin - Network Administration Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/intnetadmin
EnvironmentFile=/etc/intnetadmin/intnetadmin.conf
ExecStart=/opt/intnetadmin/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable intnetadmin
sudo systemctl start intnetadmin
```

## 🐡 FreeBSD

```bash
# Install
sudo ./install.sh

# Enable and start
sysrc intnetadmin_enable=YES
service intnetadmin start
```

## 🤝 Contributing

Contributions welcome! Fork, create a feature branch, and submit a PR.

## 📄 License

GNU General Public License v3.0 – see [LICENSE](LICENSE)

## 👤 Author

**Daniel Nylander** – [@yeager](https://github.com/yeager) – © 2026
