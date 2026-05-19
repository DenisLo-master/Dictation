#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Dictation.app"
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"

cd "$ROOT_DIR"

swift build -c release --product Dictation
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

swift "$ROOT_DIR/Scripts/generate-icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

cp "$BIN_DIR/Dictation" "$APP_DIR/Contents/MacOS/Dictation"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
chmod +x "$APP_DIR/Contents/MacOS/Dictation"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "Built $APP_DIR"
