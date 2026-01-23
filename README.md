# WM8960 Audio HAT Drivers for Orange Pi Zero 2W

Drivers and device tree overlays to enable **Keyestudio ReSpeaker 2-Mic HAT** (and compatible WM8960-based audio HATs designed for Raspberry Pi) on **Orange Pi Zero 2W** running DietPi, Armbian, or similar Linux distributions.

## Supported Hardware

- **Board**: Orange Pi Zero 2W (Allwinner H618)
- **Audio HAT**: Keyestudio ReSpeaker 2-Mic Pi HAT V1.0 (WM8960 codec)
- **Also Compatible**: Seeed ReSpeaker 2-Mic HAT, Waveshare WM8960 Audio HAT, and other WM8960-based I2S audio HATs

## Tested Configuration

- **OS**: DietPi
- **Kernel**: Linux 6.12.65-current-sunxi64
- **Architecture**: aarch64 (ARM64)

## Features

- ✅ High-quality stereo audio playback
- ✅ Dual microphone input (stereo capture)
- ✅ Headphone and speaker outputs
- ✅ Full-duplex audio (simultaneous record and playback)
- ✅ ALSA configuration with software mixing
- ✅ Easy installation script

## Quick Start

### Prerequisites

1. Orange Pi Zero 2W with DietPi, Armbian, or Ubuntu installed
2. Keyestudio ReSpeaker 2-Mic HAT (or compatible WM8960 HAT) connected to the GPIO header
3. Internet connection for package installation

### Installation

```bash
# Clone this repository
git clone https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers.git
cd WM8960_AudioHAT_OrangePiZero_Drivers

# Run the installer (requires sudo)
sudo bash scripts/install.sh

# Reboot the system
sudo reboot
```

### Verify Installation

After rebooting:

```bash
# Check driver status
wm8960-status

# Or manually check:
aplay -l    # List playback devices
arecord -l  # List capture devices
```

## GPIO Pin Mapping

The WM8960 Audio HAT uses I2C for control and I2S for audio data. The I2C pins are compatible between Raspberry Pi and Orange Pi Zero 2W at the same physical locations. The I2S pins require rewiring as shown below:

### I2C Pins (Compatible - Same Physical Location)

| Function | Raspberry Pi | Orange Pi Zero 2W | Compatible |
|----------|-------------|-------------------|------------|
| I2C SDA  | Pin 3       | Pin 3 (PI8)       | ✅ Yes     |
| I2C SCL  | Pin 5       | Pin 5 (PI7)       | ✅ Yes     |
| 3.3V     | Pin 1       | Pin 1             | ✅ Yes     |
| GND      | Pin 6, 9    | Pin 6, 9          | ✅ Yes     |

### I2S Pins (Requires Rewiring)

| Function   | Raspberry Pi Pin | Orange Pi Pin | Allwinner GPIO |
|------------|------------------|---------------|----------------|
| I2S BCLK   | Pin 12 (GPIO18)  | Pin 23        | PH6            |
| I2S LRCK   | Pin 35 (GPIO19)  | Pin 19        | PH7            |
| I2S DOUT   | Pin 40 (GPIO21)  | Pin 21        | PH8            |
| I2S DIN    | Pin 38 (GPIO20)  | N/A           | (Not used)     |

### Wiring Instructions

For the ReSpeaker 2-Mic HAT to work on Orange Pi Zero 2W:

1. **Direct Plug-in**: The HAT can be plugged directly as I2C (control) works at pins 3 and 5
2. **I2S Audio Wiring**: You may need to verify or add jumper wires:
   - Connect Raspberry Pi Pin 12 → Orange Pi Pin 23 (BCLK)
   - Connect Raspberry Pi Pin 35 → Orange Pi Pin 19 (LRCK)
   - Connect Raspberry Pi Pin 40 → Orange Pi Pin 21 (DOUT)

**Note**: Some HAT revisions may work directly if the I2S signals are routed via I2C-controlled switching. Test with `wm8960-status` after installation.

## Usage Examples

### Play Audio

```bash
# Test speakers with a generated tone
speaker-test -c 2 -t wav

# Play an audio file
aplay -D default music.wav

# Play with specific device
aplay -D plughw:wm8960soundcard music.wav
```

### Record Audio

```bash
# Record 10 seconds of audio (CD quality)
arecord -D plughw:wm8960soundcard -f cd -d 10 recording.wav

# Record at specific sample rate
arecord -D default -r 48000 -c 2 -f S16_LE recording.wav
```

### Adjust Volume

```bash
# Open the mixer
alsamixer

# Use arrow keys to adjust:
#   - Headphone volume
#   - Speaker volume
#   - Capture (microphone) volume
#   - Playback volume
```

### Use with PulseAudio

If you're using PulseAudio:

```bash
# List sinks (output devices)
pactl list sinks short

# Set WM8960 as default
pactl set-default-sink alsa_output.platform-sound-wm8960.stereo-fallback
```

