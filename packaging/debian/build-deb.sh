#!/bin/bash
# Build .deb package for IntNetAdmin
set -e

VERSION="1.0.0"
PACKAGE="intnetadmin"
ARCH="all"

# Create build directory
BUILD_DIR=$(mktemp -d)
PKG_DIR="${BUILD_DIR}/${PACKAGE}_${VERSION}_${ARCH}"

echo "Building ${PACKAGE} ${VERSION}..."

# Create directory structure
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/opt/intnetadmin"
mkdir -p "${PKG_DIR}/etc/systemd/system"
mkdir -p "${PKG_DIR}/etc/intnetadmin"

# Copy application files
cp -r ../../app.py "${PKG_DIR}/opt/intnetadmin/"
cp -r ../../templates "${PKG_DIR}/opt/intnetadmin/"
cp -r ../../static "${PKG_DIR}/opt/intnetadmin/"
cp -r ../../translations "${PKG_DIR}/opt/intnetadmin/" 2>/dev/null || true
cp ../../babel.cfg "${PKG_DIR}/opt/intnetadmin/" 2>/dev/null || true

# Create requirements.txt
cat > "${PKG_DIR}/opt/intnetadmin/requirements.txt" << 'EOF'
flask>=2.0
flask-babel>=2.0
python-pam>=1.8
gunicorn>=20.0
EOF

# Create default config
cat > "${PKG_DIR}/etc/intnetadmin/intnetadmin.conf" << 'EOF'
# IntNetAdmin Configuration
# Environment variables for the service

# Secret key for Flask sessions (change this!)
SECRET_KEY=change-me-to-a-random-string

# DHCP configuration file
DHCP_CONF=/etc/dhcp/dhcpd.conf

# DHCP leases file
DHCP_LEASES=/var/lib/dhcp/dhcpd.leases

# BIND zone directory
BIND_DIR=/etc/bind

# Network to scan (CIDR notation)
NETWORK_CIDR=192.168.1.0/24

# Scan interval in seconds (default: 2 hours)
SCAN_INTERVAL=7200
EOF

# Create systemd service
cat > "${PKG_DIR}/etc/systemd/system/intnetadmin.service" << 'EOF'
[Unit]
Description=IntNetAdmin - Internal Network Administration Dashboard
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/intnetadmin
EnvironmentFile=/etc/intnetadmin/intnetadmin.conf
ExecStartPre=/bin/bash -c 'test -d /opt/intnetadmin/venv || python3 -m venv /opt/intnetadmin/venv'
ExecStartPre=/bin/bash -c '/opt/intnetadmin/venv/bin/pip install -q -r /opt/intnetadmin/requirements.txt'
ExecStart=/opt/intnetadmin/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create control file
cat > "${PKG_DIR}/DEBIAN/control" << EOF
Package: ${PACKAGE}
Version: ${VERSION}
Section: admin
Priority: optional
Architecture: ${ARCH}
Depends: python3 (>= 3.8), python3-venv, python3-pip, isc-dhcp-server | dhcpd, bind9
Maintainer: Daniel Nylander <daniel@danielnylander.se>
Homepage: https://github.com/yeager/IntNetAdmin
Description: Internal Network Administration Dashboard
 IntNetAdmin is a web-based dashboard for managing DHCP and DNS
 services on your internal network. It provides a modern interface
 for configuring network services with real-time status monitoring.
 .
 Features:
  - DHCP host management (add/edit/delete)
  - DNS zone and record management
  - IP scanner with online/offline status
  - DHCP lease monitoring
  - Network/subnet configuration
  - 10 language support
  - Dark/light theme
EOF

# Create postinst script
cat > "${PKG_DIR}/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

echo "Setting up IntNetAdmin..."

# Create virtual environment if it doesn't exist
if [ ! -d /opt/intnetadmin/venv ]; then
    python3 -m venv /opt/intnetadmin/venv
fi

# Install dependencies
/opt/intnetadmin/venv/bin/pip install -q -r /opt/intnetadmin/requirements.txt

# Generate secret key if not set
if grep -q "change-me-to-a-random-string" /etc/intnetadmin/intnetadmin.conf; then
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    sed -i "s/change-me-to-a-random-string/${SECRET}/" /etc/intnetadmin/intnetadmin.conf
    echo "Generated new secret key"
fi

# Reload systemd
systemctl daemon-reload

echo ""
echo "IntNetAdmin installed successfully!"
echo ""
echo "To start the service:"
echo "  sudo systemctl enable intnetadmin"
echo "  sudo systemctl start intnetadmin"
echo ""
echo "Then open http://localhost:5000 in your browser"
echo "Login with your system username and password"
echo ""
echo "Configuration: /etc/intnetadmin/intnetadmin.conf"
echo ""

exit 0
EOF
chmod 755 "${PKG_DIR}/DEBIAN/postinst"

# Create prerm script
cat > "${PKG_DIR}/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ]; then
    systemctl stop intnetadmin 2>/dev/null || true
    systemctl disable intnetadmin 2>/dev/null || true
fi

exit 0
EOF
chmod 755 "${PKG_DIR}/DEBIAN/prerm"

# Create conffiles
cat > "${PKG_DIR}/DEBIAN/conffiles" << 'EOF'
/etc/intnetadmin/intnetadmin.conf
EOF

# Build package
dpkg-deb --build "${PKG_DIR}"

# Move to current directory
mv "${PKG_DIR}.deb" "./intnetadmin_${VERSION}_${ARCH}.deb"

# Cleanup
rm -rf "${BUILD_DIR}"

echo "Package built: intnetadmin_${VERSION}_${ARCH}.deb"
