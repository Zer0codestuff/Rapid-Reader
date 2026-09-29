#!/usr/bin/env bash
set -euo pipefail

# Builds build/appcast/appcast.xml for one packaged DMG, signed with the Sparkle EdDSA key.
# Upload the result next to the DMG in the GitHub release: the app reads
# https://github.com/Zer0codestuff/Rapid-Reader/releases/latest/download/appcast.xml.
#
#   SPARKLE_PRIVATE_KEY_FILE     private key file; without it, generate_appcast reads the login keychain.
#   SPARKLE_DOWNLOAD_URL_PREFIX  defaults to the GitHub release download URL for this version.
#
# The DMG must be built with the matching SPARKLE_PUBLIC_KEY; generate_appcast checks this.

VERSION="${1:?usage: $0 <version> [dmg]}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG="${2:-$ROOT_DIR/build/package/RapidReader-$VERSION.dmg}"
PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/Zer0codestuff/Rapid-Reader/releases/download/v$VERSION/}"
WORK_DIR="$ROOT_DIR/build/appcast"
TOOLS="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"

if [[ ! -f "$DMG" ]]; then
  echo "Missing $DMG. Run script/package_dmg.sh $VERSION first." >&2
  exit 1
fi
if [[ ! -x "$TOOLS/generate_appcast" ]]; then
  (cd "$ROOT_DIR" && swift package resolve)
fi

KEY_ARGS=()
if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  KEY_ARGS=(--ed-key-file "$SPARKLE_PRIVATE_KEY_FILE")
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp "$DMG" "$WORK_DIR/"
NOTES="$ROOT_DIR/docs/release-notes/$VERSION.html"
if [[ -f "$NOTES" ]]; then
  cp "$NOTES" "$WORK_DIR/$(basename "${DMG%.dmg}").html"
  KEY_ARGS+=(--embed-release-notes)
fi

"$TOOLS/generate_appcast" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} --download-url-prefix "$PREFIX" "$WORK_DIR"
echo "$WORK_DIR/appcast.xml"
