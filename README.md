# WM8960 Audio HAT Drivers for Orange Pi (H616/H618)

Complete audio support for WM8960-based audio HATs (including ReSpeaker 2-Mic HAT) on Orange Pi boards with Allwinner H616/H618 SoCs.

## Features

- ✅ Full WM8960 codec support with proper PLL configuration
- ✅ Stereo audio playback through headphones and/or speaker
- ✅ Stereo audio recording from onboard microphones
- ✅ Simultaneous headphone and speaker output
- ✅ Automatic PLL configuration at boot
- ✅ Automatic SoC detection (H616/H618) and card number detection
- ✅ Complete mixer configuration (all WM8960 controls set to known defaults)
- ✅ Multi-application audio support (dmix/dsnoop)
- ✅ Hardware ALC, Noise Gate, and 3D Enhancement controls exposed
- ✅ Works with Orange Pi OS (Bookworm, kernel 6.1.31)

## Hardware Compatibility

**Tested on:**
- Orange Pi Zero 2W (Allwinner H618)
- ReSpeaker 2-Mic Pi HAT (WM8960 codec)

**Should work on (untested):**
- Orange Pi boards with Allwinner H616 (auto-detection implemented)
- Other WM8960-based audio HATs

**Requirements:**
- [Orange Pi OS 1.0.2 Bookworm (kernel 6.1.31-orangepi)](https://drive.google.com/drive/folders/1cvPUtPOmGfOSxilAHUgq_UqZK5HmzH0t)
- WM8960 codec support compiled into kernel (See KERNEL.md)
- I2C tools installed

## Quick Start

### Update Your System

```bash
sudo apt update && sudo apt upgrade -y
```

### Quick Setup (Recommended)

Installs everything in one step — kernel with WM8960 support (if needed) and all driver components:

```bash
git clone https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers
cd WM8960_AudioHAT_OrangePiZero_Drivers
chmod +x quick-setup.sh
sudo ./quick-setup.sh
sudo reboot
```

If the kernel already has WM8960 support, the kernel step is automatically skipped.

### Driver-Only Installation

If you've already installed the kernel with WM8960 support separately:

```bash
git clone https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers
cd WM8960_AudioHAT_OrangePiZero_Drivers
chmod +x install.sh
sudo ./install.sh
sudo reboot
```

### Testing Audio

After reboot, run the interactive test script:

```bash
# Full interactive test (diagnostics + playback + recording tests)
chmod +x scripts/test-audio.sh
./scripts/test-audio.sh

# Diagnostics only (no interactive prompts — useful for debugging)
chmod +x scripts/test-audio.sh
./scripts/test-audio.sh --diagnostics-only
```

The test script checks: kernel module, I2C device, sound card, service status, ALSA config, mixer routing, and dmesg errors. Then it walks you through interactive playback and recording tests.

Or test manually:

```bash
# List audio devices (find the card number for ahub0wm8960)
aplay -l

# Test with speaker-test (using card name)
speaker-test -D plughw:ahub0wm8960,0 -c 2 -r 48000 -t sine -f 1000 -l 2

# Or use the default device (configured in asound.conf)
speaker-test -c 2 -r 48000 -t sine -f 1000 -l 2

# Test recording (5 seconds)
arecord -D plughw:ahub0wm8960,0 -r 48000 -c 2 -f S16_LE -t wav -d 5 test.wav

# Playback recording
aplay -D plughw:ahub0wm8960,0 test.wav
```

**Note:** The WM8960 appears as **ahub0wm8960** sound card. The card number may vary (typically card 3), but using the card name ensures portability. You can also use `-D default` to use the system default audio device (configured to WM8960 in `/etc/asound.conf`).

## How It Works

### The Problem

The Orange Pi kernel's WM8960 driver does not configure the PLL when the codec is in slave mode (I2S clock provided by SoC). The WM8960 HAT uses an onboard 24MHz crystal but needs the PLL configured to generate the correct internal clocks for audio processing.

Without PLL configuration, you get:
- Codec detected but no audio output
- "slave mode, but proceeding with no clock configuration" errors in dmesg

### The Solution

This package provides:

1. **Device Tree Patching** (`overlays-orangepi/sun50i-h618-wm8960-working.dts`)
   - Compiled and applied to the base DTB at install time using `fdtoverlay`
   - Configures I2S0 pins (BCLK, LRCK, DOUT, DIN)
   - Sets up AHUB audio subsystem
   - Enables I2C1 and declares WM8960 codec at address 0x1a

2. **PLL Configuration Service** (`service/wm8960-pll-config.sh`)
   - Runs at boot via systemd
   - Temporarily unbinds WM8960 driver
   - Configures PLL registers via I2C (24MHz → 12.288MHz for 48kHz audio)
   - Rebinds driver
   - Configures all WM8960 mixer controls to known defaults (playback routing, capture path, DAC/ADC settings, ALC, Noise Gate, 3D Enhancement, zero-cross detection)

3. **ALSA Configuration** (`configs/asound.conf`)
   - Sets WM8960 as default audio device
   - dmix plugin for multi-application playback
   - dsnoop plugin for multi-application recording
   - Automatic format/rate conversion via plug plugin

## Uninstalling

To remove the driver, device tree patch, and ALSA configuration:

```bash
sudo ./uninstall.sh
sudo reboot
```

This safely removes the systemd service, restores the original device tree, and removes ALSA config files. Your existing ALSA configuration is backed up before removal.

**Note:** The uninstall script does not roll back kernel changes. The WM8960-enabled kernel is safe to keep — it does not affect other audio devices or system stability. If you need to revert to a different kernel, you will need to install one manually.

## Project Structure

```
WM8960_AudioHAT_OrangePiZero_Drivers/
├── README.md                           # This file
├── LICENSE                             # License
├── quick-setup.sh                      # All-in-one setup (kernel + driver)
├── install.sh                          # Driver-only installation (auto-detects H616/H618)
├── uninstall.sh                        # Uninstallation script
├── overlays-orangepi/                  # Device tree overlay sources
│   ├── sun50i-h616-wm8960-working.dts # H616 variant (compiled and applied at install time)
│   └── sun50i-h618-wm8960-working.dts # H618 variant (compiled and applied at install time)
├── service/                            # System services
│   ├── wm8960-pll-config.sh           # PLL configuration script
│   └── wm8960-audio.service           # Systemd service
├── configs/                            # ALSA configuration
│   ├── asound.conf                    # ALSA config (sets default device)
│   └── wm8960.state                   # Mixer state
├── kernel/                             # Kernel resources
│   ├── KERNEL.md                      # Kernel build/install guide
│   └── *.tar.gz                       # Pre-compiled kernel with WM8960 support
├── scripts/                            # Utility scripts
│   ├── test-audio.sh                  # Diagnostics and interactive audio tests
│   ├── install-kernel.sh             # Kernel installation (used by quick-setup)
│   └── extract-kernel.sh            # Build tool: package kernel from device
└── docs/                               # Documentation
    └── hardware/                       # Hardware reference
        └── OrangePi_Zero2w_H618_User Manual_v1.3.pdf
```

## Audio Configuration

### Mixer Controls

Use `alsamixer` for an interactive mixer GUI:

```bash
# Open the interactive mixer (use F4 for capture view, Tab to switch views)
alsamixer -c ahub0wm8960
```

Or use `amixer` for command-line control:

**Playback controls:**

```bash
# Set headphone volume (0-127, default: 121)
amixer -c ahub0wm8960 sset 'Headphone' 121

# Set speaker volume (0-127, default: 121)
amixer -c ahub0wm8960 sset 'Speaker' 121

# Set DAC playback volume (0-255, default: 255)
amixer -c ahub0wm8960 sset 'Playback' 255

# Enable PCM output routing (required for audio output)
amixer -c ahub0wm8960 sset 'Left Output Mixer PCM' on
amixer -c ahub0wm8960 sset 'Right Output Mixer PCM' on

# Speaker boost controls (0-5, default: 0 = no boost)
amixer -c ahub0wm8960 sset 'Speaker AC' 0
amixer -c ahub0wm8960 sset 'Speaker DC' 0

# Disable mono output (reduces crosstalk)
amixer -c ahub0wm8960 sset 'Mono Output Mixer Left' off
amixer -c ahub0wm8960 sset 'Mono Output Mixer Right' off
```

**Capture/recording controls:**

```bash
# Enable capture input routing (required for recording)
amixer -c ahub0wm8960 sset 'Left Input Mixer Boost' on
amixer -c ahub0wm8960 sset 'Right Input Mixer Boost' on
amixer -c ahub0wm8960 sset 'Left Boost Mixer LINPUT1' on
amixer -c ahub0wm8960 sset 'Right Boost Mixer RINPUT1' on

# Enable capture and set volume (0-63, default: 45)
amixer -c ahub0wm8960 sset 'Capture' on
amixer -c ahub0wm8960 sset 'Capture' 45

# Set input boost gain (0-3, default: 2)
# 0 = mute, 1 = +13dB, 2 = +20dB, 3 = +29dB
amixer -c ahub0wm8960 cset numid=10 2   # Left Input Boost LINPUT1 Volume
amixer -c ahub0wm8960 cset numid=9 2    # Right Input Boost RINPUT1 Volume

# Set ADC digital volume (0-255, default: 210)
amixer -c ahub0wm8960 cset numid=37 210,210
```

**Signal path overview:**

The WM8960 audio signal flows through these mixer stages:

- **Playback:** DAC → Output Mixer (PCM switch) → Headphone/Speaker amplifier
- **Capture:** LINPUT1/RINPUT1 → Boost Mixer → Input Mixer (Boost switch) → ADC

All routing switches and volumes are configured automatically by the PLL configuration service at boot. Use the commands above to adjust levels after boot if needed.

**Saving custom mixer settings:**

If you adjust volumes or enable features like ALC, save your settings to persist across reboots:

```bash
# Save current mixer state to disk
sudo alsactl store -c ahub0wm8960
```

On first boot, the service applies defaults and saves them. On subsequent boots, it restores your saved settings instead. To reset back to factory defaults:

```bash
# Option 1: Reset defaults immediately (no reboot needed)
sudo /usr/local/bin/wm8960-pll-config.sh --reset-defaults

# Option 2: Reset on next reboot
# WARNING: This removes saved state for ALL sound cards, not just WM8960
sudo rm /var/lib/alsa/asound.state
sudo reboot
```

**WM8960 hardware features (disabled by default, enable as needed):**

```bash
# 3D Stereo Enhancement — widens the stereo image
amixer -c ahub0wm8960 sset '3D' on
amixer -c ahub0wm8960 sset '3D Volume' 10       # 0-15

# Automatic Level Control (ALC) — hardware AGC for microphone input
# Automatically adjusts capture gain to maintain consistent recording levels
amixer -c ahub0wm8960 sset 'ALC Function' 'Stereo'  # Off / Right / Left / Stereo
amixer -c ahub0wm8960 sset 'ALC Max Gain' 7      # 0-7
amixer -c ahub0wm8960 sset 'ALC Target' 4         # 0-15

# Noise Gate — mutes input below a threshold (use with ALC)
amixer -c ahub0wm8960 sset 'Noise Gate' on
amixer -c ahub0wm8960 sset 'Noise Gate Threshold' 3  # 0-31

# ADC High Pass Filter — removes DC offset from recordings
amixer -c ahub0wm8960 sset 'ADC High Pass Filter' on
```

### Recording Audio

The WM8960 supports stereo recording from the onboard microphones:

```bash
# Record 5 seconds of stereo audio at 48kHz (recommended for best compatibility)
arecord -D plughw:ahub0wm8960,0 -r 48000 -c 2 -f S16_LE -t wav -d 5 recording.wav

# Or use the default device
arecord -r 48000 -c 2 -f S16_LE -t wav -d 5 recording.wav

# Play back the recording
aplay -D plughw:ahub0wm8960,0 recording.wav
```

**Note:** Use 48kHz sample rate for best speaker playback compatibility. Lower sample rates (16kHz, 8kHz) work for headphones but may not play through the speaker.

### Service Management

```bash
# Check service status
sudo systemctl status wm8960-audio.service

# View logs
sudo journalctl -u wm8960-audio.service

# Manually run configuration
sudo /usr/local/bin/wm8960-pll-config.sh

# Disable service
sudo systemctl disable wm8960-audio.service

# Re-enable service
sudo systemctl enable wm8960-audio.service

# Restart after a failure (the service does not auto-restart)
sudo systemctl restart wm8960-audio.service
```

**Note:** The PLL configuration service runs once at boot (`Type=oneshot`) and does not automatically restart on failure. If the service fails, check the logs with `journalctl -u wm8960-audio.service` and restart it manually.

## Troubleshooting

If the steps below don't help, check the service logs with `journalctl -u wm8960-audio.service`.

### Common Issues

**No audio output:**
1. Check service status: `systemctl status wm8960-audio.service`
2. Check dmesg: `dmesg | grep wm8960`
3. Verify card detected: `aplay -l` (look for "ahub0wm8960")
4. Check mixer: `amixer -c ahub0wm8960`

**"slave mode, but proceeding with no clock configuration" error:**
- This is normal before the PLL configuration runs
- After boot, this message should not appear during playback
- If it persists, the service may have failed

**Audio too quiet:**
- Increase mixer volumes: `amixer -c ahub0wm8960 sset 'Headphone' 127`
- Check playback volume: `amixer -c ahub0wm8960 sset 'Playback' 255`

**Recording not working (no audio captured):**
1. Verify the capture signal path is enabled:
   ```bash
   amixer -c ahub0wm8960 sset 'Left Input Mixer Boost' on
   amixer -c ahub0wm8960 sset 'Right Input Mixer Boost' on
   amixer -c ahub0wm8960 sset 'Left Boost Mixer LINPUT1' on
   amixer -c ahub0wm8960 sset 'Right Boost Mixer RINPUT1' on
   amixer -c ahub0wm8960 sset 'Capture' on
   ```
2. Check capture volume: `amixer -c ahub0wm8960 sset 'Capture' 45`
3. Verify the PLL service ran successfully: `systemctl status wm8960-audio.service`
4. Try re-running the configuration: `sudo /usr/local/bin/wm8960-pll-config.sh`

## Advanced Topics

### Kernel Requirements

This driver requires WM8960 codec support compiled into the Orange Pi kernel. See [kernel/KERNEL.md](kernel/KERNEL.md) for:
- Verifying kernel support
- Compiling custom kernel with WM8960
- Installing kernel modules

### Environment Variables

The configuration script supports optional environment variable overrides:

**WM8960_CARD** - Override the sound card number
```bash
# Force use of card 2 instead of auto-detection
WM8960_CARD=2 /usr/local/bin/wm8960-pll-config.sh
```

**DEVICE_ID** - Override the I2C device identifier
```bash
# Override the device ID (default: "2-001a" for Linux bus 2, address 0x1a)
DEVICE_ID="3-001a" /usr/local/bin/wm8960-pll-config.sh
```

These are useful for non-standard configurations or systems with multiple WM8960 devices.

### Manual PLL Configuration

For debugging or custom configurations, you can manually configure the PLL:

```bash
# The WM8960 sits on hardware I2C1 (i2c@5002400), which appears as Linux bus 2 (/dev/i2c-2).
# The device ID format is "<linux-bus>-<address>", so the default is "2-001a".
DEVICE_ID="2-001a"

# Disable driver
echo "$DEVICE_ID" > /sys/bus/i2c/drivers/wm8960/unbind

# Configure PLL registers (example for 24MHz → 12.288MHz)
i2cset -y 2 0x1a 0x34 0x34  # PLL1: N=4, PRE_DIV=1, SDM mode
i2cset -y 2 0x1a 0x35 0x18  # PLL2: K[23:16]
i2cset -y 2 0x1a 0x36 0x93  # PLL3: K[15:8]
i2cset -y 2 0x1a 0x37 0x75  # PLL4: K[7:0]
i2cset -y 2 0x1a 0x1a 0x01  # Enable PLL power
sleep 0.25
i2cset -y 2 0x1a 0x04 0x01  # Switch SYSCLK to PLL

# Re-enable driver
echo "$DEVICE_ID" > /sys/bus/i2c/drivers/wm8960/bind
```

**Note:** The device ID format is `<linux-bus>-<address>` where the bus number is the **Linux bus number** (check with `i2cdetect -l`) and address is a 4-digit hex value. On the Orange Pi Zero 2W, hardware I2C1 appears as Linux bus 2, so the default device ID is `2-001a`.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test on Orange Pi Zero 2W hardware
4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Based on WM8960 driver work from Raspberry Pi community
- Allwinner AHUB audio subsystem documentation
- Orange Pi community support

## Related Projects

- [WM8960 Driver for Raspberry Pi](https://github.com/MJD19994/WM8960_AudioHAT_Drivers) - Original Raspberry Pi implementation
- [Orange Pi Build System](https://github.com/orangepi-xunlong/orangepi-build) - Orange Pi kernel sources

## Support

- **Issues**: [GitHub Issues](https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers/discussions)
- **Orange Pi Forum**: [Orange Pi Forums](http://www.orangepi.org/orangepibbsen/)

---

**Status**: ✅ Working on Orange Pi boards with Allwinner H616/H618 SoCs (kernel 6.1.31-orangepi)
