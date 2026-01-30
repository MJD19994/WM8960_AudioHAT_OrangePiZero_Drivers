# Orange Pi Zero 2W - Device Tree Analysis Results

**Date**: January 28, 2026  
**File Analyzed**: `/tmp/dtb-analysis.dts` (decompiled from Orange Pi OS 6.1.31-sun50iw9)

---

## Critical Discovery

**The Orange Pi Zero 2W device tree ONLY defines AHUB for internal use (DAM and HDMI), NOT for external I2S audio devices.**

This means:
1. Even if the DAUDIO driver existed, it has **no device tree nodes to bind to**
2. The hardware routing is **intentionally configured** for HDMI only
3. External I2S is **NOT exposed** in the device tree

---

## AHUB Instances Found

### 1. ahub_dam_plat@5097000
**Purpose**: Digital Audio Manager (DAM) - audio routing/mixing

```dts
ahub_dam_plat@5097000 {
    #sound-dai-cells = <0x00>;
    compatible = "allwinner,sunxi-snd-plat-ahub_dam";
    reg = <0x5097000 0x1000>;
    resets = <0x02 0x25>;
    clocks = <0x02 0x5b 0x02 0x5c 0x02 0x5e 0x02 0x5f>;
    clock-names = "clk_pll_audio", "clk_pll_audio_4x", 
                  "clk_audio_hub", "clk_bus_audio_hub";
    status = "okay";
};

ahub_dam_mach {
    compatible = "allwinner,sunxi-snd-mach";
    soundcard-mach,name = "ahubdam";
    status = "okay";
    
    soundcard-mach,cpu {
        sound-dai = <ahub_dam_plat>;
    };
    soundcard-mach,codec {
        /* Empty - no codec specified */
    };
};
```

**Status**: ✅ Working (for internal audio routing)

---

### 2. ahub1_plat (HDMI Audio)
**Purpose**: HDMI audio output via AHUB

```dts
ahub1_plat {
    #sound-dai-cells = <0x00>;
    compatible = "allwinner,sunxi-snd-plat-ahub";
    apb_num = <0x01>;
    dmas = <0x24 0x04 0x24 0x04>;
    dma-names = "tx", "rx";
    playback_cma = <0x80>;
    capture_cma = <0x80>;
    tx_fifo_size = <0x80>;
    rx_fifo_size = <0x80>;
    tdm_num = <0x01>;
    tx_pin = <0x00>;
    rx_pin = <0x00>;
    status = "okay";
};

ahub1_mach {
    compatible = "allwinner,sunxi-snd-mach";
    soundcard-mach,name = "ahubhdmi";
    soundcard-mach,format = "i2s";
    soundcard-mach,frame-master = <ahub1_cpu>;
    soundcard-mach,bitclock-master = <ahub1_cpu>;
    soundcard-mach,slot-num = <0x02>;
    soundcard-mach,slot-width = <0x20>;
    status = "okay";
    
    soundcard-mach,cpu {
        sound-dai = <ahub1_plat>;
        soundcard-mach,pll-fs = <0x04>;
        soundcard-mach,mclk-fs = <0x00>;
    };
    soundcard-mach,codec {
        sound-dai = <hdmi_codec>;  /* HDMI as codec */
    };
};
```

**Status**: ✅ Working (HDMI audio functional)

**Properties**:
- APB bus: 1
- DMA channels: tx and rx (channel 4)
- TDM channels: 1
- TX/RX pins: 0 (internal routing)
- Format: I2S
- Slots: 2 channels, 32-bit width

---

## What's MISSING

### NO External I2S Nodes

**Expected but NOT found:**
- `ahub2_plat` - Would be for external I2S device 2
- `ahub3_plat` - Would be for external I2S device 3  
- `ahub-i2s1@...` - External I2S controller 1
- `ahub-i2s2@...` - External I2S controller 2
- `ahub-i2s3@...` - External I2S controller 3

**Comparison with DietPi/Armbian DTB** (from earlier tests):
- DietPi/Armbian DTBs **DO** have: `ahub-i2s1@5097000`, `ahub-i2s2@...`, `ahub-i2s3@...`
- Orange Pi OS DTB **DOES NOT** have these nodes
- Orange Pi uses completely different structure: `ahub1_plat` instead of `ahub-i2s1@...`

---

## Compatible Strings

Orange Pi uses **vendor-specific** compatible strings:

```
"allwinner,sunxi-snd-plat-ahub_dam"  ← DAM platform
"allwinner,sunxi-snd-plat-ahub"      ← AHUB platform
"allwinner,sunxi-snd-mach"           ← Machine driver
```

