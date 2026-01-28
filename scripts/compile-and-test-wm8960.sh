#!/bin/bash
#
# Compile and install WM8960 overlay for Orange Pi Zero 2W
#

set -e

OVERLAY_DIR="overlays-orangepi"
OVERLAY_NAME="sun50i-h618-wm8960-working"
DTBO_FILE="${OVERLAY_NAME}.dtbo"
INSTALL_PATH="/boot/dtb/allwinner/overlay"
USER_OVERLAYS="/boot/orangepiEnv.txt"

echo "==================================="
echo "WM8960 Overlay Compilation & Install"
echo "==================================="

# Compile the overlay
echo ""
echo "[1/5] Compiling device tree overlay..."
cd "${OVERLAY_DIR}"
dtc -@ -I dts -O dtb -o "${DTBO_FILE}" "${OVERLAY_NAME}.dts"
echo "✓ Compiled: ${DTBO_FILE}"

# Backup existing overlay if present
if [ -f "${INSTALL_PATH}/${DTBO_FILE}" ]; then
    echo ""
    echo "[2/5] Backing up existing overlay..."
    sudo cp "${INSTALL_PATH}/${DTBO_FILE}" "${INSTALL_PATH}/${DTBO_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "✓ Backup created"
fi

# Install the overlay
echo ""
echo "[3/5] Installing overlay to ${INSTALL_PATH}..."
sudo cp "${DTBO_FILE}" "${INSTALL_PATH}/"
echo "✓ Installed: ${INSTALL_PATH}/${DTBO_FILE}"

# Check if overlay is already configured
echo ""
echo "[4/5] Checking orangepiEnv.txt configuration..."
if grep -q "overlays=${OVERLAY_NAME}" "${USER_OVERLAYS}" 2>/dev/null; then
    echo "✓ Overlay already configured in orangepiEnv.txt"
elif grep -q "^overlays=" "${USER_OVERLAYS}" 2>/dev/null; then
    echo "⚠ Adding ${OVERLAY_NAME} to existing overlays line..."
    sudo sed -i "s/^overlays=\(.*\)/overlays=\1 ${OVERLAY_NAME}/" "${USER_OVERLAYS}"
    echo "✓ Updated overlays line"
else
    echo "Adding overlays line to orangepiEnv.txt..."
    echo "overlays=${OVERLAY_NAME}" | sudo tee -a "${USER_OVERLAYS}"
    echo "✓ Added overlays configuration"
fi

echo ""
echo "[5/5] Verifying installation..."
ls -lh "${INSTALL_PATH}/${DTBO_FILE}"

echo ""
echo "==================================="
echo "✓ Installation Complete!"
echo "==================================="
echo ""
echo "NEXT STEPS:"
echo "1. Reboot the system: sudo reboot"
echo "2. After reboot, verify I2S0 device: aplay -l"
echo "3. Check WM8960 detection: i2cdetect -y 2"
echo "4. Check sound cards: cat /proc/asound/cards"
echo ""
echo "If successful, you should see:"
echo "  - ahub0wm8960 sound card"
echo "  - WM8960 at I2C address 0x1a"
echo ""
