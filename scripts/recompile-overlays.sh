#!/bin/bash
# Recompile and install WM8960 device tree overlays

set -e  # Exit on error

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Recompiling WM8960 Device Tree Overlays                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")/../overlays"

# Compile primary overlay (I2S2)
echo "Compiling sun50i-h616-wm8960-soundcard.dts..."
dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dts
if [ $? -eq 0 ]; then
    echo "  ✓ Compiled successfully"
else
    echo "  ✗ Compilation failed!"
    exit 1
fi

# Compile I2S3 overlay
echo "Compiling sun50i-h616-wm8960-soundcard-i2s3.dts..."
dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard-i2s3.dtbo sun50i-h616-wm8960-soundcard-i2s3.dts
if [ $? -eq 0 ]; then
    echo "  ✓ Compiled successfully"
else
    echo "  ✗ Compilation failed!"
    exit 1
fi

# Compile simple-audio-card overlay (mainline sun4i-i2s driver)
echo "Compiling sun50i-h616-wm8960-simple.dts (mainline driver)..."
dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-simple.dtbo sun50i-h616-wm8960-simple.dts
if [ $? -eq 0 ]; then
    echo "  ✓ Compiled successfully"
else
    echo "  ✗ Compilation failed!"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Installing Overlays to /boot                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Copy to boot directory
echo "Copying overlays to /boot/dtb/allwinner/overlay/..."
sudo cp -v sun50i-h616-wm8960-soundcard*.dtbo /boot/dtb/allwinner/overlay/

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   SUCCESS                                                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Overlays compiled and installed successfully!"
echo ""
echo "THREE VERSIONS AVAILABLE:"
echo "  1. wm8960-soundcard (AHUB/I2S2) - needs missing daudio driver"
echo "  2. wm8960-soundcard-i2s3 (AHUB/I2S3) - needs missing daudio driver"
echo "  3. wm8960-simple (mainline sun4i-i2s) <- RECOMMENDED TO TRY"
echo ""
echo "RECOMMENDED TEST:"
echo "Edit /boot/orangepiEnv.txt and change overlay line to:"
echo "  overlays=i2c1-pi wm8960-simple"
echo ""
echo "REBOOT REQUIRED to load the new overlays."
echo ""
echo "After reboot, run:"
echo "  sudo bash scripts/diagnose-h618.sh"
echo ""
