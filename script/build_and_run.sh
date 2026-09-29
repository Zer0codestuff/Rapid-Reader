#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="RapidReader"
DISPLAY_NAME="Rapid Reader"
BUNDLE_ID="com.gabrielemonni.RapidReader"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

RESOURCE_DIR=""
if [[ -d "$BUILD_DIR/RapidReader_RapidReader.bundle" ]]; then
  RESOURCE_DIR="$BUILD_DIR/RapidReader_RapidReader.bundle"
elif [[ -d "$BUILD_DIR/RapidReader_RapidReader.resources" ]]; then
  RESOURCE_DIR="$BUILD_DIR/RapidReader_RapidReader.resources"
fi

if [[ -n "$RESOURCE_DIR" ]] && compgen -G "$RESOURCE_DIR/*" >/dev/null; then
  cp -R "$RESOURCE_DIR/"* "$APP_RESOURCES/"
fi

if [[ -f "$ROOT_DIR/Sources/RapidReader/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Sources/RapidReader/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>Reading document</string>
      <key>CFBundleTypeRole</key><string>Viewer</string>
      <key>LSHandlerRank</key><string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.adobe.pdf</string><string>org.idpf.epub-container</string>
        <string>org.openxmlformats.wordprocessingml.document</string>
        <string>public.rtf</string><string>public.html</string><string>public.plain-text</string>
        <string>net.daringfireball.markdown</string>
      </array>
      <key>CFBundleTypeExtensions</key>
      <array><string>pdf</string><string>epub</string><string>docx</string><string>rtf</string><string>html</string><string>htm</string><string>xhtml</string><string>txt</string><string>text</string><string>md</string><string>markdown</string></array>
    </dict>
  </array>
  <key>NSServices</key>
  <array><dict>
    <key>NSMenuItem</key><dict><key>default</key><string>Read in Rapid Reader</string></dict>
    <key>NSMessage</key><string>readInRapidReader</string>
    <key>NSPortName</key><string>Rapid Reader</string>
    <key>NSSendTypes</key><array><string>public.utf8-plain-text</string><string>public.url</string></array>
  </dict></array>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --build-only|build-only)
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--build-only|--verify]" >&2
    exit 2
    ;;
esac
