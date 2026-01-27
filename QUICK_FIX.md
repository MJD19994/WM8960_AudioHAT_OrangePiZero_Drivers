# QUICK FIX - Overlay Not Loading

## Problem Identified

The diagnostic shows:
- ✓ I2C working (WM8960 detected at 0x1a)
- ✓ Module loaded (snd_soc_wm8960)
- ✗ **Overlay NOT loading** - No WM8960 in device tree

**Root Cause**: Filename mismatch!
- Boot config expects: `sun50i-h616-*.dtbo`
- Files are named: `sun50i-h618-*.dtbo`

## Immediate Fix (Run on Orange Pi)

```bash
# 1. Rename overlay files
cd /boot/dtb/allwinner/overlay/
sudo mv sun50i-h618-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dtbo
sudo mv sun50i-h618-wm8960-soundcard-i2s3.dtbo sun50i-h616-wm8960-soundcard-i2s3.dtbo

# 2. Update boot config
sudo sed -i 's/sun50i-h618-wm8960-soundcard/sun50i-h616-wm8960-soundcard/g' /boot/dietpiEnv.txt

# 3. Verify changes
grep overlay /boot/dietpiEnv.txt

# 4. Reboot
sudo reboot
```

## After Reboot - Verify

```bash
# Should now find WM8960 nodes:
find /proc/device-tree -name "*wm8960*"

# Check sound card:
cat /proc/asound/cards
aplay -l

# Run diagnostics:
sudo bash scripts/diagnose-h618.sh
```

## Expected Results

After this fix:
- WM8960 **should appear** in `/proc/device-tree`
- Device tree overlay status should change from "✗ Not loaded" to "✓ Loaded"
- May still need pin function adjustments if sound card doesn't register

## If Still Not Working After This

If overlay now loads but no sound card appears:
1. Check `dmesg | grep -i wm8960` for errors
2. Verify pins are claimed: `cat /sys/kernel/debug/pinctrl/300b000.pinctrl/pinmux-pins | grep -E "pin 25[6-9]|pin 260"`
3. May need to change pin functions from `i2s0` to `i2s2` or `i2s3`

See FIX_INSTRUCTIONS.md for detailed troubleshooting.
