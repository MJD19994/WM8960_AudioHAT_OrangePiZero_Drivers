# Kernel Switching Guide for Orange Pi Zero 2W

## Overview

This guide explains how to switch between kernel flavors (current/legacy/edge) to find one with the missing DAUDIO driver.

## Understanding Kernel Flavors

### DietPi Kernels
- **current**: Mainline-based, latest stable features
- **edge**: Cutting-edge, experimental (may not be available)
- **legacy**: Older, vendor BSP-based (most likely to have DAUDIO)

### Armbian Kernels
- **current**: Mainline-based (6.12.x)
- **edge**: Latest mainline (6.13+)
- **legacy**: Vendor BSP-based (5.x or 6.x with patches)
- **vendor**: Pure Allwinner BSP (if available)

## Why Legacy Kernel May Help

Legacy kernels typically:
- Based on vendor's original BSP (Board Support Package)
- Include proprietary/non-mainlined drivers
- Have full hardware support from manufacturer
- May use older kernel base (5.10, 5.15) with vendor patches

**DAUDIO driver is likely in legacy kernel** because:
- H616/H618 AHUB architecture is not fully mainlined
- Allwinner's BSP includes complete audio stack
- Current kernels are mainline-based, missing vendor drivers

## Method 1: DietPi Kernel Switching

### Check Available Kernels

```bash
# List available kernel packages
apt-cache search linux-image | grep sunxi64

# Check specific flavors
apt-cache policy linux-image-legacy-sunxi64
apt-cache policy linux-image-edge-sunxi64
apt-cache policy linux-image-current-sunxi64
```

### Install Legacy Kernel (Most Promising)

```bash
# Install legacy kernel
sudo apt update
sudo apt install linux-image-legacy-sunxi64 linux-headers-legacy-sunxi64

# Reboot
sudo reboot

# After reboot, verify kernel
uname -r
# Should show something like: 5.15.x-legacy-sunxi64 or 6.1.x-legacy-sunxi64

# Check for DAUDIO driver
find /lib/modules/$(uname -r) -name "*daudio*"

# If found, test audio
sudo modprobe snd_soc_sunxi_ahub_daudio
aplay -l
```

### Install Edge Kernel (If Legacy Unavailable)

```bash
sudo apt update
sudo apt install linux-image-edge-sunxi64 linux-headers-edge-sunxi64
sudo reboot

# After reboot
uname -r
find /lib/modules/$(uname -r) -name "*daudio*"
```

### Switch Between Installed Kernels

If you have multiple kernels installed:

```bash
# List installed kernels
dpkg -l | grep linux-image

# Update bootloader to show menu
# Edit /boot/dietpiEnv.txt
sudo nano /boot/dietpiEnv.txt

# Add or modify:
# console=both

# On next boot, you may see kernel selection menu
# Or manually edit:
sudo nano /boot/boot.cmd
# Change kernel image path
sudo mkimage -C none -A arm64 -T script -d /boot/boot.cmd /boot/boot.scr
```

### Remove Old Kernel (After Testing)

```bash
# If legacy kernel works, remove current
sudo apt remove linux-image-current-sunxi64 linux-headers-current-sunxi64

# Clean up
sudo apt autoremove
```

## Method 2: Armbian Kernel Switching

### Using armbian-config

```bash
# Launch Armbian configuration tool
sudo armbian-config

# Navigate to:
# System → Install → Install kernel

# Options shown:
# - Install current kernel (mainline)
# - Install legacy kernel (vendor BSP)
# - Install edge kernel (latest)

# Select: Install legacy kernel
# Wait for installation
# Reboot when prompted
```

### Manual Installation (Armbian)

```bash
# Search available kernels
apt-cache search linux-image | grep sunxi64

# Install legacy kernel
sudo apt update
sudo apt install linux-image-legacy-sunxi64 linux-headers-legacy-sunxi64 linux-dtb-legacy-sunxi64

# Important: Install DTB package too!
# Device tree binaries must match kernel version

sudo reboot
```

### Armbian Kernel Verification

```bash
# After reboot
uname -r

# Check kernel flavor
cat /etc/armbian-release | grep BRANCH
# Should show: BRANCH=legacy

# Verify DAUDIO driver
find /lib/modules/$(uname -r) -name "*daudio*"
modinfo snd_soc_sunxi_ahub_daudio 2>/dev/null
```

## Method 3: Orange Pi Official OS

If kernel switching doesn't work, try Orange Pi's official OS:

### Download Official Image

1. Visit: http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-2W.html
2. Download: Ubuntu or Debian image (official builds)
3. Flash to SD card:
   ```bash
   # On your computer
   sudo dd if=OrangePi_Zero2W_ubuntu.img of=/dev/sdX bs=4M status=progress
   sync
   ```

### Test for DAUDIO Driver

Boot Orange Pi official OS and check:

```bash
uname -r
find /lib/modules/$(uname -r) -name "*daudio*"

# If found:
ls -lh /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/*daudio*

# Get module info
modinfo snd_soc_sunxi_ahub_daudio

# Try loading
sudo modprobe snd_soc_sunxi_ahub_daudio
dmesg | tail -20
```

### Extract Driver from Official OS

If Orange Pi OS has the driver:

```bash
# On Orange Pi OS (after confirming driver exists)
uname -r  # Note the kernel version
# Example: 6.1.31-sun50iw9

# Copy driver module
cp /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/snd_soc_sunxi_ahub_daudio.ko /tmp/

# Transfer to your computer
scp /tmp/snd_soc_sunxi_ahub_daudio.ko user@your-computer:/path/

# Now flash back to DietPi/Armbian
# Then copy driver to DietPi/Armbian system...
```

