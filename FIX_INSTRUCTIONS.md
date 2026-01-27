# Fix Instructions for WM8960 Driver

## Executive Summary

The WM8960 codec **is detected on I2C** (confirmed at 0x1a on bus 3), and the kernel module loads successfully. However, **the device tree overlays are not loading** because they target non-existent device tree paths.

**Root Cause**: The overlays use `/soc@3000000/...` paths, but the actual H618 device tree uses `/soc/...` paths. Additionally, the H618 uses **AHUB (Audio Hub)** architecture, not simple I2S.

---

## Critical Fixes Required

### Fix 1: Correct Device Tree Paths in Both Overlays

**Files to fix:**
- `overlays/sun50i-h618-wm8960-soundcard.dts`
- `overlays/sun50i-h618-wm8960-soundcard-i2s3.dts`

**Changes needed:**

```diff
# In all fragments, change:
- target-path = "/soc@3000000/pinctrl@300b000";
+ target-path = "/soc/pinctrl@300b000";

- target-path = "/soc@3000000/i2c@5002400";
+ target-path = "/soc/i2c@5002400";
```

**For the I2S node in the primary overlay:**
```diff
- target-path = "/soc@3000000/i2s@5095000";
+ target-path = "/soc/ahub-i2s2@5097000";
```
OR try `ahub-i2s3@5097000` if i2s2 doesn't work.

---

### Fix 2: README Pin Mapping Table

**File:** `README.md`

**Already fixed** ✓ - Updated Pin 38 from PI3 to PI4

---

### Fix 3: Pin Function Names

The overlays currently use `function = "i2s0"` and `function = "i2s0_dout0"`, but the H618 has `i2s2-pins` and `i2s3-pins` defined in the device tree.

**Possible fixes to try:**

Option A: Use i2s2 functions
```dts
function = "i2s2";          // Instead of "i2s0"
function = "i2s2_dout0";    // Instead of "i2s0_dout0"
```

Option B: Use i2s3 functions  
```dts
function = "i2s3";
function = "i2s3_dout0";
```

Option C: Keep as i2s0 (might work if the pinctrl driver supports it)

**Recommendation**: Start with i2s2, as there's an existing `i2s2-pins` definition in the device tree.

---

### Fix 4: AHUB Architecture

The H618 has these AHUB nodes:
- `/sys/firmware/devicetree/base/soc/ahub-i2s1@5097000`
- `/sys/firmware/devicetree/base/soc/ahub-i2s2@5097000`
- `/sys/firmware/devicetree/base/soc/ahub-i2s3@5097000`

**Two approaches to try:**

#### Approach A: Use Existing AHUB Node (Recommended)
Target an existing AHUB node and enable it:

```dts
fragment@4 {
    target-path = "/soc/ahub-i2s2@5097000";
    __overlay__ {
        #sound-dai-cells = <0>;
        status = "okay";
        pinctrl-names = "default";
        pinctrl-0 = <&i2s0_wm8960_pins>, <&i2s0_wm8960_dout>;
    };
};
```

#### Approach B: Use simple-audio-card with AHUB
Reference the existing AHUB node using a phandle:
```dts
simple-audio-card,cpu {
    sound-dai = <&ahub_i2s2>;  // Reference existing node
};
```

---

## Specific File Changes

### File: `overlays/sun50i-h618-wm8960-soundcard.dts`

Make these changes:

1. **Fragment 1** (I2C node):
```dts
fragment@1 {
    target-path = "/soc/i2c@5002400";  // Remove @3000000
    __overlay__ {
        // ... rest stays the same
    };
};
```

2. **Fragment 2** (Pinctrl):
```dts
fragment@2 {
    target-path = "/soc/pinctrl@300b000";  // Remove @3000000
    __overlay__ {
        i2s0_wm8960_pins: i2s0-wm8960-pins {
            pins = "PI0", "PI1", "PI2", "PI3";
            function = "i2s2";  // Try i2s2 instead of i2s0
            drive-strength = <20>;
            bias-disable;
        };

        i2s0_wm8960_dout: i2s0-wm8960-dout {
            pins = "PI4";
            function = "i2s2_dout0";  // Try i2s2_dout0 instead of i2s0_dout0
            drive-strength = <20>;
            bias-disable;
        };
    };
};
```

