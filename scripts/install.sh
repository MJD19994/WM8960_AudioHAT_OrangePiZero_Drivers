#!/bin/bash
#
# Installation script for WM8960 Audio HAT (ReSpeaker 2-Mic / Keyestudio)
# on Orange Pi Zero 2W running DietPi, Armbian, or similar distributions
#
# Copyright (C) 2025
# License: MIT
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY_DIR="${SCRIPT_DIR}/../overlays"
CONFIG_DIR="${SCRIPT_DIR}/../configs"

# Overlay names (alphanumeric and hyphens only - safe for sed patterns)
OVERLAY_PRIMARY="sun50i-h618-wm8960-soundcard"
OVERLAY_ALT="sun50i-h618-wm8960-soundcard-i2s3"

print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   WM8960 Audio HAT Driver Installer for Orange Pi Zero 2W  ║"
    echo "║           (ReSpeaker 2-Mic HAT / Keyestudio)               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

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
        log_error "Please run this script as root (use sudo)"
        exit 1
    fi
}

check_platform() {
    log_info "Checking platform compatibility..."
    
    # Check for Orange Pi Zero 2W (H618)
    if grep -q "sun50i" /proc/device-tree/compatible 2>/dev/null; then
        log_info "Allwinner sun50i platform detected"
    elif grep -q "H618" /proc/cpuinfo 2>/dev/null; then
        log_info "Allwinner H618 detected"
    else
        log_warn "Could not confirm Orange Pi Zero 2W platform"
        log_warn "Proceeding anyway - overlay may need adjustment"
    fi
    
    # Show kernel version
    KERNEL_VERSION=$(uname -r)
    log_info "Kernel version: ${KERNEL_VERSION}"
}

detect_environment() {
    log_info "Detecting boot environment..."
    
    if [ -f "/boot/dietpiEnv.txt" ]; then
        BOOT_ENV="dietpi"
        CONFIG_FILE="/boot/dietpiEnv.txt"
        log_info "DietPi environment detected"
    elif [ -f "/boot/orangepiEnv.txt" ]; then
        BOOT_ENV="orangepi"
        CONFIG_FILE="/boot/orangepiEnv.txt"
        log_info "Orange Pi environment detected"
    elif [ -f "/boot/armbianEnv.txt" ]; then
        BOOT_ENV="armbian"
        CONFIG_FILE="/boot/armbianEnv.txt"
        log_info "Armbian environment detected"
    elif [ -f "/boot/extlinux/extlinux.conf" ]; then
        BOOT_ENV="extlinux"
        CONFIG_FILE="/boot/extlinux/extlinux.conf"
        log_info "Extlinux environment detected"
    else
        BOOT_ENV="unknown"
        log_warn "Could not detect boot environment"
    fi
    
    # Determine overlay directory
    if [ -d "/boot/dtb/allwinner/overlay" ]; then
        OVERLAY_DEST="/boot/dtb/allwinner/overlay"
    elif [ -d "/boot/overlay-user" ]; then
        OVERLAY_DEST="/boot/overlay-user"
    elif [ -d "/boot/dtbs/allwinner/overlay" ]; then
        OVERLAY_DEST="/boot/dtbs/allwinner/overlay"
    else
        OVERLAY_DEST="/boot/dtb/allwinner/overlay"
        mkdir -p "${OVERLAY_DEST}"
    fi
    
    log_info "Overlay directory: ${OVERLAY_DEST}"
}

install_dependencies() {
    log_info "Installing required packages..."
    
    apt-get update -qq
    apt-get install -y device-tree-compiler i2c-tools alsa-utils 2>/dev/null || {
        log_warn "Some packages may not have installed correctly"
    }
}

compile_overlays() {
    log_info "Compiling device tree overlays..."
    
    cd "${OVERLAY_DIR}"
    
    # Compile primary overlay (I2S2)
    if [ -f "${OVERLAY_PRIMARY}.dts" ]; then
        log_info "Compiling ${OVERLAY_PRIMARY}.dts..."
        dtc -@ -I dts -O dtb -o "${OVERLAY_PRIMARY}.dtbo" "${OVERLAY_PRIMARY}.dts" 2>/dev/null || {
            # Try without -@ flag for older dtc versions
            dtc -I dts -O dtb -o "${OVERLAY_PRIMARY}.dtbo" "${OVERLAY_PRIMARY}.dts"
        }
    fi
    
    # Compile alternative overlay (I2S3)
    if [ -f "${OVERLAY_ALT}.dts" ]; then
        log_info "Compiling ${OVERLAY_ALT}.dts..."
        dtc -@ -I dts -O dtb -o "${OVERLAY_ALT}.dtbo" "${OVERLAY_ALT}.dts" 2>/dev/null || {
            dtc -I dts -O dtb -o "${OVERLAY_ALT}.dtbo" "${OVERLAY_ALT}.dts"
        }
    fi
    
    log_info "Overlays compiled successfully"
}

