#!/usr/bin/env python3
"""
Patch Orange Pi Zero 2W DTB to add WM8960 support
"""

import sys
import re

def main():
    dts_file = "/root/sun50i-h618-original.dts"
    output_file = "/root/sun50i-h618-wm8960.dts"
    
    print("Reading original DTS...")
    with open(dts_file, 'r') as f:
        content = f.read()
    
    # Find ahub1_mach closing brace and insert ahub0 nodes after it
    print("Adding AHUB0 platform and machine nodes...")
    ahub0_nodes = '''
		ahub0_plat {
			#sound-dai-cells = <0x00>;
			compatible = "allwinner,sunxi-snd-plat-ahub";
			apb_num = <0x00>;
			dmas = <0x24 0x03 0x24 0x03>;
			dma-names = "tx", "rx";
			playback_cma = <0x80>;
			capture_cma = <0x80>;
			tx_fifo_size = <0x80>;
			rx_fifo_size = <0x80>;
			tdm_num = <0x00>;
			tx_pin = <0x00>;
			rx_pin = <0x00>;
			pinctrl-names = "default";
			pinctrl-0 = <0x999>;
			status = "okay";
			phandle = <0x998>;
		};

		ahub0_mach {
			compatible = "allwinner,sunxi-snd-mach";
			soundcard-mach,name = "ahub0wm8960";
			soundcard-mach,format = "i2s";
			soundcard-mach,frame-master = <0x997>;
			soundcard-mach,bitclock-master = <0x997>;
			soundcard-mach,slot-num = <0x02>;
			soundcard-mach,slot-width = <0x20>;
			status = "okay";

			ahub0_cpu: soundcard-mach,cpu {
				sound-dai = <0x998>;
				soundcard-mach,pll-fs = <0x04>;
				phandle = <0x997>;
			};

			ahub0_codec: soundcard-mach,codec {
				sound-dai = <0x996>;
			};
		};
'''
    
    # Find ahub1_mach closing and insert after
    pattern = r'(ahub1_mach \{.*?soundcard-mach,codec \{.*?\};[\s\n]+\};)'
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + ahub0_nodes + content[insert_pos:]
        print("✓ AHUB0 nodes added")
    else:
        print("✗ Could not find ahub1_mach insertion point")
        return 1
    
    # Add i2s0 pinctrl
    print("Adding i2s0 pinctrl...")
    i2s0_pins = '''
		i2s0_pins: i2s0-pins {
			pins = "PI1", "PI2", "PI3", "PI4";
			function = "i2s0";
			drive-strength = <0x14>;
			bias-disable;
			phandle = <0x999>;
		};
'''
    
    # Find a pinctrl node to insert after (use uart0-ph-pins)
    pattern = r'(uart0-ph-pins \{.*?phandle = <0x29>;\s+\};)'
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + i2s0_pins + content[insert_pos:]
        print("✓ i2s0 pinctrl added")
    else:
        print("✗ Could not find pinctrl insertion point")
        return 1
    
    # Add WM8960 to i2c2
    print("Adding WM8960 codec to I2C2...")
    wm8960_node = '''
			wm8960@1a {
				compatible = "wlf,wm8960";
				reg = <0x1a>;
				#sound-dai-cells = <0x00>;
				wlf,shared-lrclk;
				status = "okay";
				phandle = <0x996>;
			};
'''
    
    # Add WM8960 to i2c2 (even though it's disabled, overlay enables it)
    pattern = r'(i2c@5003000 \{.*?#size-cells = <0x00>;)'
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    if match:
        insert_pos = match.end()
        content = content[:insert_pos] + wm8960_node + content[insert_pos:]
        print("✓ WM8960 codec added")
    else:
        print("✗ Could not find i2c2 insertion point")
        return 1
    
    # Write output
    print(f"Writing patched DTS to {output_file}...")
    with open(output_file, 'w') as f:
        f.write(content)
    
    print("✓ Patching complete!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
