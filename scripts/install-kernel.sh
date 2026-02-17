#!/bin/bash
#
# WM8960 Kernel Module Installer
#
# Extracts the precompiled kernel package and installs it alongside the
# existing kernel. Updates boot symlinks to use the new kernel while
# keeping the original device trees (DTBs) intact — this preserves WiFi,
# Bluetooth, and other hardware support.
#
# Called by quick-setup.sh or can be run standalone.
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Find the kernel package
KERNEL_PKG=$(find "$REPO_DIR/kernel" -name "*.tar.gz" 2>/dev/null | head -1)

if [ -z "$KERNEL_PKG" ]; then
    log_error "No kernel package found in kernel/ directory"
    log_error "Download the precompiled kernel or build one with WM8960 support"
    log_error "See kernel/KERNEL.md for details"
    exit 1
fi

log_info "Found kernel package: $(basename "$KERNEL_PKG")"

# Extract to temp directory
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

log_info "Extracting kernel package..."
tar -xzf "$KERNEL_PKG" -C "$TMPDIR"

# Find the extracted package directory
PKG_DIR=$(find "$TMPDIR" -maxdepth 1 -type d -name "kernel-package" | head -1)
if [ -z "$PKG_DIR" ]; then
    PKG_DIR=$(find "$TMPDIR" -maxdepth 2 -type d -name "modules" | head -1)
    PKG_DIR=$(dirname "$PKG_DIR" 2>/dev/null)
fi

if [ -z "$PKG_DIR" ] || [ ! -d "$PKG_DIR" ]; then
    log_error "Could not find kernel files in extracted package"
    exit 1
fi

# Detect kernel version from the package
PKG_VERSION=$(basename "$(find "$PKG_DIR" -maxdepth 1 -name "vmlinuz-*" | head -1)" | sed 's/^vmlinuz-//')

if [ -z "$PKG_VERSION" ]; then
    log_error "Could not detect kernel version from package"
    exit 1
fi

log_info "Package kernel version: $PKG_VERSION"

# Install kernel image alongside existing kernel (do NOT overwrite)
log_info "Installing kernel image..."
cp "$PKG_DIR/vmlinuz-${PKG_VERSION}" /boot/
cp "$PKG_DIR/System.map-${PKG_VERSION}" /boot/ 2>/dev/null || true
cp "$PKG_DIR/config-${PKG_VERSION}" /boot/ 2>/dev/null || true

# Create module directory by copying all modules from the running kernel,
# then overlay the package's sound modules on top. This ensures the new
# kernel has all essential drivers (filesystem, network, WiFi, etc.)
RUNNING_VERSION=$(uname -r)
if [ ! -d "/lib/modules/${PKG_VERSION}" ]; then
    log_info "Copying base modules from running kernel ($RUNNING_VERSION)..."
    cp -a "/lib/modules/${RUNNING_VERSION}" "/lib/modules/${PKG_VERSION}"
else
    log_info "Module directory /lib/modules/${PKG_VERSION} already exists, updating..."
fi

# Overlay the package's sound modules (with WM8960 support)
log_info "Installing WM8960 sound modules..."
if [ -d "$PKG_DIR/modules/sound" ]; then
    cp -r "$PKG_DIR/modules/sound" "/lib/modules/${PKG_VERSION}/kernel/"
fi

# Update module dependencies
log_info "Updating module dependencies..."
depmod -a "${PKG_VERSION}"

# Generate initramfs for the new kernel
log_info "Generating initramfs for ${PKG_VERSION}..."
update-initramfs -c -k "${PKG_VERSION}" 2>/dev/null || true

# Convert to u-boot format if mkimage is available
if command -v mkimage >/dev/null 2>&1; then
    if [ -f "/boot/initrd.img-${PKG_VERSION}" ]; then
        mkimage -A arm64 -T ramdisk -C none -n "uInitrd-${PKG_VERSION}" \
            -d "/boot/initrd.img-${PKG_VERSION}" "/boot/uInitrd-${PKG_VERSION}" >/dev/null 2>&1 || true
    fi
fi

# Update boot symlinks to use new kernel
log_info "Updating boot symlinks..."
if [ -f "/boot/vmlinuz-${PKG_VERSION}" ]; then
    ln -sf "vmlinuz-${PKG_VERSION}" /boot/Image
    log_info "Image -> vmlinuz-${PKG_VERSION}"
fi
if [ -f "/boot/uInitrd-${PKG_VERSION}" ]; then
    ln -sf "uInitrd-${PKG_VERSION}" /boot/uInitrd
    log_info "uInitrd -> uInitrd-${PKG_VERSION}"
fi

# Explicitly do NOT touch /boot/dtb symlink — it must stay pointing to the
# original device trees which include WiFi, Bluetooth, and other hardware support
log_info "DTB symlink unchanged: $(readlink /boot/dtb 2>/dev/null || echo 'not found')"

log_info "Kernel installation complete!"
log_info "A reboot is required to use the new kernel"