install_overlays() {
    log_info "Installing device tree overlays..."
    
    # Copy compiled overlays
    if [ -f "${OVERLAY_DIR}/${OVERLAY_PRIMARY}.dtbo" ]; then
        install -Dm644 "${OVERLAY_DIR}/${OVERLAY_PRIMARY}.dtbo" "${OVERLAY_DEST}/${OVERLAY_PRIMARY}.dtbo"
        log_info "Installed ${OVERLAY_PRIMARY}.dtbo"
    fi
    
    if [ -f "${OVERLAY_DIR}/${OVERLAY_ALT}.dtbo" ]; then
        install -Dm644 "${OVERLAY_DIR}/${OVERLAY_ALT}.dtbo" "${OVERLAY_DEST}/${OVERLAY_ALT}.dtbo"
        log_info "Installed ${OVERLAY_ALT}.dtbo"
    fi
}

configure_boot() {
    log_info "Configuring boot parameters..."
    
    # Use the primary overlay by default
    OVERLAY_NAME="${OVERLAY_PRIMARY}"
    
    case "${BOOT_ENV}" in
        dietpi|orangepi|armbian)
            # These use similar syntax
            if grep -q "^overlays=" "${CONFIG_FILE}"; then
                # First, ensure i2c1-pi is enabled (required for I2C on pins 3/5)
                if ! grep -q "i2c1-pi" "${CONFIG_FILE}"; then
                    sed -i "/^overlays=/ s/$/ i2c1-pi/" "${CONFIG_FILE}"
                    log_info "Added i2c1-pi overlay for I2C support on pins 3/5"
                fi
                
                # Then add our WM8960 overlay
                if ! grep -q "${OVERLAY_NAME}" "${CONFIG_FILE}"; then
                    sed -i "/^overlays=/ s/$/ ${OVERLAY_NAME}/" "${CONFIG_FILE}"
                    log_info "Added ${OVERLAY_NAME} to existing overlays list"
                else
                    log_info "Overlay ${OVERLAY_NAME} already configured"
                fi
            elif grep -q "^user_overlays=" "${CONFIG_FILE}"; then
                if ! grep -q "i2c1-pi" "${CONFIG_FILE}"; then
                    sed -i "/^user_overlays=/ s/$/ i2c1-pi/" "${CONFIG_FILE}"
                    log_info "Added i2c1-pi overlay for I2C support"
                fi
                if ! grep -q "${OVERLAY_NAME}" "${CONFIG_FILE}"; then
                    sed -i "/^user_overlays=/ s/$/ ${OVERLAY_NAME}/" "${CONFIG_FILE}"
                    log_info "Added ${OVERLAY_NAME} to user_overlays list"
                fi
            else
                echo "overlays=i2c1-pi ${OVERLAY_NAME}" >> "${CONFIG_FILE}"
                log_info "Created overlays entry with i2c1-pi and ${OVERLAY_NAME}"
            fi
            
            # Ensure overlay_prefix is set for H618
            if ! grep -q "^overlay_prefix=" "${CONFIG_FILE}"; then
                echo "overlay_prefix=sun50i-h618" >> "${CONFIG_FILE}"
                log_info "Set overlay_prefix to sun50i-h618"
            fi
            ;;
            
        extlinux)
            if ! grep -qi "FDTOVERLAYS" "${CONFIG_FILE}"; then
                sed -i "/^[ ]*APPEND /i \    FDTOVERLAYS /dtbs/allwinner/overlay/${OVERLAY_NAME}.dtbo" "${CONFIG_FILE}"
                log_info "Added FDTOVERLAYS entry"
            elif ! grep -q "${OVERLAY_NAME}" "${CONFIG_FILE}"; then
                sed -i "s#FDTOVERLAYS \(.*\)#FDTOVERLAYS \1 /dtbs/allwinner/overlay/${OVERLAY_NAME}.dtbo#" "${CONFIG_FILE}"
                log_info "Added ${OVERLAY_NAME} to FDTOVERLAYS"
            fi
            ;;
            
        *)
            log_warn "Unknown boot environment. Manual configuration required."
            log_warn "Add 'i2c1-pi ${OVERLAY_NAME}' to your boot configuration overlays"
            ;;
    esac
}

