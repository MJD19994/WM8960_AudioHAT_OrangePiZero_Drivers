# DietPi Kernel Issue: Missing AHUB DAUDIO Driver for H618 Audio

**Hardware:** Orange Pi Zero 2W (Allwinner H618)  
**Audio HAT:** Keyestudio ReSpeaker 2-Mic HAT (WM8960 codec)  
**DietPi Version:** Latest (as of 2026-01-27)  
**Kernel:** 6.12.65-current-sunxi64  
**Issue:** H618 AHUB audio support incomplete - missing I2S controller driver

---

## Problem Summary

The H618 SoC uses AHUB (Audio Hub) architecture for audio. DietPi's kernel includes most AHUB infrastructure but is **missing the critical I2S controller driver** (`snd_soc_sunxi_ahub_daudio`), making external audio codecs unusable.

## Current Kernel Module Status

### ✅ Present in DietPi Kernel
```bash
$ ls /lib/modules/6.12.65-current-sunxi64/kernel/sound/soc/sunxi_v2/
snd_soc_sunxi_ahub.ko          # AHUB core infrastructure
snd_soc_sunxi_ahub_dam.ko      # Digital Audio Mixer
snd_soc_sunxi_machine.ko       # Machine driver
```

### ❌ Missing from DietPi Kernel
```
snd_soc_sunxi_ahub_daudio.ko   # I2S hardware controller driver
```

## Kernel Configuration Analysis

### Current Config
```bash
$ zcat /proc/config.gz | grep -i ahub
CONFIG_SND_SOC_SUNXI_AHUB_DAM=m      ✅ Enabled
CONFIG_SND_SOC_SUNXI_AHUB=m          ✅ Enabled
CONFIG_SND_SOC_SUNXI_MACH=m          ✅ Enabled

$ zcat /proc/config.gz | grep -i daudio
# (no output - driver not configured)
```

### Missing Config Option
```
CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO=m   ❌ NOT PRESENT
```

## H618 Device Tree Verification

The H618 base device tree **only has AHUB nodes** (no standard I2S):

```bash
$ dtc -I dtb -O dts /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb | grep -E "i2s|ahub"
ahub-i2s1@5097000 {              # AHUB I2S port 1
ahub-i2s2@5097000 {              # AHUB I2S port 2
ahub-i2s3@5097000 {              # AHUB I2S port 3
```

**No standard `i2s0@`, `i2s1@`, or `i2s2@` nodes exist** - H618 is AHUB-only architecture.

## Working Configuration Proof

### Hardware Setup
- ✅ I2C bus 3 configured and operational
- ✅ WM8960 codec detected at address 0x1a
- ✅ Device tree overlay loads successfully
- ✅ All AHUB hardware nodes created
- ✅ Pin multiplexing configured correctly

### Loaded Modules
```bash
$ lsmod | grep snd_soc
snd_soc_wm8960         57344  0          # WM8960 codec driver
snd_soc_sunxi_machine  20480  0          # Machine driver loaded
snd_soc_sunxi_ahub     32768  0          # AHUB core loaded
snd_soc_sunxi_ahub_dam 20480  1          # DAM loaded
```

### Device Status
```bash
$ ls -la /sys/bus/platform/devices/5097000.ahub-i2s1
drwxr-xr-x 4 root root    0 Jan 24 05:55 .
# Device exists but...

$ cat /sys/bus/platform/devices/5097000.ahub-i2s1/uevent
DRIVER=                                   # No driver bound!
MODALIAS=of:Nahub-i2s1T(null)Callwinner,sunxi-ahub-daudio

$ dmesg | grep deferred
platform soc:wm8960-sound: deferred probe pending
# Waiting forever for missing driver
```

### I2C Detection
```bash
$ i2cdetect -y 3
     0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
10: -- -- -- -- -- -- -- -- -- -- UU -- -- -- -- --   # WM8960 at 0x1a
```

## What's Working vs Missing

| Component | Status | Evidence |
|-----------|--------|----------|
| I2C communication | ✅ Working | WM8960 detected at 0x1a |
| WM8960 codec driver | ✅ Working | Module loaded, probed successfully |
| AHUB infrastructure | ✅ Working | Core modules loaded |
| AHUB hardware nodes | ✅ Created | `/sys/bus/platform/devices/5097000.ahub-i2s1` exists |
| Device tree overlay | ✅ Working | Loads without errors |
| Pin configuration | ✅ Working | PI0-PI4 configured as i2s0 functions |
| **AHUB I2S driver** | ❌ **MISSING** | **No driver to bind to ahub-i2s1 device** |

## Impact

**All H618 external audio codecs are unusable** on DietPi because:
1. H618 only has AHUB audio hardware (no standard I2S)
2. AHUB requires the DAUDIO driver to control the I2S hardware
3. Without this driver, sound cards remain in "deferred probe" state forever

## Request

**Please enable the AHUB DAUDIO driver in DietPi's kernel build:**

Add to kernel config:
```
CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO=m
```

This will compile the missing `snd_soc_sunxi_ahub_daudio.ko` module and complete the AHUB audio stack.

## References

- **Test Repository:** https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers
- **Working Overlay:** [sun50i-h616-wm8960-soundcard.dts](https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers/blob/copilot/add-drivers-for-respeaker-hat/overlays/sun50i-h616-wm8960-soundcard.dts)
- **Investigation Log:** [ARMBIAN_INVESTIGATION.md](https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers/blob/copilot/add-drivers-for-respeaker-hat/ARMBIAN_INVESTIGATION.md)

## Technical Details

### Compatible String
The missing driver needs to match:
```
compatible = "allwinner,sunxi-ahub-daudio"
```

### Expected Behavior After Fix
Once enabled, the driver will:
1. Bind to `ahub-i2s1@5097000` device
2. Register as an I2S DAI (Digital Audio Interface)
3. Allow sound card probe to complete
4. Enable audio playback/capture via external codecs

### Verification Command
After kernel update with the driver:
```bash
lsmod | grep daudio
# Should show: snd_soc_sunxi_ahub_daudio
```

---

## Appendix: Full Module List

### sunxi_v2 Directory (Current)
```bash
$ ls -la /lib/modules/6.12.65-current-sunxi64/kernel/sound/soc/sunxi_v2/
snd_soc_sunxi_ahub.ko       58112 bytes
snd_soc_sunxi_ahub_dam.ko   32992 bytes
snd_soc_sunxi_machine.ko    37744 bytes
# snd_soc_sunxi_ahub_daudio.ko - MISSING!
```

### Related Kernel Config (Full)
```bash
CONFIG_SND_SOC_SUNXI_AHUB_DAM=m
CONFIG_SND_SOC_SUNXI_AHUB=m
CONFIG_SND_SOC_SUNXI_MACH=m
CONFIG_SND_SOC_SUNXI_INTERNALCODEC=m
CONFIG_SND_SOC_SUNXI_SUN50IW9_CODEC=m
CONFIG_SND_SOC_SUNXI_AAUDIO=m
# CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO - MISSING!
```

---

## Conclusion

This is a **kernel packaging issue** rather than a hardware or configuration problem. Everything else is correctly set up and ready to work. Enabling `CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO` in the next DietPi kernel build will complete the H618 audio support and enable external audio HATs to function.

**The driver source exists in the kernel tree** (evidenced by other AHUB modules being present) - it just needs to be enabled in the build configuration.
