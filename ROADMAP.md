# WM8960 Audio HAT Drivers - Development Roadmap

> **Goal:** Build the most robust, feature-complete WM8960 Audio HAT driver package for Orange Pi boards (H616/H618), with first-class support for voice assistant and headless audio use cases.

## Supported Hardware

| Board | SoC | Status |
|-------|-----|--------|
| Orange Pi Zero 2W | H618 | Primary test board |
| Orange Pi Zero 3 | H618 | Should work (untested) |
| Orange Pi Zero 2 | H616 | Overlay exists (untested) |

| Audio HAT | WM8960 | LEDs | Button | Status |
|-----------|--------|------|--------|--------|
| Generic WM8960 HATs | Yes | No | No | Primary test board |
| Waveshare WM8960 Audio HAT | Yes | Power only | No | Planned |
| Seeed/Keyestudio ReSpeaker 2-Mic | Yes | 3x APA102 | 1x GPIO | Planned |

---

## Phase 1 — Stability & Install Robustness

Focus: Make install/uninstall bulletproof for first-time users.

### 1.1 DTB Patching Idempotency
- [x] Validate backup DTB is unpatched before using as overlay input
- [x] Check for existing WM8960 node and skip if already patched
- [x] Always patch from `.backup` file, never from current DTB

### 1.2 Module Backup in Kernel Install
- [x] Back up existing modules to timestamped directory before replacing
- [x] Clean up backup automatically on success
- [x] Print rollback instructions on failure (via EXIT trap)

### 1.3 Non-Interactive Detection in Test Script
- [x] Detect `[ ! -t 0 ]` (no TTY) and auto-switch to diagnostics-only mode
- [x] Prevents `read -p` from hanging when run via pipe, cron, or SSH without pty

### 1.4 Verbose/Debug Logging Mode
- [x] `--verbose` / `-v` flag on `install.sh` with DTB path and symlink debug output
- [x] `--verbose` / `-v` flag on `wm8960-pll-config.sh` with device wait, card detection, and mixer state debug output
- [x] `--help` / `-h` flag on both scripts

### 1.5 Clean Up Unused wm8960.state
- [x] Removed `configs/wm8960.state` from repo (was installed but never read)
- [x] `apply_mixer_defaults()` in `wm8960-pll-config.sh` is the authoritative factory defaults source
- [x] `--reset-defaults` flag uses amixer commands, not state file

### 1.6 Sample Rate Investigation
- [x] Investigated WM8960 ADCDIV/DACDIV register-based multi-rate support
- [x] Tested all rates 8kHz–48kHz on hardware — only 48kHz sounds correct on `hw:3,0`
- [x] Confirmed kernel driver is in slave mode (does not reconfigure clocks)
- [x] Attempted driver modification (3 approaches) — all failed due to AHUB machine driver bug
- [x] Discovered root cause: Allwinner AHUB corrupts codec state on rate switching
- [x] Verified ALSA software resampling via `default` device works for all rates (16kHz recording/playback confirmed)
- [x] Documented sample rate behavior and voice assistant usage in README

### 1.7 Quick Setup Script
- [x] `quick-setup.sh` — single command for kernel + driver install
- [x] Auto-detects if WM8960 kernel module is already present (skips kernel install)
- [x] Delegates to existing `install.sh` for driver setup (no logic duplication)

### 1.8 Uninstall Robustness
- [ ] Test uninstall on a fully installed system and verify clean removal
- [ ] Verify DTB restore works correctly (symlink removal + backup copy)
- [ ] Add `--verbose` flag to `uninstall.sh` for consistency
- [ ] Consider adding kernel rollback option (restore boot symlinks to previous kernel)

---

## Phase 2 — PulseAudio & PipeWire Support

Focus: Work out-of-the-box with modern Linux audio stacks, not just raw ALSA.

### 2.1 PulseAudio Configuration
- [ ] Ship `default.pa` snippet for PulseAudio setups
- [ ] Set WM8960 as default sink/source
- [ ] Configure proper sample rate (48kHz native, resampling handled by PA)
- [ ] Install conditionally (only if PulseAudio is present)

### 2.2 PipeWire Configuration
PipeWire is the default on many modern distros and **no WM8960 project provides this**.
- [ ] Ship WirePlumber rules to set WM8960 as default sink/source
- [ ] Configure appropriate buffer sizes and sample rates
- [ ] Handle both playback and capture routing
- [ ] Test coexistence with HDMI audio (if present)

