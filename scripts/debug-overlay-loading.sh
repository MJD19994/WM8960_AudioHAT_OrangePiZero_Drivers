#!/bin/bash
# Debug overlay loading issues

echo "=== Checking Device Tree Compatible Strings ==="
if [ -f /proc/device-tree/compatible ]; then
    echo "Base device tree compatible:"
    cat /proc/device-tree/compatible | tr '\0' '\n' | sed 's/^/  /'
else
    echo "Cannot read /proc/device-tree/compatible"
fi
echo

echo "=== Checking for Overlay Loading Errors in dmesg ==="
dmesg | grep -i "overlay\|dtb\|device.*tree" | tail -30
echo

echo "=== Checking u-boot overlay loading ==="
dmesg | grep -i "Loading.*overlay" | tail -10
echo

echo "=== Check if overlay file is valid ==="
if command -v fdtdump &>/dev/null; then
    echo "Checking primary overlay structure:"
    fdtdump /boot/dtb/allwinner/overlay/sun50i-h616-wm8960-soundcard.dtbo 2>&1 | head -30
else
    echo "fdtdump not available (install with: apt install device-tree-compiler)"
fi
echo

echo "=== List all overlays in boot directory ==="
ls -lh /boot/dtb/allwinner/overlay/*.dtbo | grep -v "^total"
echo

echo "=== Check what overlays are actually applied ==="
if [ -d /sys/firmware/devicetree/base/__symbols__ ]; then
    echo "Device tree symbols found, checking for WM8960 symbols:"
    ls /sys/firmware/devicetree/base/__symbols__/ | grep -i wm8960 || echo "  No WM8960 symbols found"
    echo
    echo "I2C symbols:"
    ls /sys/firmware/devicetree/base/__symbols__/ | grep -i i2c || echo "  No I2C symbols"
fi
echo

echo "=== Check I2C device tree node ==="
if [ -d /sys/firmware/devicetree/base/soc/i2c@5002400 ]; then
    echo "I2C node exists, checking children:"
    ls -la /sys/firmware/devicetree/base/soc/i2c@5002400/ | grep -v "^\." | tail -20
else
    echo "I2C node not found"
fi
