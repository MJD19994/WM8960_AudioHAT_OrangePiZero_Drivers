# Community Forum Post Template

Use this template when posting to Orange Pi, Armbian, or Linux-Sunxi forums.

---

## Title
**[H618] Missing snd_soc_sunxi_ahub_daudio driver for external I2S audio**

---

## Post Body

### Summary
I'm trying to use a WM8960 Audio HAT (I2S codec) on Orange Pi Zero 2W (H618), but the required AHUB DAUDIO driver is missing from all available kernels (DietPi, Armbian, Orange Pi OS).

### Hardware
- **Board**: Orange Pi Zero 2W (Allwinner H618 / sun50iw9)
- **Audio HAT**: Keyestudio ReSpeaker 2-Mic HAT (WM8960 codec via I2S)
- **Connection**: I2C bus 2 (codec control), GPIO PI0-PI4 (I2S audio)

### What Works ✅
- WM8960 codec detected on I2C at address 0x1a
- Device tree overlay loads successfully
- AHUB infrastructure present (`ahub1_plat`, `ahub_dam_plat`)
- Internal codec works (audiocodec)
- HDMI audio works (ahubhdmi)
- Pin configuration correct

### The Problem ❌
**Missing driver**: `snd_soc_sunxi_ahub_daudio.ko`

This driver is the I2S hardware controller that bridges AHUB to external I2S devices. Without it, AHUB cannot route audio to the physical I2S pins (PI0-PI4).

### Kernels Tested

| Distribution | Kernel Version | DAUDIO Driver | Notes |
|-------------|----------------|---------------|-------|
| DietPi | 6.12.66-current-sunxi64 | ❌ Not found | Mainline-based |
| Armbian | 6.12.67-current-sunxi64 | ❌ Not found | Mainline-based |
| Orange Pi OS | 6.1.31-sun50iw9 | ❌ Not found | Vendor BSP |

**Config check:**
```bash
zcat /proc/config.gz | grep DAUDIO
# Result: (empty - not configured)

find /lib/modules/$(uname -r) -name "*daudio*"
# Result: (empty - no driver)
```

**Source check** (on 6.1.31-sun50iw9):
```bash
find /usr/src/linux-headers-* -name "*daudio*"
# Result: (empty - source not in tree)
```

### Device Tree Status

Created device tree overlay targeting AHUB I2S:
```
fragment@3 {
    target-path = "/soc/ahub-i2s1@5097000";
    __overlay__ {
        status = "okay";
        pinctrl-0 = <&i2s0_wm8960_pins &i2s0_wm8960_dout &i2s0_wm8960_din>;
        pinctrl-names = "default";
    };
};
```

**Result**: Device created but no driver binding
```bash
ls /sys/bus/platform/devices/ | grep ahub
# Shows: ahub1_plat, ahub_dam_plat
# Missing: ahub-i2s1 (or similar external I2S device)
```

**dmesg**: No errors, no driver probe attempts

### Architecture Understanding

H618 uses AHUB (Audio Hub) architecture:
```
┌─────────────────────────────────────────┐
│              AHUB (Audio Hub)           │
├─────────────────────────────────────────┤
│  ✅ Internal Codec Path (working)       │
│  ✅ HDMI Audio Path (working)           │
│  ❌ External I2S Path (DAUDIO missing)  │
└─────────────────────────────────────────┘
```

The DAUDIO driver controls the I2S hardware interface for external devices. Without it, there's no path from AHUB to the GPIO pins.

### Questions

1. **Does the DAUDIO driver exist anywhere?**
   - Orange Pi internal SDK?
   - Allwinner Longan/Tina SDK?
   - Older kernel versions (5.4.x)?
   - Chinese-only releases?

2. **Is external I2S audio supported on H618?**
   - Are there any working examples?
   - Is this a hardware limitation or just missing software?

3. **How can we get the driver?**
   - Source code access?
   - Pre-compiled module?
   - Documentation to write our own?

### Repository
Complete investigation with device tree overlays, scripts, and documentation:
https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers

### Additional Context

**AHUB modules present:**
```bash
ls /lib/modules/6.1.31-sun50iw9/kernel/sound/soc/sunxi_v2/
# Result: (empty - no modules, all built-in)

lsmod | grep sunxi
# Shows: sunxi_cir, sunxi_cedrus (non-audio)
```

**Kernel symbols:**
```bash
cat /proc/kallsyms | grep daudio
# Result: (empty - no DAUDIO symbols)
```

**Working sound cards:**
```bash
aplay -l
# card 0: audiocodec (internal)
# card 2: ahubhdmi (HDMI audio)
# Missing: card for external I2S device
```

### What I've Tried

1. ✅ Created correct device tree overlays for H618 AHUB
2. ✅ Configured I2C and GPIO pins correctly
3. ✅ Tested on multiple kernel versions
4. ✅ Searched GitHub repositories (orangepi-xunlong, armbian)
5. ✅ Analyzed kernel source trees
6. ✅ Tested both DietPi and Orange Pi OS
7. ❌ Cannot find DAUDIO driver anywhere

### Request

Can someone from Orange Pi or Allwinner confirm:
- Does the DAUDIO driver exist in your internal SDK?
- Will it be released publicly?
- Is external I2S audio officially supported on H618?
- Any alternative way to enable I2S audio?

Or if anyone in the community has:
- Found this driver
- Got external I2S working on H618
- Access to Allwinner SDK with this driver

Please share! This would help many people trying to use audio HATs on H616/H618 boards.

### Thank You

Any help or information would be greatly appreciated. I'm happy to test patches, beta drivers, or help with documentation.

---

**Links:**
- GitHub Repo: https://github.com/MJD19994/WM8960_AudioHAT_OrangePiZero_Drivers
- Orange Pi Zero 2W Wiki: http://www.orangepi.org/orangepiwiki/index.php/Orange_Pi_Zero_2W
- Linux-Sunxi H618: https://linux-sunxi.org/H618
