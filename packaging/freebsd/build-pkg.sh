#!/bin/sh
# Build FreeBSD package for IntNetAdmin
set -e

VERSION="1.0.0"
PACKAGE="intnetadmin"

echo "Building ${PACKAGE} ${VERSION} for FreeBSD..."

# Create staging directory
STAGING=$(mktemp -d)

# Create directory structure
mkdir -p "${STAGING}/opt/intnetadmin"
mkdir -p "${STAGING}/usr/local/etc/rc.d"
mkdir -p "${STAGING}/usr/local/etc/intnetadmin"

# Copy application files
cp -r ../../app.py "${STAGING}/opt/intnetadmin/"
cp -r ../../templates "${STAGING}/opt/intnetadmin/"
cp -r ../../static "${STAGING}/opt/intnetadmin/"
cp -r ../../translations "${STAGING}/opt/intnetadmin/" 2>/dev/null || true
cp ../../babel.cfg "${STAGING}/opt/intnetadmin/" 2>/dev/null || true

# Create requirements.txt
cat > "${STAGING}/opt/intnetadmin/requirements.txt" << 'EOF'
flask>=2.0
flask-babel>=2.0
python-pam>=1.8
gunicorn>=20.0
EOF

# Create config file
cat > "${STAGING}/usr/local/etc/intnetadmin/intnetadmin.conf" << 'EOF'
# IntNetAdmin Configuration

# Secret key for Flask sessions (change this!)
SECRET_KEY=change-me-to-a-random-string

# DHCP configuration file
DHCP_CONF=/usr/local/etc/dhcpd.conf

# DHCP leases file  
DHCP_LEASES=/var/db/dhcpd/dhcpd.leases

# BIND zone directory
BIND_DIR=/usr/local/etc/namedb

# Network to scan (CIDR notation)
NETWORK_CIDR=192.168.1.0/24

# Scan interval in seconds
SCAN_INTERVAL=7200
EOF

# Create rc.d script
cat > "${STAGING}/usr/local/etc/rc.d/intnetadmin" << 'EOF'
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
: ${intnetadmin_group:="wheel"}
: ${intnetadmin_chdir:="/opt/intnetadmin"}
: ${intnetadmin_env:=""}

pidfile="/var/run/${name}.pid"
command="/usr/sbin/daemon"
procname="/opt/intnetadmin/venv/bin/python"

start_precmd="${name}_prestart"
stop_postcmd="${name}_poststop"

intnetadmin_prestart()
{
    # Create venv if needed
    if [ ! -d /opt/intnetadmin/venv ]; then
        python3 -m venv /opt/intnetadmin/venv
        /opt/intnetadmin/venv/bin/pip install -q -r /opt/intnetadmin/requirements.txt
    fi
    
    # Load environment
    if [ -f /usr/local/etc/intnetadmin/intnetadmin.conf ]; then
        . /usr/local/etc/intnetadmin/intnetadmin.conf
        export SECRET_KEY DHCP_CONF DHCP_LEASES BIND_DIR NETWORK_CIDR SCAN_INTERVAL
    fi
}

intnetadmin_poststop()
{
    rm -f ${pidfile}
}

command_args="-p ${pidfile} -u ${intnetadmin_user} /opt/intnetadmin/venv/bin/gunicorn -w 2 -b 0.0.0.0:5000 app:app"

run_rc_command "$1"
EOF
chmod 755 "${STAGING}/usr/local/etc/rc.d/intnetadmin"

# Create +MANIFEST
cat > "${STAGING}/+MANIFEST" << EOF
name: ${PACKAGE}
version: "${VERSION}"
origin: net-mgmt/intnetadmin
comment: Internal Network Administration Dashboard
maintainer: daniel@danielnylander.se
www: https://github.com/yeager/IntNetAdmin
abi: FreeBSD:*:*
arch: freebsd:*:*
prefix: /
desc: <<EOD
IntNetAdmin is a web-based dashboard for managing DHCP and DNS
services on your internal network. It provides a modern interface
for configuring network services with real-time status monitoring.

Features:
- DHCP host management (add/edit/delete)
- DNS zone and record management
- IP scanner with online/offline status
- DHCP lease monitoring
- Network/subnet configuration
- 10 language support
- Dark/light theme
EOD
deps: {
  python3: {origin: lang/python3, version: "3.8"}
  isc-dhcp44-server: {origin: net/isc-dhcp44-server, version: "4.4"}
  bind918: {origin: dns/bind918, version: "9.18"}
}
EOF

# Create +POST_INSTALL
cat > "${STAGING}/+POST_INSTALL" << 'EOF'
#!/bin/sh

echo "Setting up IntNetAdmin..."

# Create virtual environment
if [ ! -d /opt/intnetadmin/venv ]; then
    python3 -m venv /opt/intnetadmin/venv
fi

# Install dependencies
/opt/intnetadmin/venv/bin/pip install -q -r /opt/intnetadmin/requirements.txt

# Generate secret key
if grep -q "change-me-to-a-random-string" /usr/local/etc/intnetadmin/intnetadmin.conf; then
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    sed -i '' "s/change-me-to-a-random-string/${SECRET}/" /usr/local/etc/intnetadmin/intnetadmin.conf
fi

echo ""
echo "IntNetAdmin installed successfully!"
echo ""
echo "To enable and start the service:"
echo "  sysrc intnetadmin_enable=YES"
echo "  service intnetadmin start"
echo ""
echo "Then open http://localhost:5000 in your browser"
echo ""
EOF
chmod 755 "${STAGING}/+POST_INSTALL"

# Create package using tar (portable method)
echo "Creating package archive..."
tar -czvf "intnetadmin-${VERSION}.pkg.txz" -C "${STAGING}" .

# Cleanup  
rm -rf "${STAGING}"

echo "Package built: intnetadmin-${VERSION}.pkg.txz"
