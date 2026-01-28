#!/bin/bash
# Search Armbian Build Repository for DAUDIO patches
# Run on a machine with internet/git

echo "=== Searching Armbian Build Repository ==="
echo ""

# Clone repository
if [ ! -d "armbian-build" ]; then
    echo "[1/4] Cloning Armbian build repository..."
    git clone --depth 1 https://github.com/armbian/build.git armbian-build
    cd armbian-build
else
    echo "[1/4] Using existing armbian-build directory..."
    cd armbian-build
    git pull
fi

echo ""
echo "[2/4] Searching for DAUDIO-related patches..."
find patch/ -name "*.patch" -exec grep -l "daudio\|DAUDIO" {} \; 2>/dev/null

echo ""
echo "[3/4] Searching for AHUB I2S patches..."
find patch/ -name "*.patch" -exec grep -l "ahub.*i2s\|i2s.*ahub" {} \; 2>/dev/null

echo ""
echo "[4/4] Checking H618/sun50iw9 specific configurations..."

# Check board config for Orange Pi Zero 2W
if [ -f "config/boards/orangepizero2w.conf" ]; then
    echo "Board config found:"
    cat config/boards/orangepizero2w.conf
fi

if [ -f "config/boards/orangepizero2w.csc" ]; then
    echo ""
    echo "Board CSC found:"
    cat config/boards/orangepizero2w.csc
fi

echo ""
echo "[BONUS] Checking for audio-related patches in sunxi current kernel:"
ls -la patch/kernel/archive/sunxi-*/series 2>/dev/null | head
find patch/kernel/sunxi-current/ -name "*.patch" 2>/dev/null | xargs grep -l "audio\|sound\|i2s" 2>/dev/null | head -20

cd ..
echo ""
echo "=== Search Complete ==="
