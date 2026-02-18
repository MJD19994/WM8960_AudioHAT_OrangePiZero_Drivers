#!/bin/bash
#
# WM8960 PLL Configuration Script
# Configures the WM8960 codec PLL for proper audio clock generation
#
# This script is necessary because the Orange Pi kernel's WM8960 driver
# does not configure the PLL in slave mode. We manually configure the PLL
# to generate 12.288MHz SYSCLK from the onboard 24MHz crystal for 48kHz audio.
#

set -e

I2C_BUS=2
WM8960_ADDR=0x1a
DRIVER_PATH="/sys/bus/i2c/drivers/wm8960"

# Build device identifier (e.g., "$DEVICE_ID" from I2C_BUS=2 and WM8960_ADDR=0x1a)
# Allow override via environment variable
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="${I2C_BUS}-$(printf '%04x' $((WM8960_ADDR)))"
fi

# Register addresses
CLOCK1=0x04
POWER2=0x1a
PLL1=0x34
PLL2=0x35
PLL3=0x36
PLL4=0x37

# PLL values for 24MHz -> 12.288MHz
# Calculated for 48kHz audio support
PRE_DIV=1
N=4
K=0x189375

log() {
    echo "[WM8960-PLL] $1"
}

wait_for_device() {
    local max_wait=10
    local count=0

    while [ ! -e "$DRIVER_PATH/$DEVICE_ID" ] && [ $count -lt $max_wait ]; do
        sleep 1
        ((count++))
    done

    if [ ! -e "$DRIVER_PATH/$DEVICE_ID" ]; then
        log "ERROR: WM8960 device not found after ${max_wait}s"
        exit 1
    fi
}

configure_pll() {
    log "Configuring WM8960 PLL..."

    # Build PLL register values
    PLL1_VAL=$((0x20 | (PRE_DIV << 4) | N))
    K_HIGH=$(((K >> 16) & 0xFF))
    K_MID=$(((K >> 8) & 0xFF))
    K_LOW=$((K & 0xFF))

    log "PLL Config: PRE_DIV=$PRE_DIV, N=$N, K=$K"
    log "PLL1=0x$(printf '%02x' $PLL1_VAL), PLL2=0x$(printf '%02x' $K_HIGH), PLL3=0x$(printf '%02x' $K_MID), PLL4=0x$(printf '%02x' $K_LOW)"

    # Unbind driver to access I2C directly
    log "Temporarily unbinding driver..."
    echo "$DEVICE_ID" > "$DRIVER_PATH/unbind" 2>/dev/null || true
    sleep 0.2

    # Configure PLL registers
    i2cset -y $I2C_BUS $WM8960_ADDR $CLOCK1 0x00 || { log "ERROR: Failed to write CLOCK1"; exit 1; }
    i2cset -y $I2C_BUS $WM8960_ADDR $POWER2 0x00 || { log "ERROR: Failed to write POWER2"; exit 1; }
    i2cset -y $I2C_BUS $WM8960_ADDR $PLL1 $PLL1_VAL || { log "ERROR: Failed to write PLL1"; exit 1; }
    i2cset -y $I2C_BUS $WM8960_ADDR $PLL2 $K_HIGH || { log "ERROR: Failed to write PLL2"; exit 1; }
    i2cset -y $I2C_BUS $WM8960_ADDR $PLL3 $K_MID || { log "ERROR: Failed to write PLL3"; exit 1; }
    i2cset -y $I2C_BUS $WM8960_ADDR $PLL4 $K_LOW || { log "ERROR: Failed to write PLL4"; exit 1; }

    # Enable PLL
    log "Enabling PLL..."
    i2cset -y $I2C_BUS $WM8960_ADDR $POWER2 0x01 || { log "ERROR: Failed to enable PLL power"; exit 1; }
    sleep 0.25

    # Switch SYSCLK to PLL
    i2cset -y $I2C_BUS $WM8960_ADDR $CLOCK1 0x01 || { log "ERROR: Failed to set SYSCLK source"; exit 1; }

    # Rebind driver
    log "Rebinding driver..."
    echo "$DEVICE_ID" > "$DRIVER_PATH/bind" || { log "ERROR: Failed to rebind driver"; exit 1; }
    sleep 1

    log "PLL configuration complete!"
}

configure_mixer() {
    log "Configuring mixer settings..."

    # Detect WM8960 card number (allow override via environment variable)
    local CARD_NUM
    if [ -n "$WM8960_CARD" ]; then
        CARD_NUM="$WM8960_CARD"
        log "Using WM8960_CARD from environment: $CARD_NUM"
    else
        # Parse aplay -l to find WM8960 card
        CARD_NUM=$(aplay -l 2>/dev/null | grep -i "wm8960\|ahub0wm8960" | head -1 | sed -n 's/^card \([0-9]\+\):.*/\1/p')

        if [ -z "$CARD_NUM" ]; then
            log "ERROR: Could not detect WM8960 sound card. Set WM8960_CARD environment variable or check if device is present."
            return 1
        fi

        log "Detected WM8960 card: $CARD_NUM"
    fi

    # Configure playback routing and volumes
    amixer -c "$CARD_NUM" sset "Left Output Mixer PCM" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Output Mixer PCM" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Headphone" 121 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Speaker" 121 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Speaker AC" 0 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Speaker DC" 0 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Mono Output Mixer Left" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Mono Output Mixer Right" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Playback" 255 >/dev/null 2>&1

    # Configure capture/recording settings
    # Enable input signal path: LINPUT1/RINPUT1 -> Boost Mixer -> Input Mixer -> ADC
    amixer -c "$CARD_NUM" sset "Left Input Mixer Boost" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Input Mixer Boost" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Left Boost Mixer LINPUT1" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Boost Mixer RINPUT1" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Capture" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Capture" 45 >/dev/null 2>&1
    amixer -c "$CARD_NUM" cset numid=37 210,210 >/dev/null 2>&1  # ADC PCM Capture Volume
    amixer -c "$CARD_NUM" cset numid=10 2 >/dev/null 2>&1         # Left Input Boost LINPUT1 Volume
    amixer -c "$CARD_NUM" cset numid=9 2 >/dev/null 2>&1          # Right Input Boost RINPUT1 Volume

    log "Mixer configured!"
}

# Main execution
log "Starting WM8960 audio configuration..."

# Wait for device to be available
wait_for_device

# Configure PLL
configure_pll

# Configure mixer
configure_mixer

log "WM8960 audio configuration complete! Audio is ready."
exit 0
