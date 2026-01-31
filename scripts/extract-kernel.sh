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

# Create installation script
cat > "$OUTPUT_DIR/install-kernel.sh" << 'EOFINSTALL'
#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Must run as root"
    exit 1
fi

VERSION="6.1.31-orangepi"

echo "Installing Orange Pi kernel with WM8960 support..."
echo "Version: $VERSION"
echo ""

# Backup existing kernel
echo "Backing up existing kernel..."
cp /boot/vmlinuz-${VERSION} /boot/vmlinuz-${VERSION}.backup 2>/dev/null || true

# Install kernel files
echo "Installing kernel..."
cp vmlinuz-${VERSION} /boot/
cp System.map-${VERSION} /boot/
cp config-${VERSION} /boot/

# Install modules
echo "Installing modules..."
cp -r modules/sound /lib/modules/${VERSION}/kernel/ || true
cp modules/modules.* /lib/modules/${VERSION}/ || true

# Update module dependencies
echo "Updating module dependencies..."
depmod -a ${VERSION}

echo ""
echo "Kernel installation complete!"
echo "The WM8960 codec module is now available."
echo ""
echo "Next steps:"
echo "1. Install the WM8960 driver package"
echo "2. Reboot: sudo reboot"
EOFINSTALL

chmod +x "$OUTPUT_DIR/install-kernel.sh"

# Create README
cat > "$OUTPUT_DIR/README.txt" << 'EOFREADME'
Orange Pi Zero 2W Kernel with WM8960 Support
Version: 6.1.31-orangepi

This package contains a pre-compiled kernel with WM8960 audio codec support
for Orange Pi Zero 2W (H618).

INSTALLATION:
1. Extract this archive
2. Run: sudo ./install-kernel.sh
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
