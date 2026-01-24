#!/bin/bash
#
# Build WM8960 kernel module from source
# for Orange Pi Zero 2W running DietPi/Armbian
#
# This script downloads the WM8960 codec driver source from the Linux kernel
# and compiles it as an out-of-tree module for your running kernel.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/wm8960-build"
KERNEL_VERSION=$(uname -r)

print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   WM8960 Kernel Module Builder for Orange Pi Zero 2W       ║"
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

check_existing_module() {
    log_info "Checking for existing WM8960 module..."
    
    # Check if module already exists
    if find /lib/modules/${KERNEL_VERSION} -name "snd-soc-wm8960.ko*" 2>/dev/null | grep -q .; then
        log_info "WM8960 module already exists in kernel modules"
        modprobe snd_soc_wm8960 2>/dev/null && {
            log_info "Module loaded successfully!"
            exit 0
        }
    fi
    
    # Check kernel config
    if [ -f /proc/config.gz ]; then
        local config_status=$(zcat /proc/config.gz 2>/dev/null | grep "CONFIG_SND_SOC_WM8960" || echo "not found")
        if echo "$config_status" | grep -q "=y"; then
            log_info "WM8960 is built into the kernel (=y)"
            log_info "No need to build module - driver should be available"
            exit 0
        elif echo "$config_status" | grep -q "=m"; then
            log_info "WM8960 is configured as module (=m) but module file not found"
            log_warn "This might indicate a broken installation"
        else
            log_warn "CONFIG_SND_SOC_WM8960 is not set in this kernel"
            log_info "Will attempt to build module from source"
        fi
    fi
}

install_build_dependencies() {
    log_info "Installing build dependencies..."
    
    apt-get update -qq
    
    # Install kernel headers
    log_info "Installing kernel headers for ${KERNEL_VERSION}..."
    
    # Try different package names
    if apt-cache show linux-headers-${KERNEL_VERSION} &>/dev/null; then
        apt-get install -y linux-headers-${KERNEL_VERSION}
    elif apt-cache show linux-headers-current-sunxi64 &>/dev/null; then
        apt-get install -y linux-headers-current-sunxi64
    elif apt-cache show linux-headers-sunxi64 &>/dev/null; then
        apt-get install -y linux-headers-sunxi64
    else
        log_error "Could not find kernel headers package"
        log_error "Available packages:"
        apt-cache search linux-headers | head -10
        log_error ""
        log_error "Try installing manually: apt-get install linux-headers-<your-version>"
        exit 1
    fi
    
    # Install build tools
    apt-get install -y build-essential bc bison flex libssl-dev make wget curl
    
    log_info "Build dependencies installed"
}

setup_build_directory() {
    log_info "Setting up build directory..."
    
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
}

download_wm8960_source() {
    log_info "Downloading WM8960 driver source from Linux kernel..."
    
    # Get kernel major.minor version for fetching matching source
    local kernel_major=$(echo "${KERNEL_VERSION}" | cut -d. -f1)
    local kernel_minor=$(echo "${KERNEL_VERSION}" | cut -d. -f2)
    local kernel_branch="v${kernel_major}.${kernel_minor}"
    
    log_info "Using kernel branch: ${kernel_branch}"
    
    # URLs for WM8960 source files from kernel.org
    local base_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain"
    
    # Download wm8960.c
    log_info "Downloading wm8960.c..."
    if ! curl -fsSL "${base_url}/sound/soc/codecs/wm8960.c?h=${kernel_branch}" -o wm8960.c; then
        log_warn "Could not find exact kernel version, trying master branch..."
        curl -fsSL "${base_url}/sound/soc/codecs/wm8960.c" -o wm8960.c || {
            log_error "Failed to download wm8960.c"
            exit 1
        }
    fi
    
    # Download wm8960.h
    log_info "Downloading wm8960.h..."
    if ! curl -fsSL "${base_url}/sound/soc/codecs/wm8960.h?h=${kernel_branch}" -o wm8960.h; then
        curl -fsSL "${base_url}/sound/soc/codecs/wm8960.h" -o wm8960.h || {
            log_error "Failed to download wm8960.h"
            exit 1
        }
    fi
    
    log_info "Source files downloaded successfully"
}

create_makefile() {
    log_info "Creating Makefile..."
    
    cat > "${BUILD_DIR}/Makefile" << 'EOF'
# Makefile for out-of-tree WM8960 kernel module build

obj-m := snd-soc-wm8960.o
snd-soc-wm8960-objs := wm8960.o

KVERSION ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVERSION)/build

