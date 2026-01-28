#!/bin/bash
# Quick Kernel and Driver Investigation Script
# Run this on your Orange Pi Zero 2W

set -e

echo "=========================================="
echo "KERNEL & DRIVER INVESTIGATION"
echo "Orange Pi Zero 2W - WM8960 Audio HAT"
echo "=========================================="
echo ""

# System Info
echo "[1] CURRENT SYSTEM INFO"
echo "----------------------------"
echo "Kernel: $(uname -r)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Architecture: $(uname -m)"
echo ""

# Available Kernels
echo "[2] AVAILABLE KERNEL PACKAGES"
echo "----------------------------"
apt-cache search linux-image | grep sunxi64 | sort
echo ""

# Check for specific kernel flavors
echo "[3] KERNEL FLAVOR AVAILABILITY"
echo "----------------------------"
for flavor in current edge legacy; do
    package="linux-image-${flavor}-sunxi64"
    if apt-cache policy "$package" 2>/dev/null | grep -q "Candidate"; then
        version=$(apt-cache policy "$package" | grep Candidate | awk '{print $2}')
        installed=$(apt-cache policy "$package" | grep Installed | awk '{print $2}')
        echo "✓ $flavor: $version (Installed: $installed)"
    else
        echo "✗ $flavor: Not available"
    fi
done
echo ""

# Current Modules
echo "[4] CURRENT SUNXI AUDIO MODULES"
echo "----------------------------"
if [ -d "/lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2" ]; then
    ls -lh /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/*.ko 2>/dev/null || echo "No modules found"
else
    echo "Directory not found: /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2"
fi
echo ""

# Search for DAUDIO
echo "[5] SEARCHING FOR DAUDIO DRIVER"
echo "----------------------------"
daudio_found=$(find /lib/modules/$(uname -r) -name "*daudio*" 2>/dev/null)
if [ -z "$daudio_found" ]; then
    echo "✗ DAUDIO driver NOT FOUND in current kernel"
else
    echo "✓ DAUDIO driver FOUND:"
    echo "$daudio_found"
fi
echo ""

# Kernel Config
echo "[6] KERNEL CONFIG - SUNXI AUDIO"
echo "----------------------------"
if [ -f /proc/config.gz ]; then
    zcat /proc/config.gz | grep -E "SUNXI.*AHUB|SUNXI.*DAUDIO|SUNXI.*I2S" || echo "No SUNXI audio configs found"
else
    echo "Kernel config not available at /proc/config.gz"
    if [ -f /boot/config-$(uname -r) ]; then
        cat /boot/config-$(uname -r) | grep -E "SUNXI.*AHUB|SUNXI.*DAUDIO" || echo "No SUNXI audio configs found"
    fi
fi
echo ""

# Kernel Headers
echo "[7] KERNEL SOURCE/HEADERS"
echo "----------------------------"
if [ -d "/usr/src/linux-headers-$(uname -r)" ]; then
    echo "✓ Kernel headers installed at: /usr/src/linux-headers-$(uname -r)"
    
    # Check for DAUDIO source
    echo ""
    echo "Searching for DAUDIO source files..."
    daudio_src=$(find /usr/src/linux-headers-$(uname -r) -name "*daudio*" 2>/dev/null)
    if [ -z "$daudio_src" ]; then
        echo "✗ DAUDIO source NOT FOUND in kernel headers"
    else
        echo "✓ DAUDIO source FOUND:"
        echo "$daudio_src"
    fi
    
    # Check Makefile
    echo ""
    echo "Checking sunxi_v2 Makefile..."
    if [ -f "/usr/src/linux-headers-$(uname -r)/sound/soc/sunxi_v2/Makefile" ]; then
        cat /usr/src/linux-headers-$(uname -r)/sound/soc/sunxi_v2/Makefile
    else
        echo "Makefile not found"
    fi
else
    echo "✗ Kernel headers not installed"
    echo "Install with: sudo apt install linux-headers-$(uname -r)"
fi
echo ""

# DKMS Modules
echo "[8] DKMS STATUS"
echo "----------------------------"
if command -v dkms &> /dev/null; then
    dkms status || echo "No DKMS modules installed"
else
    echo "DKMS not installed"
fi
echo ""

# APT Repositories
echo "[9] APT REPOSITORIES"
echo "----------------------------"
echo "Main sources:"
cat /etc/apt/sources.list 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "No entries"
echo ""
echo "Additional sources:"
ls -1 /etc/apt/sources.list.d/*.list 2>/dev/null | while read file; do
    echo "--- $file ---"
    cat "$file" | grep -v "^#" | grep -v "^$"
done || echo "No additional sources"
echo ""

# Device Tree Status
echo "[10] DEVICE TREE STATUS"
echo "----------------------------"
echo "Loaded overlays (from /boot/dietpiEnv.txt or equivalent):"
if [ -f /boot/dietpiEnv.txt ]; then
    grep "overlay" /boot/dietpiEnv.txt
elif [ -f /boot/armbianEnv.txt ]; then
    grep "overlay" /boot/armbianEnv.txt
else
    echo "Boot environment file not found"
fi
echo ""
echo "AHUB I2S devices:"
find /sys/bus/platform/devices -name "*ahub*" 2>/dev/null | while read dev; do
    echo "  $dev"
    if [ -f "$dev/modalias" ]; then
        echo "    Modalias: $(cat $dev/modalias)"
    fi
    if [ -f "$dev/driver_override" ]; then
        driver=$(readlink "$dev/driver" 2>/dev/null | xargs basename)
        echo "    Driver: ${driver:-none}"
    fi
    if [ -f "$dev/uevent" ]; then
        echo "    Status: $(cat $dev/uevent | grep MODALIAS)"
    fi
done
echo ""

# Summary
echo "=========================================="
echo "SUMMARY & RECOMMENDATIONS"
echo "=========================================="
echo ""

# Check if legacy kernel available
if apt-cache policy linux-image-legacy-sunxi64 2>/dev/null | grep -q "Candidate"; then
    echo "⭐ ACTION: Legacy kernel is AVAILABLE"
    echo "   Try: sudo apt install linux-image-legacy-sunxi64"
    echo "   Legacy kernels often include vendor BSP drivers"
    echo ""
fi

# Check if edge kernel available
if apt-cache policy linux-image-edge-sunxi64 2>/dev/null | grep -q "Candidate"; then
    echo "⭐ ACTION: Edge kernel is AVAILABLE"
    echo "   Try: sudo apt install linux-image-edge-sunxi64"
    echo "   Edge kernels may have newer driver support"
    echo ""
fi

# If DAUDIO not found
if [ -z "$daudio_found" ]; then
    echo "⚠️  DAUDIO driver is MISSING from current kernel"
    echo ""
    echo "Next Steps:"
    echo "1. Try alternative kernel flavors (legacy/edge) if available above"
    echo "2. Download Orange Pi official OS image and check for driver"
    echo "3. Contact Orange Pi for BSP source code"
    echo "4. Check vendor kernel documentation at:"
    echo "   http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_2W"
    echo ""
fi

echo "Report saved to: kernel-investigation-report.txt"
