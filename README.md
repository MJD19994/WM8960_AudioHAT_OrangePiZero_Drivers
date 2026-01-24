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

The WM8960 Audio HAT uses I2C for control and I2S for audio data. **The 40-pin GPIO header on Orange Pi Zero 2W is compatible with Raspberry Pi HATs** - no rewiring is required. The pins are at the same physical locations and just need correct device tree configuration.

### Pin Compatibility Table

| Function   | Physical Pin | Raspberry Pi | Orange Pi Zero 2W | Compatible |
|------------|--------------|--------------|-------------------|------------|
| I2C SDA    | Pin 3        | GPIO2        | PI8               | ✅ Yes     |
| I2C SCL    | Pin 5        | GPIO3        | PI7               | ✅ Yes     |
| I2S BCLK   | Pin 12       | GPIO18       | PI1               | ✅ Yes     |
| I2S LRCK   | Pin 35       | GPIO19       | PI2               | ✅ Yes     |
| I2S DIN    | Pin 38       | GPIO20       | PI3               | ✅ Yes     |
| I2S DOUT   | Pin 40       | GPIO21       | PI3               | ✅ Yes     |
| 3.3V       | Pin 1        | 3.3V         | 3.3V              | ✅ Yes     |
| GND        | Pin 6, 9     | GND          | GND               | ✅ Yes     |

### I2C Bus Information

On Orange Pi Zero 2W with Armbian/DietPi:
- **Pins 3/5 (I2C)** require the Armbian `i2c1-pi` overlay to be enabled
- After enabling `i2c1-pi`, the I2C bus appears as `/dev/i2c-3`
- The WM8960 codec should be detected at address **0x1a** on that bus

The install script automatically adds both `i2c1-pi` and our WM8960 overlay to the boot configuration.

### Hardware Connection

Simply plug the ReSpeaker 2-Mic HAT directly onto the Orange Pi Zero 2W's 40-pin header - no additional wiring needed. The device tree overlay handles the GPIO pin mapping to the correct peripheral functions.

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
│   ├── install.sh            # Main installation script
│   ├── uninstall.sh          # Uninstallation script
│   ├── build-wm8960-module.sh # Build WM8960 kernel module from source
│   └── wm8960-status.sh      # Status check utility
└── configs/
    └── asound.conf           # ALSA configuration
```

## Uninstallation

To completely remove the WM8960 Audio HAT driver:

```bash
# Run the uninstall script
sudo bash scripts/uninstall.sh

# Or use the --force flag to skip confirmation
sudo bash scripts/uninstall.sh --force

# Reboot to apply changes
sudo reboot
```

The uninstall script will:
- Remove device tree overlay files
- Remove overlay entries from boot configuration
- Remove ALSA configuration (/etc/asound.conf)
- Remove the wm8960-status utility

## Troubleshooting

### Step 1: Check if WM8960 is detected on I2C

The WM8960 codec should appear at address 0x1a on one of the I2C buses:

```bash
# Install i2c-tools if not present
sudo apt install i2c-tools

# Scan all I2C buses for the WM8960 (address 0x1a)
for bus in 0 1 2 3; do
    echo "=== I2C Bus $bus ==="
    i2cdetect -y $bus 2>/dev/null || echo "Bus $bus not available"
done
```

Look for `1a` in the output. If you see `UU` at 0x1a, the device is being used by a driver.

### Step 2: If WM8960 is NOT detected

If the WM8960 doesn't appear on any I2C bus:

1. **Check physical connections** - Ensure the HAT is properly seated on the GPIO header
2. **Verify the HAT is powered** - Check that 3.3V is reaching the HAT
3. **Try different I2C buses** - The HAT might be on a different bus than expected

### Step 3: Check overlay loading

```bash
# Check if overlay is loaded
ls /proc/device-tree/ | grep -i sound
cat /proc/device-tree/sound*/compatible 2>/dev/null

# Check for loading errors
dmesg | grep -i overlay
dmesg | grep -i wm8960
dmesg | grep -i i2c
```

### Step 4: Verify kernel modules

```bash
# Check if required modules are loaded
lsmod | grep -E "snd_soc|wm8960"

