#!/bin/sh
# Regenerates icon/AppIcon-1024.png and icon/AppIcon.icns from make-icon.swift. Usage: icon/make-icon.sh
set -e
cd "$(dirname "$0")"

swift make-icon.swift AppIcon-1024.png
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z $size $size AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$(dirname "$ICONSET")"
echo "Wrote icon/AppIcon.icns"
