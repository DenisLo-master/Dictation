#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_BUILD_DIR="$ROOT_DIR/build"
BUILD_DIR="${DICTATION_BUILD_DIR:-$DEFAULT_BUILD_DIR}"
if [ -z "${DICTATION_BUILD_DIR:-}" ] && [ -e "$DEFAULT_BUILD_DIR/Dictation.app" ] && [ ! -w "$DEFAULT_BUILD_DIR/Dictation.app" ]; then
  BUILD_DIR="$DEFAULT_BUILD_DIR/current"
fi
DMG_ROOT="$BUILD_DIR/dmg-root"
DMG_PATH="$BUILD_DIR/Dictation.dmg"

DICTATION_BUILD_DIR="$BUILD_DIR" "$ROOT_DIR/Scripts/build-pkg.sh"

rm -rf "$DMG_ROOT" "$DMG_PATH"
mkdir -p "$DMG_ROOT"

cp "$BUILD_DIR/Dictation.pkg" "$DMG_ROOT/Install Dictation.pkg"

hdiutil create \
  -volname "Dictation" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built $DMG_PATH"
