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
BACKUP_DIR=""
cleanup() {
    rm -rf "$TMPDIR"
    if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
        log_warn "Module backup preserved at: $BACKUP_DIR"
        log_warn "To rollback: rm -rf /lib/modules/${PKG_VERSION:-unknown} && mv $BACKUP_DIR /lib/modules/${PKG_VERSION:-unknown}"
    fi
}
trap cleanup EXIT

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

# Install the full module tree from the package
# The package includes all modules (WiFi, BT, sound, etc.) compiled
# for this kernel version with matching vermagic
log_info "Installing kernel modules..."
if [ -d "$PKG_DIR/modules" ]; then
    # The package may contain modules as a full /lib/modules/<version> tree
    # or as a flat modules/ directory
    if [ -d "$PKG_DIR/modules/kernel" ]; then
        # Full module tree — install directly
        if [ -d "/lib/modules/${PKG_VERSION}" ]; then
            BACKUP_DIR="/lib/modules/${PKG_VERSION}.backup.$(date +%Y%m%d%H%M%S)"
            log_info "Backing up existing modules to ${BACKUP_DIR}..."
            mv "/lib/modules/${PKG_VERSION}" "$BACKUP_DIR"
        fi
        cp -a "$PKG_DIR/modules" "/lib/modules/${PKG_VERSION}"
    else
        # Flat layout (legacy) — create dir and copy
        mkdir -p "/lib/modules/${PKG_VERSION}/kernel"
        cp -r "$PKG_DIR/modules/"* "/lib/modules/${PKG_VERSION}/"
    fi
else
    log_error "No modules directory found in kernel package"
    exit 1
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

# Clean up module backup on success
if [ -n "${BACKUP_DIR:-}" ] && [ -d "$BACKUP_DIR" ]; then
    log_info "Removing module backup (install succeeded)..."
    rm -rf "$BACKUP_DIR"
    BACKUP_DIR=""
fi

log_info "Kernel installation complete!"
log_info "A reboot is required to use the new kernel"
