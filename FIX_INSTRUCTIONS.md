# Fix Instructions for WM8960 Driver

## Executive Summary

The WM8960 codec **is detected on I2C** (confirmed at 0x1a on bus 3), and the kernel module loads successfully. However, **the device tree overlays are not loading**.

## UPDATE (After Diagnostic Test):

**✓ Device tree paths are now fixed** (using `/soc/` instead of `/soc@3000000/`)

**✗ NEW CRITICAL ISSUE FOUND**: The overlay is **not loading** due to a **filename/prefix mismatch**:

- Boot config has: `overlay_prefix=sun50i-h616` 
- Overlay is named: `sun50i-h618-wm8960-soundcard.dtbo`
- **Mismatch!** The system is looking for `sun50i-h616-*.dtbo` files!

**Root Cause**: The H618 SoC is being treated as H616 by the bootloader. The overlay filename must match the prefix.

---

## Critical Fixes Required

### Fix 0: OVERLAY FILENAME MISMATCH (NEW - CRITICAL!)

**Problem**: Boot config uses `overlay_prefix=sun50i-h616` but overlays are named `sun50i-h618-*`

**Solution**: Rename the overlay files to match the H616 prefix

**Option A: Rename overlay files (RECOMMENDED)**
```bash
# On the Orange Pi:
cd /boot/dtb/allwinner/overlay/
sudo mv sun50i-h618-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dtbo
sudo mv sun50i-h618-wm8960-soundcard-i2s3.dtbo sun50i-h616-wm8960-soundcard-i2s3.dtbo

# Update boot config:
sudo nano /boot/dietpiEnv.txt
# Change: overlays=i2c1-pi sun50i-h618-wm8960-soundcard
# To:     overlays=i2c1-pi sun50i-h616-wm8960-soundcard

sudo reboot
```

**Option B: Change overlay prefix to h618**
```bash
sudo nano /boot/dietpiEnv.txt
# Change: overlay_prefix=sun50i-h616
# To:     overlay_prefix=sun50i-h618
sudo reboot
```

**Note**: Option A is recommended because the H618 is essentially an H616 variant, and the DietPi/Armbian system is configured for H616.

---

### Fix 1: Correct Device Tree Paths in Both Overlays (✓ DONE)

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

### Step 1: Fix the Overlay Naming (Do This First!)

**On the Orange Pi, run:**
```bash
# Rename overlay files to match h616 prefix
cd /boot/dtb/allwinner/overlay/
sudo mv sun50i-h618-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dtbo
sudo mv sun50i-h618-wm8960-soundcard-i2s3.dtbo sun50i-h616-wm8960-soundcard-i2s3.dtbo

# Update boot config
sudo sed -i 's/sun50i-h618-wm8960-soundcard/sun50i-h616-wm8960-soundcard/g' /boot/dietpiEnv.txt

# Reboot
sudo reboot
```

### Step 2: Verify Overlay Loaded

After reboot:
```bash
# Check for WM8960 in device tree (should now appear!)
find /proc/device-tree -name "*wm8960*"

# Check for sound card
cat /proc/asound/cards
aplay -l

# Check kernel messages
dmesg | grep -iE "wm8960|simple-audio|ahub"

# Run full diagnostic
sudo bash scripts/diagnose-h618.sh
```

### Step 3: If overlay loads but no sound card

If you now see WM8960 in /proc/device-tree but still no sound card, the issue is in the overlay configuration itself (likely pin functions or AHUB setup).

Then try these pin function alternatives in the DTS files:

Then try these pin function alternatives in the DTS files:
### Step 4: Check Pin Claiming

Pins PI0-PI4 should be claimed by the I2S/AHUB driver:
```bash
cat /sys/kernel/debug/pinctrl/300b000.pinctrl/pinmux-pins | grep -E "pin 25[6-9]|pin 260"
# Should show pins claimed by ahub or i2s, not UNCLAIMED
```

### Step 5: Manual Compilation (If Changing DTS)

If you need to modify and recompile overlays:
```bash
cd overlays
dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard.dtbo sun50i-h616
function = "i2s2";
function = "i2s2_dout0";
```

**Option 2: Try i2s3 functions**
```dts
function = "i2s3";
```bash
cd overlays
dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dts
```

**2. Copy to boot directory:**
```bash
sudo cp sun50i-h616-wm8960-soundcard.dtbo /boot/dtb/allwinner/overlay/
**Option 3: Keep i2s0 (might work)**

### Step 4: Check Pin Claiming
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

1. **CRITICAL**: Fix overlay filename mismatch (h618 → h616) OR change overlay_prefix
2. **HIGH**: Verify overlay loads after rename (check for WM8960 in /proc/device-tree)
3. **HIGH**: If still not working, check pin functions (i2s0 vs i2s2 vs i2s3)
4. **MEDIUM**: Verify AHUB node configuration
5. **LOW**: Consider alternative overlay approaches

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
