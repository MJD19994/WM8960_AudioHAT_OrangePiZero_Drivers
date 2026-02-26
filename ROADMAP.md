# Project Roadmap

WM8960 Audio HAT Drivers for Orange Pi (H616/H618)

## Current State (v1.0)

What we ship today:

- Device tree overlay with fdtoverlay bake-in (works around broken U-Boot overlay mechanism)
- Precompiled kernel with WM8960/I2S/audio modules (6.1.31-orangepi)
- PLL configuration service (I2C register writes at boot)
- Full mixer defaults with alsactl save/restore
- ALSA asound.conf with dmix/dsnoop for multi-app audio
- Install, uninstall, and quick-setup scripts
- Diagnostic and interactive test script
- H616/H618 auto-detection

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
| PulseAudio config | No | Yes | No |
| PipeWire config | No | No | No |
| Python examples | No | Yes | No |
| LED/button support | No | Yes | No |
| Voice assistant guides | No | Yes | No |
| Multi-board support | Partial | Yes | No |
| DKMS kernel module | No | Yes | Yes |

**Our strengths:** Test tooling, mixer management, fdtoverlay approach for non-Raspberry Pi boards, detailed documentation.

**Our gaps:** No PulseAudio/PipeWire support, no Python examples, no higher-level application guides.

---

## Phase 1 — Stability & Install Robustness

Focus: Make install/uninstall bulletproof for first-time users.

### 1.1 DTB Patching Idempotency
The install script can currently re-patch an already-patched DTB if run twice. Fix to always resolve back to the original unpatched DTB before applying the overlay.

### 1.2 Module Backup in Kernel Install
`install-kernel.sh` does `rm -rf /lib/modules/...` before extracting new modules. Add a backup step so a failed mid-install doesn't leave the system without modules.

### 1.3 Non-Interactive Detection in Test Script
Interactive `read -p` prompts hang when run without a TTY (piped, cron, SSH without pty). Detect `[ -t 0 ]` and skip interactive tests automatically, running diagnostics only.

### 1.4 Verbose/Debug Logging Mode
Add `--verbose` flag to `install.sh` and `wm8960-pll-config.sh` that logs detailed step-by-step output to help users troubleshoot failures.

### 1.5 Clean Up Unused wm8960.state
`configs/wm8960.state` is installed to `/etc/wm8960.state` but never used by the service (which uses `alsactl store/restore` with `/var/lib/alsa/asound.state`). Either remove it or repurpose it as a factory-defaults restore source.

### 1.6 Sample Rate Flexibility
Currently the PLL is configured for 12.288MHz SYSCLK (48kHz family only), and `asound.conf` hardcodes `rate 48000` in dmix/dsnoop. The ALSA `plug` layer handles software resampling transparently, so apps requesting 16kHz already work — but through conversion, not natively.

**Investigation findings (WM8960 clock architecture):**

The WM8960's ADCDIV/DACDIV registers can divide SYSCLK to produce multiple native rates from our existing 12.288MHz PLL:

| ADCDIV/DACDIV | Formula | Native Rate |
|---|---|---|
| ÷1 | 12288000 / (1 × 256) | 48000 Hz |
| ÷1.5 | 12288000 / (1.5 × 256) | 32000 Hz |
| ÷2 | 12288000 / (2 × 256) | 24000 Hz |
| ÷3 | 12288000 / (3 × 256) | 16000 Hz |
| ÷4 | 12288000 / (4 × 256) | 12000 Hz |
| ÷6 | 12288000 / (6 × 256) | 8000 Hz |

The kernel's `snd-soc-wm8960` driver has `hw_params` callbacks that can reprogram these dividers dynamically when an app opens the device at a different rate. However, our PLL script writes register 0x04 (CLOCKING1) directly via I2C before rebinding the driver, which may conflict with the kernel's own clock management.

**Test results (confirmed on device 2026-02-24):**

The kernel driver is in slave mode and **does not reconfigure clocks**. Every stream open logs: `"slave mode, but proceeding with no clock configuration"`. The driver accepts any rate from 8-48kHz at the ALSA level but the hardware clock stays at whatever our PLL script set (48kHz). Non-48kHz rates produce garbled/pitched audio on `hw:3,0`.

| Rate | Accepted? | Sounds Correct? | Why |
|------|-----------|-----------------|-----|
| 48000 Hz | Yes | Yes | Matches PLL SYSCLK |
| 44100 Hz | Yes | No (subtle pitch shift) | 48kHz clock, ~9% fast |
| 32000 Hz | Yes | No (pitched up) | 48kHz clock, 1.5× fast |
| 24000 Hz | No | N/A | Rejected by driver |
| 16000 Hz | Yes | No (chipmunk) | 48kHz clock, 3× fast |
| 8000 Hz | Yes | No (extreme chipmunk) | 48kHz clock, 6× fast |

