#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Must run as root"
    exit 1
fi

# First argument is the directory containing the extracted kernel files
KERNEL_DIR="$1"

if [ -z "$KERNEL_DIR" ] || [ ! -d "$KERNEL_DIR" ]; then
    echo "ERROR: Kernel directory not provided or doesn't exist"
    echo "Usage: $0 <kernel-directory>"
    exit 1
fi

VERSION="6.1.31-orangepi"

echo "Installing Orange Pi kernel with WM8960 support..."
echo "Version: $VERSION"
echo "Kernel directory: $KERNEL_DIR"
echo ""

# Backup existing kernel
echo "Backing up existing kernel..."
cp /boot/vmlinuz-${VERSION} /boot/vmlinuz-${VERSION}.backup 2>/dev/null || true

# Install kernel files (using absolute paths from KERNEL_DIR)
echo "Installing kernel..."
cp "$KERNEL_DIR/vmlinuz-${VERSION}" /boot/
cp "$KERNEL_DIR/System.map-${VERSION}" /boot/
cp "$KERNEL_DIR/config-${VERSION}" /boot/

# Install modules
echo "Installing modules..."

# Create module directory structure first
echo "Creating module directory structure..."
mkdir -p /lib/modules/${VERSION}/kernel

# Copy ALL module files recursively
if [ -d "$KERNEL_DIR/modules" ]; then
    echo "Copying kernel modules..."
    cp -rf "$KERNEL_DIR/modules/"* /lib/modules/${VERSION}/ || echo "Warning: Failed to copy some module files"
else
    echo "Warning: No modules directory found in $KERNEL_DIR"
fi

# Update module dependencies
echo "Updating module dependencies..."
depmod -a ${VERSION}

echo ""
echo "Kernel installation complete!"
echo "The WM8960 codec module is now available."
echo ""
echo "Next steps:"
echo "1. Driver installation will continue automatically"
echo "2. Reboot after setup completes: sudo reboot"
