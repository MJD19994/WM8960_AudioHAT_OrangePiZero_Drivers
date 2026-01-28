# DAUDIO Driver Source Code Search

## Target Driver
**File**: `snd_soc_sunxi_ahub_daudio.ko`  
**Source**: Likely named `sunxi-daudio.c` or `sunxi_ahub_daudio.c`  
**Location**: Should be in `sound/soc/sunxi_v2/` directory

## Known Locations to Check

### 1. Allwinner Official BSP

Allwinner typically releases SDK/BSP separately from mainline:

**Longan SDK (Allwinner official)**:
- Source: https://github.com/allwinner-zh/brandy-2.0
- Download: https://www.allwinnertech.com/ (requires registration)
- Contains: Full BSP including audio drivers

**Check specifically**:
```bash
# If you can access Allwinner SDK
find . -name "*daudio*.c"
find . -path "*/sound/soc/sunxi*" -name "*.c"
```

### 2. Orange Pi Downloads (Direct Source)

Visit Orange Pi wiki and download source code package:
- URL: http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_2W
- Section: "Source Code"
- Download: "Linux Source Code" or "SDK Package"

**After downloading**:
```bash
# Extract and search
tar -xzf OrangePi_Zero2W_source_*.tar.gz
cd linux-source
find . -name "*daudio*"
find . -path "*/sound/soc/sunxi_v2/*" -type f
```

### 3. Tina Linux (Allwinner IoT Distribution)

Allwinner uses "Tina Linux" for embedded devices:
- Based on OpenWrt
- Includes full BSP drivers
- Check: https://github.com/Tina-Linux

### 4. Linux-Sunxi Community

Community-maintained Allwinner resources:
- Wiki: https://linux-sunxi.org/
- Forum: https://forum.armbian.com/forum/12-allwinner-h6-h616/
- May have links to BSP sources

### 5. Orange Pi Forum Archives

Search forum for shared BSP/driver sources:
- URL: http://www.orangepi.org/orangepibbsen/
- Search terms: "H618 audio driver", "DAUDIO driver", "audio BSP"

## Vendor Kernel Detection

Some distributions include vendor kernels. Check these:

### Orange Pi Official OS Images

**Download locations**:
1. Orange Pi Downloads: http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-Pi-Zero-2W.html
2. Orange Pi Google Drive (often has more variants)
3. Orange Pi Baidu Drive (China users)

**Images to test**:
- OrangePi Zero2W Ubuntu/Debian (Official)
- OrangePi Zero2W Android (may have kernel modules)
- Any "BSP" or "Vendor" labeled images

**After flashing to SD card**:
```bash
# Boot the image
# Check for driver
find /lib/modules/$(uname -r) -name "*daudio*"

# If found:
uname -r  # Note kernel version
modinfo /lib/modules/*/kernel/sound/soc/sunxi_v2/*daudio*.ko

# Extract for analysis
sudo cp /lib/modules/*/kernel/sound/soc/sunxi_v2/*daudio*.ko /tmp/
```

### Armbian Build System

Armbian may have patches or know where to get drivers:

```bash
# Clone Armbian build system
git clone https://github.com/armbian/build
cd build

# Search for sunxi audio patches
find . -name "*.patch" | xargs grep -l "daudio\|sunxi.*audio"

# Check board configs
cat config/boards/orangepizero2w.conf
cat config/boards/orangepizero2w.csc

# Look for kernel config fragments
find . -name "*sunxi*.config"
```

## Compilation from BSP Source

### If Source Code Found

**Prerequisites**:
```bash
# On your Orange Pi
sudo apt update
sudo apt install -y \
    linux-headers-$(uname -r) \
    build-essential \
    bc \
    kmod \
    cpio \
    flex \
    bison \
    libssl-dev \
    libelf-dev
```

**Compilation Method 1: Out-of-Tree Module**

If you have just the driver source files:

```bash
# Create module directory
mkdir -p ~/daudio-driver
cd ~/daudio-driver

# Copy source files (adjust names as needed)
# sunxi_ahub_daudio.c
# sunxi_ahub_daudio.h

# Create Makefile
cat > Makefile << 'EOF'
obj-m := snd_soc_sunxi_ahub_daudio.o
snd_soc_sunxi_ahub_daudio-objs := sunxi_ahub_daudio.o

KERNEL_DIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean

install:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules_install
	depmod -a
	modprobe snd_soc_sunxi_ahub_daudio

uninstall:
	modprobe -r snd_soc_sunxi_ahub_daudio
	rm -f /lib/modules/$(shell uname -r)/extra/snd_soc_sunxi_ahub_daudio.ko
	depmod -a
EOF

# Compile
make

# Test load (before install)
sudo insmod snd_soc_sunxi_ahub_daudio.ko

# If successful, install permanently
sudo make install
```

**Compilation Method 2: DKMS (Dynamic Kernel Module Support)**

