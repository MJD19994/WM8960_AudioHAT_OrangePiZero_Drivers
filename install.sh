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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for required commands
    for cmd in dtc fdtoverlay fdtget i2cset amixer systemctl; do
        if ! command -v $cmd &> /dev/null; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    # Check kernel version
    KERNEL_VER=$(uname -r)
    log_info "Detected kernel: $KERNEL_VER"
    
    if [[ ! "$KERNEL_VER" =~ "6.1.31" ]]; then
        log_warn "This installation was tested on kernel 6.1.31"
        log_warn "Your kernel is: $KERNEL_VER"
        if [ -t 0 ]; then
            # Interactive terminal — ask user
            read -p "Continue anyway? (y/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            # Non-interactive (called from quick-setup.sh) — warn and continue
            log_warn "Non-interactive mode, continuing anyway..."
        fi
    fi
}

patch_dtb() {
    log_info "Patching device tree for WM8960 audio support..."

    # Find the DTB directory (follows /boot/dtb symlink)
    DTB_DIR=$(find /boot -type d -name "allwinner" -path "*/dtb*" 2>/dev/null | head -1)
    if [ -z "$DTB_DIR" ]; then
        log_error "Could not find allwinner DTB directory under /boot"
        exit 1
    fi
    log_info "Found DTB directory: $DTB_DIR"

    # Find the board's base DTB
    BASE_DTB=$(find "$DTB_DIR" -maxdepth 1 -name "sun50i-h61*-orangepi-zero2w.dtb" ! -name "*wm8960*" ! -name "*.backup" 2>/dev/null | head -1)
    if [ -z "$BASE_DTB" ]; then
        # DTB may already be a symlink to the wm8960 variant from a previous install
        BASE_DTB=$(find "$DTB_DIR" -maxdepth 1 -name "sun50i-h61*-orangepi-zero2w.dtb" 2>/dev/null | head -1)
    fi

    if [ -z "$BASE_DTB" ]; then
        log_error "Could not find Orange Pi Zero 2W device tree"
        exit 1
    fi
    log_info "Found base DTB: $BASE_DTB"

    # Resolve symlink to get the real file
    REAL_DTB=$(readlink -f "$BASE_DTB")
    DTB_BASENAME=$(basename "$BASE_DTB" .dtb)

    # Check if WM8960 is already patched
    if fdtget "$REAL_DTB" /soc/i2c@5002400/wm8960@1a compatible >/dev/null 2>&1; then
        log_info "Device tree already has WM8960 support — skipping patch"
        return 0
    fi

    # Create backup of original DTB (only if not already backed up)
    if [ ! -f "${BASE_DTB}.backup" ]; then
        log_info "Backing up original DTB..."
        cp "$REAL_DTB" "${BASE_DTB}.backup"
    fi

    # Use the original (unpatched) DTB as input — always patch from clean state
    INPUT_DTB="${BASE_DTB}.backup"

    # Compile the WM8960 overlay from source
    DTS_SOURCE="$SCRIPT_DIR/overlays-orangepi/sun50i-h618-wm8960-working.dts"
    if [ ! -f "$DTS_SOURCE" ]; then
        log_error "Overlay source not found: $DTS_SOURCE"
        exit 1
    fi

    WORK_DIR=$(mktemp -d)
    trap "rm -rf '$WORK_DIR'" EXIT

    log_info "Compiling WM8960 overlay..."
    dtc -@ -I dts -O dtb -o "$WORK_DIR/wm8960.dtbo" "$DTS_SOURCE" || {
        log_error "Failed to compile WM8960 overlay"
        exit 1
    }

    # Apply overlay to base DTB using fdtoverlay
    PATCHED_DTB="$DTB_DIR/${DTB_BASENAME}-wm8960.dtb"

    log_info "Applying WM8960 overlay to device tree..."
    fdtoverlay -i "$INPUT_DTB" -o "$PATCHED_DTB" "$WORK_DIR/wm8960.dtbo" || {
        log_error "Failed to apply overlay to device tree"
        rm -f "$PATCHED_DTB"
        exit 1
    }

    # Replace original DTB with symlink to patched version
    ln -sf "$(basename "$PATCHED_DTB")" "$BASE_DTB"
    log_info "Device tree patched: $(basename "$BASE_DTB") -> $(basename "$PATCHED_DTB")"

    # Verify the patch
    if fdtget "$PATCHED_DTB" /soc/i2c@5002400/wm8960@1a compatible >/dev/null 2>&1; then
        log_info "WM8960 node verified in patched device tree"
    else
        log_error "Verification failed — WM8960 node not found in patched DTB"
        log_error "Restoring backup..."
        rm -f "$PATCHED_DTB"
        rm -f "$BASE_DTB"
        cp "${BASE_DTB}.backup" "$BASE_DTB"
        exit 1
    fi
}

install_service() {
    log_info "Installing PLL configuration service..."
    
    # Install script
    cp "$SCRIPT_DIR/service/wm8960-pll-config.sh" /usr/local/bin/ || {
        log_error "Failed to copy configuration script"
        exit 1
    }
    chmod +x /usr/local/bin/wm8960-pll-config.sh
    
    # Install service file
    cp "$SCRIPT_DIR/service/wm8960-audio.service" /etc/systemd/system/ || {
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
    if [ -f "$SCRIPT_DIR/configs/asound.conf" ]; then
        cp "$SCRIPT_DIR/configs/asound.conf" /etc/asound.conf || log_warn "Failed to install asound.conf"
    fi

    # Install mixer state
    if [ -f "$SCRIPT_DIR/configs/wm8960.state" ]; then
        cp "$SCRIPT_DIR/configs/wm8960.state" /etc/ || log_warn "Failed to install mixer state"
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
patch_dtb
install_service
install_alsa_config
print_next_steps

exit 0




