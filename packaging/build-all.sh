#!/bin/bash
# Build all packages for IntNetAdmin
set -e

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/../dist"

echo "========================================"
echo "Building IntNetAdmin ${VERSION} packages"
echo "========================================"
echo ""

# Create dist directory
mkdir -p "${DIST_DIR}"

# Build Debian/Ubuntu package
echo "Building Debian/Ubuntu package..."
cd "${SCRIPT_DIR}/debian"
chmod +x build-deb.sh
./build-deb.sh
mv *.deb "${DIST_DIR}/"
echo "✓ Debian package built"
echo ""

# Build FreeBSD package
echo "Building FreeBSD package..."
cd "${SCRIPT_DIR}/freebsd"
chmod +x build-pkg.sh
./build-pkg.sh
mv *.txz "${DIST_DIR}/"
echo "✓ FreeBSD package built"
echo ""

# Create source tarball
echo "Creating source tarball..."
cd "${SCRIPT_DIR}/.."
tar -czvf "${DIST_DIR}/intnetadmin-${VERSION}.tar.gz" \
    --exclude='.git' \
    --exclude='dist' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='venv' \
    --exclude='.env' \
    app.py templates/ static/ translations/ babel.cfg requirements.txt README.md LICENSE 2>/dev/null || \
tar -czvf "${DIST_DIR}/intnetadmin-${VERSION}.tar.gz" \
    --exclude='.git' \
    --exclude='dist' \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='venv' \
    --exclude='.env' \
    app.py templates/ static/ README.md 2>/dev/null
echo "✓ Source tarball created"
echo ""

echo "========================================"
echo "All packages built successfully!"
echo "========================================"
echo ""
echo "Packages in ${DIST_DIR}:"
ls -la "${DIST_DIR}/"
