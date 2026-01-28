#!/bin/bash
# Check Orange Pi Official Sources
# Run this on a machine with internet access

echo "=== Orange Pi Official Source Investigation ==="
echo ""

# 1. Check Orange Pi downloads page
echo "[1/5] Orange Pi Zero 2W Downloads Page"
echo "URL: http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-2W.html"
echo ""
echo "Look for:"
echo "  - Linux Source Code (tar.gz or zip)"
echo "  - SDK Package"
echo "  - BSP Package"
echo ""
echo "Download any available source packages and extract them"
echo ""

# 2. Check github releases
echo "[2/5] Checking Orange Pi GitHub Releases..."
curl -sL "https://api.github.com/repos/orangepi-xunlong/linux-orangepi/releases" | grep -E "tag_name|zipball_url" | head -20
echo ""

# 3. Check for source branches
echo "[3/5] Checking Orange Pi GitHub Branches..."
curl -sL "https://api.github.com/repos/orangepi-xunlong/linux-orangepi/branches" | grep "\"name\"" | head -20
echo ""

# 4. Check Orange Pi build repository
echo "[4/5] Checking Orange Pi Build Repository..."
echo "Repo: https://github.com/orangepi-xunlong/orangepi-build"
echo "This may contain patches or configuration for building kernels"
echo ""

# 5. Download instructions
echo "[5/5] Download Instructions"
echo ""
echo "If source package is available on Orange Pi website:"
echo "  wget [URL_FROM_WEBSITE]"
echo "  tar -xzf OrangePi_*.tar.gz"
echo "  cd linux-*/sound/soc/"
echo "  find . -name '*daudio*'"
echo "  find . -name '*ahub*'"
echo ""
echo "If downloading from GitHub:"
echo "  # For orange-pi-6.1-sun50iw9 branch (vendor BSP)"
echo "  git clone --depth 1 -b orange-pi-6.1-sun50iw9 https://github.com/orangepi-xunlong/linux-orangepi.git"
echo "  cd linux-orangepi/sound/soc/"
echo "  find . -name '*daudio*'"
echo "  find . -name '*ahub*'"
echo ""

echo "=== Manual Check Required ==="
echo "Visit Orange Pi website and check downloads section for source packages"
