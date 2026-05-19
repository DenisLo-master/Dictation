#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_BUILD_DIR="$ROOT_DIR/build"
BUILD_DIR="${DICTATION_BUILD_DIR:-$DEFAULT_BUILD_DIR}"
if [ -z "${DICTATION_BUILD_DIR:-}" ] && [ -e "$DEFAULT_BUILD_DIR/Dictation.app" ] && [ ! -w "$DEFAULT_BUILD_DIR/Dictation.app" ]; then
  BUILD_DIR="$DEFAULT_BUILD_DIR/current"
fi
APP_DIR="$BUILD_DIR/Dictation.app"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

cd "$ROOT_DIR"

swift build -c release --product Dictation
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$BUILD_DIR"
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
