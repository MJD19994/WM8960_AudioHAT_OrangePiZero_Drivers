# WM8960 Driver Development Log

## Current Status: OVERLAY NOT LOADING - Compatible String Fixed, Needs Recompile

---

## Latest Finding (2026-01-27)

**Problem**: Overlay still not loading after fixing paths and filenames  
**Root Cause**: Compatible string mismatch  
- Overlay declares: `compatible = "allwinner,sun50i-h618"`
- System expects: `compatible = "allwinner,sun50i-h616"`

**Fix Applied**: Changed both `.dts` source files to use `h616`
- ✅ `overlays/sun50i-h616-wm8960-soundcard.dts` - Line 34 changed
- ✅ `overlays/sun50i-h616-wm8960-soundcard-i2s3.dts` - Line 34 changed

**Status**: Changes made to source, **NEEDS RECOMPILE** before testing

---

## Next Steps

### For Agent to Do:
1. **Recompile the overlays**:
   ```bash
   cd overlays
   dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dts
   dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard-i2s3.dtbo sun50i-h616-wm8960-soundcard-i2s3.dts
   ```

2. **Copy to Orange Pi**:
   ```bash
   sudo cp sun50i-h616-wm8960-soundcard*.dtbo /boot/dtb/allwinner/overlay/
   sudo reboot
   ```

3. **Test**:
   ```bash
   find /proc/device-tree -name "*wm8960*"
   sudo bash scripts/diagnose-h618.sh
   ```

### Expected Outcome:
- WM8960 nodes should now appear in `/proc/device-tree`
- Overlay status should show "✓ Loaded"

---

## All Fixes Applied So Far

### 1. ✅ Device Tree Paths (Fixed)
**Problem**: Overlays targeted `/soc@3000000/...` but H618 uses `/soc/...`  
**Fix**: Changed all target-path entries to remove `@3000000`
- `/soc@3000000/pinctrl@300b000` → `/soc/pinctrl@300b000`
- `/soc@3000000/i2c@5002400` → `/soc/i2c@5002400`
- Etc.

### 2. ✅ Overlay Filenames (Fixed)
**Problem**: Boot config expects `sun50i-h616-*` but files were `sun50i-h618-*`  
**Fix**: Renamed source files from h618 to h616
- `sun50i-h618-wm8960-soundcard.dts` → `sun50i-h616-wm8960-soundcard.dts`
- `sun50i-h618-wm8960-soundcard-i2s3.dts` → `sun50i-h616-wm8960-soundcard-i2s3.dts`

### 3. ✅ Compatible String (Just Fixed - Needs Recompile)
**Problem**: Overlay compatible string was `h618`, system expects `h616`  
**Fix**: Changed compatible string in both DTS files

### 4. ✅ README Pin Table (Fixed)
**Problem**: Both DIN and DOUT showed as PI3  
**Fix**: Updated table to show DIN=PI4, DOUT=PI3

---

## Hardware Verification (All Good ✓)

From actual hardware diagnostics:
- ✅ I2C: WM8960 detected at 0x1a on bus 3
- ✅ Module: snd_soc_wm8960 loads successfully
- ✅ I2C pins: PI7 (SCL) and PI8 (SDA) claimed by i2c1

**Confirmed Pin Mapping** (from HAT):
```
Pin 3  (PI8) = I2C SDA
Pin 5  (PI7) = I2C SCL  
Pin 12 (PI1) = I2S BCLK
Pin 35 (PI2) = I2S LRCK
Pin 40 (PI3) = I2S DOUT (DAC)
Pin 38 (PI4) = I2S DIN  (ADC)
```

---

## System Configuration (Confirmed)

From diagnostic output:
- Boot config: `/boot/dietpiEnv.txt`
- Overlay prefix: `sun50i-h616` (NOT h618!)
- SoC base path: `/soc` (NOT /soc@3000000!)
- AHUB nodes exist at: `/soc/ahub-i2s[1-3]@5097000`
- Existing pin definitions: `i2s2-pins` and `i2s3-pins`

---

## Remaining Unknowns (After Overlay Loads)

If overlay loads but sound card doesn't register, may need to check:

1. **Pin Functions**: Currently using `i2s0` and `i2s0_dout0`
   - System has `i2s2-pins` and `i2s3-pins` defined
   - May need to try `i2s2` or `i2s3` functions instead

2. **AHUB Configuration**: Currently targeting simple I2S approach
   - H618 uses AHUB (Audio Hub) architecture
   - May need different binding approach

3. **I2S Node**: Currently not targeting any specific AHUB node
   - Available: `ahub-i2s1`, `ahub-i2s2`, `ahub-i2s3`
   - May need to enable one of these

---

## Diagnostic Scripts Created

1. **scripts/diagnose-h618.sh** - Main diagnostic (already exists)
2. **scripts/debug-overlay-loading.sh** - Detailed overlay loading debug

---

## Test Results History

### Test 1 (Initial):
- ✗ Overlay not loading
- Reason: Wrong device tree paths (`/soc@3000000/`)

### Test 2 (After path fix):
- ✗ Overlay not loading
- Reason: Filename mismatch (h618 vs h616)

### Test 3 (After filename fix):
- ✗ Overlay still not loading
- Reason: Compatible string mismatch (h618 vs h616)

### Test 4 (Pending):
- **NEED TO RECOMPILE AND TEST**

---

## How to Update This Log

After each test, add results here:

### Test [N] (Date):
- Result: [✓ Success / ✗ Failed / ⚠️ Partial]
- What changed: [Description]
- New findings: [Any new issues discovered]
- Next action: [What to try next]
