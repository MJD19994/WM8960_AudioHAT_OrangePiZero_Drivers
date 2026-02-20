#!/bin/bash
#
# WM8960 Audio HAT Test Script
#
# Runs diagnostics and interactive audio tests for the WM8960 codec.
# Can be run without arguments for a full interactive session,
# or with --diagnostics-only to skip interactive tests.
#

CARD_NAME="ahub0wm8960"
DEVICE="plughw:${CARD_NAME},0"
SAMPLE_RATE=48000
TEST_FILE="/tmp/wm8960-test-recording.wav"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
fail() { echo -e "  ${RED}FAIL${NC} $1"; }
warn() { echo -e "  ${YELLOW}WARN${NC} $1"; }
info() { echo -e "  ${CYAN}INFO${NC} $1"; }
header() { echo -e "\n${BOLD}=== $1 ===${NC}"; }

DIAG_ONLY=false
ERRORS=0

if [ "$1" = "--diagnostics-only" ] || [ "$1" = "-d" ]; then
    DIAG_ONLY=true
fi

# --- Diagnostics ---

header "WM8960 Audio HAT Diagnostics"

# 1. Check kernel
echo ""
echo "Kernel: $(uname -r)"
if modinfo snd_soc_wm8960 >/dev/null 2>&1; then
    pass "WM8960 kernel module available"
else
    fail "WM8960 kernel module not found"
    ((ERRORS++))
fi

# 2. Check I2C device
# When the WM8960 driver is bound, i2cdetect shows "UU" instead of "1a"
if command -v i2cdetect >/dev/null 2>&1; then
    I2C_OUTPUT=$(i2cdetect -y 2 2>/dev/null || true)
    if echo "$I2C_OUTPUT" | grep -qE "\b(1a|UU)\b" 2>/dev/null; then
        if echo "$I2C_OUTPUT" | grep -q "UU" 2>/dev/null; then
            pass "WM8960 detected on I2C bus 2 at 0x1a (driver bound)"
        else
            pass "WM8960 detected on I2C bus 2 at 0x1a"
        fi
    else
        fail "WM8960 not detected on I2C bus 2"
        ((ERRORS++))
    fi
else
    warn "i2cdetect not available — skipping I2C check"
fi

# 3. Check sound card
CARD_NUM=$(aplay -l 2>/dev/null | grep -i "$CARD_NAME" | head -1 | sed -n 's/^card \([0-9]\+\):.*/\1/p')
if [ -n "$CARD_NUM" ]; then
    pass "Sound card detected: card $CARD_NUM ($CARD_NAME)"
else
    fail "Sound card '$CARD_NAME' not found in aplay -l"
    echo ""
    echo "Available sound cards:"
    aplay -l 2>/dev/null || echo "  (none)"
    ((ERRORS++))
fi

# 4. Check service
if systemctl is-active --quiet wm8960-audio.service 2>/dev/null; then
    pass "wm8960-audio.service is active"
elif systemctl is-enabled --quiet wm8960-audio.service 2>/dev/null; then
    warn "wm8960-audio.service is enabled but not active (may need reboot)"
else
    fail "wm8960-audio.service is not enabled"
    ((ERRORS++))
fi

# 5. Check PLL config script
if [ -x /usr/local/bin/wm8960-pll-config.sh ]; then
    pass "PLL configuration script installed"
else
    fail "PLL configuration script not found at /usr/local/bin/wm8960-pll-config.sh"
    ((ERRORS++))
fi

# 6. Check ALSA config
if [ -f /etc/asound.conf ]; then
    if grep -q "$CARD_NAME" /etc/asound.conf 2>/dev/null; then
        pass "ALSA config present and references $CARD_NAME"
    else
        warn "ALSA config exists but does not reference $CARD_NAME"
    fi
else
    warn "No /etc/asound.conf found — default audio device may not be WM8960"
fi

# 7. Check key mixer controls
if [ -n "$CARD_NUM" ]; then
    PCM_LEFT=$(amixer -c "$CARD_NUM" sget "Left Output Mixer PCM" 2>/dev/null | grep -c "\[on\]")
    PCM_RIGHT=$(amixer -c "$CARD_NUM" sget "Right Output Mixer PCM" 2>/dev/null | grep -c "\[on\]")
    CAPTURE=$(amixer -c "$CARD_NUM" sget "Capture" 2>/dev/null | grep -c "\[on\]")
    BOOST_L=$(amixer -c "$CARD_NUM" sget "Left Input Mixer Boost" 2>/dev/null | grep -c "\[on\]")

    if [ "$PCM_LEFT" -gt 0 ] && [ "$PCM_RIGHT" -gt 0 ]; then
        pass "Playback routing enabled (Output Mixer PCM)"
    else
        fail "Playback routing disabled — run: sudo /usr/local/bin/wm8960-pll-config.sh"
        ((ERRORS++))
    fi

    if [ "$CAPTURE" -gt 0 ] && [ "$BOOST_L" -gt 0 ]; then
        pass "Capture routing enabled (Input Mixer Boost)"
    else
        fail "Capture routing disabled — run: sudo /usr/local/bin/wm8960-pll-config.sh"
        ((ERRORS++))
    fi

    HP_VOL=$(amixer -c "$CARD_NUM" sget "Headphone" 2>/dev/null | grep -oP '\[\d+%\]' | head -1)
    SPK_VOL=$(amixer -c "$CARD_NUM" sget "Speaker" 2>/dev/null | grep -oP '\[\d+%\]' | head -1)
    info "Headphone volume: ${HP_VOL:-unknown}  Speaker volume: ${SPK_VOL:-unknown}"
