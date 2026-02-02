#!/bin/bash
# IntNetAdmin Installation Script
# Works on Debian/Ubuntu, FreeBSD, and other Unix-like systems

set -e

VERSION="1.0.0"
INSTALL_DIR="/opt/intnetadmin"
CONFIG_DIR="/etc/intnetadmin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   IntNetAdmin ${VERSION} Installer        ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root (sudo ./install.sh)${NC}"
    exit 1
fi

# Detect OS
if [ -f /etc/debian_version ]; then
    OS="debian"
    echo -e "${GREEN}Detected: Debian/Ubuntu${NC}"
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
    echo -e "${GREEN}Detected: RHEL/CentOS/Fedora${NC}"
elif [ "$(uname)" = "FreeBSD" ]; then
    OS="freebsd"
    echo -e "${GREEN}Detected: FreeBSD${NC}"
else
    OS="unknown"
    echo -e "${YELLOW}Warning: Unknown OS, will try generic installation${NC}"
fi

echo ""

# Install system dependencies
echo "Installing system dependencies..."
case $OS in
    debian)
        apt-get update -qq
        apt-get install -y python3 python3-venv python3-pip
        ;;
    rhel)
        yum install -y python3 python3-pip
        ;;
    freebsd)
        pkg install -y python3 py39-pip
        ;;
esac
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Create directories
echo "Creating directories..."
mkdir -p "${INSTALL_DIR}"
mkdir -p "${CONFIG_DIR}"
echo -e "${GREEN}✓ Directories created${NC}"

# Copy files
echo "Copying files..."
cp app.py "${INSTALL_DIR}/"
cp -r templates "${INSTALL_DIR}/"
cp -r static "${INSTALL_DIR}/"
[ -d translations ] && cp -r translations "${INSTALL_DIR}/"
[ -f babel.cfg ] && cp babel.cfg "${INSTALL_DIR}/"
echo -e "${GREEN}✓ Files copied${NC}"

# Create requirements.txt
cat > "${INSTALL_DIR}/requirements.txt" << 'EOF'
flask>=2.0
flask-babel>=2.0
python-pam>=1.8
gunicorn>=20.0
EOF

# Create virtual environment
echo "Creating Python virtual environment..."
python3 -m venv "${INSTALL_DIR}/venv"
"${INSTALL_DIR}/venv/bin/pip" install -q --upgrade pip
"${INSTALL_DIR}/venv/bin/pip" install -q -r "${INSTALL_DIR}/requirements.txt"
echo -e "${GREEN}✓ Virtual environment created${NC}"

# Create config file
if [ ! -f "${CONFIG_DIR}/intnetadmin.conf" ]; then
    echo "Creating configuration..."
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    
    if [ "$OS" = "freebsd" ]; then
        DHCP_CONF="/usr/local/etc/dhcpd.conf"
        DHCP_LEASES="/var/db/dhcpd/dhcpd.leases"
        BIND_DIR="/usr/local/etc/namedb"
    else
        DHCP_CONF="/etc/dhcp/dhcpd.conf"
        DHCP_LEASES="/var/lib/dhcp/dhcpd.leases"
        BIND_DIR="/etc/bind"
    fi
    
    cat > "${CONFIG_DIR}/intnetadmin.conf" << EOF
# IntNetAdmin Configuration
SECRET_KEY=${SECRET}
DHCP_CONF=${DHCP_CONF}
DHCP_LEASES=${DHCP_LEASES}
BIND_DIR=${BIND_DIR}
NETWORK_CIDR=192.168.1.0/24
SCAN_INTERVAL=7200
EOF
    echo -e "${GREEN}✓ Configuration created${NC}"
else
    echo -e "${YELLOW}Configuration already exists, skipping${NC}"
fi

# Create systemd service (Linux)
if [ "$OS" != "freebsd" ] && [ -d /etc/systemd/system ]; then
    echo "Creating systemd service..."
    cat > /etc/systemd/system/intnetadmin.service << EOF
[Unit]
Description=IntNetAdmin - Internal Network Administration Dashboard
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${INSTALL_DIR}
EnvironmentFile=${CONFIG_DIR}/intnetadmin.conf
ExecStart=${INSTALL_DIR}/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    echo -e "${GREEN}✓ Systemd service created${NC}"
fi

# Create rc.d script (FreeBSD)
if [ "$OS" = "freebsd" ]; then
    echo "Creating rc.d service..."
    cat > /usr/local/etc/rc.d/intnetadmin << 'EOF'
#!/bin/sh
# PROVIDE: intnetadmin
# REQUIRE: LOGIN DAEMON NETWORKING
# KEYWORD: shutdown

. /etc/rc.subr

name="intnetadmin"
rcvar="intnetadmin_enable"

load_rc_config $name

: ${intnetadmin_enable:="NO"}
: ${intnetadmin_user:="root"}

pidfile="/var/run/${name}.pid"
command="/usr/sbin/daemon"
command_args="-p ${pidfile} -u ${intnetadmin_user} /opt/intnetadmin/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app"

start_precmd="cd /opt/intnetadmin && . /etc/intnetadmin/intnetadmin.conf && export SECRET_KEY DHCP_CONF DHCP_LEASES BIND_DIR NETWORK_CIDR"

run_rc_command "$1"
EOF
    chmod 755 /usr/local/etc/rc.d/intnetadmin
    echo -e "${GREEN}✓ rc.d service created${NC}"
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Installation Complete!               ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Configuration: ${CONFIG_DIR}/intnetadmin.conf"
echo ""

if [ "$OS" = "freebsd" ]; then
    echo "To start IntNetAdmin:"
    echo "  sysrc intnetadmin_enable=YES"
    echo "  service intnetadmin start"
else
    echo "To start IntNetAdmin:"
    echo "  sudo systemctl enable intnetadmin"
    echo "  sudo systemctl start intnetadmin"
fi

echo ""
echo "Then open: ${GREEN}http://localhost:5000${NC}"
echo "Login with your system username and password"
echo ""
