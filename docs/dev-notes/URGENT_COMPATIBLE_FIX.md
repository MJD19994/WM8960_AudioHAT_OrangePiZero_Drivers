# URGENT FIX - Overlay Still Not Loading

## Problem Identified

The overlay is **still not loading** because of a **compatible string mismatch**.

### The Issue:

**In the overlay DTS file (line 34):**
```dts
compatible = "xunlong,orangepi-zero2w", "allwinner,sun50i-h618";
```

**But the system treats the H618 as H616:**
- Boot config: `overlay_prefix=sun50i-h616`
- The base device tree likely declares itself as `sun50i-h616`, not `h618`

### The Fix

**Change the compatible string in BOTH overlay files:**

#### File 1: `overlays/sun50i-h616-wm8960-soundcard.dts`

Change line 34 from:
```dts
compatible = "xunlong,orangepi-zero2w", "allwinner,sun50i-h618";
```

To:
```dts
compatible = "xunlong,orangepi-zero2w", "allwinner,sun50i-h616";
```

#### File 2: `overlays/sun50i-h616-wm8960-soundcard-i2s3.dts`

Make the same change (change h618 to h616 in compatible string).

### Recompile and Deploy

```bash
# On your dev machine (in the repo):
cd overlays
dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard.dtbo sun50i-h616-wm8960-soundcard.dts
dtc -@ -I dts -O dtb -o sun50i-h616-wm8960-soundcard-i2s3.dtbo sun50i-h616-wm8960-soundcard-i2s3.dts

# Copy to Orange Pi:
scp sun50i-h616-wm8960-soundcard*.dtbo root@dietpi:/boot/dtb/allwinner/overlay/

# On Orange Pi:
sudo reboot
```

### Verify Base Device Tree Compatible

Before making changes, run this on the Orange Pi to confirm what the system reports:

```bash
cat /proc/device-tree/compatible | tr '\0' '\n'
```

This will show what compatible strings the base device tree has. Look for h616 vs h618.

### Alternative: Remove Compatible Check

If you want the overlay to load regardless of the base device tree compatible string, you can remove the compatible property entirely:

```dts
/ {
	// Remove or comment out the compatible line
	// compatible = "xunlong,orangepi-zero2w", "allwinner,sun50i-h618";
```

But this is less safe as it could load on incompatible systems.

### Why This Matters

Device tree overlays will **only load** if their `compatible` string matches one of the compatible strings in the base device tree. Since the H618 is essentially an H616 (same die, different marketing), the device tree likely identifies as H616.

### After This Fix

The WM8960 nodes should appear in /proc/device-tree and you should see:
```bash
find /proc/device-tree -name "*wm8960*"
# Should return paths to WM8960 nodes
```

Then you may still need to address pin function issues if the sound card doesn't register, but at least the overlay will load.