**Conclusion:** Only 48kHz works natively. All other rates must go through ALSA software resampling (the `plug` layer in our `asound.conf`). This is how Seeed and Waveshare handle it too — they also hardcode their dmix/dsnoop to one rate and let ALSA resample.

**The good news:** Apps using the default ALSA device (`plug` → `asymed` → `dmix`/`dsnoop`) get automatic transparent resampling. A voice pipeline requesting 16kHz will work correctly — ALSA converts 48kHz↔16kHz in software. The quality is fine for speech.

**Driver modification attempt (2026-02-25):**

We attempted to patch the kernel driver (`snd-soc-wm8960.ko`) to enable native multi-rate support via PLL reconfiguration. Multiple approaches were tried:
- v1: Read `wlf,mclk-frequency` DT property at probe, set `WM8960_SYSCLK_AUTO` mode — failed because the AHUB machine driver calls `set_dai_sysclk(freq=0)` at stream open, overwriting our values
- v2: Store DT value separately (`dt_mclk_freq`), restore in `configure_clocking` fallback — PLL disable/enable cycle caused total audio loss (DAC stops producing output)
- v3: Configure PLL once at probe, only change dividers at runtime — also caused audio loss

**Root cause discovered:** The Allwinner AHUB **corrupts the WM8960 codec state when switching sample rates**. Even with the completely stock unmodified driver, playing 16kHz on `hw:3,0` then playing 48kHz results in silence — requiring a full reboot to recover. This is a bug in the AHUB machine driver (built-in `=y`, not modifiable).

**Final verdict:** Native multi-rate support is not feasible without modifying the built-in AHUB machine driver. Software resampling via ALSA dmix is the correct and proven approach.

**Remaining action items:**
- Document in README that 48kHz is the native hardware rate and other rates are software-resampled
- Document that apps must use the `default` ALSA device (never `hw:3,0` directly for non-48kHz rates)
- Consider adding a convenience ALSA device alias (e.g., `pcm.wm8960_16k`) for clarity

---

## Phase 2 — PulseAudio & PipeWire Support

Focus: Work out-of-the-box with modern Linux audio stacks, not just raw ALSA.

### 2.1 PulseAudio Configuration
Create a PulseAudio profile or `default.pa` snippet that:
- Sets the WM8960 as the default sink/source
- Uses the ALSA dmix/dsnoop underneath (or direct hardware access)
- Works alongside the existing asound.conf

### 2.2 PipeWire Configuration
PipeWire is the default on many modern distros and **no WM8960 project provides this**. Create PipeWire/WirePlumber config that:
- Defines the WM8960 as the default audio device
- Sets appropriate buffer sizes and sample rates
- Handles both playback and capture routing

### 2.3 Audio Stack Detection in Installer
Detect which audio server is running (PulseAudio, PipeWire, or bare ALSA) and install the appropriate configuration automatically.

---

## Phase 3 — Python Tools & Examples

Focus: Give users a programmatic interface and practical examples.

### 3.1 Device Discovery Utility
Python script to find the WM8960 sound card index and device name programmatically. Useful as a building block for other projects.

### 3.2 Recording Example
Simple Python script using `sounddevice` or `pyaudio` to record audio from the WM8960 microphones and save to WAV.

### 3.3 Playback Example
Python script to play WAV/MP3 files through the WM8960.

### 3.4 Volume Control Utility
Python CLI tool or simple TUI to adjust WM8960 mixer controls (master volume, mic gain, speaker/headphone select) without needing to know `amixer` syntax.

### 3.5 Audio Level Monitor
Real-time CLI display of input audio levels (VU meter style). Useful for verifying microphone input is working and adjusting gain.

---

## Phase 4 — Expanded Board Support

Focus: Support more Orange Pi models and audio HATs beyond our tested config.

### 4.1 Orange Pi Zero 3 Support
The Zero 3 uses the same H618 SoC. Verify and document compatibility, create board-specific overlay if needed.

### 4.2 Orange Pi Zero 2 (H616) Verification
We have an H616 overlay but haven't tested it. Find a user or device to verify.

### 4.3 Waveshare WM8960 Audio HAT Compatibility
The Waveshare HAT uses the same WM8960 codec but may have different pinout or additional components. Test and document.

### 4.4 Armbian Support
Armbian is the most widely used community OS for Orange Pi boards and would significantly expand our user base. Key differences from Orange Pi OS:

