#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: $0 <version>, for example 1.1.0}"
APP_NAME="Rapid Reader"
PROCESS_NAME="RapidReader"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
PACKAGE_DIR="$ROOT_DIR/build/package"
STAGING_DIR="$ROOT_DIR/build/dmg-staging"
DMG_PATH="$PACKAGE_DIR/RapidReader-$VERSION.dmg"

cd "$ROOT_DIR"

# Optional distribution settings:
#   DEVELOPER_ID_APPLICATION  "Developer ID Application: Name (TEAMID)" for signing with the hardened runtime.
#   NOTARY_PROFILE            notarytool keychain profile (xcrun notarytool store-credentials) to notarize and staple.
# Without them the app is ad-hoc signed and Gatekeeper will ask users to confirm the first launch.
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
if [[ -n "$NOTARY_PROFILE" && -z "$SIGN_IDENTITY" ]]; then
  echo "NOTARY_PROFILE requires DEVELOPER_ID_APPLICATION." >&2
  exit 1
fi

APP_VERSION="$VERSION" CONFIGURATION=release UNIVERSAL="${UNIVERSAL:-1}" \
  "$ROOT_DIR/script/build_and_run.sh" --build-only

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle at $APP_BUNDLE" >&2
  exit 1
fi

if [[ -n "$SIGN_IDENTITY" ]]; then
  # Sign Sparkle's nested code first, as Sparkle documents; --deep would drop the Downloader entitlements.
  SPARKLE="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
  SIGN=(codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY")
  "${SIGN[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
  "${SIGN[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
  "${SIGN[@]}" "$SPARKLE/Versions/B/Autoupdate"
  "${SIGN[@]}" "$SPARKLE/Versions/B/Updater.app"
  "${SIGN[@]}" "$SPARKLE"
  "${SIGN[@]}" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi
codesign --verify --deep --strict "$APP_BUNDLE"

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

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
fi
if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
fi
rm -rf "$STAGING_DIR"
pkill -x "$PROCESS_NAME" >/dev/null 2>&1 || true

echo "$DMG_PATH"
