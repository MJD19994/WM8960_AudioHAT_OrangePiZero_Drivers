#!/bin/bash
#
# WM8960 Audio HAT Quick Setup
#
# All-in-one installer that handles kernel module installation (via DKMS),
# device tree patching, mixer service, and audio server configuration.
# Safe to re-run.
#
# This script delegates to install.sh which handles everything including
# DKMS module building, OS detection, and audio stack configuration.
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/install.sh" ]; then
    log_error "install.sh not found in $SCRIPT_DIR"
    exit 1
fi

log_info "WM8960 Audio HAT Quick Setup"
echo ""

bash "$SCRIPT_DIR/install.sh" "$@"

echo ""
log_info "Setup complete! Reboot to activate: sudo reboot"
