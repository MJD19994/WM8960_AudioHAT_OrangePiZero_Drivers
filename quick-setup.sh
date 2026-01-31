#!/bin/bash
#
# WM8960 Audio HAT Quick Setup
#
# All-in-one installer that handles both kernel installation (if needed)
# and driver/overlay/service setup. Safe to re-run.
#
# For driver-only installation (kernel already has WM8960 support),
# use install.sh instead.
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

install_kernel() {
    log_info "Checking for WM8960 kernel module..."

    if modinfo snd_soc_wm8960 >/dev/null 2>&1; then
        log_info "WM8960 kernel module already installed, skipping kernel installation"
        return 0
    fi

    log_warn "WM8960 kernel module not found, installing kernel..."

    # Find the kernel package in the repo
    KERNEL_PKG=$(find "$SCRIPT_DIR/kernel" -name "*.tar.gz" 2>/dev/null | head -1)

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

    # Find and run the install script
    INSTALL_SCRIPT=$(find "$TMPDIR" -name "install-kernel.sh" | head -1)

    if [ -z "$INSTALL_SCRIPT" ]; then
        log_error "install-kernel.sh not found in kernel package"
        exit 1
    fi

    log_info "Installing kernel with WM8960 support..."
    chmod +x "$INSTALL_SCRIPT"
    bash "$INSTALL_SCRIPT"

    # Verify installation
    if modinfo snd_soc_wm8960 >/dev/null 2>&1; then
        log_info "Kernel module installed successfully"
    else
        log_warn "Kernel module installed but not yet available (normal before reboot)"
    fi
}

install_driver() {
    log_info "Running driver installation..."

    if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
        log_error "install.sh not found in $SCRIPT_DIR"
        exit 1
    fi

    bash "$SCRIPT_DIR/install.sh"
}

# Main
log_info "WM8960 Audio HAT Quick Setup"
echo ""

check_root
install_kernel
install_driver

echo ""
log_info "Setup complete! Reboot to activate: sudo reboot"
