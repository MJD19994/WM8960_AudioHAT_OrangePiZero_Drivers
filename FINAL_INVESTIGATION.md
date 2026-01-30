# Final Exhaustive Investigation - DAUDIO Driver Search

**Goal**: Absolutely confirm whether the DAUDIO driver exists anywhere before purchasing alternative hardware.

**Date Started**: January 28, 2026  
**Status**: IN PROGRESS

---

## Investigation Checklist

### 1. Orange Pi Official Source Packages 🔥 **CRITICAL**

**FOUND**: Orange Pi stores source code on **Google Drive**!
**URL**: https://drive.google.com/drive/folders/1vsbWC8RqeLDxNBWgYmiKxOYcF6l9iJq1

**What to check:**
- Kernel source packages (tar.gz files)
- SDK packages
- BSP (Board Support Package) downloads
- Build system tools

**Actions:**
- [x] Found: Google Drive source location
- [ ] Download: Linux Source Code package from Drive
- [ ] Search inside: `sound/soc/sunxi_v2/` for `*daudio*` files
- [ ] Check: Device tree source for disabled ahub2/ahub3 nodes

**Commands to run after download:**
```bash
tar -xzf [downloaded-package].tar.gz
cd linux-*/

# Search for DAUDIO driver
find . -name "*daudio*"
find . -path "*/sound/soc/sunxi_v2/*" -name "*.c"

# Check device tree source
cat arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero2w.dts | grep -A 20 "ahub"
```

**See detailed instructions**: [GOOGLE_DRIVE_SOURCE_CHECK.md](GOOGLE_DRIVE_SOURCE_CHECK.md)

---

### 2. Orange Pi OS - 5.4 Kernel Version ✅ **CHECKED**

**Result**: NO 5.4 kernel available

**What we found:**
- Only ONE kernel version: `linux-image-next-sun50iw9 6.1.31`
- No legacy/edge kernel flavors
- No alternative kernel versions in APT repository

**Commands run:**
```bash
apt search linux-image | grep orangepi
# Result: Only 6.1.31-sun50iw9 available

dpkg -l | grep linux-image
# Result: ii  linux-image-next-sun50iw9  1.0.2  arm64
```

**Conclusion**: Orange Pi OS only provides single kernel version. No alternative kernels to test.

---

### 3. Check Orange Pi Repositories ⏳

**What to check:**
APT repositories might have additional packages not visible in default search.

**On Orange Pi, run:**
```bash
# Check for kernel module packages
apt search linux-modules | grep orangepi
apt search sunxi | grep audio
apt search alsa | grep sunxi

# Check for firmware packages
apt search firmware | grep orangepi

# Check for extra modules
dpkg -l | grep -E "linux-modules|kernel-modules"
```

---

### 4. Allwinner Official SDK 🔍

**What to check:**
Allwinner provides SDKs that vendors use. May require registration.

**Resources:**
- Allwinner official site: https://www.allwinnertech.com/
- Look for: Tina Linux SDK
- Look for: Longan SDK
- Check: H618 / sun50iw9 specific packages

**Notes:**
- May require business registration
- SDK might be China-only
- Could be paywalled or NDA-required

**Action:** Check if download is possible without business account

---

### 5. Linux-Sunxi Community 🔍

**What to check:**
Community wiki and mailing list archives.

**Resources to search:**

**A. Linux-Sunxi Wiki:**
- https://linux-sunxi.org/H618
- https://linux-sunxi.org/AHUB
- Search for: I2S, DAUDIO, audio

**B. Linux-Sunxi Mailing List:**
- https://groups.google.com/g/linux-sunxi
- Search: "H618 audio", "AHUB I2S", "DAUDIO", "sun50iw9 audio"

**C. IRC/Matrix:**
- #linux-sunxi on OFTC
- Ask about H618 AHUB DAUDIO driver

---

### 6. Armbian Build System 🔍

**What to check:**
Armbian build scripts might have patches or know where to get drivers.

**Actions:**
```bash
# Clone Armbian build repository
git clone https://github.com/armbian/build.git --depth 1
cd build

# Search for DAUDIO patches
find . -name "*.patch" | xargs grep -l "daudio"
find . -name "*.patch" | xargs grep -l "ahub.*i2s"

# Check H618 board configs
cat config/boards/orangepizero2w.conf
cat config/boards/orangepizero2w.csc

# Check kernel patches directory
ls patch/kernel/archive/sunxi-*/ | grep -i audio
ls patch/kernel/sunxi-current/ | grep -i audio
```

---

### 7. Chinese Forums & Resources 🔍

**What to check:**
Orange Pi has stronger presence in Chinese-speaking community.

**Resources:**

**A. Baidu Forums:**
- Search: "全志 H618 音频" (Allwinner H618 audio)
- Search: "香橙派 Zero 2W I2S" (Orange Pi Zero 2W I2S)

**B. Chinese CSDN Blog:**
- https://blog.csdn.net/
- Search: "H618 DAUDIO", "sun50iw9 音频驱动"

**C. GitHub Issues (Chinese):**
- Search orangepi-xunlong issues in Chinese
- Check closed issues for audio problems

**D. WeChat/QQ Groups:**
- Orange Pi official groups might have information
- Technical discussions may reference driver availability

---

### 8. Reverse Engineering Attempt 🔬

**What to check:**
Can we understand AHUB from HDMI path and replicate for I2S?

