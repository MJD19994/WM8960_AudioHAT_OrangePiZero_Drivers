# WM8960 Driver Development Log

## Current Status: TEST 9 - Recompile with sunxi-snd-mach (In Progress)

---

## Latest Finding (2026-01-27 - Test 9)

**Problem**: Overlays still have old simple-audio-card compatible loaded  
**Root Cause**: Source files were updated but overlays not recompiled yet  
- Source files now have `allwinner,sunxi-snd-mach` ✓
- Compiled .dtbo files still have old simple-audio-card ✗
- Need to recompile the overlays

**Status**: Created recompile script, **READY TO RECOMPILE**

---

## Next Steps

### RECOMPILE AND TEST:
```bash
# Make script executable
chmod +x scripts/recompile-overlays.sh

# Recompile and install overlays
sudo bash scripts/recompile-overlays.sh

# Reboot to load new overlays
sudo reboot
```

### After reboot:
```bash
# Check if sunxi machine driver loaded
lsmod | grep sunxi
cat /sys/firmware/devicetree/base/wm8960-sound-ahub/compatible

# Run diagnostics
sudo bash scripts/diagnose-h618.sh
aplay -l
```

### Expected Outcome:
- sunxi_machine driver should load automatically
- Sound card should register successfully
- `aplay -l` should show wm8960-soundcard device

---

## All Test Iterations

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

### Test 4 (2026-01-27 02:32):
- Result: ✗ **FAILED - Overlay still not loading**
- What changed: Compiled with h616 compatible string
- New findings: 
  - **CRITICAL**: Base device tree reports `allwinner,sun50i-h618`
  - Overlay was compiled with `h616` - **THIS IS THE MISMATCH!**
  - We changed the WRONG direction - need h618, not h616!
  - Boot config uses h616 prefix but base DT is h618
- Next action: **Change compatible back to h618**

### Test 5 (2026-01-27 02:43):
- Result: ✗ **FAILED - Overlay STILL not loading**
- What changed: Reverted to h618 compatible (correct)
- New findings:
  - **ROOT CAUSE FOUND**: Boot config error!
  - Config has: `overlays=i2c1-pi sun50i-h616-wm8960-soundcard`
  - But bootloader adds prefix automatically!
  - It's looking for: `sun50i-h616-sun50i-h616-wm8960-soundcard.dtbo`
  - File is actually: `sun50i-h616-wm8960-soundcard.dtbo`
- Next action: **Change boot config to just `wm8960-soundcard`**

### Test 6 (2026-01-27 02:50):
- Result: ⚠️ **PARTIAL SUCCESS - Overlay IS LOADING!**
- What changed: Fixed boot config to `overlays=i2c1-pi wm8960-soundcard`
- Successes:
  - ✅ WM8960 nodes appear in device tree!
  - ✅ I2C shows "UU" at 0x1a (driver claimed it)
  - ✅ WM8960 codec initializing (loading dummy regulators)
  - ✅ Custom pinctrl definitions loaded (i2s2-wm8960-pins)
- New Issue:
  - ✗ **simple-audio-card parse error**
  - Error: `platform wm8960-sound: deferred probe pending: asoc-simple-card: parse error`
  - Pins PI0-PI4 still UNCLAIMED (I2S not starting)
- Root cause: simple-audio-card can't parse something in the overlay
- Next action: Check I2S node reference and simple-audio-card configuration

### Test 7 (2026-01-27 03:00):
- Result: ⚠️ **ISSUE IDENTIFIED**
- What checked: AHUB compatible string and simple-audio-card compatibility
- Root cause found:
  - AHUB compatible: `allwinner,sunxi-ahub-daudio`
  - simple-audio-card does NOT support AHUB devices
  - simple-audio-card only works with standard I2S/DAI devices
  - H618 requires Allwinner-specific `sunxi-snd-mach` driver
- Solution: Try the alternative overlay (i2s3) that uses AHUB-based approach
- Next action: Switch to sun50i-h616-wm8960-soundcard-i2s3 overlay

