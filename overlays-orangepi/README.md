# Device Tree Overlay Sources

WM8960 device tree overlay source files for Orange Pi boards with Allwinner H616/H618 SoCs. The installer automatically selects the correct overlay based on your OS.

## How They Work

The overlay DTS files are **compiled and merged into the base device tree at install time** using `fdtoverlay`. This approach is used because Orange Pi OS's U-Boot does not reliably apply overlays at runtime (complex overlays with multiple fragments are silently dropped).

At install time, `install.sh`:
1. Backs up the original DTB (only on first install)
2. Compiles the DTS source into a `.dtbo` using `dtc -@`
3. Applies it to the **backup** DTB using `fdtoverlay` (never the current DTB, to prevent double-patching)
4. Creates a symlink from the original DTB name to the patched version
5. Verifies the WM8960 node exists with `fdtget`

## Files

| File | OS | SoC | Status |
|------|-----|-----|--------|
| `sun50i-h618-wm8960-working.dts` | Orange Pi OS | H618 | Tested, working |
| `sun50i-h618-wm8960-armbian.dts` | Armbian | H618 | Tested, working |
| `sun50i-h616-wm8960-working.dts` | Orange Pi OS | H616 | Untested |

The installer auto-detects the OS (`/etc/armbian-release`) and SoC to select the correct file.

## What Each Overlay Adds

### Common to All Overlays

1. **I2S0 pin configuration** — PI1/PI2 (BCLK/LRCK), PI3 (DOUT), PI4 (DIN) with 3 separate pin groups
2. **AHUB0 platform device** (`ahub0_plat`) — External I2S interface with DMA channels for the WM8960
3. **AHUB0 machine driver** (`ahub0_mach`) — Binds the WM8960 codec to the AHUB audio subsystem, creates `ahub0wm8960` sound card
4. **I2C1 WM8960 node** — Enables I2C1 (`i2c@5002400`) and declares the WM8960 codec at address 0x1a

### Armbian-Specific Additions

The Armbian overlay includes two extra fragments not needed on Orange Pi OS:

- **AHUB DAM enable** (`ahub_dam_plat@5097000`) — The shared AHUB register space is disabled by default in Armbian's DTB. Without this, the AHUB platform probe fails with `"no match device"`.
- **I2C1 pinctrl** (`pinctrl-0 = <&i2c1_pi_pins>`) — Armbian's mainline kernel requires explicit pin muxing for I2C1 (PI7/PI8). Orange Pi OS's vendor kernel handles this implicitly. The `i2c1_pi_pins` label already exists in the Armbian base DTB.

### OS Differences Summary

| Feature | Orange Pi OS | Armbian |
|---------|-------------|---------|
| AHUB DAM (`@5097000`) | Already enabled | Must be enabled by overlay |
| I2C1 pinctrl | Implicit (vendor kernel) | Explicit pin mux required |
| I2C bus number | Bus 2 | Bus 3 |
| Sound card number | Card 3 | Card 0 |
| WM8960 kernel module | Included in kernel package | Built from source by `build-module.sh` |

## Manual Overlay Installation

If you want to apply an overlay manually (for experimentation or debugging), here are the steps that `install.sh` automates:

### 1. Find Your Base DTB

```bash
# Find the allwinner DTB directory
DTB_DIR=$(find /boot -type d -name "allwinner" -path "*/dtb*" | head -1)
echo "DTB directory: $DTB_DIR"

# Find the board DTB
ls "$DTB_DIR"/sun50i-h61*-orangepi-zero2w.dtb
```

### 2. Back Up the Original DTB

```bash
BASE_DTB="$DTB_DIR/sun50i-h618-orangepi-zero2w.dtb"
cp "$BASE_DTB" "${BASE_DTB}.backup"
```

### 3. Edit the Overlay (Optional)

If you want to modify the overlay before applying it, edit the DTS source:

```bash
# Pick the right overlay for your OS
# Orange Pi OS:
nano overlays-orangepi/sun50i-h618-wm8960-working.dts
# Armbian:
nano overlays-orangepi/sun50i-h618-wm8960-armbian.dts
```

Common things to experiment with:
- Change I2S pin assignments in the `i2s0_pins_*` nodes
- Adjust `soundcard-mach,slot-width` (16 or 32 bit I2S frames)
- Modify `drive-strength` values for signal integrity tuning
- Add `wlf,*` properties to the WM8960 node (see the WM8960 driver source for options)

### 4. Compile the Overlay

```bash
# The -@ flag enables phandle references (required for overlays)
# Use the overlay file you selected/edited in Step 3
dtc -@ -I dts -O dtb -o /tmp/wm8960.dtbo overlays-orangepi/<your-overlay>.dts
```

You'll see warnings about missing phandle references — these are normal for overlays and can be ignored.

### 5. Apply the Overlay

```bash
# Always apply to the BACKUP, not the current DTB (prevents double-patching)
fdtoverlay -i "${BASE_DTB}.backup" -o "$DTB_DIR/sun50i-h618-orangepi-zero2w-wm8960.dtb" /tmp/wm8960.dtbo
```

### 6. Symlink the Patched DTB

```bash
# Point the original DTB name at the patched version
ln -sf "sun50i-h618-orangepi-zero2w-wm8960.dtb" "$BASE_DTB"
```

### 7. Verify

```bash
# Check that the WM8960 node exists in the patched DTB
fdtget "$DTB_DIR/sun50i-h618-orangepi-zero2w-wm8960.dtb" /soc/i2c@5002400/wm8960@1a compatible
# Should output: wlf,wm8960
```

### 8. Reboot

```bash
sudo reboot
```

After reboot, verify with:
```bash
# Check I2C — should show "UU" at address 0x1a (driver bound) or "1a" (no driver)
i2cdetect -y 2    # Orange Pi OS
i2cdetect -y 3    # Armbian

# Check sound card
aplay -l | grep wm8960
```

### Reverting to Original DTB

```bash
# Remove the symlink and restore the backup
rm -f "$DTB_DIR/sun50i-h618-orangepi-zero2w.dtb"
cp "${DTB_DIR}/sun50i-h618-orangepi-zero2w.dtb.backup" "$DTB_DIR/sun50i-h618-orangepi-zero2w.dtb"
rm -f "$DTB_DIR/sun50i-h618-orangepi-zero2w-wm8960.dtb"
sudo reboot
```

## Technical Notes

- Overlays use `target-path` (string paths) instead of `target = <&phandle>` references, which is required for `fdtoverlay` compatibility
- I2S0 pins are split into 3 separate groups with different pin functions (`i2s0`, `i2s0_dout0`, `i2s0_din0`) — this matches the vendor BSP's pin function naming
- The AHUB nodes (`ahub0_plat`, `ahub0_mach`) are direct children of `/soc`
- The WM8960 uses its onboard 24MHz crystal — no external MCLK clock reference is needed (no `clocks` property)
- The `wlf,shared-lrclk` property enables shared LRCLK mode on the WM8960
- The AHUB machine driver uses `soundcard-mach,slot-width = <32>` for 32-bit I2S frames
