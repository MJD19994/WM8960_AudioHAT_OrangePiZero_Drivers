#!/bin/bash
#
# WM8960 Kernel Module Builder
#
# Builds the WM8960 codec module from source for kernels that don't
# include it (e.g., Armbian). Downloads source from kernel.org matching
# the running kernel version, builds out-of-tree, and installs.
#
# Can be run standalone or called from quick-setup.sh.
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root"
    exit 1
fi

KVER=$(uname -r)
# Extract major.minor.patch from kernel version (e.g., "6.12.74" from "6.12.74-current-sunxi64")
KVER_BASE=$(echo "$KVER" | sed -n 's/^\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
if [ -z "$KVER_BASE" ]; then
    log_error "Could not parse kernel version from: ${KVER}"
    exit 1
fi
MODULE_DIR="/lib/modules/${KVER}/kernel/sound/soc/codecs"
HEADERS_DIR="/lib/modules/${KVER}/build"

log_info "Building WM8960 module for kernel ${KVER}..."

# Check if module already exists
if modinfo snd_soc_wm8960 >/dev/null 2>&1; then
    log_info "WM8960 module already available — skipping build"
    exit 0
fi

# Install build dependencies if missing
install_deps() {
    local missing=()

    if [ ! -d "$HEADERS_DIR" ]; then
        # Try to find the right headers package name
        local headers_pkg=""
        if apt-cache show "linux-headers-current-sunxi64" >/dev/null 2>&1; then
            headers_pkg="linux-headers-current-sunxi64"
        elif apt-cache show "linux-headers-${KVER}" >/dev/null 2>&1; then
            headers_pkg="linux-headers-${KVER}"
        fi
        if [ -n "$headers_pkg" ]; then
            missing+=("$headers_pkg")
        else
            log_error "Cannot find kernel headers package for ${KVER}"
            log_error "Install headers manually: apt install linux-headers-..."
            exit 1
        fi
    fi

    command -v make >/dev/null 2>&1    || missing+=("make")
    command -v gcc >/dev/null 2>&1     || missing+=("gcc")
    command -v curl >/dev/null 2>&1    || missing+=("curl")
    command -v i2cset >/dev/null 2>&1  || missing+=("i2c-tools")

    if [ ${#missing[@]} -gt 0 ]; then
        log_info "Installing build dependencies: ${missing[*]}"
        apt-get update -qq
        apt-get install -y -qq "${missing[@]}"
    fi

    # Verify headers are now present
    if [ ! -d "$HEADERS_DIR" ]; then
        log_error "Kernel headers not found at ${HEADERS_DIR} after installation"
        exit 1
    fi
}

# Download WM8960 source from kernel.org
download_source() {
    local build_dir="$1"
    local base_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/sound/soc/codecs"

    log_info "Downloading WM8960 source (kernel v${KVER_BASE})..."

    curl -sSf --retry 3 --connect-timeout 10 "${base_url}/wm8960.c?h=v${KVER_BASE}" -o "${build_dir}/wm8960.c" || {
        log_error "Failed to download wm8960.c for kernel v${KVER_BASE}"
        exit 1
    }

    curl -sSf --retry 3 --connect-timeout 10 "${base_url}/wm8960.h?h=v${KVER_BASE}" -o "${build_dir}/wm8960.h" || {
        log_error "Failed to download wm8960.h for kernel v${KVER_BASE}"
        exit 1
    }

    # Create out-of-tree Makefile
    cat > "${build_dir}/Makefile" << 'EOF'
obj-m += snd-soc-wm8960.o
snd-soc-wm8960-objs := wm8960.o

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
EOF
}

# Build and install
build_module() {
    local build_dir="$1"

    log_info "Compiling module..."
    make -C "$HEADERS_DIR" M="$build_dir" modules || {
        log_error "Module compilation failed"
        exit 1
    }

    if [ ! -f "${build_dir}/snd-soc-wm8960.ko" ]; then
        log_error "Build succeeded but snd-soc-wm8960.ko not found"
        exit 1
    fi

    log_info "Installing module to ${MODULE_DIR}/"
    mkdir -p "$MODULE_DIR"
    cp "${build_dir}/snd-soc-wm8960.ko" "$MODULE_DIR/"

    log_info "Running depmod..."
    depmod -a "$KVER"
}

# Main
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

install_deps
download_source "$BUILD_DIR"
build_module "$BUILD_DIR"

# Verify
if modinfo snd_soc_wm8960 >/dev/null 2>&1; then
    log_info "WM8960 module built and installed successfully"
else
    log_warn "Module installed but modinfo can't find it yet (may need reboot)"
fi