These are **NOT** in mainline Linux. They require vendor drivers:
- `snd_soc_sunxi_ahub_dam.ko` ✅ (present, built-in)
- `snd_soc_sunxi_ahub.ko` ✅ (present, built-in)
- `snd_soc_sunxi_machine.ko` ✅ (present, built-in)
- `snd_soc_sunxi_ahub_daudio.ko` ❌ (MISSING)

---

## Clock Configuration

AHUB uses these clocks:
```
clk_pll_audio        - PLL Audio main clock
clk_pll_audio_4x     - PLL Audio 4x multiplier
clk_audio_hub        - Audio Hub clock
clk_bus_audio_hub    - Audio Hub bus clock
```

All clocks are **configured and enabled** in the DAM node.

---

## I2C Configuration (Working)

From `/boot/orangepiEnv.txt`:
```
overlays=pi-i2c1 wm8960-orangepi
```

I2C overlay successfully loaded:
- I2C bus 3 exposed: `/dev/i2c-3`
- WM8960 detected on I2C bus 2: address `0x1a`
- I2C communication: ✅ Working

---

## Pin Configuration

From earlier pinctrl investigation, I2S pins on PI0-PI4:
- PI0: I2S_BCLK (bit clock)
- PI1: I2S_LRCK (left/right clock)  
- PI2: I2S_DOUT (data out)
- PI3: I2S_DIN (data in)
- PI4: I2S_MCLK (master clock)

**Problem**: Pins are multiplexed but **no device tree node configures them for external I2S**

---

## Implications

### Why External I2S Doesn't Work

1. **No device tree nodes** for external AHUB I2S controllers
2. **No driver binding points** - DAUDIO driver (if it existed) has nothing to attach to
3. **Pins not configured** - Device tree doesn't set PI0-PI4 for external I2S use
4. **Intentional design** - Orange Pi OS DTB only enables HDMI audio, not external I2S

### What Would Be Needed

To enable external I2S, Orange Pi would need to:

1. **Add device tree nodes** like:
   ```dts
   ahub2_plat {
       compatible = "allwinner,sunxi-snd-plat-ahub";
       /* ... configuration ... */
       status = "okay";
   };
   
   ahub2_mach {
       compatible = "allwinner,sunxi-snd-mach";
       soundcard-mach,name = "wm8960";
       /* ... configuration ... */
       
       soundcard-mach,codec {
           sound-dai = <&wm8960_codec>;
       };
   };
   ```

2. **Include DAUDIO driver** in kernel or as module

3. **Configure pinmux** for PI0-PI4 as I2S function

4. **Enable in DTB** with `status = "okay"`

### Why This Wasn't Done

Possible reasons:
1. **Cost saving** - Reduce kernel/DTB complexity for unused features
2. **Product focus** - Zero 2W marketed for basic computing, not audio
3. **Driver licensing** - DAUDIO driver may have issues preventing public release
4. **Market segmentation** - Reserve audio features for higher-end boards
5. **Testing** - External I2S not validated/tested on this hardware

---

## Comparison: DietPi vs Orange Pi OS

| Feature | DietPi/Armbian | Orange Pi OS |
|---------|----------------|--------------|
| AHUB nodes | ahub-i2s1@5097000, ahub-i2s2@..., ahub-i2s3@... | ahub1_plat only |
| External I2S | Nodes exist but no driver | No nodes, no driver |
| HDMI Audio | Via ahub-i2s + HDMI | Via ahub1_plat + HDMI |
| Compatible | Standard "allwinner,sun..." | Vendor "sunxi-snd-plat" |
| DAUDIO driver | Missing | Missing |
| Result | Deferred probe pending | No device to probe |

**Both fail**, but for different reasons:
- **DietPi/Armbian**: Device nodes exist, driver missing
- **Orange Pi OS**: Driver missing AND no device nodes

---

## Conclusion

The Orange Pi Zero 2W running Orange Pi OS is **fundamentally configured** for HDMI audio only. External I2S support would require:

1. ✅ Hardware capability (exists - H618 has AHUB I2S)
2. ❌ Device tree nodes (NOT present in Orange Pi OS DTB)
3. ❌ DAUDIO driver (missing from all tested kernels)
4. ❌ Pin configuration (not set up for external I2S)

**Status**: External I2S audio on Orange Pi Zero 2W is **NOT SUPPORTED** by official Orange Pi OS.

**Next step**: Check Google Drive source to see if device tree source and/or DAUDIO driver exist in the vendor SDK.

---

**Generated from**: `/tmp/dtb-analysis.dts`  
**Board**: Orange Pi Zero 2W  
**SoC**: Allwinner H618 (sun50iw9)  
**OS**: Orange Pi OS 6.1.31-sun50iw9  
**Date**: January 28, 2026
