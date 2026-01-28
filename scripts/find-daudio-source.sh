#!/bin/bash
#
# Quick script to find DAUDIO driver source code
# This will clone orangepi-build and search for the driver
#

set -e

WORKDIR="/tmp/orangepi-source-check"
RESULTS_FILE="/workspaces/WM8960_AudioHAT_OrangePiZero_Drivers/DAUDIO_SOURCE_SEARCH_RESULTS.txt"

echo "=========================================="
echo "DAUDIO Driver Source Code Search"
echo "=========================================="
echo ""
echo "This will:"
echo "1. Clone orangepi-build repository"
echo "2. Let it download kernel source (or check cache)"
echo "3. Search for DAUDIO driver files"
echo ""
echo "Working directory: $WORKDIR"
echo "Results will be saved to: $RESULTS_FILE"
echo ""

# Create working directory
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Initialize results file
cat > "$RESULTS_FILE" << 'EOF'
# DAUDIO Driver Source Code Search Results
# Generated: $(date)
# Search Location: Orange Pi Build System

========================================
SEARCH SUMMARY
========================================

EOF

echo "[1/5] Cloning orangepi-build repository..."
if [ ! -d "orangepi-build" ]; then
    git clone --depth=1 https://github.com/orangepi-xunlong/orangepi-build.git
    echo "✓ Repository cloned"
else
    echo "✓ Repository already exists"
fi

cd orangepi-build

echo ""
echo "[2/5] Checking for cached kernel sources..."
KERNEL_CACHE_DIRS=$(find . -type d -path "*/cache/sources/linux-*" 2>/dev/null || true)

if [ -z "$KERNEL_CACHE_DIRS" ]; then
    echo "⚠ No cached kernel sources found"
    echo ""
    echo "NOTE: The build system downloads kernel source when you run:"
    echo "  sudo ./build.sh"
    echo ""
    echo "However, we can still check the build scripts for kernel source URLs..."
    echo ""
    
    # Search build scripts for kernel source URLs
    echo "[3/5] Searching build scripts for kernel source locations..."
    {
        echo ""
        echo "KERNEL SOURCE REFERENCES IN BUILD SCRIPTS:"
        echo "=========================================="
        grep -r "KERNELSOURCE\|kernel.*source\|linux-.*tar" config/ scripts/ 2>/dev/null | head -20 || echo "None found"
        echo ""
    } | tee -a "$RESULTS_FILE"
    
    KERNEL_SOURCE_FOUND="NO - Need to run build system"
else
    echo "✓ Found cached kernel sources:"
    echo "$KERNEL_CACHE_DIRS"
    
    echo ""
    echo "[3/5] Searching for DAUDIO driver in kernel source..."
    
    # Search for DAUDIO files
    DAUDIO_FILES=$(find $KERNEL_CACHE_DIRS -type f -name "*daudio*" 2>/dev/null || true)
    
    {
        echo ""
        echo "SEARCH LOCATION: $KERNEL_CACHE_DIRS"
        echo ""
        echo "DAUDIO FILES FOUND:"
        echo "=========================================="
        if [ -z "$DAUDIO_FILES" ]; then
            echo "❌ NO DAUDIO FILES FOUND"
        else
            echo "✅ DAUDIO FILES FOUND:"
            echo "$DAUDIO_FILES"
        fi
        echo ""
    } | tee -a "$RESULTS_FILE"
    
    # Search in sound/soc directories
    echo "[4/5] Searching sound/soc/sunxi directories..."
    {
        echo "SUNXI SOUND DRIVER DIRECTORIES:"
        echo "=========================================="
        find $KERNEL_CACHE_DIRS -type d -path "*/sound/soc/sunxi*" 2>/dev/null || echo "None found"
        echo ""
    } | tee -a "$RESULTS_FILE"
    
    # List all files in sunxi sound directories
    SUNXI_SOUND_DIRS=$(find $KERNEL_CACHE_DIRS -type d -path "*/sound/soc/sunxi*" 2>/dev/null)
    if [ ! -z "$SUNXI_SOUND_DIRS" ]; then
        {
            echo "FILES IN SUNXI SOUND DIRECTORIES:"
            echo "=========================================="
            for dir in $SUNXI_SOUND_DIRS; do
                echo ""
                echo "Directory: $dir"
                ls -lh "$dir" 2>/dev/null | grep -E "\.(c|h|ko)$" || echo "  No source files found"
            done
            echo ""
        } | tee -a "$RESULTS_FILE"
    fi
    
    # Check kernel config
    echo "[5/5] Checking kernel configuration..."
    CONFIG_FILES=$(find $KERNEL_CACHE_DIRS -name ".config" -o -name "defconfig" 2>/dev/null)
    if [ ! -z "$CONFIG_FILES" ]; then
        {
            echo "KERNEL AUDIO CONFIG OPTIONS:"
            echo "=========================================="
            for config in $CONFIG_FILES; do
                echo ""
                echo "Config file: $config"
                grep -i "CONFIG_SND_SOC.*AHUB\|CONFIG_SND_SOC.*DAUDIO" "$config" 2>/dev/null || echo "  No AHUB/DAUDIO config options found"
            done
            echo ""
        } | tee -a "$RESULTS_FILE"
    fi
    
    if [ -z "$DAUDIO_FILES" ]; then
        KERNEL_SOURCE_FOUND="NO"
    else
        KERNEL_SOURCE_FOUND="YES"
    fi
