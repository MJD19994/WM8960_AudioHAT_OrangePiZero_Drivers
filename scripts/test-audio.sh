#!/bin/bash
# Quick audio test script

echo "Testing WM8960 Audio HAT..."
echo ""
echo "Card information:"
aplay -l | grep -A 2 "ahub0wm8960" || echo "WM8960 card not found!"
echo ""
echo "Playing test tone (1kHz, 2 seconds)..."
speaker-test -D plughw:3,0 -c 2 -r 48000 -t sine -f 1000 -l 2