enable_i2c() {
    log_info "Enabling I2C interface..."
    
    # Load I2C kernel modules
    modprobe i2c-dev 2>/dev/null || true
    modprobe i2c-sunxi 2>/dev/null || true
    
    # Add to modules file for persistence
    if ! grep -q "^i2c-dev" /etc/modules 2>/dev/null; then
        echo "i2c-dev" >> /etc/modules
        log_info "Added i2c-dev to /etc/modules"
    fi
    
    # Check for available I2C buses after overlay would be loaded
    log_info "Checking I2C bus availability..."
    for bus in 0 1 2 3 4 5; do
        if [ -e "/dev/i2c-${bus}" ]; then
            log_info "  I2C bus ${bus} available (/dev/i2c-${bus})"
        fi
    done
}

load_audio_modules() {
    log_info "Loading audio kernel modules..."
    
    # First, check if wm8960 driver is available in kernel
    local wm8960_available=false
    
    # Check if module file exists
    if find /lib/modules/$(uname -r) -name "*wm8960*" 2>/dev/null | grep -q .; then
        wm8960_available=true
        log_info "  WM8960 kernel module found"
    fi
    
    # Check if built into kernel
    if [ -f "/lib/modules/$(uname -r)/modules.builtin" ]; then
        if grep -q "wm8960" "/lib/modules/$(uname -r)/modules.builtin" 2>/dev/null; then
            wm8960_available=true
            log_info "  WM8960 driver is built into kernel"
        fi
    fi
    
    # Check kernel config if available
    if [ -f /proc/config.gz ]; then
        if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_SND_SOC_WM8960=[my]"; then
            wm8960_available=true
        elif zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_SND_SOC_WM8960 is not set"; then
            log_warn "  ⚠️  CONFIG_SND_SOC_WM8960 is NOT enabled in your kernel!"
            log_warn "      The WM8960 driver is not available."
            log_warn "      You may need a custom kernel with CONFIG_SND_SOC_WM8960=m"
            wm8960_available=false
        fi
    fi
    
    if [ "$wm8960_available" = false ]; then
        log_warn ""
        log_warn "  ════════════════════════════════════════════════════════"
        log_warn "  ⚠️  WARNING: WM8960 kernel driver may not be available!"
        log_warn "  ════════════════════════════════════════════════════════"
        log_warn "  The Armbian/DietPi kernel may not include WM8960 support."
        log_warn "  Check: zcat /proc/config.gz | grep WM8960"
        log_warn "  If CONFIG_SND_SOC_WM8960 is not set, you need a custom kernel."
        log_warn ""
    fi
    
    # Try to load required sound modules
    local modules="snd_soc_core snd_soc_wm8960 snd_soc_simple_card snd_soc_simple_card_utils"
    
    for mod in $modules; do
        if modprobe "$mod" 2>/dev/null; then
            log_info "  Loaded module: $mod"
        else
            log_warn "  Module $mod not available (may be built-in or not in kernel)"
        fi
    done
    
    # Add audio modules to /etc/modules for persistence
    for mod in snd_soc_wm8960 snd_soc_simple_card; do
        if ! grep -q "^${mod}" /etc/modules 2>/dev/null; then
            echo "$mod" >> /etc/modules
            log_info "Added $mod to /etc/modules"
        fi
    done
}

install_alsa_config() {
    log_info "Installing ALSA configuration..."
    
    # Create asound.conf for WM8960
    if [ -f "${CONFIG_DIR}/asound.conf" ]; then
        install -Dm644 "${CONFIG_DIR}/asound.conf" "/etc/asound.conf"
        log_info "Installed /etc/asound.conf"
    else
        # Create a basic configuration
        cat > /etc/asound.conf << 'EOF'
# ALSA configuration for WM8960 Audio HAT
# Orange Pi Zero 2W

pcm.!default {
    type asym
    playback.pcm {
        type plug
        slave.pcm "dmixer"
    }
    capture.pcm {
        type plug
        slave.pcm "wm8960sndrec"
    }
}

pcm.dmixer {
    type dmix
    ipc_key 1024
    slave {
        pcm "hw:wm8960soundcard"
        period_time 0
        period_size 1024
        buffer_size 8192
        rate 48000
        channels 2
    }
    bindings {
        0 0
        1 1
    }
}

pcm.wm8960sndrec {
    type dsnoop
    ipc_key 2048
    slave {
        pcm "hw:wm8960soundcard"
        period_time 0
        period_size 1024
        buffer_size 8192
        rate 48000
        channels 2
    }
    bindings {
        0 0
        1 1
    }
}

ctl.!default {
    type hw
    card wm8960soundcard
}
EOF
        log_info "Created basic ALSA configuration"
    fi
}