# Try loading them manually
sudo modprobe snd_soc_wm8960
sudo modprobe snd_soc_simple_card
```

### Step 5: Check if snd_soc_wm8960 is available in your kernel

**⚠️ IMPORTANT**: The Armbian/DietPi kernel for sunxi64 may NOT include the WM8960 driver by default!

```bash
# Check if the module exists
find /lib/modules/$(uname -r) -name "*wm8960*"

# Check if it's built into the kernel
zcat /proc/config.gz 2>/dev/null | grep CONFIG_SND_SOC_WM8960

# Expected output for working setup:
# CONFIG_SND_SOC_WM8960=m   (module - can be loaded)
# CONFIG_SND_SOC_WM8960=y   (built-in - always available)
# If you see "is not set" or nothing, the driver is NOT available
```

If the WM8960 driver is missing from your kernel, you have these options:

#### Option 1: Build the WM8960 module from source (RECOMMENDED)

We provide a script that automatically downloads and compiles the WM8960 driver for your kernel:

```bash
# Build and install the WM8960 kernel module
sudo bash scripts/build-wm8960-module.sh

# Then reboot
sudo reboot

# After reboot, reinstall the overlay
sudo bash scripts/install.sh
sudo reboot
```

This script will:
- Install kernel headers for your running kernel
- Download the WM8960 driver source from the Linux kernel repository
- Compile it as an out-of-tree kernel module
- Install it to `/lib/modules/<kernel-version>/`
- Configure it to load automatically at boot

#### Option 2: Request kernel change from Armbian team

Request the Armbian/DietPi team to include `CONFIG_SND_SOC_WM8960=m` in their kernel config for sunxi64.

#### Option 3: Build a custom kernel

To build a custom kernel with WM8960 support:
```bash
# In kernel menuconfig:
# Device Drivers → Sound card support → ALSA → 
#   CODEC drivers → Wolfson Microelectronics WM8960 CODEC
# Set to <M> for module or <*> for built-in
```

### Step 6: Try alternative overlay

If the primary overlay doesn't work, try the I2C3 version:

```bash
# Edit boot configuration
sudo nano /boot/armbianEnv.txt
# Change: overlays=sun50i-h618-wm8960-soundcard
# To:     overlays=sun50i-h618-wm8960-soundcard-i2s3
sudo reboot
```

### ALSA Configuration Issues

If you see errors like "dsnoop is not a compound":

```bash
# Remove the problematic ALSA config temporarily
sudo mv /etc/asound.conf /etc/asound.conf.bak
# Test audio without custom config
aplay -l
```

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

The Allwinner H618 uses the **AHUB (Audio Hub)** architecture which differs from the simple I2S interface used on Raspberry Pi. We provide two overlay approaches:

1. **Primary overlay** (`sun50i-h618-wm8960-soundcard.dts`):
   - Uses standard I2S0 interface with simple-audio-card binding
   - Targets I2S0 controller at `/soc@3000000/i2s@5095000`
   - May work on some kernel versions

2. **Alternative overlay** (`sun50i-h618-wm8960-soundcard-i2s3.dts`):
   - Uses AHUB-based approach with `allwinner,sunxi-snd-mach` binding
   - More compatible with Armbian kernel audio architecture
   - Required if kernel patches for H616/H618 sound are applied

The overlays configure:
- I2C1 bus with WM8960 at address 0x1a (via i2c1-pi overlay)
- I2S interface for audio data on PI0-PI4 pins
- Audio routing for speakers, headphones, and microphones

### Important Notes on H618 Audio

**⚠️ Current Limitations:**
- The Allwinner H618 has limited mainline kernel audio support
- The kernel may require Armbian patches for proper I2S/AHUB functionality
- The `snd_soc_wm8960` module is NOT included in default Armbian kernels
- You may need to build the WM8960 module from source (see build-wm8960-module.sh)

**Current Progress:**
- ✅ WM8960 codec detected on I2C bus 3 at address 0x1a
- ✅ snd_soc_wm8960 module can be built and loaded
- ✅ snd_soc_simple_card module loaded
- ⚠️ Sound card registration depends on proper overlay loading

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