# Handle Armbian's header location
ifeq ($(wildcard $(KDIR)),)
    KDIR := /usr/src/linux-headers-$(KVERSION)
endif

PWD := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a

.PHONY: all clean install
EOF

    log_info "Makefile created"
}

build_module() {
    log_info "Building WM8960 kernel module..."
    log_info "This may take a few minutes..."
    
    cd "${BUILD_DIR}"
    
    # Find kernel headers directory
    local kdir="/lib/modules/${KERNEL_VERSION}/build"
    if [ ! -d "${kdir}" ]; then
        kdir="/usr/src/linux-headers-${KERNEL_VERSION}"
    fi
    
    if [ ! -d "${kdir}" ]; then
        log_error "Kernel headers not found at ${kdir}"
        log_error "Make sure linux-headers are installed"
        exit 1
    fi
    
    log_info "Using kernel headers from: ${kdir}"
    
    # Build the module
    make KDIR="${kdir}" KVERSION="${KERNEL_VERSION}" all 2>&1 | tee build.log
    
    if [ ! -f "snd-soc-wm8960.ko" ]; then
        log_error "Build failed! Check ${BUILD_DIR}/build.log for details"
        exit 1
    fi
    
    log_info "Module built successfully: snd-soc-wm8960.ko"
}

install_module() {
    log_info "Installing WM8960 kernel module..."
    
    cd "${BUILD_DIR}"
    
    # Create destination directory
    local mod_dir="/lib/modules/${KERNEL_VERSION}/kernel/sound/soc/codecs"
    mkdir -p "${mod_dir}"
    
    # Copy module
    install -Dm644 snd-soc-wm8960.ko "${mod_dir}/snd-soc-wm8960.ko"
    
    # Update module dependencies
    log_info "Updating module dependencies..."
    depmod -a
    
    log_info "Module installed to: ${mod_dir}/snd-soc-wm8960.ko"
}

load_module() {
    log_info "Loading WM8960 module..."
    
    # Load the module
    if modprobe snd_soc_wm8960; then
        log_info "Module loaded successfully!"
    else
        log_warn "Could not load module (may need reboot)"
    fi
    
    # Show loaded modules
    log_info "Loaded sound modules:"
    lsmod | grep -E "snd_soc|wm8960" || echo "  (none loaded yet - reboot may be required)"
}

setup_module_autoload() {
    log_info "Configuring module autoload..."
    
    # Add to modules list for auto-loading
    if ! grep -q "^snd_soc_wm8960" /etc/modules 2>/dev/null; then
        echo "snd_soc_wm8960" >> /etc/modules
        log_info "Added snd_soc_wm8960 to /etc/modules"
    fi
}

print_summary() {
    echo
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           WM8960 Module Build Complete!                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "The WM8960 kernel module has been built and installed."
    echo
    echo "Next steps:"
    echo "  1. Reboot your system: sudo reboot"
    echo "  2. After reboot, check module: lsmod | grep wm8960"
    echo "  3. Check sound card: aplay -l"
    echo "  4. Run status check: wm8960-status"
    echo
    echo "If the sound card still doesn't appear:"
    echo "  - Run the main installer again: sudo bash scripts/install.sh"
    echo "  - Check dmesg: dmesg | grep -i wm8960"
    echo
    echo "Build artifacts are in: ${BUILD_DIR}"
    echo
}

cleanup_on_error() {
    log_error "An error occurred during build"
    log_error "Build directory preserved at: ${BUILD_DIR}"
    log_error "Check ${BUILD_DIR}/build.log for details"
    exit 1
}

# Set trap for error handling
trap cleanup_on_error ERR

# Main build flow
main() {
    print_banner
    check_root
    check_existing_module
    install_build_dependencies
    setup_build_directory
    download_wm8960_source
    create_makefile
    build_module
    install_module
    setup_module_autoload
    load_module
    print_summary
}

# Parse command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo
        echo "Build and install the WM8960 kernel module from source."
        echo
        echo "This script is needed when the Armbian/DietPi kernel does not"
        echo "include the CONFIG_SND_SOC_WM8960 driver."
        echo
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --clean       Remove build directory and exit"
        echo "  --check       Check if module exists without building"
        echo
        echo "Prerequisites:"
        echo "  - Root/sudo access"
        echo "  - Internet connection"
        echo "  - Kernel headers (installed automatically)"
        echo
        exit 0
        ;;
    --clean)
        log_info "Cleaning build directory..."
        rm -rf "${BUILD_DIR}"
        log_info "Done"
        exit 0
        ;;
    --check)
        check_existing_module
        exit 0
        ;;
    *)
        main
        ;;
esac
