# Kernel Installation Guide

This guide covers kernel installation options for WM8960 support on Orange Pi Zero 2W.

## Important Note

The kernel tar.gz package should **only** contain kernel binaries and modules. The installation script is now located in the repository at `scripts/install-kernel.sh` for better version control and transparency.

## Option 1: Use Precompiled Kernel (Recommended)

The easiest way is to use our precompiled kernel that includes WM8960 support.

### Download and Install

```bash
# Download kernel package (12MB)
wget https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers/releases/download/v1.0/orangepi-zero2w-wm8960-kernel-6.1.31-orangepi.tar.gz

# Extract
tar -xzf orangepi-zero2w-wm8960-kernel-6.1.31-orangepi.tar.gz
cd kernel-package

# Install (requires root)
sudo ./install-kernel.sh

# Verify WM8960 module is available
modinfo snd_soc_wm8960
```

### What's Included

- Kernel version: 6.1.31-orangepi
- WM8960 codec driver (snd-soc-wm8960)
- Full ALSA/ASoC sound subsystem
- All dependencies

### Compatibility

- ✅ Orange Pi Zero 2W (H618)
- ✅ Orange Pi OS 1.0.2 Bookworm
- ✅ Armbian (may require adaptation)

## Option 2: Compile Your Own Kernel

If you prefer to compile your own kernel or need a different version:

### Method A: Native Compilation on Orange Pi (Recommended)

Compile directly on your Orange Pi Zero 2W. This is simpler as it doesn't require cross-compilation setup.

**⏱️ Time Required:** ~3 hours on Orange Pi Zero 2W

```bash
# 1. Install build dependencies
sudo apt-get update
sudo apt-get install -y build-essential bc bison flex libssl-dev libncurses5-dev \
    libelf-dev git kmod cpio rsync u-boot-tools device-tree-compiler

# 2. Clone Orange Pi kernel source (branch for H618)
cd ~
git clone --depth=1 -b orange-pi-6.1-sun50iw9 \
    https://github.com/orangepi-xunlong/linux-orangepi.git
cd linux-orangepi

# 3. Use current running kernel config as base
cp /boot/config-$(uname -r) .config

# 4. Enable WM8960 driver as a module
./scripts/config --module SND_SOC_WM8960

# 5. Build kernel (uses all CPU cores)
# This takes ~3 hours on Orange Pi Zero 2W
make -j$(nproc) ARCH=arm64 Image modules dtbs

# 6. Install kernel modules
sudo make modules_install

# 7. Install kernel and device tree
sudo cp arch/arm64/boot/Image /boot/vmlinuz-6.1.31-orangepi
sudo cp arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero2w.dtb /boot/dtb/allwinner/

# 8. Create System.map and config
sudo cp System.map /boot/System.map-6.1.31-orangepi
sudo cp .config /boot/config-6.1.31-orangepi

# 9. Update initramfs (if needed)
sudo update-initramfs -u -k 6.1.31-orangepi
```

**Notes:**
- Compilation uses ~2GB RAM - ensure you have swap enabled
- Total time: ~3 hours on Orange Pi Zero 2W (4-core ARM Cortex-A53)
- The system will be usable during compilation but will be slow
- Consider using `screen` or `tmux` so compilation continues if SSH disconnects

### Method B: Cross-Compilation on x86_64 Linux

Faster if you have a powerful x86 Linux machine.

**⏱️ Time Required:** ~15-30 minutes on modern desktop

#### Prerequisites

```bash
sudo apt update
sudo apt install -y build-essential bc bison flex libssl-dev \
    libncurses-dev git rsync gcc-aarch64-linux-gnu
```

#### Get Orange Pi Kernel Sources

```bash
git clone --depth=1 https://github.com/orangepi-xunlong/linux-orangepi.git -b orange-pi-6.1-sun50iw9
cd linux-orangepi
```

#### Configure Kernel

```bash
# Load Orange Pi default config
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- orangepi_defconfig

# Enable WM8960 support using config script
./scripts/config --module SND_SOC_WM8960

# OR use menuconfig for interactive configuration
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
```

In menuconfig, navigate to:
```
Device Drivers
  └─> Sound card support
      └─> Advanced Linux Sound Architecture (ALSA)
          └─> ALSA for SoC audio support
              └─> CODEC drivers
                  └─> <M> Wolfson Microelectronics WM8960 CODEC
```

**Important:** Select `<M>` (module) or `<*>` (built-in), not `< >` (disabled).

#### Compile

```bash
# Compile kernel
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs modules

# Package modules for Orange Pi
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- INSTALL_MOD_PATH=./modules_install modules_install
```

#### Transfer to Orange Pi

```bash
# Copy kernel image
scp arch/arm64/boot/Image root@orangepi:/boot/vmlinuz-6.1.31-orangepi

# Copy device tree
scp arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero2w.dtb \
    root@orangepi:/boot/dtb/allwinner/

# Copy modules (requires rsync)
rsync -avz modules_install/lib/modules/* root@orangepi:/lib/modules/

# SSH to Orange Pi and update
ssh root@orangepi "depmod -a 6.1.31-orangepi && update-initramfs -u"
```

### Verify

```bash
# Reboot
sudo reboot

# After reboot, verify kernel
uname -r  # Should show 6.1.31-orangepi

# Verify WM8960 module
modinfo snd_soc_wm8960
lsmod | grep wm8960
```

## Verifying WM8960 Support

### Check Module

```bash
# Module info
modinfo snd_soc_wm8960

# Load module manually (if needed)
sudo modprobe snd_soc_wm8960

# Check if loaded
lsmod | grep wm8960
```

### Check Kernel Config

```bash
# Verify WM8960 is enabled in kernel config
zcat /proc/config.gz | grep WM8960
# Should show: CONFIG_SND_SOC_WM8960=y or =m
```

## Troubleshooting

### "modinfo: ERROR: Module snd_soc_wm8960 not found"

The kernel doesn't have WM8960 support compiled in.

**Solutions:**
1. Use our precompiled kernel (easiest)
2. Recompile kernel with WM8960 enabled
3. Check if you're running the correct kernel: `uname -r`

### Module loads but codec not detected

Check device tree overlay is installed and active:
```bash
# Verify overlay exists
ls -l /boot/dtb-$(uname -r)/allwinner/overlay/sun50i-h618-wm8960-working.dtbo

# Check I2C
i2cdetect -y 2
# Should show device at 0x1a
```

### Kernel compilation fails

**Common issues:**
- Missing dependencies: Install build tools
- Out of disk space: Need ~10GB free
- Wrong architecture: Use `ARCH=arm64`
- Cross-compilation: Use `CROSS_COMPILE=aarch64-linux-gnu-`

## Alternative: Armbian Custom Kernel

If using Armbian instead of Orange Pi OS:

```bash
# Clone Armbian build system
git clone https://github.com/armbian/build
cd build

# Build custom kernel with WM8960
./compile.sh \
    BOARD=orangepi-zero2w \
    BRANCH=current \
    RELEASE=bookworm \
    KERNEL_CONFIGURE=yes \
    BUILD_DESKTOP=no \
    BUILD_MINIMAL=yes
```

In kernel config, enable WM8960 as described above.

## Support

For kernel-related issues:
- Check dmesg: `dmesg | grep -i wm8960`
- Verify config: `zcat /proc/config.gz | grep SND_SOC`
- Module dependencies: `modprobe --show-depends snd_soc_wm8960`

For more help, open an issue on GitHub.
