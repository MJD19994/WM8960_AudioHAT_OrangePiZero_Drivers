# Device Tree Overlay Sources

These are the WM8960 device tree overlay source files for Orange Pi boards with Allwinner H616/H618 SoCs running **Orange Pi OS** (vendor BSP kernel 6.1.31-sun50iw9).

## How They Work

The overlay DTS files are **compiled and merged into the base device tree at install time** using `fdtoverlay`. This approach is used because Orange Pi OS's U-Boot does not reliably apply overlays at runtime.

At install time, `install.sh`:
1. Compiles the DTS source into a `.dtbo` using `dtc`
2. Applies it to the base DTB using `fdtoverlay`
3. Symlinks the original DTB name to the patched version
4. Verifies the WM8960 node exists with `fdtget`

## Files

- `sun50i-h618-wm8960-working.dts` — For Orange Pi Zero 2W (H618)
- `sun50i-h616-wm8960-working.dts` — For other Orange Pi H616 boards (untested)

Both variants are identical in structure. The installer auto-detects the SoC and selects the correct file.

## What the Overlay Adds

1. **I2S0 pin configuration** — PI1/PI2 (BCLK/LRCK), PI3 (DOUT), PI4 (DIN)
2. **AHUB0 platform device** — External I2S interface for the WM8960
3. **AHUB0 machine driver** — Binds the WM8960 codec to the AHUB audio subsystem
4. **I2C1 WM8960 node** — Enables I2C1 (`i2c@5002400`, Linux bus 2) and declares the WM8960 codec at address 0x1a

## Technical Notes

- Overlays use `target-path` (string paths) instead of `target = <&phandle>` references, which is required for `fdtoverlay` compatibility
- I2S0 pins are split into 3 separate groups with different pin functions (`i2s0`, `i2s0_dout0`, `i2s0_din0`)
- The AHUB nodes (`ahub0_plat`, `ahub0_mach`) are direct children of `/soc`
- The WM8960 uses its onboard 24MHz crystal — no external MCLK clock reference is needed