### 2.3 Audio Stack Detection in Installer
- [ ] Detect which audio server is running (PipeWire, PulseAudio, or bare ALSA)
- [ ] Install the appropriate configuration automatically
- [ ] Log which audio stack was detected (helpful for troubleshooting)

---

## Phase 3 — Python Tools & Examples

Focus: Give users a programmatic interface and practical examples.

### 3.1 Device Discovery Utility
- [ ] Python script to find WM8960 card index and device name programmatically
- [ ] Handle multiple sound cards gracefully
- [ ] Usable as a building block / importable module for other projects

### 3.2 Recording Example
- [ ] Python script using `sounddevice` or `pyaudio` to record from WM8960 mics
- [ ] Save to WAV file
- [ ] Support configurable sample rate (demonstrate 16kHz for voice, 48kHz for general)

### 3.3 Playback Example
- [ ] Python script to play WAV/MP3 files through the WM8960
- [ ] Auto-detect WM8960 device (use discovery utility)

### 3.4 Volume Control Utility
- [ ] Python CLI tool to adjust WM8960 mixer controls without knowing `amixer` syntax
- [ ] Named presets: `speakers`, `headphones`, `recording`, `voice`
- [ ] `show` command to display current levels
- [ ] `reset` command to restore factory defaults

### 3.5 Audio Level Monitor
- [ ] Real-time CLI VU meter display of input audio levels
- [ ] Useful for verifying microphone input and adjusting gain
- [ ] Configurable threshold indicators

---

## Phase 4 — Expanded Board & OS Support

Focus: Support more Orange Pi models, HAT variants, and Linux distributions.

### 4.1 Orange Pi Zero 3 (H618) Verification
- [ ] Verify compatibility (same H618 SoC as Zero 2W)
- [ ] Test with existing overlay and installer
- [ ] Document any differences (pin routing, DTB naming)

### 4.2 Orange Pi Zero 2 (H616) Verification
- [ ] Test the existing H616 overlay on real hardware
- [ ] Find a user or device for testing
- [ ] Document compatibility status

### 4.3 Waveshare WM8960 Audio HAT Compatibility
- [ ] Test with the Waveshare variant (same WM8960, may differ in pinout)
- [ ] Document any hardware differences
- [ ] Create HAT-specific configuration if needed

### 4.4 Armbian Support (High Priority)
Armbian is the most popular community OS for Orange Pi boards.
- [ ] Test install on Armbian Bookworm (BSP kernel) for Orange Pi Zero 2W
- [ ] Identify DTB path differences and make installer auto-detect
- [ ] Evaluate whether `armbian-add-overlay` can load our DTS directly
- [ ] Determine if Armbian's built-in WM8960 kernel module works or if we need our own
- [ ] Handle `/boot/armbianEnv.txt` vs `orangepiEnv.txt` differences
- [ ] Make installer smart enough to handle both Orange Pi OS and Armbian
- [ ] Test with Armbian desktop images (PipeWire default — ties into Phase 2)

### 4.5 Mainline Kernel Investigation
- [ ] Evaluate feasibility of mainline Linux kernels (6.6+)
- [ ] Test if mainline `snd-soc-wm8960` module works with our overlay
- [ ] Determine if I2S/AHUB support exists in mainline for H616/H618
- [ ] Document findings and compatibility matrix

### 4.6 DKMS Kernel Module Packaging
- [ ] Evaluate building WM8960/I2S modules via DKMS instead of shipping a full kernel
- [ ] Would allow compatibility with kernel upgrades without rebuilding
- [ ] Requires kernel headers to be available on target system
- [ ] Could eliminate the need for `install-kernel.sh` entirely

---

## Phase 5 — Advanced Audio Features

Focus: Unlock the full potential of the WM8960 hardware.

### 5.1 ALC (Automatic Level Control) Profiles
- [ ] Create named presets for common ALC configurations
- [ ] **Voice**: Optimized for speech recording (moderate attack/decay, narrow range)
- [ ] **Music**: Gentle compression for music playback
- [ ] **Conferencing**: Aggressive leveling for varying speaker distances
- [ ] Apply via: `wm8960-profile voice` or similar utility

