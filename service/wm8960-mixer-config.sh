#!/bin/bash
#
# WM8960 Audio HAT Configuration Script
# Configures the WM8960 codec PLL (Orange Pi OS only) and mixer settings.
#
# On Orange Pi OS (vendor BSP kernel), the machine driver does not call the
# ASoC clock APIs on the codec, so we must configure the PLL via i2cset before
# audio will work. On Armbian (mainline kernel), the DKMS driver handles PLL
# internally and PLL configuration is skipped.
#
# On first boot (no saved state), applies factory defaults for playback routing,
# volume levels, and capture settings. On subsequent boots, restores the user's
# saved mixer state via alsactl. Use --reset-defaults to force factory defaults.
#

set -e

# Parse command-line options
RESET_DEFAULTS=false
VERBOSE=false
for arg in "$@"; do
    case "$arg" in
        --reset-defaults)
            RESET_DEFAULTS=true
            ;;
        --verbose|-v)
            VERBOSE=true
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --reset-defaults  Force-apply factory mixer defaults, replacing any"
            echo "                    custom settings saved with 'alsactl store'"
            echo "  --verbose, -v     Show detailed step-by-step output for troubleshooting"
            echo "  --help, -h        Show this help message"
            exit 0
            ;;
    esac
done

WM8960_ADDR=0x1a
DRIVER_PATH="/sys/bus/i2c/drivers/wm8960"

# Auto-detect I2C bus from sysfs (bus number varies: 2 on Orange Pi OS, 3 on Armbian)
if [ -z "$I2C_BUS" ]; then
    I2C_BUS=$(find /sys/bus/i2c/devices/ -maxdepth 1 -name '*-001a' 2>/dev/null \
              | head -1 | sed -n 's|.*/\([0-9]*\)-001a$|\1|p' || true)
    if [ -z "$I2C_BUS" ]; then
        I2C_BUS=2  # fallback for Orange Pi OS default
    fi
fi

# Build device identifier (e.g., "2-001a")
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="${I2C_BUS}-$(printf '%04x' $((WM8960_ADDR)))"
fi

log() {
    echo "[WM8960] $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo "[WM8960] [DEBUG] $1"
    fi
}

# Detect OS: Armbian vs Orange Pi OS
# On Armbian, the DKMS driver handles PLL configuration internally.
# On Orange Pi OS, the vendor BSP machine driver doesn't call the ASoC
# clock APIs, so we must configure PLL via i2cset.
is_armbian() {
    [ -f /etc/armbian-release ]
}

wait_for_device() {
    local max_wait=10
    local count=0

    log_debug "Waiting for device at $DRIVER_PATH/$DEVICE_ID"
    while [ ! -e "$DRIVER_PATH/$DEVICE_ID" ] && [ $count -lt $max_wait ]; do
        log_debug "Device not ready, waiting... (${count}/${max_wait}s)"
        sleep 1
        count=$((count + 1))
    done

    if [ ! -e "$DRIVER_PATH/$DEVICE_ID" ]; then
        log "ERROR: WM8960 device not found after ${max_wait}s"
        log "Check that the WM8960 is connected to I2C bus $I2C_BUS at address $WM8960_ADDR"
        exit 1
    fi
    log_debug "Device found after ${count}s"
}