## Method 4: Compile Custom Kernel

### Download Orange Pi Kernel Source

```bash
# Clone Orange Pi kernel repository
git clone https://github.com/orangepi-xunlong/linux-orangepi.git
cd linux-orangepi

# List available branches
git branch -r

# Checkout appropriate branch for H618
# (Check Orange Pi wiki for correct branch)
git checkout orange-pi-6.1-sun50iw9
# Or
git checkout orange-pi-5.16-sun50iw9
```

### Check if DAUDIO Source Exists

```bash
# Search for DAUDIO in kernel source
find . -name "*daudio*"

# Check sunxi_v2 directory
ls -la sound/soc/sunxi_v2/

# If DAUDIO source exists:
cat sound/soc/sunxi_v2/Kconfig | grep DAUDIO
cat sound/soc/sunxi_v2/Makefile | grep daudio
```

### Build Just the DAUDIO Module

If source found:

```bash
# On Orange Pi (with kernel headers installed)
cd ~/linux-orangepi

# Use current kernel config as base
zcat /proc/config.gz > .config

# Prepare for module compilation
make modules_prepare

# Build only DAUDIO module
make M=sound/soc/sunxi_v2 CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO=m

# Install the module
sudo cp sound/soc/sunxi_v2/snd_soc_sunxi_ahub_daudio.ko \
    /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/

# Update module dependencies
sudo depmod -a

# Load module
sudo modprobe snd_soc_sunxi_ahub_daudio
```

## Kernel Compatibility Matrix

| Kernel Flavor | Kernel Base | DAUDIO Probability | Hardware Support |
|---------------|-------------|-------------------|------------------|
| DietPi Current | 6.12.x mainline | ❌ Low (0%) | Excellent |
| DietPi Legacy | 5.x-6.1.x BSP | ✅ High (80%) | Excellent |
| Armbian Current | 6.12.x mainline | ❌ Low (0%) | Excellent |
| Armbian Legacy | 5.x-6.1.x BSP | ✅ High (80%) | Excellent |
| Orange Pi Official | 5.x-6.1.x BSP | ✅ Very High (95%) | Complete |

## Troubleshooting

### No Legacy Kernel Available

```bash
# Check if you need to add repositories
cat /etc/apt/sources.list.d/*.list

# For DietPi, may need to enable additional repos
sudo nano /etc/apt/sources.list

# For Armbian, make sure apt-armbian is working
sudo armbian-install
```

### Legacy Kernel Boots But No Audio

```bash
# Check kernel modules
lsmod | grep snd

# Check device tree
ls /boot/dtb/allwinner/

# Ensure overlay is loaded
sudo nano /boot/dietpiEnv.txt
# or
sudo nano /boot/armbianEnv.txt

# Verify overlays line:
overlays=i2c1-pi wm8960-soundcard
```

### Multiple Kernels Conflict

```bash
# Remove all except working kernel
dpkg -l | grep linux-image

# Remove specific kernel
sudo apt remove linux-image-<version>-sunxi64

# Keep only:
# - Working kernel with DAUDIO
# - Corresponding headers
```

## Quick Test Script

Run after switching kernel:

```bash
#!/bin/bash
echo "Kernel: $(uname -r)"
echo "---"
echo "DAUDIO driver:"
find /lib/modules/$(uname -r) -name "*daudio*"
echo "---"
echo "SUNXI audio modules:"
ls /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/ 2>/dev/null || echo "Directory not found"
echo "---"
echo "Loaded modules:"
lsmod | grep -E "snd|sunxi"
echo "---"
echo "AHUB devices:"
find /sys/bus/platform/devices -name "*ahub*" -exec echo {} \; -exec cat {}/modalias \; 2>/dev/null
echo "---"
echo "Sound cards:"
aplay -l 2>/dev/null || echo "No sound cards"
```

Save as `test-kernel.sh` and run: `bash test-kernel.sh`

## Expected Results

### If DAUDIO Found (Success!)

```bash
$ find /lib/modules/$(uname -r) -name "*daudio*"
/lib/modules/5.15.74-legacy-sunxi64/kernel/sound/soc/sunxi_v2/snd_soc_sunxi_ahub_daudio.ko

$ sudo modprobe snd_soc_sunxi_ahub_daudio
$ lsmod | grep daudio
snd_soc_sunxi_ahub_daudio    24576  0
snd_soc_sunxi_ahub          32768  1 snd_soc_sunxi_ahub_daudio

$ aplay -l
card 0: audiocodec [audiocodec], device 0: SUNXI-CODEC sunxi-snd-codec-0 []
  Subdevices: 1/1
  Subdevice #0: subdevice #0
card 1: wm8960soundcard [wm8960-soundcard], device 0: ...
  Subdevices: 1/1
  Subdevice #0: subdevice #0
```

### If DAUDIO Still Missing

Try Orange Pi official OS or contact vendor for BSP source.

## Summary Priority

**Try in this order:**

1. ⭐ **DietPi/Armbian Legacy Kernel** (80% success chance)
2. ⭐ **Orange Pi Official OS** (95% success chance)
3. **Orange Pi Kernel Source** (if you can find it)
4. **Contact Orange Pi** (request BSP/SDK)

Most likely solution: **Legacy kernel** with vendor BSP drivers.
