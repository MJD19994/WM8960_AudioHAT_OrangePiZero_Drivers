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

# Remove overlay from orangepiEnv.txt
ENV_FILE="/boot/orangepiEnv.txt"
OVERLAY_ENTRY="wm8960-working"

if [ -f "$ENV_FILE" ] && grep -q "$OVERLAY_ENTRY" "$ENV_FILE"; then
    log_info "Removing overlay from orangepiEnv.txt..."
    # Remove the entry from the overlays line (handle both "only entry" and "one of many")
    CURRENT_OVERLAYS=$(grep "^overlays=" "$ENV_FILE" | sed 's/^overlays=//')
    NEW_OVERLAYS=$(echo "$CURRENT_OVERLAYS" | sed "s/ *${OVERLAY_ENTRY}//;s/^ *//;s/ *$//;s/  */ /g")
    sed -i "s/^overlays=.*/overlays=${NEW_OVERLAYS}/" "$ENV_FILE"
    log_info "Updated: $(grep '^overlays=' "$ENV_FILE")"
fi

log_info "Uninstallation complete!"
log_warn "Device tree overlay .dtbo file remains in /boot - remove manually if needed"
log_info "Reboot recommended"
