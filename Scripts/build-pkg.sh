#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_BUILD_DIR="$ROOT_DIR/build"
BUILD_DIR="${DICTATION_BUILD_DIR:-$DEFAULT_BUILD_DIR}"
if [ -z "${DICTATION_BUILD_DIR:-}" ] && [ -e "$DEFAULT_BUILD_DIR/Dictation.app" ] && [ ! -w "$DEFAULT_BUILD_DIR/Dictation.app" ]; then
  BUILD_DIR="$DEFAULT_BUILD_DIR/current"
fi
APP_DIR="$BUILD_DIR/Dictation.app"
PKG_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dictation-pkg-root.XXXXXX")"
PKG_SCRIPTS="$(mktemp -d "${TMPDIR:-/tmp}/dictation-pkg-scripts.XXXXXX")"
PKG_PATH="$BUILD_DIR/Dictation.pkg"

DICTATION_BUILD_DIR="$BUILD_DIR" "$ROOT_DIR/Scripts/build-app.sh"

rm -f "$PKG_PATH"
mkdir -p "$PKG_ROOT/Applications" "$PKG_SCRIPTS"

COPYFILE_DISABLE=1 COPY_EXTENDED_ATTRIBUTES_DISABLE=1 /usr/bin/ditto --norsrc --noextattr "$APP_DIR" "$PKG_ROOT/Applications/Dictation.app"
if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$PKG_ROOT"
fi
find "$PKG_ROOT" -name '._*' -delete

cat > "$PKG_SCRIPTS/preinstall" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

/usr/bin/osascript -e 'tell application id "dev.denis.Dictation" to quit' >/dev/null 2>&1 || true
/bin/sleep 1
/usr/bin/pkill -x Dictation >/dev/null 2>&1 || true

for app in \
  "/Applications/Dictation.app" \
  /Applications/Dictation\ [0-9]*.app \
  /Applications/Dictation\ copy*.app \
  /Applications/Dictation\ копия*.app
do
  if [ -e "$app" ]; then
    /bin/rm -rf "$app"
  fi
done

exit 0
SCRIPT

cat > "$PKG_SCRIPTS/postinstall" <<'SCRIPT'
#!/bin/bash
set -euo pipefail

APP_PATH="/Applications/Dictation.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

/usr/bin/touch "$APP_PATH" || true
if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$APP_PATH" >/dev/null 2>&1 || true
fi
/usr/bin/qlmanage -r cache >/dev/null 2>&1 || true

logged_in_user="$(/usr/bin/stat -f %Su /dev/console)"
if [ -n "$logged_in_user" ] && [ "$logged_in_user" != "root" ]; then
  user_id="$(/usr/bin/id -u "$logged_in_user")"
  /bin/launchctl asuser "$user_id" /usr/bin/osascript -e 'tell application "Finder" to update POSIX file "/Applications/Dictation.app"' >/dev/null 2>&1 || true
  /bin/launchctl asuser "$user_id" /usr/bin/open -a "$APP_PATH" >/dev/null 2>&1 || true
fi

exit 0
SCRIPT

chmod +x "$PKG_SCRIPTS/preinstall" "$PKG_SCRIPTS/postinstall"

COPYFILE_DISABLE=1 COPY_EXTENDED_ATTRIBUTES_DISABLE=1 pkgbuild \
  --root "$PKG_ROOT" \
  --scripts "$PKG_SCRIPTS" \
  --install-location "/" \
  --identifier "dev.denis.Dictation.pkg" \
  --version "0.1.17" \
  "$PKG_PATH"

echo "Built $PKG_PATH"

if [ "${DICTATION_KEEP_BUILD_APPS:-0}" != "1" ]; then
  rm -rf "$PKG_ROOT" "$PKG_SCRIPTS" "$APP_DIR" "$BUILD_DIR/AppIcon.iconset" 2>/dev/null || true
fi
