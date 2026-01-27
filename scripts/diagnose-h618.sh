#!/bin/bash
#
# H618 Audio System Diagnostic Script
# For Orange Pi Zero 2W with WM8960 HAT
#
# This script checks the actual device tree structure and audio configuration
# to help identify issues with the WM8960 driver installation.
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   H618 Audio System Diagnostic for WM8960 HAT             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# 1. Check I2C Detection
echo -e "${BLUE}=== I2C Detection ===${NC}"
echo "Checking I2C bus 3 for WM8960 at address 0x1a:"
i2cdetect -y 3 2>/dev/null || echo "Cannot scan I2C bus 3"
echo

# 2. Check Device Tree Structure
echo -e "${BLUE}=== Device Tree Structure ===${NC}"
echo "Checking actual device tree paths..."

echo -n "SoC base path: "
if [ -d "/sys/firmware/devicetree/base/soc@3000000" ]; then
    echo -e "${GREEN}/soc@3000000${NC}"
elif [ -d "/sys/firmware/devicetree/base/soc" ]; then
    echo -e "${GREEN}/soc${NC}"
else
    echo -e "${RED}Not found${NC}"
fi

echo -n "Pinctrl path: "
if [ -d "/sys/firmware/devicetree/base/soc@3000000/pinctrl@300b000" ]; then
    echo -e "${GREEN}/soc@3000000/pinctrl@300b000${NC}"
elif [ -d "/sys/firmware/devicetree/base/soc/pinctrl@300b000" ]; then
    echo -e "${GREEN}/soc/pinctrl@300b000${NC}"
else
    echo -e "${RED}Not found${NC}"
fi

echo -n "I2C1 path: "
if [ -d "/sys/firmware/devicetree/base/soc@3000000/i2c@5002400" ]; then
    echo -e "${GREEN}/soc@3000000/i2c@5002400${NC}"
elif [ -d "/sys/firmware/devicetree/base/soc/i2c@5002400" ]; then
    echo -e "${GREEN}/soc/i2c@5002400${NC}"
else
    echo -e "${RED}Not found${NC}"
fi
echo

# 3. Check I2S/AHUB Nodes
echo -e "${BLUE}=== I2S/AHUB Nodes ===${NC}"
echo "Looking for I2S and AHUB nodes..."

echo "Simple I2S nodes:"
ls /sys/firmware/devicetree/base/soc*/i2s* 2>/dev/null | sed 's|^|  |' || echo "  None found"

echo "AHUB I2S nodes:"
ls -d /sys/firmware/devicetree/base/soc*/ahub-i2s* 2>/dev/null | sed 's|^|  |' || echo "  None found"

echo "Audio Hub (AHUB) nodes:"
ls -d /sys/firmware/devicetree/base/soc*/ahub* 2>/dev/null | grep -v i2s | sed 's|^|  |' || echo "  None found"
echo

# 4. Check Pinctrl Definitions
echo -e "${BLUE}=== Pinctrl I2S Pin Definitions ===${NC}"
echo "Existing I2S pin definitions:"
ls /sys/firmware/devicetree/base/soc*/pinctrl*/i2s* 2>/dev/null | sed 's|^|  |' || echo "  None found"
echo

# 5. Check Pin Status
echo -e "${BLUE}=== Pin Status (PI0-PI8) ===${NC}"
if [ -f "/sys/kernel/debug/pinctrl/300b000.pinctrl/pinmux-pins" ]; then
    echo "Pin functions for PI port (pins 256-264):"
    for i in {0..8}; do
        pin=$((256 + i))
        status=$(grep "pin $pin" /sys/kernel/debug/pinctrl/300b000.pinctrl/pinmux-pins 2>/dev/null || echo "pin $pin (PI$i): NOT FOUND")
        echo "  $status"
    done
else
    echo "  Pinmux debug info not available"
    echo "  (Enable CONFIG_DEBUG_FS and mount debugfs)"
fi
echo

# 6. Check Loaded Modules
echo -e "${BLUE}=== Loaded Audio Modules ===${NC}"
lsmod | grep -E "snd_soc|wm8960|simple|ahub" | sed 's/^/  /' || echo "  No audio modules loaded"
echo

# 7. Check Sound Cards
echo -e "${BLUE}=== Sound Cards ===${NC}"
if [ -f /proc/asound/cards ]; then
    cat /proc/asound/cards | sed 's/^/  /'
else
    echo "  No sound cards found"
fi
echo

