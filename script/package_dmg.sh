#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
APP_NAME="Rapid Reader"
PROCESS_NAME="RapidReader"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
PACKAGE_DIR="$ROOT_DIR/build/package"
STAGING_DIR="$ROOT_DIR/build/dmg-staging"
DMG_PATH="$PACKAGE_DIR/RapidReader-$VERSION.dmg"

cd "$ROOT_DIR"

"$ROOT_DIR/script/build_and_run.sh" --build-only

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle at $APP_BUNDLE" >&2
  exit 1
fi

if codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1; then
  codesign --verify --deep --strict "$APP_BUNDLE"
else
  echo "Warning: ad-hoc codesigning failed; continuing with unsigned local build." >&2
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$PACKAGE_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
rm -rf "$STAGING_DIR"
pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true

echo "$DMG_PATH"
