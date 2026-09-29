#!/usr/bin/env bash
set -euo pipefail

# Regenerates the icon assets from Icon/make_icon_layers.swift:
#   Icon/AppIcon.icon/Assets/*.png            Icon Composer layers (compiled by build_and_run.sh with actool)
#   Sources/RapidReader/Resources/AppIcon.icns    full-size icon for macOS 14 and 15
#   Sources/RapidReader/Resources/AppIconArtwork.png  in-app artwork
# Requires Xcode 26 or newer and macOS 26 or newer, which renders the Liquid Glass icon.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$ROOT_DIR"

swift Icon/make_icon_layers.swift
mkdir -p "$WORK/compiled"
xcrun actool "$ROOT_DIR/Icon/AppIcon.icon" --compile "$WORK/compiled" --platform macosx \
  --minimum-deployment-target 14.0 --app-icon AppIcon --include-all-app-icons \
  --output-partial-info-plist "$WORK/partial.plist" >/dev/null

# A minimal runnable bundle lets LaunchServices draw the compiled icon.
BUNDLE="$WORK/IconPreview.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp /usr/bin/true "$BUNDLE/Contents/MacOS/preview"
cp "$WORK/compiled/Assets.car" "$BUNDLE/Contents/Resources/"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>local.rapidreader.iconpreview.$$</string>
  <key>CFBundleExecutable</key><string>preview</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST

swiftc -O Icon/render_bundle_icon.swift -o "$WORK/render"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  "$WORK/render" "$BUNDLE" "$ICONSET/icon_${size}x${size}.png" "$size"
  "$WORK/render" "$BUNDLE" "$ICONSET/icon_${size}x${size}@2x.png" "$((size * 2))"
done
iconutil -c icns "$ICONSET" -o Sources/RapidReader/Resources/AppIcon.icns
cp "$ICONSET/icon_512x512@2x.png" Sources/RapidReader/Resources/AppIconArtwork.png
echo "Icon assets updated."