## Directory Structure

```
WM8960_AudioHAT_OrangePiZero_Drivers/
├── README.md                 # This file
├── overlays/
│   ├── sun50i-h618-wm8960-soundcard.dts      # Device tree overlay (I2S2)
│   └── sun50i-h618-wm8960-soundcard-i2s3.dts # Alternative overlay (I2S3)
├── scripts/
│   ├── install.sh           # Main installation script
│   └── wm8960-status.sh     # Status check utility
└── configs/
    └── asound.conf          # ALSA configuration
```

## Troubleshooting

### No sound card detected

1. **Check I2C connection**:
   ```bash
   sudo apt install i2c-tools
   i2cdetect -y 1
   ```
   You should see `1a` at address 0x1a if the WM8960 is detected.

2. **Verify overlay is loaded**:
   ```bash
   cat /proc/device-tree/sound*/compatible
   # Should show "simple-audio-card"
   ```

3. **Check kernel messages**:
   ```bash
   dmesg | grep -i wm8960
   dmesg | grep -i i2s
   ```

### Try alternative I2S interface

If the primary overlay doesn't work, try the I2S3 version:

1. Edit your boot configuration:
   ```bash
   # For DietPi/Armbian:
   sudo nano /boot/armbianEnv.txt
   # Change: overlays=sun50i-h618-wm8960-soundcard
   # To:     overlays=sun50i-h618-wm8960-soundcard-i2s3
   ```

2. Reboot and test again.

### Audio plays but no sound from speakers

1. Check mixer settings:
   ```bash
   alsamixer
   # Ensure "Speaker" and "Headphone" are not muted (MM)
   # Press 'm' to unmute, use arrow keys to adjust volume
   ```

2. Verify audio routing:
   ```bash
   amixer -c wm8960soundcard
   ```

### Recording doesn't work

1. Check capture controls in alsamixer:
   ```bash
   alsamixer
   # Press F4 to view capture controls
   # Unmute and increase "Capture" volume
   ```

2. Set the input source:
   ```bash
   amixer -c wm8960soundcard set 'Left Input Mux' 'IN1'
   amixer -c wm8960soundcard set 'Right Input Mux' 'IN1'
   ```

## Manual Installation

If the automatic installer doesn't work, you can install manually:

1. **Install dependencies**:
   ```bash
   sudo apt update
   sudo apt install device-tree-compiler i2c-tools alsa-utils
   ```

2. **Compile the overlay**:
   ```bash
   cd overlays
   dtc -@ -I dts -O dtb -o sun50i-h618-wm8960-soundcard.dtbo sun50i-h618-wm8960-soundcard.dts
   ```

3. **Install the overlay**:
   ```bash
   sudo cp sun50i-h618-wm8960-soundcard.dtbo /boot/dtb/allwinner/overlay/
   ```

4. **Enable the overlay** (edit boot config):
   ```bash
   # For DietPi/Armbian:
   echo "overlays=sun50i-h618-wm8960-soundcard" | sudo tee -a /boot/armbianEnv.txt
   
   # Or for Orange Pi OS:
   echo "overlays=sun50i-h618-wm8960-soundcard" | sudo tee -a /boot/orangepiEnv.txt
   ```

5. **Install ALSA config**:
   ```bash
   sudo cp configs/asound.conf /etc/asound.conf
   ```

6. **Reboot**:
   ```bash
   sudo reboot
   ```

## Uninstallation

```bash
sudo bash scripts/install.sh --uninstall
```

Then manually remove the overlay from your boot configuration file.

## Technical Details

### WM8960 Codec

The WM8960 is a low-power, high-quality stereo CODEC with integrated Class D speaker drivers. It communicates via:

- **I2C** (address 0x1a): For configuration and control
- **I2S**: For digital audio data transfer

### Device Tree Overlay

The overlay configures:
- I2C1 bus with WM8960 at address 0x1a
- I2S2 (or I2S3) interface for audio data
- Simple-audio-card for ALSA integration
- Audio routing for speakers, headphones, and microphones

## Contributing

Contributions are welcome! If you've tested this on different hardware or kernel versions, please open an issue or PR.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Seeed Studio](https://www.seeedstudio.com/) for the ReSpeaker HAT design
- [Keyestudio](https://www.keyestudio.com/) for the compatible HAT
- The Armbian and DietPi communities for Linux support on Orange Pi
- Linux kernel maintainers for the WM8960 and simple-audio-card drivers

## References

- [WM8960 Datasheet](https://www.cirrus.com/products/wm8960/)
- [Orange Pi Zero 2W Wiki](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/details/Orange-Pi-Zero-2W.html)
- [Linux Device Tree Documentation](https://www.kernel.org/doc/html/latest/devicetree/)
- [ALSA Configuration](https://www.alsa-project.org/wiki/Main_Page)