- **Kernel**: Armbian ships both vendor BSP kernels (6.1.x) and mainline kernels (6.6+). The BSP variant should be close to compatible; mainline will need investigation.
- **Device tree**: Armbian has its own DTB build pipeline and overlay mechanism (`armbian-add-overlay`). Our fdtoverlay approach should still work, but the base DTB path and naming may differ.
- **Boot config**: Armbian uses `/boot/armbianEnv.txt` instead of `orangepiEnv.txt`, and has a different U-Boot overlay loading mechanism that may actually work for our overlay (unlike Orange Pi's broken one).
- **Audio stack**: Armbian Bookworm images may ship PipeWire by default instead of bare ALSA, tying into Phase 2 work.
- **Module packaging**: Armbian kernels use different vermagic strings. Our precompiled kernel package won't work — we'd need either DKMS or Armbian-specific kernel modules.

**Action items:**
- Test install on Armbian Bookworm (BSP kernel) for Orange Pi Zero 2W
- Identify DTB path differences and make installer auto-detect
- Evaluate whether `armbian-add-overlay` can load our DTS directly (avoiding fdtoverlay)
- Determine if Armbian's built-in WM8960 kernel module works or if we need to ship our own
- Create Armbian-specific install path or make the existing installer smart enough to handle both

### 4.5 Mainline Kernel Investigation
Evaluate feasibility of supporting mainline Linux kernels (6.6+) instead of only the vendor BSP 6.1.31. This would future-proof the project as Orange Pi updates their OS releases. Relevant for both Armbian mainline images and future Orange Pi OS updates.

---

## Phase 5 — Advanced Audio Features

Focus: Unlock the full potential of the WM8960 hardware.

### 5.1 ALC (Automatic Level Control) Profiles
Create named presets for common ALC configurations:
- **Voice**: Optimized for speech recording (moderate attack/decay, narrow range)
- **Music**: Gentle compression for music playback
- **Conferencing**: Aggressive leveling for varying speaker distances
- Users could apply via: `wm8960-profile voice`

### 5.2 EQ / 3D Enhancement Presets
The WM8960 has built-in 3D stereo enhancement. Create presets that configure it for different use cases (speakers vs headphones, room size).

### 5.3 Loopback / Monitor Mode
Enable hardware monitoring path so users can hear microphone input through speakers/headphones in real-time (useful for testing, karaoke, etc).

### 5.4 Bluetooth Audio Bridge
Guide and/or script for routing Bluetooth audio through the WM8960 (using PulseAudio/PipeWire as the bridge). Play phone audio through the HAT speakers, or use the HAT microphones for Bluetooth calls.

---

## Phase 6 — Voice Assistant & Application Integration

Focus: Practical application guides that show what you can build.

### 6.1 Voice Assistant Quick-Start Guide
Documentation for setting up:
- Google Assistant
- Amazon Alexa
- OpenAI Whisper (local speech-to-text)
- Home Assistant voice pipeline

### 6.2 Intercom / Baby Monitor Project
Example project combining recording + playback + network streaming for a practical use case.

### 6.3 Music Player Integration
Guide for setting up MPD (Music Player Daemon) or Mopidy with the WM8960 HAT for a headless music player/streamer.

---

## Phase 7 — Hardware Extras (HAT-Dependent)

Focus: Support additional hardware features on HATs that have them.

### 7.1 APA102 LED Control (ReSpeaker HAT)
Python driver for the 3 RGB LEDs on the ReSpeaker 2-Mic HAT. Patterns for:
- Audio level visualization
- Status indicators (recording, playing, error)
- Custom animations

### 7.2 User Button Support (ReSpeaker HAT)
GPIO17 button handler with configurable actions:
- Push-to-talk
- Play/pause
- Record toggle
- Custom command execution

### 7.3 Grove Connector Examples (ReSpeaker HAT)
Example code for using the I2C and digital Grove connectors for sensor integration.

---

## Contribution & Priority Notes

- **Phases 1-2** are high priority — they fix real usability issues and fill the biggest feature gaps
- **Sample rate flexibility (1.6)** — native multi-rate is not feasible (AHUB bug), but software resampling via `default` device works perfectly for 16kHz voice pipelines
- **Armbian support (4.4)** is high priority — it's the most popular community OS for these boards and would greatly expand reach
- **Phase 3** is medium priority — makes the project much more accessible to Python developers
- **Phases 5-7** are lower priority and can be tackled based on community interest
- PipeWire support (2.2) is a unique differentiator — no other WM8960 project provides it
- Voice assistant integration (6.1) drives the most user interest based on forum activity

---

*Last updated: 2026-02-25*
