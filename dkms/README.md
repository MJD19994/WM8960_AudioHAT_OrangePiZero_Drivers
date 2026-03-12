# DKMS — WM8960 Patched Kernel Module

This directory contains everything needed to build the WM8960 codec kernel module via [DKMS](https://github.com/dell/dkms) (Dynamic Kernel Module Support). The module is built from mainline kernel source with patches applied to fix PLL clocking issues on boards with an onboard 24MHz crystal and no Linux clock driver.

## Why DKMS?

The mainline `snd-soc-wm8960` kernel module has bugs that affect boards like the WM8960 Audio HAT on the Orange Pi Zero 2W. Rather than shipping pre-compiled `.ko` files (which break on kernel updates and differ between distros), DKMS builds the patched module from source against the running kernel's headers. This means:

- One source works on both Armbian and Orange Pi OS
- Survives kernel upgrades (DKMS rebuilds automatically)
- No version/vermagic mismatches

## Patches Applied

Five changes vs mainline `sound/soc/codecs/wm8960.c` (kernel.org):

| # | Location | Change | Why |
|---|----------|--------|-----|
| 1 | `wm8960_set_dai_sysclk()` | Force `clk_id = WM8960_SYSCLK_PLL` and `freq_in = 24000000` | Board has 24MHz onboard crystal with no Linux clock driver — force PLL mode so the codec generates correct internal clocks |
| 2 | `wm8960_configure_clocking()` | Comment out `return 0` in slave mode check | Mainline skips ALL clock programming in slave mode — this lets PLL configuration proceed |
| 3 | `wm8960_configure_clocking()` | Add `WM8960_SYSCLK_PLL` fallback in sysclk switch | When the machine driver never calls `set_dai_sysclk` (Allwinner AHUB), `sysclk` is 0 — allow PLL mode to auto-calculate output frequency via `configure_pll()` |
| 4 | `wm8960_i2c_probe()` | Set `clk_id = WM8960_SYSCLK_PLL` and `freq_in = 24000000` at probe | Ensures PLL mode is active from boot, even if `set_dai_sysclk` is never called |
| 5 | DAPM routes | Add `MICB` supply routes to Boost Mixers | Ensures mic bias voltage powers on automatically during capture |

Patches 1-4 fix the "slave mode, but proceeding with no clock configuration" issue that causes only 48kHz to work correctly. With these patches, all sample rates (8kHz-48kHz) work directly on `hw:N,0` and rate switching no longer corrupts codec state.

Patch 5 is from Waveshare/Seeed's driver forks and improves microphone reliability.

## Files

| File | Purpose |
|------|---------|
| `wm8960.c` | Patched WM8960 codec driver source |
| `wm8960.h` | WM8960 register definitions header |
| `Makefile` | Out-of-tree kernel module build rules |
| `dkms.conf` | DKMS build configuration |
| `kheaders-6.1.31-sun50iw9.tar.xz` | Pre-prepared kernel headers for Orange Pi OS (see below) |

## Kernel Headers

DKMS requires kernel headers at `/lib/modules/$(uname -r)/build` to compile modules.

- **Armbian**: Install via `apt install linux-headers-current-sunxi64` — no extra steps needed.
- **Orange Pi OS**: The vendor BSP kernel (6.1.31-sun50iw9) ships no headers package. The included `kheaders-6.1.31-sun50iw9.tar.xz` (7.1 MB) is a stripped-down headers tree extracted from the full kernel source. The installer handles extracting and symlinking this automatically.

### Creating Kernel Headers From Source (Reference)

If you need to create a headers package for a different kernel version or board (e.g., for your own project), here is the process we used. The kernel source for Orange Pi OS comes from the vendor BSP repository:

- **Orange Pi kernel source**: https://github.com/orangepi-xunlong/linux-orangepi (branch `orange-pi-6.1-sun50iw9`)

#### Step 1: Clone and Prepare

```bash
git clone --depth 1 https://github.com/orangepi-xunlong/linux-orangepi.git -b orange-pi-6.1-sun50iw9
cd linux-orangepi
cp /boot/config-$(uname -r) .config
# Set CONFIG_LOCALVERSION to match your kernel's suffix
# e.g., for "6.1.31-sun50iw9", set CONFIG_LOCALVERSION="-sun50iw9"
make modules_prepare
```

#### Step 2: Use Full Headers or Create Minimal Headers

**Option A — Use the full source tree as headers (~1.9 GB)**

The simplest approach. After `make modules_prepare`, the entire source tree is ready for out-of-tree module builds. Just symlink it:

```bash
ln -sf /path/to/linux-orangepi /lib/modules/$(uname -r)/build
```

This is the easiest option if disk space is not a concern and you want the complete kernel source available for reference or further module development.

**Option B — Extract minimal headers (~56 MB uncompressed, ~7 MB compressed)**

For a smaller footprint, extract only the files needed for out-of-tree module builds:

```bash
SRCDIR=$(pwd)
HDRDIR=/tmp/kheaders-$(uname -r)
mkdir -p "$HDRDIR"

# Top-level build files
cp "$SRCDIR"/{Makefile,Kbuild,.config,Module.symvers} "$HDRDIR/"

# Kernel headers
cp -a "$SRCDIR/include" "$HDRDIR/"

# Architecture headers + Makefile (adjust arch for your platform)
mkdir -p "$HDRDIR/arch/arm64"
cp -a "$SRCDIR/arch/arm64/include" "$HDRDIR/arch/arm64/"
cp "$SRCDIR/arch/arm64/Makefile" "$HDRDIR/arch/arm64/"

# Build scripts (modpost, fixdep, etc.)
cp -a "$SRCDIR/scripts" "$HDRDIR/"

# Remove scripts not needed for module builds
rm -rf "$HDRDIR/scripts/"{dtc,kconfig,coccinelle,selinux,gcc-plugins,gdb,atomic}
```

Compress and install:

```bash
# Compress
tar cJf kheaders-$(uname -r).tar.xz -C /tmp kheaders-$(uname -r)/

# Install on target (symlink so DKMS can find it)
tar xJf kheaders-$(uname -r).tar.xz -C /usr/src/
ln -sf /usr/src/kheaders-$(uname -r) /lib/modules/$(uname -r)/build
```

The key insight is that out-of-tree module builds only need `include/`, `arch/*/include/`, `scripts/`, and the top-level build files — not the actual kernel source code. This reduces 1.9 GB down to ~56 MB (7 MB compressed).

## References

- [Mainline wm8960.c (kernel.org)](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/sound/soc/codecs/wm8960.c)
- [Waveshare WM8960 driver fork](https://github.com/waveshareteam/WM8960-Audio-HAT)
- [Seeed/HinTak WM8960 driver fork](https://github.com/HinTak/seeed-voicecard)
- [Orange Pi kernel source (vendor BSP)](https://github.com/orangepi-xunlong/linux-orangepi)
- [DKMS documentation](https://github.com/dell/dkms)