fi

# 8. Check dmesg for errors
WM8960_ERRORS=$(dmesg 2>/dev/null | grep -i wm8960 | grep -ci "error\|fail" || true)
if [ "$WM8960_ERRORS" -gt 0 ]; then
    warn "Found $WM8960_ERRORS error(s) in dmesg related to WM8960:"
    dmesg 2>/dev/null | grep -i wm8960 | grep -i "error\|fail" | tail -3 | while read -r line; do
        echo "       $line"
    done
else
    pass "No WM8960 errors in dmesg"
fi

# Summary
header "Diagnostics Summary"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
else
    echo -e "${RED}$ERRORS check(s) failed.${NC} See above for details."
fi

# Exit here if diagnostics-only mode
if [ "$DIAG_ONLY" = true ]; then
    exit "$ERRORS"
fi

# Bail out if card not found — interactive tests won't work
if [ -z "$CARD_NUM" ]; then
    echo ""
    echo "Cannot run interactive tests without a working sound card."
    echo "Fix the issues above and try again."
    exit 1
fi

# --- Interactive Tests ---

header "Interactive Audio Tests"
echo ""
echo "The following tests will play sounds and record audio."
echo "Make sure your headphones or speaker are connected."
echo ""

# Test 1: Sine wave
echo -e "${BOLD}[Test 1] Playback — 1kHz Sine Wave${NC}"
echo "  This will play a 1kHz tone for 3 seconds."
read -p "  Press Enter to play (or 's' to skip): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    timeout 3 speaker-test -D "$DEVICE" -c 2 -r "$SAMPLE_RATE" -t sine -f 1000 2>/dev/null || true
    read -p "  Did you hear the tone? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pass "Sine wave playback"
    else
        fail "Sine wave playback — check speaker/headphone connection and volume"
        ((ERRORS++))
    fi
else
    info "Skipped"
fi

# Test 2: Pink noise (left/right)
echo ""
echo -e "${BOLD}[Test 2] Playback — Stereo Channel Test${NC}"
echo "  This will play pink noise alternating between left and right channels."
read -p "  Press Enter to play (or 's' to skip): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    timeout 6 speaker-test -D "$DEVICE" -c 2 -r "$SAMPLE_RATE" -t pink -l 1 2>/dev/null || true
    read -p "  Did you hear sound in both channels? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pass "Stereo playback"
    else
        fail "Stereo playback — one or both channels may not be working"
        ((ERRORS++))
    fi
else
    info "Skipped"
fi

# Test 3: Recording
echo ""
echo -e "${BOLD}[Test 3] Recording — Microphone Test${NC}"
echo "  This will record 5 seconds of audio from the onboard microphones,"
echo "  then play it back so you can hear the result."
read -p "  Press Enter to start recording (or 's' to skip): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "  Recording for 5 seconds... speak into the microphone."
    if timeout 10 arecord -D "$DEVICE" -r "$SAMPLE_RATE" -c 2 -f S16_LE -t wav -d 5 "$TEST_FILE" 2>/dev/null; then
        # Check if recording has any audio content
        FILE_SIZE=$(stat -c%s "$TEST_FILE" 2>/dev/null || echo 0)
        if [ "$FILE_SIZE" -gt 1000 ]; then
            echo "  Recording complete ($FILE_SIZE bytes). Playing back..."
            timeout 10 aplay -D "$DEVICE" "$TEST_FILE" 2>/dev/null || true
            read -p "  Did you hear your recording? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                pass "Microphone recording and playback"
            else
                fail "Recording may have captured silence — check microphone and capture volume"
                ((ERRORS++))
            fi
        else
            fail "Recording file is empty or too small — capture may not be working"
            ((ERRORS++))
        fi
    else
        fail "Recording failed or timed out — capture device may be unavailable"
        ((ERRORS++))
    fi
    rm -f "$TEST_FILE"
else
    info "Skipped"
fi

# Test 4: Different frequencies
echo ""
echo -e "${BOLD}[Test 4] Playback — Frequency Sweep${NC}"
echo "  This will play tones at 440Hz, 1kHz, and 4kHz (2 seconds each)."
read -p "  Press Enter to play (or 's' to skip): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    for freq in 440 1000 4000; do
        echo "  Playing ${freq}Hz..."
        timeout 2 speaker-test -D "$DEVICE" -c 2 -r "$SAMPLE_RATE" -t sine -f "$freq" 2>/dev/null || true
    done
    read -p "  Did you hear all three tones (low, mid, high)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        pass "Frequency sweep playback"
    else
        fail "Some frequencies may not be playing correctly"
        ((ERRORS++))
    fi
else
    info "Skipped"
fi

# Final summary
header "Test Results"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}All tests passed! Your WM8960 Audio HAT is working correctly.${NC}"
else
    echo -e "${RED}$ERRORS test(s) failed.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check service: systemctl status wm8960-audio.service"
    echo "  - Check logs:    journalctl -u wm8960-audio.service"
    echo "  - Re-run config: sudo /usr/local/bin/wm8960-pll-config.sh"
    echo "  - Adjust mixer:  alsamixer -c $CARD_NAME"
fi
echo ""
