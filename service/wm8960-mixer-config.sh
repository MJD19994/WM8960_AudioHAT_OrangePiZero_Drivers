#!/bin/bash
#
# WM8960 Mixer Configuration Script
# Configures the WM8960 codec mixer settings for proper audio output and input.
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

log() {
    echo "[WM8960-MIXER] $1"
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo "[WM8960-MIXER] [DEBUG] $1"
    fi
}

wait_for_soundcard() {
    local max_wait=15
    local count=0

    log_debug "Waiting for WM8960 sound card to appear..."
    while ! aplay -l 2>/dev/null | grep -qi "wm8960" && [ $count -lt $max_wait ]; do
        log_debug "Sound card not ready, waiting... (${count}/${max_wait}s)"
        sleep 1
        ((count++))
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
    # Check if alsactl has a saved state for this card
    local card_num="$1"
    local state_file="/var/lib/alsa/asound.state"

    [ -f "$state_file" ] && grep -qE "state\.card${card_num}[[:space:]]*\{" "$state_file" 2>/dev/null
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

# Main execution
log "Starting WM8960 mixer configuration..."

# Wait for sound card to be available
wait_for_soundcard

# Configure mixer
configure_mixer

log "WM8960 mixer configuration complete! Audio is ready."
exit 0
