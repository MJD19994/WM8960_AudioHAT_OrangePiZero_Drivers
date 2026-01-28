#!/bin/bash
# Exhaustive DAUDIO driver search on Orange Pi
# Run this on your Orange Pi Zero 2W

echo "=== Exhaustive DAUDIO Driver Search ==="
echo "Started: $(date)"
echo ""

# 1. Kernel module search
echo "[1/8] Searching for DAUDIO kernel modules..."
find /lib/modules/$(uname -r) -name "*daudio*" 2>/dev/null
find /lib/modules/$(uname -r) -name "*i2s*" 2>/dev/null | grep -i sunxi
echo ""

# 2. Kernel symbols
echo "[2/8] Checking kernel symbols..."
echo "DAUDIO symbols:"
cat /proc/kallsyms | grep -i daudio | wc -l
echo "AHUB I2S symbols:"
cat /proc/kallsyms | grep -i "ahub.*i2s" | wc -l
echo ""

# 3. Kernel config
echo "[3/8] Checking kernel config..."
if [ -f /proc/config.gz ]; then
    echo "DAUDIO config:"
    zcat /proc/config.gz | grep -i daudio
    echo "AHUB config:"
    zcat /proc/config.gz | grep -i "SUNXI.*AHUB"
else
    echo "No /proc/config.gz available"
fi
echo ""

# 4. APT package search
echo "[4/8] Searching APT packages..."
echo "Kernel module packages:"
apt search linux-modules 2>/dev/null | grep -E "orangepi|sunxi" | head -10
echo ""
echo "Audio-related packages:"
apt search sunxi 2>/dev/null | grep -i audio | head -10
echo ""

# 5. Check all sound modules
echo "[5/8] Listing all sound modules..."
echo "Loaded sound modules:"
lsmod | grep snd
echo ""
echo "Available sunxi sound modules:"
find /lib/modules/$(uname -r)/kernel/sound/ -name "*.ko" | grep -i sunxi
echo ""

# 6. Device tree analysis
echo "[6/8] Analyzing device tree..."
if [ -f /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb ]; then
    echo "Decompiling DTB..."
    dtc -I dtb -O dts /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb > /tmp/dtb-analysis.dts 2>/dev/null
    echo "AHUB nodes found:"
    grep -c "ahub" /tmp/dtb-analysis.dts
    echo "I2S nodes found:"
    grep "i2s@" /tmp/dtb-analysis.dts | grep -v "//.*i2s@"
else
    echo "DTB file not found at expected location"
fi
echo ""

# 7. Platform devices
echo "[7/8] Checking platform devices..."
echo "AHUB-related devices:"
ls /sys/bus/platform/devices/ | grep -i ahub
echo ""
echo "I2S-related devices:"
ls /sys/bus/platform/devices/ | grep -i i2s
echo ""

# 8. Check for alternate driver names
echo "[8/8] Searching for alternate driver names..."
echo "Looking for: daim, dmic, cpudai..."
find /lib/modules/$(uname -r) -name "*daim*.ko" 2>/dev/null
find /lib/modules/$(uname -r) -name "*dmic*.ko" 2>/dev/null
find /lib/modules/$(uname -r) -name "*cpudai*.ko" 2>/dev/null
echo ""

# Summary
echo "=== Search Complete ==="
echo ""
echo "Next Steps:"
echo "1. Check Orange Pi website for source code downloads"
echo "2. Try Orange Pi OS 5.4 kernel (if available)"
echo "3. Search Chinese forums and resources"
echo "4. Post to community forums (template: COMMUNITY_POST_TEMPLATE.md)"
echo ""
echo "Results saved to: /tmp/daudio-search-$(date +%Y%m%d-%H%M%S).log"
