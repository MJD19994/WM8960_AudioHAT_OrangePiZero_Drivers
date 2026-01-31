# Root Cause Found - Compatible String Mismatch

## Problem
The overlay files use `compatible = "allwinner,sun50i-h618"` but the system's base device tree identifies as `sun50i-h616`. Overlays will **only load** if their compatible string matches the base device tree.

## Fix Applied
Changed both overlay `.dts` files:
- `overlays/sun50i-h616-wm8960-soundcard.dts`
- `overlays/sun50i-h616-wm8960-soundcard-i2s3.dts`

From:
```dts
compatible = "xunlong,orangepi-zero2w", "allwinner,sun50i-h618";
```

To:
```dts
compatible = "xunlong,orangepi-zero2w", "allwinner,sun50i-h616";
```

## Next Steps for Your Agent

1. **Recompile the overlays**:
   ```bash
   cd overlays
   dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dts
   dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard-i2s3.dtbo sun50i-h616-wm8960-soundcard-i2s3.dts
   ```

2. **Copy to Orange Pi**:
   ```bash
   # Replace the old .dtbo files on the Pi
   sudo cp sun50i-h616-wm8960-soundcard*.dtbo /boot/dtb/allwinner/overlay/
   ```

3. **Reboot**:
   ```bash
   sudo reboot
   ```

4. **Test**:
   ```bash
   # Should now find WM8960 nodes:
   find /proc/device-tree -name "*wm8960*"
   
   # Run diagnostics:
   sudo bash scripts/diagnose-h618.sh
   ```

## Expected Outcome

After this fix:
- ✅ WM8960 nodes **should appear** in `/proc/device-tree`
- ✅ Overlay status should show "✓ Loaded"
- ⚠️ Sound card may still not register (will need to check pin functions next)

## Why H616 vs H618?

The Allwinner H618 is essentially an H616 with minor differences (mainly power management). The device tree and bootloader treat them identically, so overlays must use the H616 compatible string.

## Files Changed in This Repo

- [x] `overlays/sun50i-h616-wm8960-soundcard.dts` - Compatible string fixed
- [x] `overlays/sun50i-h616-wm8960-soundcard-i2s3.dts` - Compatible string fixed
- [x] Created `URGENT_COMPATIBLE_FIX.md` - Documentation
- [x] Created `scripts/debug-overlay-loading.sh` - Debug script

## All Issues Fixed So Far

1. ✅ Device tree paths (soc@3000000 → soc)
2. ✅ Overlay filename (h618 → h616)
3. ✅ Compatible string (h618 → h616)
4. ✅ README pin table (PI3 → PI4 for DIN)

## Remaining Potential Issues

If overlay loads but sound card doesn't register:
- Pin functions might need changing (i2s0 → i2s2 or i2s3)
- AHUB configuration might need adjustment
- Check dmesg for errors

Run `scripts/debug-overlay-loading.sh` on the Pi for detailed diagnostics.