For automatic recompilation on kernel updates:

```bash
# Install DKMS
sudo apt install dkms

# Create DKMS structure
sudo mkdir -p /usr/src/sunxi-daudio-1.0
cd /usr/src/sunxi-daudio-1.0

# Copy source files
sudo cp ~/path/to/sunxi_ahub_daudio.c .
sudo cp ~/path/to/sunxi_ahub_daudio.h .

# Create dkms.conf
sudo cat > dkms.conf << 'EOF'
PACKAGE_NAME="sunxi-daudio"
PACKAGE_VERSION="1.0"
BUILT_MODULE_NAME[0]="snd_soc_sunxi_ahub_daudio"
DEST_MODULE_LOCATION[0]="/kernel/sound/soc/sunxi_v2/"
AUTOINSTALL="yes"
EOF

# Create Makefile (same as above)
sudo cp ~/daudio-driver/Makefile .

# Add to DKMS
sudo dkms add -m sunxi-daudio -v 1.0

# Build
sudo dkms build -m sunxi-daudio -v 1.0

# Install
sudo dkms install -m sunxi-daudio -v 1.0

# Module will auto-rebuild on kernel updates
```

**Compilation Method 3: Full Kernel Build**

If you need to build the entire kernel with BSP:

```bash
# Download kernel source
git clone https://github.com/orangepi-xunlong/linux-orangepi -b orange-pi-6.x-sun50iw9
cd linux-orangepi

# Copy current config
zcat /proc/config.gz > .config

# Enable DAUDIO (if option exists)
make menuconfig
# Navigate to: Device Drivers > Sound > SoC > Allwinner
# Enable: CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO=m

# Build just the module
make modules_prepare
make M=sound/soc/sunxi_v2

# Install module
sudo cp sound/soc/sunxi_v2/snd_soc_sunxi_ahub_daudio.ko \
    /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/
sudo depmod -a
```

## Cross-Kernel Module Loading

### Can We Use a Module from Different Kernel?

**Generally NO**, but worth trying if:
- Kernel versions very close (e.g., 6.12.66 vs 6.12.67)
- Same kernel config options
- Same compiler version

**Test Method**:
```bash
# Copy module from Orange Pi OS (if found)
sudo cp /path/to/snd_soc_sunxi_ahub_daudio.ko /tmp/

# Check module info
modinfo /tmp/snd_soc_sunxi_ahub_daudio.ko | grep vermagic

# Compare with current kernel
cat /proc/version

# If vermagic matches or close, try loading
sudo insmod /tmp/snd_soc_sunxi_ahub_daudio.ko

# Check if loaded
lsmod | grep daudio
dmesg | tail -20
```

**Force Load** (risky, may crash):
```bash
# Only if desperate
sudo modprobe --force-vermagic /tmp/snd_soc_sunxi_ahub_daudio.ko
```

## Expected File Contents

When you find the source, it should contain:

**Main driver file** (`sunxi_ahub_daudio.c`):
```c
// Key functions to look for:
- sunxi_ahub_daudio_probe()
- sunxi_ahub_daudio_hw_params()
- sunxi_ahub_daudio_trigger()
- sunxi_ahub_daudio_dai_ops

// Platform driver structure:
static struct platform_driver sunxi_ahub_daudio_driver = {
    .probe = sunxi_ahub_daudio_probe,
    .remove = sunxi_ahub_daudio_remove,
    .driver = {
        .name = "sunxi-ahub-daudio",
        .of_match_table = sunxi_ahub_daudio_of_match,
    },
};
```

**Header file** (`sunxi_ahub_daudio.h`):
- Register definitions
- Hardware constants
- Structure definitions

## Immediate Action Plan

Run these commands on your Orange Pi NOW:

```bash
# 1. Check if source is in kernel headers
ls -la /usr/src/linux-headers-$(uname -r)/sound/soc/
find /usr/src/linux-headers-$(uname -r) -name "*daudio*" 2>/dev/null

# 2. Check Kconfig for hints
cat /usr/src/linux-headers-$(uname -r)/sound/soc/sunxi_v2/Kconfig 2>/dev/null

# 3. Check Makefile for compilation rules
cat /usr/src/linux-headers-$(uname -r)/sound/soc/sunxi_v2/Makefile 2>/dev/null

# 4. Search for any daudio references in kernel source
grep -r "ahub.*daudio" /usr/src/linux-headers-$(uname -r)/ 2>/dev/null | head -20

# 5. Check if other boards have similar driver
find /usr/src/linux-headers-$(uname -r) -path "*/sound/soc/*" -name "*i2s*.c"
```

## Priority Actions

1. **Download Orange Pi official source code** (highest priority)
2. **Test Orange Pi official OS image** (may have pre-built driver)
3. **Check Armbian legacy kernel** (may include vendor BSP)
4. **Contact Orange Pi support** (request BSP source)

Once source is found, compilation is straightforward using methods above.
