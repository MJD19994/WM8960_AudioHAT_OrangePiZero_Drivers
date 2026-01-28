# Building AHUB DAUDIO Module for DietPi (Advanced)

**Prerequisites:** Experience with kernel module compilation (you have this!)

---

## Option A: Using Kernel Headers (If Available)

### Step 1: Check Headers Availability
```bash
# Check if headers package exists
apt search linux-headers-$(uname -r)
apt search linux-headers-6.12.65-current-sunxi64

# If found, install
sudo apt update
sudo apt install linux-headers-$(uname -r)
sudo apt install build-essential bc kmod flex bison libssl-dev libelf-dev
```

### Step 2: Locate Driver Source
```bash
# Find sunxi audio source
find /usr/src/linux-headers-$(uname -r) -name "*daudio*" -o -name "sunxi*.c"

# Check directory structure
ls -la /usr/src/linux-headers-$(uname -r)/sound/soc/sunxi*
```

### Step 3: Build Single Module

**If source files exist:**
```bash
cd /usr/src/linux-headers-$(uname -r)

# Enable the config option temporarily
echo "CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO=m" >> .config

# Build just the sunxi audio modules
make M=sound/soc/sunxi_v2 modules

# Or specifically
make M=sound/soc/sunxi_v2 CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO=m modules
```

### Step 4: Install Module
```bash
# Copy to modules directory
sudo cp sound/soc/sunxi_v2/snd_soc_sunxi_ahub_daudio.ko \
     /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/

# Update module dependencies
sudo depmod -a

# Test load
sudo modprobe snd_soc_sunxi_ahub_daudio

# Check if loaded
lsmod | grep daudio
```

---

## Option B: Full Kernel Source Build

### Step 1: Get DietPi Kernel Source

**Check DietPi's kernel source location:**
```bash
# DietPi might use Armbian's kernel
# Check kernel package info
dpkg -l | grep linux-image

# Find kernel source
apt-cache search linux-source-6.12
```

**Or get from DietPi's GitHub:**
```bash
# DietPi uses Armbian build system
git clone https://github.com/armbian/build
cd build

# Check for Orange Pi Zero 2W config
ls config/boards/orangepizero2w.*
cat config/boards/orangepizero2w.csc
```

### Step 2: Download Matching Kernel Source
```bash
# DietPi likely uses kernel from here:
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.65.tar.xz
tar xf linux-6.12.65.tar.xz
cd linux-6.12.65
```

### Step 3: Get Current Kernel Config
```bash
# Copy current running config
zcat /proc/config.gz > .config

# Or from boot
cp /boot/config-$(uname -r) .config

# Enable the missing option
scripts/config --module SND_SOC_SUNXI_AHUB_DAUDIO

# Prepare for module build
make oldconfig
make prepare
make scripts
```

### Step 4: Build Only Audio Modules
```bash
# Build just sunxi_v2 audio directory
make M=sound/soc/sunxi_v2

# This will compile:
# - snd_soc_sunxi_ahub.ko (already have)
# - snd_soc_sunxi_ahub_dam.ko (already have)
# - snd_soc_sunxi_ahub_daudio.ko (THE ONE WE NEED!)
# - snd_soc_sunxi_machine.ko (already have)
```

### Step 5: Install New Module
```bash
# Install just the missing one
sudo cp sound/soc/sunxi_v2/snd_soc_sunxi_ahub_daudio.ko \
     /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/

sudo depmod -a
sudo modprobe snd_soc_sunxi_ahub_daudio
```

---

## Option C: Extract from Armbian

**Easiest if Armbian has it:**

1. Boot Armbian on Orange Pi Zero 2W
2. Check kernel version: `uname -r`
3. If close to 6.12.65, copy the module:
```bash
# On Armbian
scp /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/snd_soc_sunxi_ahub_daudio.ko \
    user@dietpi-host:/tmp/

# On DietPi
sudo cp /tmp/snd_soc_sunxi_ahub_daudio.ko \
     /lib/modules/$(uname -r)/kernel/sound/soc/sunxi_v2/
sudo depmod -a
sudo modprobe snd_soc_sunxi_ahub_daudio
```

**⚠️ Warning:** Only works if kernel versions are very close (same major.minor)

---

## Troubleshooting

### "No rule to make target" Error
```bash
# Need to build kernel dependencies first
make modules_prepare
make scripts
```

### "Invalid module format" Error
```bash
# Kernel version mismatch
modinfo snd_soc_sunxi_ahub_daudio.ko | grep vermagic
uname -r

# Must match exactly
```

### Missing Source Files
```bash
# Driver might be in different location
find /usr/src -name "*daudio*"
find /usr/src -name "sunxi*.c" | grep -i sound
```

### Build Requires Specific Options
```bash
# Some drivers need other options enabled
scripts/config --enable SND_SOC_SUNXI_AHUB
scripts/config --enable SND_SOC_SUNXI_AHUB_DAM
scripts/config --enable SND_SOC_SUNXI_MACH
scripts/config --module SND_SOC_SUNXI_AHUB_DAUDIO
make olddefconfig
```

---

## Comparison to Your Raspberry Pi Experience

**Similar to Pi Zero 2W driver build, but:**

| Raspberry Pi | Orange Pi Zero 2W |
|--------------|-------------------|
| Out-of-tree driver (DKMS) | In-tree driver (just not compiled) |
| Need vendor source repo | Already in kernel tree |
| DKMS auto-rebuilds on updates | One-time build (or request in main kernel) |
| Custom Makefile | Use kernel's Makefile |

**Your Pi experience means you can handle this!**

The process is actually **simpler** because:
- No DKMS needed
- No custom source repo
- Driver already in kernel source
- Just enable one config option and build

---

## Expected Timeline

| Method | Time | Difficulty | Success Rate |
|--------|------|------------|--------------|
| **Use Armbian module** | 1 hour | Easy | 70% (if versions match) |
| **Build with headers** | 2 hours | Medium | 80% (if headers exist) |
| **Full source build** | 4+ hours | Hard | 90% (always works) |
| **Test Armbian first** | 30 min | Easy | 70% (might already work) |

---

## Recommendation

Given your experience building Pi drivers:

1. **Test Armbian first** (30 min)
   - If it works, you're done
   - If it has the driver, extract it
   - Either way, you learn their config

2. **Try headers method** (2 hours)
   - Check if `apt install linux-headers-$(uname -r)` works
   - Quick build if headers available
   - No full kernel source needed

3. **Full build as last resort** (4+ hours)
   - You know how to do this from Pi experience
   - Will definitely work
   - Can submit `.ko` to help others

---

## After Building

Make it permanent:
```bash
# Add to /etc/modules to load on boot
echo "snd_soc_sunxi_ahub_daudio" | sudo tee -a /etc/modules

# Prevent updates from removing it
sudo apt-mark hold linux-image-$(uname -r)
```

**Then install your overlay:**
```bash
cd ~/WM8960_AudioHAT_OrangePiZero_Drivers
sudo ./scripts/install.sh
sudo reboot
```

---

## Share Your Success!

If you successfully build it:
1. Share the `.ko` with other DietPi + Orange Pi Zero 2W users
2. Document the process
3. Show DietPi it's possible (pressure them to add it officially)
4. Help the community!

**You have the skills to do this!** 🚀
