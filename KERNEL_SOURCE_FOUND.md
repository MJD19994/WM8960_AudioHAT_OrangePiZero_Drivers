# Kernel Source Repository Found!

## Repository Details

**Repository URL**: `https://github.com/orangepi-xunlong/linux-orangepi`  
**Branch for Orange Pi Zero 2W (H618/sun50iw9)**: `orange-pi-6.1-sun50iw9`

## Discovery Process

1. **Found in orangepi-build configuration**:
   ```bash
   # From external/config/sources/arm64.conf:
   GIT_SERVER="https://github.com/orangepi-xunlong"
   KERNELSOURCE="${GIT_SERVER}/linux-orangepi.git"
   ```

2. **Board configuration** (`external/config/boards/orangepizero2w.conf`):
   ```
   BOARD_NAME="OPI Zero2W"
   BOARDFAMILY="sun50iw9"
   KERNEL_TARGET="current,next"
   KERNELBRANCH="branch:orange-pi-6.1-sun50iw9"  # for next branch
   ```

3. **Family configuration** (`external/config/sources/families/sun50iw9.conf`):
   - legacy: `orange-pi-4.9-sun50iw9`
   - current: `orange-pi-5.4-sun50iw9`
   - next: `orange-pi-6.1-sun50iw9` ← **Currently running on Orange Pi OS**

## Important Discovery

The GitHub repository tool searched the **MAIN branch** (mainline kernel) which only has:
- `sound/soc/sunxi/` - mainline drivers (sun4i-codec, sun4i-i2s, sun50i-codec-analog, etc.)
- **NO** `sound/soc/sunxi_v2/` directory (vendor BSP drivers)

The vendor BSP drivers are likely in the **`orange-pi-6.1-sun50iw9` BRANCH**, not the main branch!

## Next Steps

1. **Browse the vendor BSP branch directly**:
   - URL: https://github.com/orangepi-xunlong/linux-orangepi/tree/orange-pi-6.1-sun50iw9
   - Look for: `sound/soc/sunxi_v2/`
   - Search for: `snd_sunxi_ahub_daudio.c`

2. **Check Kconfig for DAUDIO option**:
   - File: `sound/soc/sunxi_v2/Kconfig`
   - Look for: `CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO`

3. **If driver found**:
   - Clone the repository with specific branch: `git clone -b orange-pi-6.1-sun50iw9 --depth=1 https://github.com/orangepi-xunlong/linux-orangepi`
   - Navigate to: `sound/soc/sunxi_v2/`
   - Attempt to compile the DAUDIO driver module

4. **If driver NOT found in vendor branch**:
   - Driver never released publicly
   - Contact Orange Pi support directly
   - Post to Orange Pi forums with findings
   - **Recommendation**: Purchase alternative hardware with better I2S support

## Critical Question

**Does `sound/soc/sunxi_v2/snd_sunxi_ahub_daudio.c` exist in the `orange-pi-6.1-sun50iw9` branch?**

This is the definitive test of whether the driver exists in Orange Pi's public kernel source.

## Repository Structure Expected

If vendor BSP exists, structure should be:
```
linux-orangepi/
├── sound/
│   └── soc/
│       ├── sunxi/          # Mainline drivers (confirmed exists)
│       └── sunxi_v2/       # Vendor BSP drivers (need to verify)
│           ├── Kconfig
│           ├── Makefile
│           ├── snd_sunxi_ahub_daudio.c
│           ├── snd_sunxi_ahub_dam.c
│           └── ...
```

## Branches to Check

- `orange-pi-4.9-sun50iw9` (legacy)
- `orange-pi-5.4-sun50iw9` (current)
- `orange-pi-6.1-sun50iw9` (next) ← **Priority: matches current kernel 6.1.31**

## Status

⏳ **PENDING**: Manual browser check of vendor BSP branch to confirm existence of sunxi_v2 directory

---

**Date**: $(date)  
**Current Kernel**: 6.1.31-sun50iw9 (Orange Pi OS)  
**Current OS**: Orange Pi Jammy (Ubuntu 22.04)
