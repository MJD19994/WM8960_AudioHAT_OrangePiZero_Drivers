# Critical Issues Found in WM8960 Driver

## Summary
The WM8960 codec **IS detected on I2C** (0x1a on bus 3), but the device tree overlays are targeting **non-existent nodes**. The H618 uses **AHUB (Audio Hub) architecture**, not simple I2S.

---

## Issue 1: Wrong Device Tree Paths ⚠️ CRITICAL

### Current (WRONG):
```dts
target-path = "/soc@3000000/i2s@5095000";  // DOES NOT EXIST
target-path = "/soc@3000000/pinctrl@300b000";  // WRONG PATH
```

### Actual paths on H618:
```bash
# I2S nodes that actually exist:
/sys/firmware/devicetree/base/soc/ahub-i2s1@5097000
/sys/firmware/devicetree/base/soc/ahub-i2s2@5097000
/sys/firmware/devicetree/base/soc/ahub-i2s3@5097000

# Pinctrl node:
/sys/firmware/devicetree/base/soc/pinctrl@300b000  # NOT soc@3000000!

# Existing pin definitions:
/sys/firmware/devicetree/base/soc/pinctrl@300b000/i2s2-pins
/sys/firmware/devicetree/base/soc/pinctrl@300b000/i2s3-pins
```

### Fix Required:
- Change `target-path = "/soc@3000000/..."` to `target-path = "/soc/..."`
- Use AHUB I2S nodes instead of simple I2S
- Target the correct AHUB-based audio architecture

---

## Issue 2: README Pin Mapping Table is WRONG ⚠️

### Current README (INCORRECT):
```
| I2S DIN    | Pin 38  | GPIO20  | PI3  | ✅ Yes |
| I2S DOUT   | Pin 40  | GPIO21  | PI3  | ✅ Yes |
```
Both show PI3 - this is WRONG!

### Correct Pin Mapping (from actual HAT):
```
SDA    = PI8  (Pin 3)  - I2C
SCL    = PI7  (Pin 5)  - I2C
CLK    = PI1  (Pin 12) - I2S BCLK
LRCLK  = PI2  (Pin 35) - I2S Frame Clock
DAC    = PI3  (Pin 40) - I2S DOUT (from SoC to codec)
ADC    = PI4  (Pin 38) - I2S DIN  (from codec to SoC)
```

### Fix Required:
Update README table:
```
| I2S DIN    | Pin 38  | GPIO20  | PI4  | ✅ Yes |
| I2S DOUT   | Pin 40  | GPIO21  | PI3  | ✅ Yes |
```

---

## Issue 3: Device Tree Overlay Pins Are Correct (Good News!) ✓

The overlays **do** have the correct pin assignments:
- PI0, PI1, PI2, PI3 for main I2S functions
- PI4 for DOUT (ADC input)

This matches the HAT's actual wiring.

---

## Issue 4: H618 Uses AHUB, Not Simple I2S ⚠️ CRITICAL

### Evidence:
```bash
# No simple I2S nodes exist
ls /sys/firmware/devicetree/base/soc/i2s* 
# Returns: No such file or directory

# Only AHUB nodes exist
ls /sys/firmware/devicetree/base/soc/ahub-i2s*
# Returns: ahub-i2s1@5097000, ahub-i2s2@5097000, ahub-i2s3@5097000
```

### Fix Required:
The **alternative overlay** (i2s3) is closer to correct approach, but still has wrong paths:
- It creates custom AHUB nodes (`ahub0_plat`, `ahub0_mach`)
- But targets wrong paths with `soc@3000000`

Need to:
1. Use the AHUB-based approach
2. Fix the target paths to `/soc/` not `/soc@3000000/`
3. Potentially use existing `ahub-i2s2` or `ahub-i2s3` nodes instead of creating new ones

---

## Issue 5: Pinctrl Function Names Need Verification

Current overlay uses:
```dts
function = "i2s0_dout0";  // For PI4
function = "i2s0";        // For PI0-PI3
```

But the system shows existing pins use `i2s2` and `i2s3`, not `i2s0`:
```bash
/sys/firmware/devicetree/base/soc/pinctrl@300b000/i2s2-pins
/sys/firmware/devicetree/base/soc/pinctrl@300b000/i2s3-pins
```

### Fix Required:
Check what function names are actually valid for the H618 PI pins. Likely should be:
- `function = "i2s2"` or `function = "i2s3"` (not i2s0)

---

## Diagnostic Results Summary

### ✓ Working:
- I2C detection: WM8960 found at 0x1a on bus 3
- WM8960 kernel module loads successfully
- Pin mappings in DTS are correct

### ✗ Not Working:
- Device tree overlay not loading (wrong node paths)
- Sound card not being created
- I2S interface not initialized

---

## Recommended Fixes (Priority Order)

### 1. Fix Device Tree Paths (CRITICAL)
Change all occurrences in both DTS files:
```diff
- target-path = "/soc@3000000/pinctrl@300b000";
+ target-path = "/soc/pinctrl@300b000";

- target-path = "/soc@3000000/i2c@5002400";
+ target-path = "/soc/i2c@5002400";

- target-path = "/soc@3000000/i2s@5095000";
+ target-path = "/soc/ahub-i2s2@5097000";
```

### 2. Use Existing AHUB Nodes
Instead of creating custom nodes, try to use existing `ahub-i2s2` or `ahub-i2s3` nodes

### 3. Fix Pin Function Names
Change to `i2s2` or `i2s3` based on which AHUB interface is used

### 4. Fix README
Update the pin mapping table to show PI4 for DIN

### 5. Add Diagnostic Commands to Install Script
Add checks to verify:
- Overlay actually loaded
- Sound card created
- I2S nodes present in /proc/device-tree

---

## Test Commands for Verification

After fixes, run these on the Orange Pi:

```bash
# Check if overlay loaded
ls /proc/device-tree/sound* 2>/dev/null

# Check for WM8960 codec in device tree
find /proc/device-tree -name "*wm8960*"

# Check I2C detection
i2cdetect -y 3

# Check sound cards
cat /proc/asound/cards

# Check for errors
dmesg | grep -E "wm8960|i2s|ahub|simple-audio"
```
