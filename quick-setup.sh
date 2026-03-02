#!/bin/bash
#
# WM8960 Audio HAT Quick Setup
#
# All-in-one installer that handles both kernel installation (if needed)
# and driver/device-tree/service setup. Safe to re-run.
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

# Detect OS: Armbian vs Orange Pi OS (vendor BSP)
# Orange Pi OS uses a vendor BSP kernel with "sun50iw9" in the version string,
# or has DTB directories with that marker (persists after our kernel install).
# Unknown distros default to the Armbian path (builds module from source).
DISTRO="orangepi"
detect_os() {
    if [ -f /etc/armbian-release ]; then
        DISTRO="armbian"
        log_info "Detected OS: Armbian"
    elif uname -r | grep -q "sun50iw9" || ls -d /boot/dtb-*sun50iw9* >/dev/null 2>&1; then
        DISTRO="orangepi"
        log_info "Detected OS: Orange Pi OS"
    else
        log_warn "Unrecognized OS — this installer is tested on Orange Pi OS and Armbian"
        log_warn "Proceeding with Armbian-compatible install (builds module from source)"
        DISTRO="armbian"
    fi
}

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

    if [ "$DISTRO" = "armbian" ]; then
        log_info "Building WM8960 module from source for Armbian..."
        if [ ! -f "$SCRIPT_DIR/scripts/build-module.sh" ]; then
            log_error "scripts/build-module.sh not found"
            exit 1
        fi
        bash "$SCRIPT_DIR/scripts/build-module.sh"
    else
        log_warn "WM8960 kernel module not found, installing kernel..."
        if [ ! -f "$SCRIPT_DIR/scripts/install-kernel.sh" ]; then
            log_error "scripts/install-kernel.sh not found"
            exit 1
        fi
        bash "$SCRIPT_DIR/scripts/install-kernel.sh"
    fi

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
detect_os
install_kernel
install_driver

echo ""
log_info "Setup complete! Reboot to activate: sudo reboot"
