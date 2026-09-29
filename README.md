# Rapid Reader

Rapid Reader is a native macOS app for focused long-form reading. It combines rapid serial visual presentation (RSVP) with a normal full-text reader, so you can move quickly through books and articles while still being able to inspect the original text and resume from any word.

![Rapid Reader RSVP mode](docs/screenshots/rapid-reader-rsvp.png)

## Highlights

- Import EPUB, PDF, DOCX, RTF, HTML, Markdown, plain text, pasted text, and web articles.
- Keep a local library with reading progress, favorite documents, notes, preferences, sections, and EPUB cover art.
- Read in RSVP mode with pivot-letter highlighting, context preview, punctuation pauses, and adjustable chunk size.
- Switch to full-text mode whenever you want to browse normally, then click a word to resume from that exact position.
- Tune speed, font size, focus mode, section navigation, and playback controls from one compact reading surface.
- Recover gracefully from image-only EPUB cover pages and older library data.
- Search inside a document, choose a light, dark, or sepia reader, and review reading time and speed in Statistics.
- Store everything locally in `~/Library/Application Support/Rapid Reader`.

![Rapid Reader full-text mode](docs/screenshots/rapid-reader-text.png)

## Download

The latest DMG is attached to the GitHub release for this repository.

1. Download `RapidReader-<version>.dmg` from [Releases](https://github.com/Zer0codestuff/Rapid-Reader/releases).
2. Open the DMG.
3. Drag `Rapid Reader.app` into `Applications`.
4. Launch Rapid Reader.

The DMG contains a universal app for Apple Silicon and Intel Macs. Unless a release says it is notarized, the app is ad-hoc signed: if macOS blocks the first launch, open **System Settings -> Privacy & Security** and allow the app after your first launch attempt.

## Build From Source

Requirements:

- macOS 14 or newer
- Xcode command line tools
- Swift 6 compatible toolchain

Run the app:

```bash
./script/build_and_run.sh
```

Build the app bundle without launching:

```bash
./script/build_and_run.sh --build-only
```

Run tests:

```bash
swift test
```

Create a universal release DMG (release configuration, arm64 and x86_64, version and build number in `Info.plist`):

```bash
./script/package_dmg.sh 1.1.0
```

The packaged app is written to `dist/Rapid Reader.app`, and the DMG is written to `build/package/`. `build_and_run.sh` accepts the same settings through `CONFIGURATION=release`, `UNIVERSAL=1`, `APP_VERSION`, and `BUILD_NUMBER`.

Optional signing and notarization, with credentials on the build Mac:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Name (TEAMID)" \
NOTARY_PROFILE=rapid-reader-notary \
./script/package_dmg.sh 1.1.0
```

`NOTARY_PROFILE` is a keychain profile created with `xcrun notarytool store-credentials`.

## Updates

Rapid Reader uses [Sparkle](https://sparkle-project.org) for updates. The updater and the **Check for Updates…** menu item are enabled only in builds made with `SPARKLE_PUBLIC_KEY`. The app reads `appcast.xml` from the latest GitHub release.

One-time setup by the owner:

1. Run `.build/artifacts/sparkle/Sparkle/bin/generate_keys` after `swift package resolve`. It stores the private key in the login keychain and prints the public key.
2. Export the private key with `generate_keys -x sparkle-private.key`, keep a backup offline, and add its contents as the `SPARKLE_PRIVATE_KEY` repository secret. Add the public key as the `SPARKLE_PUBLIC_KEY` repository variable.

Local release with updates:

```bash
SPARKLE_PUBLIC_KEY=<public key> ./script/package_dmg.sh 1.1.0
./script/make_appcast.sh 1.1.0   # uses the keychain key, or SPARKLE_PRIVATE_KEY_FILE
```

Upload the DMG and `build/appcast/appcast.xml` to the `v1.1.0` release. The tag workflow does this automatically when the secret and variable exist. Optional release notes go in `docs/release-notes/<version>.html`. Losing the private key means existing installs can no longer verify updates.

## Releases

Pushing a tag such as `v1.1.0` runs `.github/workflows/release.yml`, which tests, packages the DMG, and attaches it to a draft GitHub release for review. The workflow can also be started manually to build a DMG artifact without creating a release. CI signs ad-hoc; Developer ID signing and notarization currently run locally.

## Keyboard And Reader Controls

- `Space`: play or pause RSVP playback.
- `Left Arrow` / `Right Arrow`: move backward or forward.
- `Command-O`: import files.
- `Command-F`: search in the current document.
- Section picker: jump to a specific chapter or section.
- Text mode: click a word to set the resume position.

## Development Notes

Rapid Reader is implemented with SwiftUI and SwiftPM. The core import, parsing, text-processing, and persistence logic lives in `RapidReaderCore`, while the macOS UI target owns the reading surface, sidebar, app resources, and packaging entrypoints.

The project includes regression tests for:

- EPUB cover extraction.
- Image-only EPUB cover-page filtering.
- Library repair for older imported documents.
- Markdown section splitting.
- Reading progress and preference persistence.
- RSVP pivot-letter calculation.
