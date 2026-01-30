# WM8960 Audio HAT Drivers for Orange Pi Zero 2W (H618)

Complete audio support for WM8960-based audio HATs (including ReSpeaker 2-Mic HAT) on Orange Pi Zero 2W with Allwinner H618 SoC.

## Features

- ✅ Full WM8960 codec support with proper PLL configuration
- ✅ Stereo audio playback through headphones and/or speaker
- ✅ Simultaneous headphone and speaker output
- ✅ Automatic PLL configuration at boot
- ✅ Pre-configured mixer settings
- ✅ Works with Orange Pi OS (Bookworm, kernel 6.1.31)

## Hardware Compatibility

**Tested on:**
- Orange Pi Zero 2W (Allwinner H618)
- ReSpeaker 2-Mic Pi HAT (WM8960 codec)
- Other WM8960-based audio HATs should work

**Requirements:**
- Orange Pi OS 1.0.2 Bookworm (kernel 6.1.31-orangepi)
- WM8960 codec support compiled into kernel
- I2C tools installed

## Quick Start

### Installation

```bash
git clone https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers
cd WM8960_AudioHAT_OrangePiZero_Drivers
sudo ./install.sh
sudo reboot
```

### Testing Audio

After reboot, test audio playback:

```bash
# Test with speaker-test
speaker-test -D plughw:3,0 -c 2 -r 48000 -t sine -f 1000 -l 2

# Play a WAV file
aplay -D plughw:3,0 /usr/share/sounds/alsa/Front_Center.wav

# List audio devices
aplay -l
```

The WM8960 will appear as **card 3 (ahub0wm8960)**.

## How It Works

### The Problem

The Orange Pi kernel's WM8960 driver does not configure the PLL when the codec is in slave mode (I2S clock provided by SoC). The WM8960 HAT uses an onboard 24MHz crystal but needs the PLL configured to generate the correct internal clocks for audio processing.

Without PLL configuration, you get:
- Codec detected but no audio output
- "slave mode, but proceeding with no clock configuration" errors in dmesg

### The Solution

This package provides:

1. **Device Tree Overlay** (`overlays-orangepi/sun50i-h618-wm8960-working.dts`)
   - Configures I2S0 pins (BCLK, LRCK, DOUT, DIN)
   - Sets up AHUB audio subsystem
   - Declares WM8960 codec on I2C bus 2
   - References 24MHz fixed clock

2. **PLL Configuration Service** (`service/wm8960-pll-config.sh`)
   - Runs at boot via systemd
   - Temporarily unbinds WM8960 driver
   - Configures PLL registers via I2C (24MHz → 12.288MHz for 48kHz audio)
   - Rebinds driver
   - Sets optimal mixer levels

3. **ALSA Configuration** (`configs/wm8960.state`)
   - Pre-configured mixer settings
   - Optimal headphone/speaker volumes
   - Proper audio routing

## Project Structure

```
WM8960_AudioHAT_OrangePiZero_Drivers/
├── README.md                           # This file
├── LICENSE                             # License
├── install.sh                          # Installation script
├── uninstall.sh                        # Uninstallation script
├── overlays-orangepi/                  # Device tree overlays
│   └── sun50i-h618-wm8960-working.dts
├── service/                            # System services
│   ├── wm8960-pll-config.sh           # PLL configuration script
│   └── wm8960-audio.service           # Systemd service
├── configs/                            # ALSA configuration
│   ├── asound.conf                    # ALSA config
│   └── wm8960.state                   # Mixer state
└── docs/                               # Documentation
    ├── INSTALLATION.md
    ├── TROUBLESHOOTING.md
    └── KERNEL.md
```

## Audio Configuration

### Mixer Controls

Key mixer controls for the WM8960:

```bash
# Set headphone volume (0-127)
amixer -c 3 sset 'Headphone' 121

# Set speaker volume (0-127)
amixer -c 3 sset 'Speaker' 121

# Enable PCM routing
amixer -c 3 sset 'Left Output Mixer PCM' on
amixer -c 3 sset 'Right Output Mixer PCM' on

# Set playback volume (0-255)
amixer -c 3 sset 'Playback' 255
```

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
```

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for detailed troubleshooting steps.

### Common Issues

**No audio output:**
1. Check service status: `systemctl status wm8960-audio.service`
2. Check dmesg: `dmesg | grep wm8960`
3. Verify card detected: `aplay -l`
4. Check mixer: `amixer -c 3`

**"slave mode, but proceeding with no clock configuration" error:**
- This is normal before the PLL configuration runs
- After boot, this message should not appear during playback
- If it persists, the service may have failed

**Audio too quiet:**
- Increase mixer volumes: `amixer -c 3 sset 'Headphone' 127`
- Check playback volume: `amixer -c 3 sset 'Playback' 255`

## Advanced Topics

### Kernel Requirements

This driver requires WM8960 codec support compiled into the Orange Pi kernel. See [docs/KERNEL.md](docs/KERNEL.md) for:
- Verifying kernel support
- Compiling custom kernel with WM8960
- Installing kernel modules

### Manual PLL Configuration

For debugging or custom configurations, you can manually configure the PLL:

```bash
# Disable driver
echo "2-001a" > /sys/bus/i2c/drivers/wm8960/unbind

# Configure PLL registers (example for 24MHz → 12.288MHz)
i2cset -y 2 0x1a 0x34 0x34  # PLL1: N=4, PRE_DIV=1, SDM mode
i2cset -y 2 0x1a 0x35 0x18  # PLL2: K[23:16]
i2cset -y 2 0x1a 0x36 0x93  # PLL3: K[15:8]
i2cset -y 2 0x1a 0x37 0x75  # PLL4: K[7:0]
i2cset -y 2 0x1a 0x1a 0x01  # Enable PLL power
sleep 0.25
i2cset -y 2 0x1a 0x04 0x01  # Switch SYSCLK to PLL

# Re-enable driver
echo "2-001a" > /sys/bus/i2c/drivers/wm8960/bind
```

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

- **Issues**: [GitHub Issues](https://github.com/YOUR_USERNAME/WM8960_AudioHAT_OrangePiZero_Drivers/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USERNAME/WM8960_AudioHAT_OrangePiZero_Drivers/discussions)
- **Orange Pi Forum**: [Orange Pi Forums](http://www.orangepi.org/orangepibbsen/)

---

**Status**: ✅ Working on Orange Pi Zero 2W (H618) with kernel 6.1.31-orangepi
