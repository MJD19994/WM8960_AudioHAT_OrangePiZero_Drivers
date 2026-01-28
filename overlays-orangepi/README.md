# Orange Pi OS Specific Overlays

These overlays are designed for **Orange Pi's official OS** (vendor BSP kernel 6.1.31-sun50iw9).

## Differences from DietPi/Armbian Overlays

Orange Pi OS uses a different device tree structure:
- **AHUB nodes**: Uses `ahub1_plat`/`ahub1_mach` instead of `ahub-i2s1@5097000`
- **I2C structure**: Different phandle system
- **No exposed I2S interfaces**: AHUB I2S devices not exposed in device tree

## Current Status

❌ **Orange Pi OS does NOT have DAUDIO driver** even in vendor BSP
❌ **AHUB I2S interfaces not exposed** in device tree for external codecs
✅ Internal codec works
✅ AHUB HDMI audio works

## Files

- `sun50i-h616-wm8960-orangepi.dtbo` - WM8960 on I2C with clock (I2C only, no audio)
- Documentation for limitations

## Installation

**WARNING**: These overlays will NOT enable audio. They only add the WM8960 codec to I2C for detection purposes.

The AHUB architecture in Orange Pi OS is configured only for internal codec and HDMI. External I2S audio is not supported without the missing DAUDIO driver.
