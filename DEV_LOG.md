# WM8960 Driver Development Log

## Current Status: TEST 17 - Switch to Mainline sun4i-i2s Driver

---

## CRITICAL DISCOVERY (2026-01-27 - Test 16-17)

**ROOT CAUSE IDENTIFIED**: Missing AHUB DAUDIO driver in kernel

### What We Found:
1. The `ahub-i2s1@5097000` device exists and is properly configured
2. It has compatible string: `allwinner,sunxi-ahub-daudio`  
3. **NO kernel driver exists for this compatible string**
4. Only 3 AHUB modules exist:
   - `snd_soc_sunxi_ahub.ko` (platform wrapper)
   - `snd_soc_sunxi_ahub_dam.ko` (DAM controller)
   - `snd_soc_sunxi_machine.ko` (machine driver)
   - **MISSING**: `snd_soc_sunxi_ahub_daudio.ko` (I2S hardware driver)

### The Problem:
```bash
# Device exists but no driver can bind to it
$ ls /sys/bus/platform/devices/5097000.ahub-i2s1/
# NO driver/ symlink - device is orphaned

$ cat /sys/bus/platform/devices/5097000.ahub-i2s1/modalias
of:Nahub-i2s1T(null)Callwinner,sunxi-ahub-daudio
# This modalias has NO matching driver in the system

$ find /lib/modules/$(uname -r) -name "*daudio*"
# (empty) - driver doesn't exist
```

### Solution: Use Mainline sun4i-i2s Driver
Since the vendor AHUB DAUDIO driver is missing, we're switching to the **mainline** approach:
- Driver: `sun4i-i2s.ko` (exists in kernel: `/lib/modules/.../sunxi/sun4i-i2s.ko`)
- Card: `simple-audio-card` (proven mainline pattern)
- Architecture: Simple I2S (not vendor AHUB)

**Status**: Created new overlay using mainline driver - **READY TO TEST**

---

## Next Steps

### TEST THE MAINLINE DRIVER:
```bash
# Recompile all overlays (includes new simple version)
sudo bash scripts/recompile-overlays.sh

# Edit boot config to use the simple overlay
sudo nano /boot/orangepiEnv.txt
# Change line to: overlays=i2c1-pi wm8960-simple

# Reboot to test
sudo reboot
```

### After reboot - Check if it worked:
```bash
# Check if sun4i-i2s driver loaded
lsmod | grep sun4i

# Check sound card
aplay -l

# Look for simple-audio-card registration
dmesg | grep -i "simple\|audio\|wm8960\|i2s"

# Run full diagnostics
sudo bash scripts/diagnose-h618.sh
```

### Expected Outcome:
- `sun4i-i2s` driver loads and binds to i2s0 device
- `simple-audio-card` creates sound card
- `aplay -l` shows "wm8960-audio" card
- WM8960 codec detected on I2C bus 3

### If This Fails:
The H618 might not have proper i2s0 node support in mainline. We would need to:
1. Check if H616/H618 is supported by sun4i-i2s driver
2. Look for vendor kernel sources with AHUB DAUDIO driver
3. Consider building custom kernel module

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

### Test 12 (2026-01-27 04:32):
- Result: ⚠️ **PIN FUNCTION MISMATCH DISCOVERED!**
- AHUB platform device attempted to bind but failed with error -22
- Errors: `unsupported function i2s2 on pin PI0-PI4`
- **ROOT CAUSE:** PI port pins use I2S0 functions, NOT I2S2!
  - Pinmux shows: `i2s0, groups = [ PI0 PI1 PI2 ]`
  - I2S2 is actually on PG pins: `i2s2, groups = [ PG10 PG11 PG12 PG13 PG14 ]`
- **Fix Applied:**
  - Changed pin functions: `i2s2` → `i2s0`
  - Changed DIN function: `i2s2_din0` → `i2s0_din0`
  - Changed AHUB TDM: `tdm_num = 2` → `tdm_num = 0` (for I2S0)
  - Updated pinctrl references in AHUB platform device

### Test 13 (2026-01-27 04:40):
- Result: ⚠️ **PI3 function mismatch - needs specific dout function!**
- Error: `unsupported function i2s0 on pin PI3`
- **Reason:** PI3 is NOT in the generic `i2s0` group
  - Pinmux shows: `i2s0, groups = [ PI0 PI1 PI2 ]` (PI3 NOT included!)
  - PI3 has dedicated function: `i2s0_dout0, groups = [ PI3 ]`
- **Fix Applied:** Split pinctrl into three groups:
  - `i2s0-wm8960-pins`: PI0, PI1, PI2 → `i2s0`
  - `i2s0-wm8960-dout`: PI3 → `i2s0_dout0`
  - `i2s0-wm8960-din`: PI4 → `i2s0_din0`
  - Updated AHUB pinctrl-0 to reference all three groups

### Test 14: Missing DMA Configuration
- **Result:** AHUB platform device probe fails with error -22
- **Errors Found:**
  ```
  [AHUB_DAM snd_soc_sunxi_ahub_mem_get] regmap is invalid
  [AHUB sunxi_ahub_dev_probe] remap get failed
  probe with driver sunxi-snd-plat-ahub failed with error -22
  ```
- **Root Cause:** wm8960-ahub-plat device missing DMA properties completely
  - ahub1_plat has: `dma-names="txrx"` and `dmas` property
  - Our device: NO DMA properties at all!
  - AHUB driver requires DMA channels for audio data transfer
- **DMA Config from ahub1_plat:**
  ```
  dmas = 0x1c 0x04 0x1c 0x04  (phandle + request for TX/RX)
  dma-names = "tx", "rx"
  DMA controller: /soc/dma-controller@3002000
  ahub1_plat: tdm_num=1 (I2S1), DMA request 4
  ```

### Test 15: DMA Properties Added (Still Failing)
- **Change:** Add DMA properties to wm8960-ahub-plat
  ```dts
  dmas = <0x1c 0x04>, <0x1c 0x04>;
  dma-names = "tx", "rx";
  ```
- **Result:** Still failing with same error -22, regmap invalid
- **Investigation:** Compared base DT nodes, discovered critical architecture issue:
  - AHUB hardware nodes: ahub-i2s1 (tdm=1), ahub-i2s2 (tdm=2), ahub-i2s3 (tdm=3)
  - **NO ahub-i2s0 node exists in H616/H618 AHUB!**
  - Our tdm_num=0 tries to find ahub-i2s0@5097000 for regmap → doesn't exist → error!
  - Pinctrl functions use "i2s0" naming (physical pins), but AHUB software needs tdm 1/2/3

### Test 16 (Current):
- **Change:** Change `tdm_num = <0>` to `tdm_num = <1>` to use ahub-i2s1 hardware node
- **Root Cause:** Pin functions (i2s0) ≠ AHUB TDM interface numbers (1/2/3)
- **Expected:** AHUB driver finds ahub-i2s1, gets regmap, probe succeeds! 🎵

---

## How to Update This Log

After each test, add results here:

### Test [N] (Date):
- Result: [✓ Success / ✗ Failed / ⚠️ Partial]
- What changed: [Description]
- New findings: [Any new issues discovered]
- Next action: [What to try next]