configure_pll() {
    log "Configuring WM8960 PLL (Orange Pi OS)..."

    # PLL values for 24MHz -> 12.288MHz SYSCLK (48kHz audio)
    local PRE_DIV=1
    local N=4
    local K=0x189375

    local PLL1_VAL=$((0x20 | (PRE_DIV << 4) | N))
    local K_HIGH=$(((K >> 16) & 0xFF))
    local K_MID=$(((K >> 8) & 0xFF))
    local K_LOW=$((K & 0xFF))

    log_debug "PLL Config: PRE_DIV=$PRE_DIV, N=$N, K=$K"
    log_debug "PLL1=0x$(printf '%02x' $PLL1_VAL), PLL2=0x$(printf '%02x' $K_HIGH), PLL3=0x$(printf '%02x' $K_MID), PLL4=0x$(printf '%02x' $K_LOW)"

    # Unbind driver to access I2C directly
    log "Temporarily unbinding driver..."
    echo "$DEVICE_ID" > "$DRIVER_PATH/unbind" 2>/dev/null || true
    sleep 0.2

    # Configure PLL registers in a subshell so we always rebind on failure
    pll_result=0
    (
        set +e
        local_fail=0
        i2cset -y $I2C_BUS $WM8960_ADDR 0x04 0x00 || { log "ERROR: Failed to write CLOCK1"; local_fail=1; }
        i2cset -y $I2C_BUS $WM8960_ADDR 0x1a 0x00 || { log "ERROR: Failed to write POWER2"; local_fail=1; }
        i2cset -y $I2C_BUS $WM8960_ADDR 0x34 $PLL1_VAL || { log "ERROR: Failed to write PLL1"; local_fail=1; }
        i2cset -y $I2C_BUS $WM8960_ADDR 0x35 $K_HIGH || { log "ERROR: Failed to write PLL2"; local_fail=1; }
        i2cset -y $I2C_BUS $WM8960_ADDR 0x36 $K_MID || { log "ERROR: Failed to write PLL3"; local_fail=1; }
        i2cset -y $I2C_BUS $WM8960_ADDR 0x37 $K_LOW || { log "ERROR: Failed to write PLL4"; local_fail=1; }

        if [ $local_fail -eq 0 ]; then
            # Enable PLL
            i2cset -y $I2C_BUS $WM8960_ADDR 0x1a 0x01 || { log "ERROR: Failed to enable PLL power"; local_fail=1; }
            sleep 0.25
            # Switch SYSCLK to PLL
            i2cset -y $I2C_BUS $WM8960_ADDR 0x04 0x01 || { log "ERROR: Failed to set SYSCLK source"; local_fail=1; }
        fi
        exit $local_fail
    ) || pll_result=$?

    # Always rebind driver, even if PLL configuration failed
    log "Rebinding driver..."
    echo "$DEVICE_ID" > "$DRIVER_PATH/bind" || { log "ERROR: Failed to rebind driver"; exit 1; }
    sleep 1
    log_debug "Driver rebound successfully"

    if [ $pll_result -ne 0 ]; then
        log "ERROR: PLL register configuration failed"
        exit 1
    fi

    log "PLL configuration complete!"
}

wait_for_soundcard() {
    local max_wait=15
    local count=0

    log_debug "Waiting for WM8960 sound card to appear..."
    while ! aplay -l 2>/dev/null | grep -qi "wm8960" && [ $count -lt $max_wait ]; do
        log_debug "Sound card not ready, waiting... (${count}/${max_wait}s)"
        sleep 1
        count=$((count + 1))
    done

    if ! aplay -l 2>/dev/null | grep -qi "wm8960"; then
        log "ERROR: WM8960 sound card not found after ${max_wait}s"
        log "Check that the WM8960 module is loaded and device tree is patched"
        exit 1
    fi
    log_debug "Sound card found after ${count}s"
}

detect_card() {
    # Detect WM8960 card number (allow override via environment variable)
    if [ -n "$WM8960_CARD" ]; then
        echo "$WM8960_CARD"
        return 0
    fi

    local card
    card=$(aplay -l 2>/dev/null | grep -i "wm8960\|ahub0wm8960" | head -1 | sed -n 's/^card \([0-9]\+\):.*/\1/p')

    if [ -z "$card" ]; then
        log "ERROR: Could not detect WM8960 sound card. Set WM8960_CARD environment variable or check if device is present."
        return 1
    fi

    echo "$card"
}

has_saved_state() {
    # Check if alsactl has a saved state for this card.
    # alsactl keys state sections by card ID (e.g., "state.ahub0wm8960"),
    # not by card number (e.g., "state.card0").
    local card_num="$1"
    local state_file="/var/lib/alsa/asound.state"
    local card_id

    [ -f "$state_file" ] || return 1
    card_id=$(cat "/proc/asound/card${card_num}/id" 2>/dev/null) || return 1
    grep -q "state\.${card_id}[[:space:]]*{" "$state_file" 2>/dev/null
}

