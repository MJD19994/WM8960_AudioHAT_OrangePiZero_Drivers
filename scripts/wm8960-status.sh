#!/bin/bash
#
# WM8960 Audio HAT Status Check Script
# for Orange Pi Zero 2W
#
# Copyright (C) 2025
# License: MIT
#

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

check_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "  ${RED}✗${NC} $1"
}

check_warn() {
    echo -e "  ${YELLOW}!${NC} $1"
}

echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          WM8960 Audio HAT Status Check                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# 1. System Information
print_section "System Information"
echo "  Hostname:      $(hostname)"
echo "  Kernel:        $(uname -r)"
echo "  Architecture:  $(uname -m)"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  Distribution:  ${PRETTY_NAME:-Unknown}"
fi
echo

# 2. Check I2C
print_section "I2C Bus Status"
WM8960_FOUND=false
I2C_BUS=""

for bus in 0 1 2 3 4 5; do
    if [ -e "/dev/i2c-${bus}" ]; then
        check_pass "I2C bus ${bus} exists (/dev/i2c-${bus})"
        
        # Check for WM8960 at address 0x1a
        if command -v i2cdetect &> /dev/null; then
            if i2cdetect -y ${bus} 2>/dev/null | grep -q "1a"; then
                check_pass "WM8960 codec found at 0x1a on bus ${bus}"
                WM8960_FOUND=true
                I2C_BUS=$bus
            fi
        fi
    fi
done

if [ "$WM8960_FOUND" = false ]; then
    check_fail "WM8960 codec not detected on any I2C bus"
    echo "        Ensure the HAT is properly connected and I2C is enabled"
fi
echo

# 3. Check kernel modules
print_section "Kernel Modules"
MODULES=("snd_soc_core" "snd_soc_wm8960" "snd_soc_simple_card")

for mod in "${MODULES[@]}"; do
    if lsmod | grep -q "${mod//-/_}"; then
        check_pass "Module ${mod} loaded"
    else
        # Check if built into kernel
        if [ -f "/lib/modules/$(uname -r)/modules.builtin" ]; then
            if grep -q "${mod}" "/lib/modules/$(uname -r)/modules.builtin" 2>/dev/null; then
                check_pass "Module ${mod} built-in"
            else
                check_warn "Module ${mod} not loaded"
            fi
        else
            check_warn "Module ${mod} not loaded"
        fi
    fi
done
echo

# 4. Check sound cards
print_section "Sound Cards"
if [ -f /proc/asound/cards ]; then
    CARDS=$(cat /proc/asound/cards)
    if echo "$CARDS" | grep -qi "wm8960"; then
        check_pass "WM8960 sound card registered"
        echo "$CARDS" | sed 's/^/        /'
    else
        check_fail "WM8960 sound card not found"
        if [ -n "$CARDS" ]; then
            echo "  Available cards:"
            echo "$CARDS" | sed 's/^/        /'
        fi
    fi
else
    check_fail "No sound cards found (/proc/asound/cards missing)"
fi
echo

# 5. Check playback devices
print_section "Playback Devices"
if command -v aplay &> /dev/null; then
    PLAYBACK=$(aplay -l 2>&1)
    if echo "$PLAYBACK" | grep -qi "wm8960\|soundcard"; then
        check_pass "Playback device available"
        echo "$PLAYBACK" | grep -i "card\|wm8960\|soundcard" | sed 's/^/        /'
    elif echo "$PLAYBACK" | grep -q "no soundcards"; then
        check_fail "No playback devices found"
    else
        check_warn "WM8960 playback not found, other devices available"
        echo "$PLAYBACK" | head -5 | sed 's/^/        /'
    fi
else
    check_warn "aplay command not found - install alsa-utils"
fi
echo

# 6. Check capture devices
print_section "Capture Devices"
if command -v arecord &> /dev/null; then
    CAPTURE=$(arecord -l 2>&1)
    if echo "$CAPTURE" | grep -qi "wm8960\|soundcard"; then
        check_pass "Capture device available"
        echo "$CAPTURE" | grep -i "card\|wm8960\|soundcard" | sed 's/^/        /'
    elif echo "$CAPTURE" | grep -q "no soundcards"; then
        check_fail "No capture devices found"
    else
        check_warn "WM8960 capture not found, other devices available"
    fi
else
    check_warn "arecord command not found - install alsa-utils"
fi
echo

# 7. Check device tree
print_section "Device Tree Status"
DT_WM8960=$(find /proc/device-tree -name "*wm8960*" 2>/dev/null | head -1)
DT_SOUND=$(find /proc/device-tree -name "*sound*" -type d 2>/dev/null | head -3)

if [ -n "$DT_WM8960" ]; then
    check_pass "WM8960 found in device tree"
    echo "        Path: ${DT_WM8960}"
else
    check_fail "WM8960 not found in device tree"
    echo "        The overlay may not be loaded correctly"
fi

if [ -n "$DT_SOUND" ]; then
    echo "  Sound nodes:"
    echo "$DT_SOUND" | sed 's/^/        /'
fi
echo

# 8. Check DMESG
print_section "Recent Kernel Messages (WM8960)"
DMESG_WM=$(dmesg 2>/dev/null | grep -i wm8960 | tail -5)
if [ -n "$DMESG_WM" ]; then
    printf '%s\n' "$DMESG_WM" | sed 's/^/  /'
else
    check_warn "No WM8960 messages in dmesg"
fi
echo

# 9. ALSA Configuration
print_section "ALSA Configuration"
if [ -f /etc/asound.conf ]; then
    check_pass "/etc/asound.conf exists"
    if grep -q "wm8960" /etc/asound.conf; then
        check_pass "WM8960 configured in asound.conf"
    fi
else
    check_warn "/etc/asound.conf not found (optional)"
fi
echo

# 10. Summary
print_section "Summary"
if [ "$WM8960_FOUND" = true ] && [ -f /proc/asound/cards ] && grep -qi "wm8960" /proc/asound/cards; then
    echo -e "  ${GREEN}✓ WM8960 Audio HAT appears to be working!${NC}"
    echo
    echo "  Test commands:"
    echo "    Playback:  speaker-test -c 2 -t wav"
    echo "    Record:    arecord -D plughw:wm8960soundcard -f cd -d 5 test.wav"
    echo "    Play back: aplay test.wav"
    echo "    Mixer:     alsamixer"
else
    echo -e "  ${RED}✗ WM8960 Audio HAT is not working correctly${NC}"
    echo
    echo "  Troubleshooting steps:"
    echo "    1. Check physical connection of the HAT"
    echo "    2. Verify the overlay is enabled in your boot config"
    echo "    3. Try rebooting the system"
    echo "    4. Check dmesg for errors: dmesg | grep -i wm8960"
    echo "    5. Try the alternative overlay (i2s3 version)"
fi
echo