3. **Fragment 4** (I2S node):
```dts
fragment@4 {
    target-path = "/soc/ahub-i2s2@5097000";  // Use AHUB node
    __overlay__ {
        #sound-dai-cells = <0>;
        status = "okay";
        pinctrl-names = "default";
        pinctrl-0 = <&i2s0_wm8960_pins>, <&i2s0_wm8960_dout>;
    };
};
```

---

### File: `overlays/sun50i-h618-wm8960-soundcard-i2s3.dts`

Make similar path changes:

1. All `target-path = "/soc@3000000/..."` → `target-path = "/soc/..."`

2. Fragment 3 and 4 need revision - they create custom AHUB nodes that might conflict

---

## Testing Procedure

After making changes:

1. **Recompile the overlay:**
```bash
cd overlays
dtc -@ -I dts -O dtb -o sun50i-h618-wm8960-soundcard.dtbo sun50i-h618-wm8960-soundcard.dts
```

2. **Copy to boot directory:**
```bash
sudo cp sun50i-h618-wm8960-soundcard.dtbo /boot/dtb/allwinner/overlay/
```

3. **Reboot:**
```bash
sudo reboot
```

4. **Run diagnostics:**
```bash
sudo bash scripts/diagnose-h618.sh
```

5. **Check for WM8960 in device tree:**
```bash
find /proc/device-tree -name "*wm8960*"
# Should return some paths if overlay loaded
```

6. **Check sound card:**
```bash
cat /proc/asound/cards
aplay -l
```

7. **Check kernel messages:**
```bash
dmesg | grep -iE "wm8960|simple-audio|ahub"
```

---

## Pin Mapping Reference (Confirmed Correct)

From actual HAT hardware:
```
Pin 3  (PI8) = I2C SDA
Pin 5  (PI7) = I2C SCL
Pin 12 (PI1) = I2S BCLK (Clock)
Pin 35 (PI2) = I2S LRCK (Frame Clock)
Pin 40 (PI3) = I2S DAC  (DOUT from SoC)
Pin 38 (PI4) = I2S ADC  (DIN to SoC)
```

This matches what's in the DTS files - the pin assignments are **correct**.

---

## What's Working vs Not Working

### ✓ Working:
- WM8960 detected on I2C bus 3 at 0x1a
- Kernel module `snd_soc_wm8960` loads successfully
- Pin definitions in DTS are correct
- README now has correct pin table

### ✗ Not Working:
- Device tree overlay not loading (wrong paths)
- Sound card not being created
- No WM8960 nodes appear in /proc/device-tree

---

## Priority Actions

1. **HIGH**: Fix device tree paths (`/soc@3000000/` → `/soc/`)
2. **HIGH**: Use AHUB node instead of simple I2S
3. **MEDIUM**: Try i2s2 function names instead of i2s0
4. **LOW**: Consider which AHUB interface to use (i2s2 vs i2s3)

---

## Additional Files Created

1. **ISSUES_FOUND.md** - Detailed analysis of all issues
2. **scripts/diagnose-h618.sh** - Diagnostic script to run on Orange Pi
3. This file (FIX_INSTRUCTIONS.md) - Step-by-step fix guide

---

## Questions to Investigate

1. Should we use `ahub-i2s2` or `ahub-i2s3`?
2. Are the pin functions `i2s2` or `i2s3`? (Check with actual pinctrl driver)
3. Does the AHUB node need additional configuration beyond status="okay"?
4. Should we use `simple-audio-card` or the Allwinner-specific `sunxi-snd-mach`?

---

## Contact

If issues persist after these fixes, gather output from:
```bash
sudo bash scripts/diagnose-h618.sh > diagnostic_output.txt
dmesg > dmesg_output.txt
```

And share both files for further analysis.