apply_mixer_defaults() {
    local CARD_NUM="$1"

    # Run in subshell with errexit disabled — individual mixer controls may vary
    # by driver version and a single missing control should not abort the script
    (
    set +e

    # --- Playback routing and volumes ---
    # Enable DAC -> Output Mixer -> Headphone/Speaker path
    amixer -c "$CARD_NUM" sset "Left Output Mixer PCM" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Output Mixer PCM" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Left Output Mixer Boost Bypass" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Output Mixer Boost Bypass" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Left Output Mixer LINPUT3" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Output Mixer RINPUT3" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Mono Output Mixer Left" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Mono Output Mixer Right" off >/dev/null 2>&1

    # Headphone volume (0-127, with zero-cross for click-free changes)
    amixer -c "$CARD_NUM" sset "Headphone" 121 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Headphone Playback ZC" on >/dev/null 2>&1

    # Speaker volume (0-127, with zero-cross for click-free changes)
    amixer -c "$CARD_NUM" sset "Speaker" 121 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Speaker Playback ZC" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Speaker AC" 0 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Speaker DC" 0 >/dev/null 2>&1

    # DAC playback volume (0-255)
    amixer -c "$CARD_NUM" sset "Playback" 255 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "PCM Playback -6dB" off >/dev/null 2>&1

    # DAC settings
    amixer -c "$CARD_NUM" sset "DAC Deemphasis" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "DAC Polarity" "No Inversion" >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "DAC Mono Mix" "Stereo" >/dev/null 2>&1

    # 3D Enhancement (off by default, can be enabled for stereo widening)
    amixer -c "$CARD_NUM" sset "3D" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "3D Volume" 0 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "3D Filter Upper Cut-Off" "High" >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "3D Filter Lower Cut-Off" "Low" >/dev/null 2>&1

    # --- Capture/recording settings ---
    # Enable input signal path: LINPUT1/RINPUT1 -> Boost Mixer -> Input Mixer -> ADC
    amixer -c "$CARD_NUM" sset "Left Input Mixer Boost" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Input Mixer Boost" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Left Boost Mixer LINPUT1" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Right Boost Mixer RINPUT1" on >/dev/null 2>&1

    # Capture volume (0-63) and switch
    amixer -c "$CARD_NUM" sset "Capture" on >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Capture" 45 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Capture Volume ZC" on >/dev/null 2>&1

    # ADC digital volume (0-255)
    amixer -c "$CARD_NUM" cset name='ADC PCM Capture Volume' 210,210 >/dev/null 2>&1

    # Input boost gain (0=mute, 1=+13dB, 2=+20dB, 3=+29dB)
    amixer -c "$CARD_NUM" cset name='Left Input Boost Mixer LINPUT1 Volume' 2 >/dev/null 2>&1
    amixer -c "$CARD_NUM" cset name='Right Input Boost Mixer RINPUT1 Volume' 2 >/dev/null 2>&1

    # ADC settings
    amixer -c "$CARD_NUM" sset "ADC Polarity" "No Inversion" >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ADC High Pass Filter" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ADC Data Output Select" "Left Data = Left ADC;  Right Data = Right ADC" >/dev/null 2>&1

    # --- Automatic Level Control (off by default, enable for hardware AGC) ---
    amixer -c "$CARD_NUM" sset "ALC Function" "Off" >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ALC Max Gain" 7 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ALC Min Gain" 0 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ALC Target" 4 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ALC Hold Time" 0 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ALC Decay" 3 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ALC Attack" 2 >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "ALC Mode" "ALC" >/dev/null 2>&1

    # --- Noise Gate (off by default) ---
    amixer -c "$CARD_NUM" sset "Noise Gate" off >/dev/null 2>&1
    amixer -c "$CARD_NUM" sset "Noise Gate Threshold" 0 >/dev/null 2>&1

    exit 0
    )
}

