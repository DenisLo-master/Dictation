#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DMG_ROOT="$BUILD_DIR/dmg-root"
DMG_PATH="$BUILD_DIR/Dictation.dmg"

"$ROOT_DIR/Scripts/build-app.sh"

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"

cp -R "$BUILD_DIR/Dictation.app" "$DMG_ROOT/Dictation.app"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "Dictation" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built $DMG_PATH"