### 5.2 EQ / 3D Enhancement Presets
- [ ] Configure WM8960's built-in 3D stereo enhancement for different scenarios
- [ ] Presets for: speakers vs headphones, small room vs large room
- [ ] Document available hardware DSP controls

### 5.3 Loopback / Monitor Mode
- [ ] Enable hardware monitoring path (mic → speakers/headphones in real-time)
- [ ] Useful for testing, karaoke, conferencing
- [ ] Script or simple command to toggle on/off

### 5.4 Bluetooth Audio Bridge
- [ ] Guide for routing Bluetooth audio through WM8960 via PulseAudio/PipeWire
- [ ] Play phone audio through HAT speakers
- [ ] Use HAT microphones for Bluetooth calls
- [ ] Depends on Phase 2 (PulseAudio/PipeWire support)

### 5.5 ALSA Convenience Device Aliases
- [ ] Add named ALSA device aliases in `asound.conf` for common use cases
- [ ] `pcm.wm8960_voice` — 16kHz mono capture for voice assistants
- [ ] `pcm.wm8960_music` — 48kHz stereo playback optimized for music
- [ ] Document usage in README

---

## Phase 6 — Voice Assistant & Application Integration

Focus: Practical application guides that show what you can build.

### 6.1 Voice Assistant Quick-Start Guide
- [ ] Home Assistant voice pipeline setup
- [ ] OpenAI Whisper (local speech-to-text)
- [ ] Google Assistant SDK
- [ ] Amazon Alexa AVS
- [ ] Document expected audio format (16kHz, 16-bit, mono via `default` device)

### 6.2 Echo Cancellation Setup
Without AEC, playing TTS through the speaker feeds back into the mic, breaking wake word detection.
- [ ] PipeWire AEC config using `libpipewire-module-echo-cancel` (WebRTC backend)
- [ ] PulseAudio AEC config using `module-echo-cancel`
- [ ] ALSA AEC config using SpeexDSP plugin (for headless / ALSA-only setups)
- [ ] Document which approach to use for which setup
- [ ] *Note: No WM8960 HAT manufacturer provides this — differentiator*

### 6.3 Music Player Integration
- [ ] Guide for MPD (Music Player Daemon) with WM8960 HAT
- [ ] Guide for Mopidy as a headless music streamer
- [ ] ALSA device configuration for each

### 6.4 Intercom / Baby Monitor Project
- [ ] Example project combining recording + playback + network streaming
- [ ] Practical use case demonstrating full-duplex audio

---

## Phase 7 — Hardware Extras (HAT-Dependent)

Focus: Support additional hardware features on HATs that have them.

### 7.1 APA102 LED Control (ReSpeaker HAT)
- [ ] Python driver for 3 RGB LEDs (APA102 over SPI)
- [ ] Patterns: audio level visualization, status indicators, custom animations
- [ ] Install as optional component (skip on HATs without LEDs)

### 7.2 User Button Support (ReSpeaker HAT)
- [ ] GPIO button handler with configurable actions
- [ ] Push-to-talk, play/pause, record toggle, custom command
- [ ] Install as optional component

### 7.3 Grove Connector Examples (ReSpeaker HAT)
- [ ] Example code for I2C and digital Grove connectors
- [ ] Sensor integration examples

---

## Completed Features

Features already implemented and working.

- [x] Device tree overlay with `fdtoverlay` bake-in (works around broken U-Boot overlay mechanism)
- [x] Precompiled kernel with WM8960/I2S/audio modules (`6.1.31-orangepi`)
- [x] PLL configuration service (I2C register writes at boot, unbind/rebind driver)
- [x] Full mixer defaults with `alsactl save/restore` and `--reset-defaults` flag
- [x] ALSA `asound.conf` with dmix/dsnoop/asym/plug for multi-app audio
- [x] `install.sh` with DTB patching, service install, ALSA config, prerequisite checks
- [x] `uninstall.sh` with service removal, DTB restore, config cleanup
- [x] `quick-setup.sh` — single-command all-in-one installer (kernel + driver)
- [x] `install-kernel.sh` with module backup, boot symlink management, initramfs generation
- [x] `test-audio.sh` with 10 diagnostic checks + 4 interactive audio tests
- [x] H616/H618 auto-detection in device tree overlay
- [x] Non-interactive detection in test script (auto-skip prompts without TTY)
- [x] `--verbose` debug logging in install and PLL config scripts
- [x] DTB patching idempotency (backup validation, double-patch prevention)
- [x] Module backup safety net in kernel installer
- [x] Sample rate documentation (48kHz native, software resampling for other rates)