# 8. Check for WM8960 in Device Tree
echo -e "${BLUE}=== WM8960 in Device Tree ===${NC}"
wm8960_nodes=$(find /sys/firmware/devicetree/base -name "*wm8960*" 2>/dev/null)
if [ -n "$wm8960_nodes" ]; then
    echo -e "${GREEN}WM8960 nodes found:${NC}"
    echo "$wm8960_nodes" | sed 's/^/  /'
else
    echo -e "${RED}No WM8960 nodes in device tree${NC}"
    echo "  This means the overlay did not load correctly"
fi
echo

# 9. Check for Sound Nodes
echo -e "${BLUE}=== Sound Card Nodes ===${NC}"
sound_nodes=$(find /sys/firmware/devicetree/base -name "*sound*" -type d 2>/dev/null | head -5)
if [ -n "$sound_nodes" ]; then
    echo "Sound nodes found:"
    echo "$sound_nodes" | sed 's/^/  /'
else
    echo "  No sound nodes found"
fi
echo

# 10. Check Kernel Messages
echo -e "${BLUE}=== Recent Kernel Messages ===${NC}"
echo "WM8960 messages:"
dmesg | grep -i wm8960 | tail -10 | sed 's/^/  /' || echo "  No WM8960 messages"
echo
echo "I2S/AHUB messages:"
dmesg | grep -iE "i2s|ahub|daudio" | tail -10 | sed 's/^/  /' || echo "  No I2S/AHUB messages"
echo
echo "Simple audio card messages:"
dmesg | grep -i "simple.*audio\|asoc.*simple" | tail -10 | sed 's/^/  /' || echo "  No simple-audio-card messages"
echo

# 11. Check Boot Configuration
echo -e "${BLUE}=== Boot Configuration ===${NC}"
echo "Checking overlay configuration..."
if [ -f "/boot/armbianEnv.txt" ]; then
    echo "Overlays in /boot/armbianEnv.txt:"
    grep "overlay" /boot/armbianEnv.txt | sed 's/^/  /'
elif [ -f "/boot/dietpiEnv.txt" ]; then
    echo "Overlays in /boot/dietpiEnv.txt:"
    grep "overlay" /boot/dietpiEnv.txt | sed 's/^/  /'
else
    echo "  Boot config file not found"
fi
echo

# 12. Check Overlay Files
echo -e "${BLUE}=== Installed Overlay Files ===${NC}"
echo "Checking for WM8960 overlay files..."
for dir in /boot/dtb/allwinner/overlay /boot/overlay-user /boot/dtbs/allwinner/overlay; do
    if [ -d "$dir" ]; then
        echo "In $dir:"
        ls -lh "$dir"/*wm8960* 2>/dev/null | sed 's/^/  /' || echo "  No WM8960 overlays found"
    fi
done
echo

# Summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     Summary                                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Check critical items
i2c_ok=false
dt_ok=false
module_ok=false
card_ok=false

if i2cdetect -y 3 2>/dev/null | grep -q "1a"; then
    i2c_ok=true
fi

if find /sys/firmware/devicetree/base -name "*wm8960*" 2>/dev/null | grep -q .; then
    dt_ok=true
fi

if lsmod | grep -q "snd_soc_wm8960"; then
    module_ok=true
fi

if [ -f /proc/asound/cards ] && grep -qi "wm8960\|soundcard" /proc/asound/cards; then
    card_ok=true
fi

echo -n "I2C Detection (0x1a on bus 3): "
[ "$i2c_ok" = true ] && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ FAILED${NC}"

echo -n "WM8960 Kernel Module:          "
[ "$module_ok" = true ] && echo -e "${GREEN}✓ Loaded${NC}" || echo -e "${RED}✗ Not loaded${NC}"

echo -n "Device Tree Overlay:           "
[ "$dt_ok" = true ] && echo -e "${GREEN}✓ Loaded${NC}" || echo -e "${RED}✗ Not loaded${NC}"

echo -n "Sound Card Registration:       "
[ "$card_ok" = true ] && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ Not created${NC}"

echo
if [ "$i2c_ok" = true ] && [ "$module_ok" = true ] && [ "$dt_ok" = false ]; then
    echo -e "${YELLOW}Issue: WM8960 detected on I2C and module loaded, but overlay not in device tree${NC}"
    echo "  → This indicates the device tree overlay is not loading correctly"
    echo "  → Check the target paths in the overlay DTS file"
elif [ "$i2c_ok" = true ] && [ "$module_ok" = true ] && [ "$dt_ok" = true ] && [ "$card_ok" = false ]; then
    echo -e "${YELLOW}Issue: Everything loaded but sound card not created${NC}"
    echo "  → Check dmesg for errors in sound card initialization"
    echo "  → Verify I2S/AHUB node configuration"
fi

echo
echo "This diagnostic information should be shared when asking for help."
echo
