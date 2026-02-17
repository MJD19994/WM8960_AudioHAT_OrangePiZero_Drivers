#!/bin/bash
#
# Extract and package the compiled kernel with WM8960 support
# Run this on the Orange Pi with the working kernel
#

set -e

VERSION="6.1.31-orangepi"
OUTPUT_DIR="kernel-package"
TARBALL="orangepi-zero2w-wm8960-kernel-${VERSION}.tar.gz"

echo "Extracting kernel $VERSION with WM8960 support..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy kernel image
echo "Copying kernel image..."
cp /boot/vmlinuz-${VERSION} "$OUTPUT_DIR/"
cp /boot/System.map-${VERSION} "$OUTPUT_DIR/"
cp /boot/config-${VERSION} "$OUTPUT_DIR/"

# Copy modules (WM8960 and dependencies)
echo "Copying kernel modules..."
mkdir -p "$OUTPUT_DIR/modules"

# Copy WM8960 module and sound subsystem
cp -r /lib/modules/${VERSION}/kernel/sound "$OUTPUT_DIR/modules/" || true

# Copy module dependencies
cp /lib/modules/${VERSION}/modules.* "$OUTPUT_DIR/modules/" || true

# Create README
cat > "$OUTPUT_DIR/README.txt" << 'EOFREADME'
Orange Pi Zero 2W Kernel with WM8960 Support
Version: 6.1.31-orangepi

This package contains a pre-compiled kernel with WM8960 audio codec support
for Orange Pi Zero 2W (H618).

INSTALLATION:
This tar.gz should be placed in the kernel/ directory of the 
WM8960_AudioHAT_OrangePiZero_Drivers repository.

Installation is handled automatically by running quick-setup.sh from the 
repository, which uses the install-kernel.sh script from scripts/ directory.

For manual installation:
1. Extract this archive
2. From the repository root, run: sudo ./scripts/install-kernel.sh <path-to-extracted-kernel-package>
3. Install WM8960 driver package from main repository
4. Reboot

WHAT'S INCLUDED:
- Kernel image (vmlinuz-6.1.31-orangepi)
- System map and config
- WM8960 codec kernel module
- Sound subsystem modules

COMPATIBILITY:
- Orange Pi Zero 2W (H618)
- Orange Pi OS 1.0.2 Bookworm

For support, see: https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers
EOFREADME

# Create tarball
echo "Creating tarball..."
tar -czf "$TARBALL" "$OUTPUT_DIR"

echo ""
echo "Kernel package created: $TARBALL"
echo "Size: $(du -h $TARBALL | cut -f1)"
echo ""
echo "Upload this file to GitHub releases or file hosting"
rm -rf "$OUTPUT_DIR"