**On Orange Pi, gather info:**
```bash
# Check AHUB HDMI configuration
cat /sys/bus/platform/devices/soc:ahub1_mach/uevent
cat /sys/bus/platform/devices/soc:ahub1_plat/uevent

# Check kernel symbols for AHUB functions
cat /proc/kallsyms | grep ahub | sort

# Decompile DTB to see AHUB structure
dtc -I dtb -O dts /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb > /tmp/dtb.dts
grep -A 50 "ahub" /tmp/dtb.dts

# Check loaded modules
lsmod | grep -E "snd|ahub"

# Get module information
modinfo snd_soc_sunxi_ahub 2>/dev/null
modinfo snd_soc_sunxi_machine 2>/dev/null
```

**Analysis needed:**
- Can we see AHUB register addresses?
- Is there enough info to write a basic I2S driver?
- Are there kernel functions we can call directly?

---

### 9. Alternative Allwinner SoC Comparison 🔍

**What to check:**
Do other Allwinner SoCs with AHUB have DAUDIO in mainline?

**Check mainline kernel:**
```bash
# On dev machine or Orange Pi
git clone --depth 1 https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
cd linux

# Search for AHUB DAUDIO in any Allwinner SoC
find sound/soc/sunxi* -name "*daudio*" 2>/dev/null
find sound/soc/sunxi* -name "*ahub*" 2>/dev/null
grep -r "ahub.*daudio" sound/soc/ 2>/dev/null
grep -r "sunxi.*ahub.*i2s" sound/soc/ 2>/dev/null

# Check device tree for AHUB
find arch/arm64/boot/dts/allwinner/ -name "*.dts*" | xargs grep -l "ahub"
```

**If found:** Check if it can be ported to H618

---

### 10. Community Help Request 📢

**What to do:**
Post comprehensive question to multiple forums with all findings.

**Forums to post on:**
- [ ] Orange Pi Forum: http://www.orangepi.org/orangepibbsen/
- [ ] Armbian Forum: https://forum.armbian.com/
- [ ] Linux-Sunxi Mailing List
- [ ] Reddit: r/OrangePI
- [ ] GitHub Issue: orangepi-xunlong/linux-orangepi

**Post template created:** See COMMUNITY_POST_TEMPLATE.md

---

## Current Findings Summary

### ✅ Completed Investigations

**Device Tree Analysis (CRITICAL DISCOVERY):**
```
DTB decompiled and analyzed: /tmp/dtb-analysis.dts

AHUB Instances Found:
1. ahub_dam_plat@5097000 - Digital Audio Manager (DAM)
   Compatible: "allwinner,sunxi-snd-plat-ahub_dam"
   Sound card: "ahubdam"
   
2. ahub1_plat - HDMI Audio Path
   Compatible: "allwinner,sunxi-snd-plat-ahub"
   Sound card: "ahubhdmi"
   DMA channels: tx/rx
   Status: okay (working - HDMI audio functional)

MISSING: ahub2, ahub3, or any external I2S nodes!
```

**Smoking Gun**: The device tree **intentionally** only defines AHUB for DAM and HDMI. 
**No nodes exist** for external I2S devices. Even if DAUDIO driver existed, it has nothing to bind to.

**Kernel Availability:**
- ❌ Only 6.1.31-sun50iw9 available
- ❌ No 5.4 kernel option
- ❌ No legacy/edge flavors

**Google Drive Source:**
- ✅ Found: Orange Pi stores source on Google Drive
- ⏳ Pending: Download and check for DAUDIO source code

---

### Confirmed Missing (Tested):
- ❌ DietPi 6.12.66-current-sunxi64
- ❌ Armbian 6.12.67-current-sunxi64  
- ❌ Orange Pi OS 6.1.31-sun50iw9
- ❌ GitHub orangepi-xunlong/linux-orangepi (all branches)
- ❌ Armbian legacy kernel (boot failure on DietPi)

### Confirmed Working:
- ✅ Hardware: WM8960 detected on I2C bus 2
- ✅ Device tree overlays: Load correctly
- ✅ I2C configuration: Working
- ✅ Pin configuration: Correct
- ✅ AHUB infrastructure: Present and working (HDMI audio proof)

### Outstanding Questions:
1. Does Orange Pi official source package have DAUDIO code?
2. Does 5.4 kernel version have it?
3. Is there a Chinese-only release with the driver?
4. Can we reverse engineer from HDMI audio path?
5. Does any Allwinner SoC have DAUDIO in mainline that we can port?

---

## Investigation Timeline

**Immediate (Today):**
- Check Orange Pi website for source downloads
- Search Chinese forums
- Check linux-sunxi wiki

**Short-term (This Week):**
- Try Orange Pi OS 5.4 kernel if available
- Clone Armbian build system and search patches
- Post on community forums

**Medium-term (2 weeks):**
- Wait for community responses
- Check if Allwinner SDK accessible
- Attempt reverse engineering analysis

---

## Decision Point

After completing this investigation, we will know:
1. ✅ **Driver exists somewhere** → Compile and use it
2. ❌ **Driver doesn't exist publicly** → Consider:
   - Alternative hardware (Radxa Zero 2/3)
   - USB audio adapter workaround
   - Wait for community/vendor to release driver
   - Community-funded reverse engineering effort

---

## Progress Tracking

| Check | Status | Findings | Date |
|-------|--------|----------|------|
| Official Source Package | ⏳ Pending | - | - |
| OS 5.4 Kernel | ⏳ Pending | - | - |
| APT Repository Search | ⏳ Pending | - | - |
| Allwinner SDK | ⏳ Pending | - | - |
| Linux-Sunxi Wiki/ML | ⏳ Pending | - | - |
| Armbian Build Patches | ⏳ Pending | - | - |
| Chinese Forums | ⏳ Pending | - | - |
| Reverse Engineering | ⏳ Pending | - | - |
| Mainline Comparison | ⏳ Pending | - | - |
| Community Posts | ⏳ Pending | - | - |

---

**Next Update:** After completing investigations 1-3 (Orange Pi sources)
