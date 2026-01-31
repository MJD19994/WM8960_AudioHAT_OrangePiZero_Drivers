# Orange Pi Build System Instructions - Finding DAUDIO Driver

## What We Know

The manual points to: https://github.com/orangepi-xunlong/orangepi-build

**IMPORTANT**: This is the BUILD SYSTEM, not the kernel source itself.

## Two Possible Paths

### Path 1: Use orangepi-build to Download Kernel Source (RECOMMENDED)

1. **Clone orangepi-build:**
   ```bash
   git clone https://github.com/orangepi-xunlong/orangepi-build.git
   cd orangepi-build
   ```

2. **Run the build script:**
   ```bash
   sudo ./build.sh
   ```

3. **Select your board:**
   - Choose "orangepizero2w" from the menu
   - Select kernel branch (likely "next" or "current")

4. **The build system will:**
   - Download the appropriate kernel source automatically
   - Store it in: `external/cache/sources/linux-<kernel_version>-<soc>/`
   
5. **Search for DAUDIO driver:**
   ```bash
   find external/cache/sources/ -name "*daudio*"
   find external/cache/sources/ -path "*/sound/soc/sunxi*" -name "*"
   ```

6. **Check kernel config:**
   ```bash
   cd external/cache/sources/linux-*/
   grep -i daudio .config
   grep -i "CONFIG_SND_SOC.*AHUB" .config
   ```

### Path 2: Find Pre-packaged Kernel Source on Google Drive

The Google Drive you found (https://drive.google.com/drive/folders/1vsbWC8RqeLDxNBWgYmiKxOYcF6l9iJq1) should contain:

**Look for folders named:**
- `source` or `sources`
- `linux-source` or `kernel-source`  
- `sun50iw9` (your SoC family)
- `linux-6.1` (your kernel version)
- `orangepi-build` (full build system with source)
- `SDK` or `BSP` packages

**Inside those folders, look for files like:**
- `linux-source-6.1-sun50iw9.tar.gz`
- `orangepi-sdk-h618.tar.gz`
- `kernel-sun50iw9.tar.gz`

**After downloading and extracting, search for:**
```bash
tar -tzf linux-source*.tar.gz | grep daudio
# OR after extraction:
find . -name "*daudio*"
find . -path "*/sound/soc/sunxi*"
```

## What to Look For

### If Driver Exists ✅

You should find files like:
```
sound/soc/sunxi_v2/snd_sunxi_ahub_daudio.c
sound/soc/sunxi_v2/snd_sunxi_ahub_daudio.h
sound/soc/sunxi_v2/Makefile (containing daudio references)
sound/soc/sunxi_v2/Kconfig (containing CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO)
```

### If Driver Doesn't Exist ❌

- No `*daudio*` files in `sound/soc/sunxi*`
- No CONFIG_SND_SOC_SUNXI_AHUB_DAUDIO in Kconfig
- Only HDMI audio-related files

**This means**: Driver was never released publicly, alternative hardware required.

## Next Steps Based on Findings

### Scenario A: Driver Found
1. Compile the driver module
2. Modify device tree to add external I2S nodes
3. Install driver and test

### Scenario B: Driver NOT Found
1. **Post to Orange Pi forums** (use COMMUNITY_POST_TEMPLATE.md)
2. **Ask Orange Pi directly** if they have DAUDIO driver for H618
3. **Consider alternative hardware:**
   - Radxa Zero 2 Pro / Zero 3 (verify I2S support first)
   - Banana Pi M2 Zero
   - USB audio adapter (workaround)

## Critical Questions to Answer

1. **Does orangepi-build automatically download kernel source when run?**
   - YES → Use Path 1
   - NO → You MUST find it on Google Drive (Path 2)

2. **What's in the Google Drive `source` or `SDK` folders?**
   - Navigate back from "Office_Tools" folder
   - Look for kernel-related packages
   - Share screenshot of main folder list

3. **Does the kernel source contain sun50iw9 DAUDIO driver?**
   - This is the CRITICAL question
   - Everything depends on this answer

## Time Estimate

- Path 1 (orangepi-build): 1-3 hours (includes download time)
- Path 2 (Google Drive): 30 minutes - 2 hours (depends on package size)

## Your Current Status

You were in the "Office_Tools" folder on Google Drive (contains utilities, not kernel source).

**ACTION NEEDED**: Navigate back to main Google Drive view and look for kernel/source folders.

## Final Note

This is your LAST investigation option. After checking the kernel source, we'll know definitively whether the DAUDIO driver exists or if you need alternative hardware.
