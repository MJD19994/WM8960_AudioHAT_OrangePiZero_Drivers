# Google Drive Source Investigation

**URL**: https://drive.google.com/drive/folders/1vsbWC8RqeLDxNBWgYmiKxOYcF6l9iJq1

Orange Pi stores their tools and source code on Google Drive.

---

## What to Look For

### 1. Kernel Source Package
Look for files named:
- `orangepi-zero-2w-linux-*.tar.gz`
- `linux-source-*.tar.gz`
- `kernel-source-*.tar.gz`
- `OrangePi-Kernel-*.tar.gz`
- `sun50iw9-linux-*.tar.gz`

### 2. SDK Package
Look for:
- `orangepi-sdk-*.tar.gz`
- `OrangePi-Build-*.tar.gz`
- `BSP-*.tar.gz`
- `Tina-SDK-*.tar.gz`
- `Longan-SDK-*.tar.gz`

### 3. What to Search Inside

Once downloaded and extracted:

```bash
# Extract the source
tar -xzf [downloaded-file].tar.gz
cd [extracted-directory]

# Search for DAUDIO driver
find . -name "*daudio*"
find . -name "*ahub*" -name "*.c"
find . -path "*/sound/soc/sunxi*" -name "*ahub*.c"

# Search for AHUB I2S driver
find . -path "*/sound/soc/sunxi*" -name "*.c" | grep -i i2s

# Check sound/soc/sunxi_v2 directory (vendor driver location)
ls -la sound/soc/sunxi_v2/ 2>/dev/null

# Search for H618 / sun50iw9 specific audio
find . -name "*sun50iw9*" | grep -i audio
find . -name "*h618*" | grep -i audio
```

### 4. Key Directories to Check

If kernel source exists, check these paths:

```
sound/soc/sunxi_v2/              ← Vendor AHUB drivers
sound/soc/sunxi_v2/snd_sunxi_ahub_daudio.c   ← THE MISSING DRIVER
sound/soc/sunxi_v2/snd_sunxi_ahub_dam.c      ← DAM driver (we have this)
sound/soc/sunxi_v2/snd_sunxi_ahub.c          ← AHUB core (we have this)
sound/soc/sunxi_v2/snd_sunxi_mach.c          ← Machine driver (we have this)

arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero2w.dts  ← Device tree source
```

### 5. Device Tree Source Check

If you find the DTS file, look for AHUB I2S nodes:

```bash
# In the source directory
cat arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero2w.dts | grep -A 20 "ahub"

# Look for disabled ahub2, ahub3, etc.
grep "ahub[0-9]" arch/arm64/boot/dts/allwinner/*.dts*
```

They might have **disabled** ahub2/ahub3 in the DTS with `status = "disabled"`.

---

## Alternative: Check the Build System

Look for:
- `OrangePi-Build/` directory
- `scripts/` directory with kernel build scripts
- `configs/` directory with kernel configurations

Check the kernel config:
```bash
# Find kernel config for Zero 2W
find . -name "*h618*config" -o -name "*sun50iw9*config"
cat [config-file] | grep DAUDIO
cat [config-file] | grep AHUB
```

---

## If Source Found - Compilation Steps

### Option 1: Find Pre-compiled DAUDIO Module

```bash
# Search for already compiled .ko file
find . -name "snd_sunxi_ahub_daudio.ko"
find . -name "*daudio*.ko"
```

### Option 2: Compile DAUDIO Driver

If source code exists in `sound/soc/sunxi_v2/`:

```bash
# On your Orange Pi
cd [kernel-source]

# Prepare kernel build environment
make scripts
make prepare

# Try to compile just the AHUB audio drivers
make M=sound/soc/sunxi_v2/

# Or compile specific driver
make M=sound/soc/sunxi_v2/ snd_sunxi_ahub_daudio.ko

# Install the module
sudo cp sound/soc/sunxi_v2/snd_sunxi_ahub_daudio.ko /lib/modules/$(uname -r)/kernel/sound/soc/
sudo depmod -a
```

---

## Expected Outcome

### If Driver Source Found ✅

1. **Compile** the missing DAUDIO driver
2. **Load** the module: `modprobe snd_sunxi_ahub_daudio`
3. **Create** ahub2 or ahub3 device tree nodes
4. **Recompile** device tree overlay
5. **Test** WM8960 audio

### If Driver NOT Found ❌

**Conclusion**: Driver never released publicly.

**Options:**
1. **Contact Orange Pi** officially requesting driver source
2. **Post on forums** with findings (COMMUNITY_POST_TEMPLATE.md)
3. **Purchase alternative hardware** (Radxa Zero 2/3)
4. **Use USB audio** as workaround
5. **Wait for community** to reverse engineer or Orange Pi to release

---

## Additional Files to Look For

### Documentation
- `DATASHEETS/H618-*.pdf`
- `docs/audio/`
- `README-audio.txt`
- Any PDFs about AHUB or audio

### Patches
- `patches/` directory
- Look for: `*ahub*.patch`, `*audio*.patch`, `*i2s*.patch`

### Binary Blobs
- `firmware/` directory
- Pre-compiled binaries: `*.ko`, `*.bin`

---

## Download Instructions

1. **Browse** the Google Drive folder
2. **Download** any kernel source or SDK packages
3. **Extract** on your Orange Pi or dev machine:
   ```bash
   tar -xzf [package].tar.gz
   cd [extracted-dir]
   ```
4. **Run** the search commands above
5. **Report** what you find

---

## Critical Question to Answer

**Does the DAUDIO driver source code exist in the Google Drive source package?**

- **YES** → We can compile it and solve this!
- **NO** → Driver was never released, need alternative solution

---

## Next Steps After Checking

If source found:
- Update ACTION_PLAN.md with compilation instructions
- Create COMPILATION_GUIDE.md
- Test and document success

If source NOT found:
- Document definitive conclusion
- Recommend Radxa Zero 2/3 with verification
- Post to community forums
- Consider USB audio adapter

---

**Check the Google Drive now and report what you find!**