configure_mixer() {
    log "Configuring mixer settings..."

    local CARD_NUM
    CARD_NUM=$(detect_card) || return 1

    if [ -n "$WM8960_CARD" ]; then
        log "Using WM8960_CARD from environment: $CARD_NUM"
    else
        log "Detected WM8960 card: $CARD_NUM"
    fi

    log_debug "Card number: $CARD_NUM"
    log_debug "RESET_DEFAULTS=$RESET_DEFAULTS"
    log_debug "State file check: $([ -f /var/lib/alsa/asound.state ] && echo 'exists' || echo 'missing')"

    # Check for --reset-defaults flag
    if [ "$RESET_DEFAULTS" = true ]; then
        log "Resetting mixer to factory defaults (--reset-defaults)..."
        apply_mixer_defaults "$CARD_NUM"
        alsactl store "$CARD_NUM" >/dev/null 2>&1 || true
        log "Factory defaults applied and saved!"
    elif has_saved_state "$CARD_NUM"; then
        log "Restoring saved mixer state..."
        if alsactl restore "$CARD_NUM" >/dev/null 2>&1; then
            log "Mixer restored from saved state!"
        else
            log "WARNING: Failed to restore saved state, applying defaults..."
            apply_mixer_defaults "$CARD_NUM"
            alsactl store "$CARD_NUM" >/dev/null 2>&1 || true
        fi
    else
        log "No saved state found — applying defaults..."
        apply_mixer_defaults "$CARD_NUM"

        # Save initial defaults so future boots know state exists
        alsactl store "$CARD_NUM" >/dev/null 2>&1 || true
        log "Mixer defaults applied and saved!"
    fi
}

ensure_dkms_module() {
    local module_name="wm8960-audio-hat"
    local module_version="1.0"
    local kver
    kver=$(uname -r)

    # Check if our DKMS module is already installed for this kernel
    if dkms status "${module_name}/${module_version}" -k "$kver" 2>/dev/null | grep -q installed; then
        log_debug "WM8960 DKMS module already installed for kernel $kver"
        modprobe snd_soc_wm8960 2>/dev/null || true
        return 0
    fi

    log "WM8960 module not found for kernel $kver — attempting DKMS rebuild..."

    # Verify DKMS is installed and module source exists
    if ! command -v dkms >/dev/null 2>&1; then
        log "ERROR: dkms not installed, cannot rebuild module"
        return 1
    fi

    if [ ! -d "/usr/src/${module_name}-${module_version}" ]; then
        log "ERROR: DKMS source not found at /usr/src/${module_name}-${module_version}"
        return 1
    fi

    # Check kernel headers are available
    if [ ! -d "/lib/modules/${kver}/build" ]; then
        log "ERROR: Kernel headers not found for ${kver}"
        log "Install headers and re-run, or reboot into the previous kernel"
        return 1
    fi

    # Ensure module is registered with DKMS
    if ! dkms status "${module_name}/${module_version}" 2>/dev/null | grep -q .; then
        log "Registering DKMS module..."
        dkms add "${module_name}/${module_version}" || { log "ERROR: dkms add failed"; return 1; }
    fi

    # Build and install for running kernel
    log "Building module for kernel ${kver}..."
    if dkms install "${module_name}/${module_version}" -k "${kver}" 2>&1; then
        log "DKMS rebuild successful!"
        # Load the freshly built module
        modprobe snd_soc_wm8960 2>/dev/null || true
    else
        log "ERROR: DKMS build failed for kernel ${kver}"
        return 1
    fi
}

# Main execution
log "Starting WM8960 audio configuration..."

# Ensure DKMS module is built for the running kernel (handles kernel upgrades)
ensure_dkms_module || log "WARNING: DKMS module check failed — audio may not work"

# Wait for I2C device to be available
wait_for_device

# Configure PLL on Orange Pi OS only
# On Armbian, the DKMS driver handles PLL internally via ASoC.
# On Orange Pi OS, the vendor BSP machine driver doesn't call set_sysclk/set_pll
# on the codec, so we must configure PLL via direct i2cset.
if is_armbian; then
    log_debug "Armbian detected — skipping PLL configuration (handled by driver)"
else
    configure_pll
fi

# Wait for sound card after PLL config (rebind creates new card instance)
wait_for_soundcard

# Configure mixer
configure_mixer

log "WM8960 audio configuration complete! Audio is ready."
exit 0
