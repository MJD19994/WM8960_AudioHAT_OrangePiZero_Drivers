# Pi Zero Footprint SBC Alternatives for WM8960 Audio HAT

Research on alternatives to Orange Pi Zero 2W with same form factor and better audio support.

## Requirements
- ✅ Rectangular Pi Zero footprint (65mm x 30mm)
- ✅ 40-pin GPIO header
- ✅ More powerful than Pi Zero 2W (>1GHz quad-core)
- ✅ Working I2S audio support
- ✅ Compatible with Pi HATs
- ✅ Currently available for purchase

---

## Radxa Zero Series

### Radxa Zero (Original) - Amlogic S905Y2
**Specifications:**
- Form factor: 65mm x 30mm ✅ EXACT Pi Zero match
- CPU: Quad-core Cortex-A53 @ 1.8GHz (faster than Pi Zero 2W)
- RAM: 512MB - 4GB
- GPIO: 40-pin compatible
- I2S: Amlogic has I2S support in mainline Linux

**I2S Audio Status:**
- Amlogic S905Y2 has I2S controller
- Mainline kernel support exists
- Device tree overlays available
- **Need to verify**: WM8960 specifically

**Availability:** Limited (older model, being phased out)

**Price:** ~$15-35 (when available)

---

### Radxa Zero 2 Pro - Rockchip RK3528A
**Specifications:**
- Form factor: **UNKNOWN** - need to verify if Pi Zero footprint
- CPU: Quad-core Cortex-A53 @ 2.0GHz
- RAM: 2GB - 8GB
- GPIO: Need to verify

**Status:** Need more research on form factor

---

### Radxa Zero 3 - Rockchip RK3566
**Specifications:**
- Form factor: **SQUARE** ❌ NOT Pi Zero footprint (66mm x 30mm but different GPIO position)
- CPU: Quad-core Cortex-A55 @ 1.8GHz
- RAM: 1GB - 8GB
- GPIO: 40-pin but different layout

**Audio Status:**
- RK3566 has excellent I2S support
- Mainline Linux support good
- **But form factor is WRONG**

**Verdict:** ❌ Not compatible with Pi Zero HATs due to layout differences

---

## Other Alternatives

### Banana Pi BPI-M2 Zero - Allwinner H3
**Specifications:**
- Form factor: 65mm x 52.5mm ❌ Wider than Pi Zero (but close)
- CPU: Quad-core Cortex-A7 @ 1.2GHz
- RAM: 512MB
- GPIO: 40-pin compatible
- I2S: Allwinner H3 has better driver support than H618

**I2S Audio Status:**
- H3 has sun4i-i2s driver in mainline
- Better documented than H618
- Device tree support exists
- Likely compatible with WM8960

**Availability:** Good (still in production)

**Price:** ~$20-25

**Verdict:** ⚠️ Slightly wider but might work if your enclosure allows

---

### NanoPi Neo Core/Neo2 - Allwinner H3/H5
**Specifications:**
- Form factor: 40mm x 40mm ❌ Square (but has 40-pin header)
- CPU: H3 or H5 (quad-core A53)
- I2S: Good support on H3/H5

**Verdict:** ❌ Wrong form factor for Pi Zero HATs

---

### Raspberry Pi Zero 2 W (Baseline)
**Specifications:**
- Form factor: 65mm x 30mm ✅
- CPU: Quad-core Cortex-A53 @ 1GHz
- RAM: 512MB
- GPIO: 40-pin (original design)
- I2S: Perfect support (designed for it)

**Audio Status:** ✅ Works perfectly with WM8960 HATs

**Availability:** Improving (but still limited stock)

**Price:** ~$15-20

**Verdict:** ✅ Guaranteed to work, but not more powerful

---

## Research Needed

### For Radxa Zero (Original)
- [ ] Confirm I2S pinout matches Pi Zero
- [ ] Find WM8960 device tree overlay examples
- [ ] Check Armbian/Radxa OS support status
- [ ] Verify current availability/pricing

### For BPI-M2 Zero
- [ ] Verify WM8960 HAT physical fit (width difference)
- [ ] Find I2S device tree examples for H3
- [ ] Check Armbian support

---

## Recommendations

### Best Option (If Available): Radxa Zero (Original)
**Pros:**
- Exact Pi Zero footprint ✅
- 1.8GHz (faster than Pi Zero 2W) ✅
- Amlogic has I2S support ✅
- Good mainline Linux support ✅

**Cons:**
- Limited availability
- Need to verify WM8960 compatibility
- Less community support than Pi

**Action:** Search Aliexpress, official Radxa store, Arace

### Alternative: Banana Pi BPI-M2 Zero
**Pros:**
- Close to Pi Zero size
- Allwinner H3 has better driver support than H618
- Currently available
- Affordable

**Cons:**
- 22.5mm wider (might not fit enclosures)
- Only 512MB RAM
- Slower than Zero 2W

### Safest Option: Raspberry Pi Zero 2 W
**Pros:**
- Guaranteed compatibility ✅
- Perfect form factor ✅
- Best community support ✅

**Cons:**
- Not more powerful than original ❌
- Still limited availability

---

## Next Steps

1. **Research Radxa Zero I2S pinout**
   - Check if pins 12, 35, 38, 40 are I2S on Radxa Zero
   - Find device tree documentation
   - Look for existing audio HAT projects

2. **Check Radxa Forum**
   - Search for "I2S" or "audio HAT"
   - Ask about WM8960 compatibility
   - Check Armbian support status

3. **Measure BPI-M2 Zero viability**
   - Check if extra width matters for your use case
   - Verify I2S driver availability

4. **Or Continue Orange Pi Zero 2W driver search**
   - Post on Orange Pi forum
   - Contact Orange Pi support
   - Check if anyone has found DAUDIO driver

---

## Resources

- Radxa Wiki: https://wiki.radxa.com/
- Radxa Forum: https://forum.radxa.com/
- Armbian Forum: https://forum.armbian.com/
- linux-sunxi Wiki: https://linux-sunxi.org/
- Pi Zero HAT Pinout: https://pinout.xyz/

---

**Status:** Research in progress - need to verify Radxa Zero I2S compatibility specifically.