### Test 8 (2026-01-27 03:20):
- Result: ✗ **FAILED - Same parse error**
- What changed: Switched to i2s3 overlay (but it still had simple-audio-card)
- Boot config: `overlays=i2c1-pi wm8960-soundcard-i2s3`
- Findings:
  - ✅ Overlay loading successfully
  - ✅ WM8960 codec initializing
  - ✅ I2C working (UU at 0x1a)
  - ✗ **STILL getting: asoc-simple-card: parse error**
  - Root cause: i2s3 overlay also uses simple-audio-card!
- **Solution identified**: 
  - Found driver: `snd_soc_sunxi_machine.ko` exists in kernel
  - Need to update BOTH overlays to use `allwinner,sunxi-snd-mach`
  - Change properties from `simple-audio-card,*` to `soundcard-mach,*`
- Next action: Update both overlays to use sunxi-snd-mach driver

### Test 9 (2026-01-27 03:31):
- Result: ⚠️ **PARTIAL SUCCESS - Driver loads but probe deferred**
- What changed: Recompiled overlays with sunxi-snd-mach compatible
- Boot config: Both overlays loaded (wm8960-soundcard-i2s3 AND sun50i-h616-wm8960-soundcard)
- Successes:
  - ✅ `snd_soc_sunxi_machine` module loaded!
  - ✅ No more "asoc-simple-card: parse error"
  - ✅ Compatible string correct: `allwinner,sunxi-snd-mach`
  - ✅ Device tree has soundcard-mach,cpu and soundcard-mach,codec nodes
- New issue:
  - ✗ **deferred probe pending: (reason unknown)**
  - Root cause found: Missing required properties!
  - Comparing to working ahub1_mach, our overlay is missing:
    - `soundcard-mach,slot-num` (should be 2 for stereo)
    - `soundcard-mach,slot-width` (should be 32 for 32-bit slots)
- Next action: Add missing slot properties and use only ONE overlay

### Test 10 (2026-01-27 04:00):
- Result: ✗ **OVERLAY NOT LOADING - Prefix duplication bug reintroduced!**
- What changed: Used single overlay, added slot properties
- Boot config said: `overlays=i2c1-pi sun50i-h616-wm8960-soundcard`
- Root cause: Install script was using FULL filename in boot config
- With `overlay_prefix=sun50i-h616`, system looked for:
  - `sun50i-h616-sun50i-h616-wm8960-soundcard.dtbo` ✗
  - Instead of: `sun50i-h616-wm8960-soundcard.dtbo` ✓
- **This is the SAME bug from Test 5!**
- Fix: Install script now uses SHORT name (without prefix) for boot config
  - Boot config: `overlays=i2c1-pi wm8960-soundcard`
  - Bootloader adds prefix automatically: `sun50i-h616-wm8960-soundcard.dtbo`

### Test 11 (2026-01-27 04:20):
- Result: ⚠️ **ROOT CAUSE FOUND - AHUB architecture mismatch!**
- What discovered: Loaded AHUB modules but devices not binding
- Root cause identified:
  - Overlay referenced `ahub-i2s2` node (phandle 0x92) - **NO DRIVER**
  - System's `ahub1_mach` references `ahub1_plat` (phandle 0x32) - **HAS DRIVER**
  - Individual ahub-i2s nodes have no driver: `allwinner,sunxi-ahub-daudio`
  - Platform driver exists: `allwinner,sunxi-snd-plat-ahub`
- **Architecture:**
  - Must create AHUB platform device (like `ahub1_plat`)
  - Platform device properties: `apb_num`, `tdm_num` (I2S port), `tx_pin`, `rx_pin`
  - Sound card references platform device, not bare I2S node
- **Fix Applied:** Rewrote overlay to create `wm8960-ahub-plat` platform device
  - Compatible: `allwinner,sunxi-snd-plat-ahub`
  - `tdm_num = 2` for I2S2
  - Sound card now references the platform device
- Updated install script to load `snd_soc_sunxi_ahub` module

### Test 12 (Pending):
- **Pull updated code and reinstall with AHUB platform device**
- Expected: Platform driver binds, sound card registers successfully!

---

## How to Update This Log

After each test, add results here:

### Test [N] (Date):
- Result: [✓ Success / ✗ Failed / ⚠️ Partial]
- What changed: [Description]
- New findings: [Any new issues discovered]
- Next action: [What to try next]