fi

# Final summary
echo ""
echo "=========================================="
echo "FINAL VERDICT"
echo "=========================================="

{
    echo ""
    echo "=========================================="
    echo "FINAL VERDICT"
    echo "=========================================="
    echo ""
    if [ "$KERNEL_SOURCE_FOUND" = "YES" ]; then
        echo "✅ DAUDIO DRIVER SOURCE CODE EXISTS!"
        echo ""
        echo "Files found:"
        echo "$DAUDIO_FILES"
        echo ""
        echo "NEXT STEPS:"
        echo "1. Examine the source code"
        echo "2. Compile the driver module"
        echo "3. Modify device tree to add I2S nodes"
        echo "4. Install and test"
    elif [ "$KERNEL_SOURCE_FOUND" = "NO" ]; then
        echo "❌ DAUDIO DRIVER SOURCE CODE NOT FOUND"
        echo ""
        echo "NEXT STEPS:"
        echo "1. Post to Orange Pi forums asking for DAUDIO driver"
        echo "2. Check Google Drive for SDK packages"
        echo "3. Consider alternative hardware:"
        echo "   - Radxa Zero 2/3 (verify I2S support)"
        echo "   - USB audio adapter"
    else
        echo "⚠ NEED TO RUN BUILD SYSTEM"
        echo ""
        echo "Kernel source not downloaded yet. Run:"
        echo "  cd $WORKDIR/orangepi-build"
        echo "  sudo ./build.sh"
        echo ""
        echo "Select: orangepizero2w (or orangepizero2)"
        echo "Then run this script again."
    fi
    echo ""
    echo "Full results saved to:"
    echo "$RESULTS_FILE"
    echo ""
} | tee -a "$RESULTS_FILE"

# Quick GitHub API check
echo ""
echo "=========================================="
echo "BONUS: Checking Allwinner GitHub"
echo "=========================================="
{
    echo ""
    echo "GITHUB API CHECK:"
    echo "=========================================="
    echo "Searching Allwinner repositories for DAUDIO..."
    
    # Search Allwinner org
    curl -s "https://api.github.com/search/code?q=daudio+org:allwinner-zh+language:c" | \
        jq -r '.items[]? | "\(.repository.full_name): \(.path)"' 2>/dev/null || echo "No results or API rate limited"
    
    echo ""
    echo "Searching Orange Pi org for DAUDIO..."
    curl -s "https://api.github.com/search/code?q=daudio+org:orangepi-xunlong+language:c" | \
        jq -r '.items[]? | "\(.repository.full_name): \(.path)"' 2>/dev/null || echo "No results or API rate limited"
    echo ""
} | tee -a "$RESULTS_FILE"

echo ""
echo "=========================================="
echo "Search complete!"
echo "Results saved to: $RESULTS_FILE"
echo "=========================================="