install_status_script() {
    log_info "Installing status check script..."
    
    install -Dm755 "${SCRIPT_DIR}/wm8960-status.sh" "/usr/local/bin/wm8960-status" 2>/dev/null || {
        # Create inline if script doesn't exist
        cat > /usr/local/bin/wm8960-status << 'EOF'
#!/bin/bash
#
# WM8960 Audio HAT Status Check Script
#

echo "=== WM8960 Audio HAT Status ==="
echo

echo "1. Kernel Version:"
uname -r
echo

echo "2. I2C Device Detection (looking for 0x1a):"
if command -v i2cdetect &> /dev/null; then
    # Try common I2C buses
    for bus in 0 1 2 3; do
        if [ -e "/dev/i2c-${bus}" ]; then
            echo "  Bus ${bus}:"
            i2cdetect -y ${bus} 2>/dev/null | grep -E "10:|1a" || echo "    (no WM8960 found on bus ${bus})"
        fi
    done
else
    echo "  i2cdetect not found. Install with: apt install i2c-tools"
fi
echo

echo "3. Sound Cards:"
if command -v aplay &> /dev/null; then
    aplay -l 2>/dev/null || echo "  No playback devices found"
else
    cat /proc/asound/cards 2>/dev/null || echo "  Unable to list sound cards"
fi
echo

echo "4. Capture Devices:"
if command -v arecord &> /dev/null; then
    arecord -l 2>/dev/null || echo "  No capture devices found"
fi
echo

echo "5. Kernel Modules:"
lsmod | grep -E "wm8960|snd_soc" || echo "  No WM8960/SoC audio modules loaded"
echo

echo "6. Device Tree Check:"
if [ -d "/proc/device-tree" ]; then
    find /proc/device-tree -name "*wm8960*" 2>/dev/null || echo "  No WM8960 device tree entries found"
fi
echo

echo "7. DMESG (WM8960 related):"
dmesg | grep -i wm8960 | tail -10 || echo "  No WM8960 messages in dmesg"
echo

echo "=== End of Status ==="
EOF
        chmod +x /usr/local/bin/wm8960-status
    }
    
    log_info "Status script installed as /usr/local/bin/wm8960-status"
}

print_summary() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║               Installation Complete!                       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "Next steps:"
    echo "  1. Reboot your Orange Pi Zero 2W: sudo reboot"
    echo "  2. After reboot, check status: wm8960-status"
    echo "  3. Test audio playback: speaker-test -c 2 -t wav"
    echo "  4. Test recording: arecord -D plughw:wm8960soundcard -f cd test.wav"
    echo
    echo "Troubleshooting:"
    echo "  - If no sound card appears, try the alternative overlay:"
    echo "    Edit ${CONFIG_FILE} and change overlay to: ${OVERLAY_ALT}"
    echo "  - Check I2C with: i2cdetect -y 1"
    echo "  - View kernel messages: dmesg | grep -i wm8960"
    echo
    echo "For more help, see the README.md file"
    echo
}

# Main installation flow
main() {
    print_banner
    check_root
    check_platform
    detect_environment
    install_dependencies
    compile_overlays
    install_overlays
    configure_boot
    enable_i2c
    load_audio_modules
    install_alsa_config
    install_status_script
    print_summary
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --uninstall   Remove the WM8960 driver"
        echo
        exit 0
        ;;
    --uninstall)
        echo "Uninstalling WM8960 driver..."
        rm -f "${OVERLAY_DEST}/${OVERLAY_PRIMARY}.dtbo" 2>/dev/null
        rm -f "${OVERLAY_DEST}/${OVERLAY_ALT}.dtbo" 2>/dev/null
        rm -f /usr/local/bin/wm8960-status 2>/dev/null
        rm -f /etc/asound.conf 2>/dev/null
        log_info "Driver files removed. Edit your boot config to remove overlay entries."
        exit 0
        ;;
    *)
        main
        ;;
esac
