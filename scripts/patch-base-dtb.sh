#!/bin/bash
#
# Patch base DTB to add AHUB0 (I2S0) support for WM8960
#

set -e

DTS_FILE="$HOME/sun50i-h618-original.dts"
PATCHED_DTS="$HOME/sun50i-h618-wm8960.dts"
PATCHED_DTB="/boot/dtb/allwinner/sun50i-h618-orangepi-zero2w-wm8960.dtb"
BACKUP_DTB="/boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb.backup"

echo "========================================="
echo "WM8960 Base DTB Patcher"
echo "========================================="
echo ""

# Check if DTS exists
if [ ! -f "$DTS_FILE" ]; then
    echo "Error: $DTS_FILE not found!"
    echo "Run first: dtc -I dtb -O dts /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb > ~/sun50i-h618-original.dts"
    exit 1
fi

echo "[1/6] Copying original DTS..."
cp "$DTS_FILE" "$PATCHED_DTS"

echo "[2/6] Adding i2s0 pinctrl..."
# Find the pinctrl node and add i2s0 pins
sed -i '/pinctrl@300b000 {/,/};/{
    /i2c4_pins: i2c4-pins {/,/};/a\
\
		i2s0_pins: i2s0-pins {\
			pins = "PI1", "PI2", "PI3", "PI4";\
			function = "i2s0";\
			drive-strength = <0x14>;\
			bias-disable;\
			phandle = <0x999>;\
		};
}' "$PATCHED_DTS"

echo "[3/6] Adding AHUB0 platform device..."
# Add ahub0_plat after ahub_dam_mach
sed -i '/ahub_dam_mach {/,/};/{
    /};/a\
\
		ahub0_plat {\
			#sound-dai-cells = <0x00>;\
			compatible = "allwinner,sunxi-snd-plat-ahub";\
			apb_num = <0x00>;\
			dmas = <0x24 0x03 0x24 0x03>;\
			dma-names = "tx", "rx";\
			playback_cma = <0x80>;\
			capture_cma = <0x80>;\
			tx_fifo_size = <0x80>;\
			rx_fifo_size = <0x80>;\
			tdm_num = <0x00>;\
			tx_pin = <0x00>;\
			rx_pin = <0x00>;\
			pinctrl-names = "default";\
			pinctrl-0 = <0x999>;\
			status = "okay";\
			phandle = <0x998>;\
		};
}' "$PATCHED_DTS"

echo "[4/6] Adding AHUB0 machine driver..."
# Add ahub0_mach after ahub0_plat
sed -i '/ahub0_plat {/,/};/{
    /};/a\
\
		ahub0_mach {\
			compatible = "allwinner,sunxi-snd-mach";\
			soundcard-mach,name = "ahub0wm8960";\
			soundcard-mach,format = "i2s";\
			soundcard-mach,frame-master = <0x997>;\
			soundcard-mach,bitclock-master = <0x997>;\
			soundcard-mach,slot-num = <0x02>;\
			soundcard-mach,slot-width = <0x20>;\
			status = "okay";\
\
			ahub0_cpu: soundcard-mach,cpu {\
				sound-dai = <0x998>;\
				soundcard-mach,pll-fs = <0x04>;\
				phandle = <0x997>;\
			};\
\
			ahub0_codec: soundcard-mach,codec {\
				sound-dai = <0x996>;\
			};\
		};
}' "$PATCHED_DTS"

echo "[5/6] Adding WM8960 codec to I2C2..."
# Add WM8960 to i2c2 node
sed -i '/i2c@5003000 {/,/^[[:space:]]*};/{
    /status = "okay";/a\
\
			wm8960@1a {\
				compatible = "wlf,wm8960";\
				reg = <0x1a>;\
				#sound-dai-cells = <0x00>;\
				wlf,shared-lrclk;\
				status = "okay";\
				phandle = <0x996>;\
			};
}' "$PATCHED_DTS"

echo "[6/6] Compiling patched DTB..."
dtc -I dts -O dtb -o "$PATCHED_DTB" "$PATCHED_DTS" 2>&1 | grep -v "Warning" || true

# Backup original if not already backed up
if [ ! -f "$BACKUP_DTB" ]; then
    echo ""
    echo "Backing up original DTB..."
    sudo cp /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb "$BACKUP_DTB"
fi

echo ""
echo "========================================="
echo "✓ Patched DTB created!"
echo "========================================="
echo ""
echo "Files created:"
echo "  - Patched DTS: $PATCHED_DTS"
echo "  - Patched DTB: $PATCHED_DTB"
echo "  - Backup DTB: $BACKUP_DTB"
echo ""
echo "NEXT STEPS:"
echo "1. Review the patched DTS: less $PATCHED_DTS"
echo "2. Test the new DTB:"
echo "   sudo ln -sf sun50i-h618-orangepi-zero2w-wm8960.dtb /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb"
echo "3. Reboot: sudo reboot"
echo "4. Verify: cat /proc/asound/cards"
echo ""
echo "TO RESTORE ORIGINAL:"
echo "   sudo cp $BACKUP_DTB /boot/dtb/allwinner/sun50i-h618-orangepi-zero2w.dtb"
echo ""
