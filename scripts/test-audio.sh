#!/bin/bash
# Quick audio test script

echo "Testing WM8960 Audio HAT..."
echo ""
echo "Card information:"
if ! aplay -l | grep -A 2 "ahub0wm8960"; then
    echo "WM8960 card not found! Is the driver installed and loaded?"
    exit 1
fi
echo ""
echo "Playing test tone (1kHz, 2 seconds)..."
speaker-test -D plughw:ahub0wm8960,0 -c 2 -r 48000 -t sine -f 1000 -l 2