---

## Competitor Landscape

Research into Seeed Studio (seeed-voicecard), Waveshare, and Keyestudio driver packages:

| Feature | Us | Seeed | Waveshare |
|---------|:--:|:-----:|:---------:|
| Install/uninstall scripts | Yes | Yes | Yes |
| Boot service | Yes | Yes | Yes |
| Mixer state management | Yes | Yes | Yes |
| dmix/dsnoop config | Yes | Yes | Yes |
| Diagnostic/test script | Yes | No | No |
| `--reset-defaults` flag | Yes | No | No |
| `--verbose` debug mode | Yes | No | No |
| Quick-setup (one command) | Yes | No | No |
| PulseAudio config | No | Yes | No |
| PipeWire config | No | No | No |
| Python examples | No | Yes | No |
| LED/button support | No | Yes | No |
| Voice assistant guides | No | Yes | No |
| Echo cancellation config | No | No | No |
| Multi-board support | Partial | Yes | No |
| DKMS kernel module | No | Yes | Yes |

**Our strengths:** Test tooling, mixer management, fdtoverlay approach for non-Raspberry Pi boards, verbose debugging, detailed documentation, idempotent installs.

**Our gaps:** No PulseAudio/PipeWire support, no Python examples, no higher-level application guides, no DKMS.

---

## Priority & Effort Matrix

| Phase | Impact | Effort | When |
|-------|--------|--------|------|
| Phase 1 — Stability | High | Low | **Done** |
| Phase 2 — Audio Stacks | High | Medium | Next |
| Phase 4.4 — Armbian | High | Medium | Next |
| Phase 3 — Python Tools | Medium | Low-Medium | After Phase 2 |
| Phase 5 — Advanced Audio | Medium | Low | After Phase 3 |
| Phase 6 — Voice/Apps | High (user interest) | Medium | After Phase 2 |
| Phase 4.6 — DKMS | High (maintainability) | High | When resources allow |
| Phase 7 — Hardware Extras | Low | Medium | Community driven |

---

## Investigation Notes

### Sample Rate Architecture (2026-02-24/25)

The WM8960's ADCDIV/DACDIV registers can divide SYSCLK to produce multiple native rates from our 12.288MHz PLL:

| ADCDIV/DACDIV | Formula | Native Rate |
|---|---|---|
| /1 | 12288000 / (1 x 256) | 48000 Hz |
| /1.5 | 12288000 / (1.5 x 256) | 32000 Hz |
| /2 | 12288000 / (2 x 256) | 24000 Hz |
| /3 | 12288000 / (3 x 256) | 16000 Hz |
| /4 | 12288000 / (4 x 256) | 12000 Hz |
| /6 | 12288000 / (6 x 256) | 8000 Hz |

However, the kernel driver is in slave mode and does not reconfigure clocks. Every stream open logs: `"slave mode, but proceeding with no clock configuration"`. The hardware clock stays at 48kHz regardless of the requested rate.

**Driver modification attempts (3 approaches, all failed):**
1. Read `wlf,mclk-frequency` DT property at probe, set `WM8960_SYSCLK_AUTO` — AHUB machine driver calls `set_dai_sysclk(freq=0)` at stream open, overwriting values
2. Store DT value in `dt_mclk_freq`, restore in `configure_clocking` fallback — PLL disable/enable cycle killed DAC output
3. Configure PLL at probe, only change dividers at runtime — also killed DAC output

**Root cause:** The Allwinner AHUB corrupts the WM8960 codec state when switching sample rates. Even with the stock unmodified driver, playing 16kHz on `hw:3,0` then playing 48kHz results in silence, requiring a full reboot. This is a bug in the AHUB machine driver (built-in `=y`, not modifiable).

**Solution:** Software resampling via ALSA dmix (same approach as Seeed/Waveshare). Apps using the `default` ALSA device get automatic transparent 48kHz<->any-rate conversion. Confirmed working for both 16kHz playback and 16kHz recording.

---

*Last updated: 2026-02-26*
