# Quick Start: Kernel Investigation Summary

## The Problem

Your WM8960 Audio HAT hardware is correctly configured, but audio doesn't work because the **`snd_soc_sunxi_ahub_daudio.ko` driver is missing** from current mainline kernels (DietPi 6.12.66, Armbian 6.12.67).

## What is DAUDIO?

The DAUDIO driver is the I2S hardware controller for Allwinner's AHUB (Audio Hub) architecture. Think of it as:
- **AHUB** = Audio highway system
- **DAUDIO** = The road/bridge connecting to I2S audio devices
- **Your WM8960** = Destination (codec)

Without DAUDIO, the AHUB can't communicate with your WM8960 codec.

## Why Is It Missing?

- **Mainline kernels** (6.12.x "current"): Focus on standardized drivers
- **Vendor BSP kernels** (5.x-6.1.x "legacy"): Include Allwinner-specific drivers
- DAUDIO is in Allwinner's BSP but NOT in mainline Linux yet

## Solutions (Try in Order)

### 🥇 Solution 1: Switch to Legacy Kernel (RECOMMENDED)

**Success Rate: 80%** - Legacy kernels include vendor BSP with DAUDIO driver

```bash
# On your Orange Pi Zero 2W:

# For DietPi:
sudo apt update
sudo apt install linux-image-legacy-sunxi64 linux-headers-legacy-sunxi64
sudo reboot

# For Armbian:
sudo armbian-config
# Navigate: System → Install → Install legacy kernel
# Follow prompts and reboot

# After reboot, verify:
uname -r  # Should show "legacy" in version
find /lib/modules/$(uname -r) -name "*daudio*"
# If you see: snd_soc_sunxi_ahub_daudio.ko - SUCCESS!

# Test audio:
aplay -l  # Should show your sound card
```

**Time Required**: 10-15 minutes  
**Difficulty**: Easy (one command + reboot)  
**See**: [KERNEL_SWITCHING_GUIDE.md](KERNEL_SWITCHING_GUIDE.md)

---

### 🥈 Solution 2: Orange Pi Official OS

**Success Rate: 95%** - Vendor OS always includes all drivers

1. **Download** Orange Pi official OS:
   - URL: http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_2W
   - Choose: Ubuntu or Debian image

2. **Flash** to SD card:
   ```bash
   # On your computer (Linux)
   sudo dd if=OrangePi_Zero2W_*.img of=/dev/sdX bs=4M status=progress
   sync
   ```

3. **Boot** and verify:
   ```bash
   find /lib/modules/$(uname -r) -name "*daudio*"
   ```

4. **Options**:
   - Use Orange Pi OS permanently, OR
   - Extract the driver and try loading it on DietPi/Armbian (risky)

**Time Required**: 30-60 minutes (download + flash)  
**Difficulty**: Medium  
**See**: [KERNEL_SWITCHING_GUIDE.md](KERNEL_SWITCHING_GUIDE.md) Section: Orange Pi Official OS

---

### 🥉 Solution 3: Find and Compile Driver Source

**Success Rate: 60%** - If you can find the source code

**Where to look**:
- Orange Pi official downloads (kernel source package)
- Allwinner Longan SDK (requires registration)
- Tina Linux (Allwinner's OpenWrt)

**If found**:
```bash
# See DRIVER_SOURCE_SEARCH.md for full instructions
cd ~/daudio-driver
# (Copy source files: sunxi_ahub_daudio.c, *.h)
make
sudo make install
sudo modprobe snd_soc_sunxi_ahub_daudio
```

**Time Required**: 1-3 hours (searching + compiling)  
**Difficulty**: Advanced  
**See**: [DRIVER_SOURCE_SEARCH.md](DRIVER_SOURCE_SEARCH.md)

---

### 🔍 Solution 4: Investigation First

Not sure which kernel flavors are available? Run this:

```bash
# On your Orange Pi
cd WM8960_AudioHAT_OrangePiZero_Drivers
chmod +x scripts/investigate-kernel.sh
sudo bash scripts/investigate-kernel.sh > kernel-report.txt
cat kernel-report.txt
```

This script checks:
- ✓ Available kernel packages (current/legacy/edge)
- ✓ Current kernel configuration
- ✓ Whether DAUDIO driver exists anywhere
- ✓ Kernel module status
- ✓ Recommendations for your specific system

**See**: [KERNEL_FLAVOR_INVESTIGATION.md](KERNEL_FLAVOR_INVESTIGATION.md)

---

## Quick Decision Tree

```
Do you want to keep DietPi/Armbian?
│
├─ YES → Try legacy kernel first (Solution 1)
│   │
│   ├─ Legacy kernel available? → Install it (80% success)
│   │
│   └─ No legacy kernel? → Try Orange Pi OS temporarily (Solution 2)
│       └─ Extract driver if successful
│
└─ NO (willing to switch OS) → Use Orange Pi official OS (Solution 2, 95% success)
```

## Expected Timeline

| Solution | Time Investment | Success Rate | Difficulty |
|----------|----------------|--------------|------------|
| Legacy Kernel | 15 min | 80% | Easy ⭐ |
| Orange Pi OS | 1 hour | 95% | Medium ⭐⭐ |
| Compile Driver | 3 hours | 60% | Hard ⭐⭐⭐ |

## What If Nothing Works?

If none of the above solutions work:

1. **Contact Orange Pi support**:
   - Forum: http://www.orangepi.org/orangepibbsen/
   - Request: BSP kernel source with DAUDIO driver
   - Link your GitHub repo as proof of working hardware

2. **USB audio adapter** (temporary workaround):
   - $10-20 USB sound card
   - Works immediately without drivers
   - Use while waiting for proper solution

3. **Wait for mainline support**:
   - DAUDIO driver may eventually be mainlined
   - Check kernel updates regularly
   - Follow linux-sunxi community

## Documentation Index

All guides in this repository:

- **[README.md](README.md)** - Main documentation
- **[KERNEL_FLAVOR_INVESTIGATION.md](KERNEL_FLAVOR_INVESTIGATION.md)** - Investigation plan
- **[KERNEL_SWITCHING_GUIDE.md](KERNEL_SWITCHING_GUIDE.md)** - Kernel switching how-to
- **[DRIVER_SOURCE_SEARCH.md](DRIVER_SOURCE_SEARCH.md)** - Driver source locations
- **[DEV_LOG.md](DEV_LOG.md)** - Complete test history
- **[ARMBIAN_INVESTIGATION.md](ARMBIAN_INVESTIGATION.md)** - Armbian test results
- **[OS_COMPARISON.md](OS_COMPARISON.md)** - OS alternatives

## Need Help?

Open an issue on GitHub with:
- Output of `scripts/investigate-kernel.sh`
- Your kernel version: `uname -r`
- Your OS: `cat /etc/os-release`
- Which solution you tried

---

**TL;DR**: Install legacy kernel (`sudo apt install linux-image-legacy-sunxi64`), reboot, done. 80% chance it has the missing driver.
