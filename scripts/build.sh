#!/bin/bash
# Builds Murmur.app into ./build without Xcode. Usage: scripts/build.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

config="${1:-release}"
swift build -c "$config"
bin="$(swift build -c "$config" --show-bin-path)/Murmur"

app="build/Murmur.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Murmur"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"   # redraw with scripts/make-icon.swift
codesign --force --sign - "$app" >/dev/null 2>&1

echo "$app"
