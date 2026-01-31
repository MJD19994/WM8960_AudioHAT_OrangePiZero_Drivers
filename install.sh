#!/bin/bash
#
# WM8960 Audio HAT Installation Script for Orange Pi Zero 2W (H618)
# 
# This script installs and configures the WM8960 audio codec support
# including device tree overlay, PLL configuration service, and ALSA settings.
#

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "This script must be run as root"
        exit 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for required commands
    for cmd in dtc i2cset amixer systemctl; do
        if ! command -v $cmd &> /dev/null; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    # Check kernel version
    KERNEL_VER=$(uname -r)
    log_info "Detected kernel: $KERNEL_VER"
    
    if [[ ! "$KERNEL_VER" =~ "6.1.31-orangepi" ]]; then
        log_warn "This installation was tested on kernel 6.1.31-orangepi"
        log_warn "Your kernel is: $KERNEL_VER"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_overlay() {
    log_info "Installing device tree overlay..."

    # Find the overlay directory (kernel name in path may differ from uname -r)
    OVERLAY_DIR=$(find /boot -type d -name "overlay" -path "*/allwinner/*" 2>/dev/null | head -1)
    if [ -z "$OVERLAY_DIR" ]; then
        log_error "Could not find allwinner overlay directory under /boot"
        exit 1
    fi
    log_info "Found overlay directory: $OVERLAY_DIR"

    # Detect SoC variant (H616 vs H618) from existing overlays
    SOC_PREFIX=""
    if ls "$OVERLAY_DIR"/sun50i-h618-*.dtbo >/dev/null 2>&1; then
        SOC_PREFIX="h618"
        log_info "Detected H618 SoC from existing overlays"
    elif ls "$OVERLAY_DIR"/sun50i-h616-*.dtbo >/dev/null 2>&1; then
        SOC_PREFIX="h616"
        log_info "Detected H616 SoC from existing overlays"
    else
        # Fallback: check base DTB files
        ALLWINNER_DIR=$(dirname "$OVERLAY_DIR")
        BASE_DTB=$(find "$ALLWINNER_DIR" -maxdepth 1 -name "sun50i-h6*.dtb" 2>/dev/null | head -1)
        if echo "$BASE_DTB" | grep -q "h618"; then
            SOC_PREFIX="h618"
            log_info "Detected H618 SoC from base DTB"
        elif echo "$BASE_DTB" | grep -q "h616"; then
            SOC_PREFIX="h616"
            log_info "Detected H616 SoC from base DTB"
        else
            SOC_PREFIX="h618"
            log_warn "Could not detect SoC variant, defaulting to H618"
        fi
    fi

    DTS_SOURCE="overlays-orangepi/sun50i-${SOC_PREFIX}-wm8960-working.dts"
    OVERLAY_NAME="sun50i-${SOC_PREFIX}-wm8960-working.dtbo"

    if [ ! -f "$DTS_SOURCE" ]; then
        log_error "Overlay source not found: $DTS_SOURCE"
        log_error "Your board uses ${SOC_PREFIX} but overlay file is missing"
        exit 1
    fi

    # Compile overlay
    log_info "Compiling device tree overlay for ${SOC_PREFIX}..."
    dtc -@ -I dts -O dtb -o "/tmp/$OVERLAY_NAME" "$DTS_SOURCE" || {
        log_error "Failed to compile overlay"
        exit 1
    }

    # Backup existing overlay if present
    if [ -f "$OVERLAY_DIR/$OVERLAY_NAME" ]; then
        log_info "Backing up existing overlay..."
        cp "$OVERLAY_DIR/$OVERLAY_NAME" "$OVERLAY_DIR/${OVERLAY_NAME}.backup-$(date +%Y%m%d)"
    fi

    # Install overlay
    cp "/tmp/$OVERLAY_NAME" "$OVERLAY_DIR/" || {
        log_error "Failed to install overlay"
        exit 1
    }

    log_info "Overlay installed successfully: $OVERLAY_NAME"
}

install_service() {
    log_info "Installing PLL configuration service..."
    
    # Install script
    cp service/wm8960-pll-config.sh /usr/local/bin/ || {
        log_error "Failed to copy configuration script"
        exit 1
    }
    chmod +x /usr/local/bin/wm8960-pll-config.sh
    
    # Install service file
    cp service/wm8960-audio.service /etc/systemd/system/ || {
        log_error "Failed to copy service file"
        exit 1
    }
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable wm8960-audio.service || {
        log_error "Failed to enable service"
        exit 1
    }
    
    log_info "Service installed and enabled"
}

install_alsa_config() {
    log_info "Installing ALSA configuration..."
    
    # Install ALSA config
    if [ -f "configs/asound.conf" ]; then
        cp configs/asound.conf /etc/asound.conf || log_warn "Failed to install asound.conf"
    fi
    
    # Install mixer state
    if [ -f "configs/wm8960.state" ]; then
        cp configs/wm8960.state /etc/ || log_warn "Failed to install mixer state"
    fi
    
    log_info "ALSA configuration installed"
}

print_next_steps() {
    echo ""
    log_info "Installation complete!"
    echo ""
    echo "Next steps:"
    echo "1. Reboot your Orange Pi: sudo reboot"
    echo "2. After reboot, test audio with:"
    echo "   speaker-test -D plughw:ahub0wm8960,0 -c 2 -r 48000 -t sine -f 1000 -l 1"
    echo ""
    echo "Notes:"
    echo "- Card 3 is the WM8960 (ahub0wm8960)"
    echo "- Both headphones and speaker will work simultaneously"
    echo "- Service status: systemctl status wm8960-audio.service"
    echo "- Logs: journalctl -u wm8960-audio.service"
    echo ""
}

# Main installation
log_info "WM8960 Audio HAT Installation for Orange Pi Zero 2W"
echo ""

check_root
check_prerequisites
install_overlay
install_service
install_alsa_config
print_next_steps

exit 0








