#!/bin/bash
#
# WM8960 Audio HAT Uninstallation Script
#

set -e

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

log_info "Uninstalling WM8960 Audio HAT support..."

# Stop and disable service
if systemctl is-active --quiet wm8960-audio.service; then
    log_info "Stopping service..."
    systemctl stop wm8960-audio.service
fi

if systemctl is-enabled --quiet wm8960-audio.service; then
    log_info "Disabling service..."
    systemctl disable wm8960-audio.service
fi

# Remove service files
rm -f /etc/systemd/system/wm8960-audio.service
rm -f /usr/local/bin/wm8960-pll-config.sh
systemctl daemon-reload

# Remove ALSA config (backup first)
if [ -f /etc/asound.conf ]; then
    # Preserve existing backup if it exists
    if [ -f /etc/asound.conf.wm8960-backup ]; then
        TIMESTAMP=$(date +%s)
        log_info "Existing backup found, preserving as /etc/asound.conf.wm8960-backup.$TIMESTAMP"
        mv /etc/asound.conf.wm8960-backup /etc/asound.conf.wm8960-backup.$TIMESTAMP
    fi

    log_info "Backing up /etc/asound.conf to /etc/asound.conf.wm8960-backup"
    cp /etc/asound.conf /etc/asound.conf.wm8960-backup
    rm -f /etc/asound.conf
fi

rm -f /etc/wm8960.state

# Remove WM8960 module if it was built from source (Armbian)
WM8960_MODULE="/lib/modules/$(uname -r)/kernel/sound/soc/codecs/snd-soc-wm8960.ko"
if [ -f "$WM8960_MODULE" ] && [ -f /etc/armbian-release ]; then
    log_info "Removing WM8960 kernel module (built from source)..."
    rm -f "$WM8960_MODULE"
    depmod -a
fi

# Restore original device tree
DTB_DIR=$(find /boot -type d -name "allwinner" -path "*/dtb*" 2>/dev/null | head -1)
if [ -n "$DTB_DIR" ]; then
    BASE_DTB=$(find "$DTB_DIR" -maxdepth 1 -name "sun50i-h61*-orangepi-zero2w.dtb" 2>/dev/null | head -1)
    if [ -n "$BASE_DTB" ] && [ -L "$BASE_DTB" ]; then
        # DTB is a symlink to patched version — restore from backup
        if [ -f "${BASE_DTB}.backup" ]; then
            log_info "Restoring original device tree..."
            rm -f "$BASE_DTB"
            cp "${BASE_DTB}.backup" "$BASE_DTB"
            log_info "Original DTB restored"
            # Remove patched DTB
            PATCHED_DTB="$DTB_DIR/$(basename "$BASE_DTB" .dtb)-wm8960.dtb"
            rm -f "$PATCHED_DTB"
        else
            log_warn "DTB backup not found — cannot restore original device tree"
            log_warn "System may be left in an inconsistent state"
        fi
    else
        log_info "Device tree does not appear to be patched"
    fi
else
    log_info "DTB directory not found — skipping DTB restoration"
fi

log_info "Uninstallation complete!"
log_info "Reboot recommended"
