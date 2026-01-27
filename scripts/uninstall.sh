#!/bin/bash
#
# Uninstallation script for WM8960 Audio HAT (ReSpeaker 2-Mic / Keyestudio)
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

# Overlay names
OVERLAY_PRIMARY="sun50i-h616-wm8960-soundcard"
OVERLAY_ALT="sun50i-h616-wm8960-soundcard-i2s3"

print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  WM8960 Audio HAT Driver Uninstaller for Orange Pi Zero 2W ║"
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
        CONFIG_FILE=""
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
    fi
    
    log_info "Overlay directory: ${OVERLAY_DEST}"
}

remove_overlays() {
    log_info "Removing device tree overlays..."
    
    local removed=0
    
    if [ -f "${OVERLAY_DEST}/${OVERLAY_PRIMARY}.dtbo" ]; then
        rm -f "${OVERLAY_DEST}/${OVERLAY_PRIMARY}.dtbo"
        log_info "Removed ${OVERLAY_PRIMARY}.dtbo"
        removed=$((removed + 1))
    fi
    
    if [ -f "${OVERLAY_DEST}/${OVERLAY_ALT}.dtbo" ]; then
        rm -f "${OVERLAY_DEST}/${OVERLAY_ALT}.dtbo"
        log_info "Removed ${OVERLAY_ALT}.dtbo"
        removed=$((removed + 1))
    fi
    
    if [ $removed -eq 0 ]; then
        log_warn "No overlay files found to remove"
    fi
}

remove_boot_config() {
    log_info "Removing overlay from boot configuration..."
    
    if [ -z "${CONFIG_FILE}" ] || [ ! -f "${CONFIG_FILE}" ]; then
        log_warn "Boot configuration file not found - skipping"
        return
    fi
    
    # Create backup
    cp "${CONFIG_FILE}" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    log_info "Created backup of boot config"
    
    case "${BOOT_ENV}" in
        dietpi|orangepi|armbian)
            # Remove overlay entries from overlays= line
            if grep -q "overlays=" "${CONFIG_FILE}"; then
                # Remove our overlay names (with and without prefix)
                sed -i "s/ ${OVERLAY_PRIMARY}//g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_PRIMARY} //g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_PRIMARY}//g" "${CONFIG_FILE}"
                sed -i "s/ ${OVERLAY_ALT}//g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_ALT} //g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_ALT}//g" "${CONFIG_FILE}"
                # Also remove short names without sun50i-h616 prefix
                sed -i "s/ wm8960-soundcard//g" "${CONFIG_FILE}"
                sed -i "s/wm8960-soundcard //g" "${CONFIG_FILE}"
                sed -i "s/ wm8960-soundcard-i2s3//g" "${CONFIG_FILE}"
                sed -i "s/wm8960-soundcard-i2s3 //g" "${CONFIG_FILE}"
                
                # Clean up empty overlays= line
                sed -i '/^overlays=$/d' "${CONFIG_FILE}"
                
                log_info "Removed overlay entries from boot config"
            fi
            
            # Remove user_overlays entries if present
            if grep -q "user_overlays=" "${CONFIG_FILE}"; then
                sed -i "s/ ${OVERLAY_PRIMARY}//g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_PRIMARY} //g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_PRIMARY}//g" "${CONFIG_FILE}"
                sed -i "s/ ${OVERLAY_ALT}//g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_ALT} //g" "${CONFIG_FILE}"
                sed -i "s/${OVERLAY_ALT}//g" "${CONFIG_FILE}"
                sed -i '/^user_overlays=$/d' "${CONFIG_FILE}"
            fi
            ;;
            
        extlinux)
            # Remove FDTOVERLAYS entries for our overlays
            sed -i "/${OVERLAY_PRIMARY}/d" "${CONFIG_FILE}"
            sed -i "/${OVERLAY_ALT}/d" "${CONFIG_FILE}"
            log_info "Removed overlay entries from extlinux config"
            ;;
            
        *)
            log_warn "Unknown boot environment - please manually edit your boot config"
            ;;
    esac
}

remove_alsa_config() {
    log_info "Removing ALSA configuration..."
    
    if [ -f "/etc/asound.conf" ]; then
        # Check if it's our config
        if grep -q "wm8960" "/etc/asound.conf"; then
            rm -f /etc/asound.conf
            log_info "Removed /etc/asound.conf"
        else
            log_warn "/etc/asound.conf exists but doesn't appear to be ours - skipping"
        fi
    else
        log_info "No ALSA configuration file found"
    fi
}

remove_status_script() {
    log_info "Removing status check script..."
    
    if [ -f "/usr/local/bin/wm8960-status" ]; then
        rm -f /usr/local/bin/wm8960-status
        log_info "Removed /usr/local/bin/wm8960-status"
    else
        log_info "Status script not found"
    fi
}

print_summary() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Uninstallation Complete!                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "The WM8960 Audio HAT driver has been removed."
    echo
    echo "Next steps:"
    echo "  1. Reboot your Orange Pi Zero 2W: sudo reboot"
    echo "  2. After reboot, verify with: aplay -l"
    echo
    echo "Note: The installed packages (device-tree-compiler, i2c-tools, alsa-utils)"
    echo "have NOT been removed as they may be used by other applications."
    echo
}

# Main uninstallation flow
main() {
    print_banner
    check_root
    
    echo -e "${YELLOW}This will remove the WM8960 Audio HAT driver from your system.${NC}"
    echo
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
    
    detect_environment
    remove_overlays
    remove_boot_config
    remove_alsa_config
    remove_status_script
    print_summary
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Uninstall the WM8960 Audio HAT driver from Orange Pi Zero 2W"
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --force, -f   Skip confirmation prompt"
        echo
        exit 0
        ;;
    --force|-f)
        print_banner
        check_root
        detect_environment
        remove_overlays
        remove_boot_config
        remove_alsa_config
        remove_status_script
        print_summary
        ;;
    *)
        main
        ;;
esac
