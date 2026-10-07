# Rapid Reader

Native macOS 14+ SwiftUI reader. SwiftPM builds the `RapidReader` app and `RapidReaderCore` library. Core owns imports, document models, RSVP playback, and local persistence. UI and AppKit integration live in `Sources/RapidReader`.

The separate browser version lives entirely in `web/`. React, TypeScript and Vite render the same Quiet reader; IndexedDB keeps the web library local. An Express server serves the app and retrieves article URLs. See `web/AGENTS.md` and `web/README.md` for architecture and browser-specific constraints. The native app and its library remain independent.

## Work and verification

- `swift test` runs the core regression tests.
- Web: Node.js 24, `cd web && npm ci`, `npm run dev`. `npm test` verifies web core and imports; `npm run build` builds the offline app; `npm start` serves it. `npm run test:browser` uses an isolated browser and test server. It requires Playwright browsers; see `web/README.md`.
- `./script/build_and_run.sh --build-only` builds the app bundle; omit the flag to launch.
- `./script/package_dmg.sh <version>` packages a universal (arm64 + x86_64) release DMG with version and build number in the plist. Optional `DEVELOPER_ID_APPLICATION` and `NOTARY_PROFILE` sign with the hardened runtime and notarize.
- Use `RAPID_READER_LIBRARY_DIR` pointing to a temporary folder for runtime QA. Never test against the user's library. Launch with `open -n --env RAPID_READER_LIBRARY_DIR=... "dist/Rapid Reader.app"` so any instance started by `open` also uses it.
- Work on `improvements` for product points and on `redesign` for the visual redesign. The user authorized all fixes and product ideas from T3 thread `6bd0906d-c9c0-40ef-949f-0e1a24d5db09`, with a separate commit and push after each point. New ideas need approval. Do not merge or publish a release without instructions.

## Status

- Completed before this handoff: tolerant library decoding and backups, per-document content files, debounced metadata saves. Commits `b228b80` and `bff0b5f` are on the remote.
- RSVP now uses `ReaderSession`, cached section tokens, absolute clock deadlines, and throttled progress reports. Playback stops when leaving a book. The inherited incomplete file is preserved in ignored `build/checkpoints/`.
- Reader shows remaining section/book time based on word count and selected WPM, explicitly excluding optional pauses.
- Optional pacing, off by default and per document: warm-up from half speed over 0 to 10 s, longer display for words over 8 characters (up to +60%), and rewind of 0 to 20 words when resuming after a playback pause. Seeking clears the pending rewind.
- The app has a single library `Window` and stays running when it closes; Finder opens, Services, and Dock reopen show that window instead of creating a second reader session. AppDelegate owns one shared library. File menu commands, URL/file drops, Finder document opening, and a Read in Rapid Reader macOS Service route through the same importer. The Service may require enabling in macOS Keyboard Shortcuts after installation.
- All six original preferences have defaults for new documents. Font size is consistently 42...110. Controls wrap in an adaptive grid; minimum window size is 740x560.
- Notes support edit, delete, and jump with a visible Done button. URL import focuses its field and guards repeated submission. Recent reads show Now; playback controls have accessibility labels.
- Reimporting identical section text selects the existing book and keeps progress. Clipboard titles use the first line. Failed content/index writes report an import error.
- PDFs use outline chapter titles where present, remove recurring short margins and numeric page labels, and join lowercase words broken across lines. PDF outline tests use explicit PDF objects because PDFKit dropped the generated outline during fixture serialization. This cleanup is heuristic; scanned PDFs still need OCR outside the app.
- EPUB chapters follow EPUB 3 nav or EPUB 2 NCX entries, including fragment boundaries in shared spine files. Nonlinear spine items and marked Gutenberg boilerplate are skipped.
- HTML and article imports use SwiftSoup without AppKit HTML loading. Article selection prefers Wikipedia content, article/main elements, then prose density.
- Library deletion is available from the context menu and Delete key, with confirmation. Content is removed only after the index saves successfully.
- Reader arrow/space shortcuts are scoped to the active reader window and excluded from text fields, controls, and sheets. Native search-field cursor behavior was checked.
- RSVP and text mode share normalized UTF-16 token ranges; text mode caches its document and updates only the current highlight.
- Search in document (Cmd+F popover in the reader header) is case- and diacritic-insensitive, builds its index off the main thread, shows up to 500 matches with context, and jumps in the shared token space.
- Reader themes: System, Light, Dark, Sepia. One app-wide `readerTheme` setting (reading options popover and Settings) applies to the RSVP and text reader; the sidebar follows macOS. Amber stays the accent.
- Reading statistics: `ReaderSession` reports `(words, seconds)` per playback run; words count after their display time ends. `LibraryStore` keeps per-day totals in `statistics.json` (unreadable files move to Backups). The toolbar Statistics sheet shows today, last 7 days, average WPM including punctuation pauses, words read, and a 14-day chart. Bar colors validated with the dataviz script: #C2700F light, #CC7A18 dark.
- Packaging: `package_dmg.sh` builds a universal release DMG with version and build number in Info.plist; optional `DEVELOPER_ID_APPLICATION` and `NOTARY_PROFILE` sign (Sparkle parts first) and notarize. `ci.yml` tests and packages on main and PRs; `release.yml` runs on `v*` tags and creates a draft release. Neither workflow has run remotely from this branch.
- Updates use Sparkle 2 (SwiftPM, embedded in Contents/Frameworks). `AppUpdater` starts only when Info.plist has `SUPublicEDKey` and `SUFeedURL`, written only when `SPARKLE_PUBLIC_KEY` is set. `make_appcast.sh` signs the appcast; `release.yml` uses `vars.SPARKLE_PUBLIC_KEY` and `secrets.SPARKLE_PRIVATE_KEY` when present. The owner must create the keys (see README).
- Validation: 41 tests pass, including playback timing and session lifetime. On this Mac, 20 lookups of 28,000 words fell from 416 ms with repeated tokenization to 0.013 ms with cached tokens. This is a core benchmark, not whole-app CPU.
- All authorized points from the source thread are implemented, except Italian localization, which the owner cancelled on 2026-09-29 (see Constraints). New ideas need approval.
- Redesign (branch `redesign`): a "Quiet reader" UI. The RSVP stage has a theme background, amber glow, pivot letter on the focus line, and a floating glass control capsule that hides 2.2 s after playback starts and returns on mouse move; Up/Down change speed with a HUD. `Support/Glass.swift` gates `glassEffect` and `.glass` button styles on macOS 26 and falls back to `.regularMaterial`. Library, notes, statistics, article import, document search, and settings share the same rounded fields, amber focus rings, and glass buttons. The app icon is the "focus point" mark built from `Icon/AppIcon.icon` with `Icon/build_icon.sh` (actool compiles `Assets.car`; `AppIcon.icns` is the fallback). Nothing was changed in storage, preferences keys, or import formats.
- Licensing and discoverability (2026-10-04, on `main` at the owner's request): the repository is MIT licensed (`LICENSE`, copyright Gabriele Monni). README opens with "free, open-source", has a `How It Compares` table against Outread and Spreeder built only from their websites, and a `License` section. The GitHub description uses the same wording so search engines and AI agents match queries such as "free open source speed reader for Mac". Recheck the competitor facts before editing that table.
- README hero is `docs/screenshots/rapid-reader-demo.gif` (2026-10-07): a real recording of the release build with an isolated `RAPID_READER_LIBRARY_DIR` and three Project Gutenberg EPUBs, RSVP at 350 WPM followed by the text view. Recorded with `screencapture -v`, static areas stabilized, then `ffmpeg` palette and `gifsicle -O3` (900 px wide, about 1.8 MB). Keep `rapid-reader-rsvp.png`; external list entries link to it.
- Developer ID signing, notarization, and signed update publication require the owner's credentials. Implement and verify the local workflow first, then report any missing setup.
- Web version (2026-10-07, branch `web-reader`): browser RSVP and text reading, all seven file formats, URL and clipboard import, covers, chapters, favorites, notes, document search, per-document preferences, themes, reading statistics, local backup/restore, responsive library drawer and offline reading. The owner approved local browser data without accounts and a new Railway Rapid Reader project with a domain that excludes `production`. Deploy only the `web/` directory. The web app supplements the native app; it does not replace it.

## Constraints

Keep the existing amber identity, covers, import formats, text-mode word selection, and local storage. The project and the app must be entirely in English: code, docs, UI copy, and generated titles. Do not add localizations; the owner withdrew the earlier Italian localization approval. Keep preferences backward compatible and record validation results in `docs/validation.md`.

## Do not

- Do not overwrite unreadable library data or test with the real library.
- Do not remove existing working formats or replace native UI with a web app.
- Do not introduce cloud storage, telemetry, decorative UI, or unapproved product features.
- Do not use em dashes in agent-written content.
- Do not claim Intel, VoiceOver, notarization, or update installation was tested unless it was actually checked.
- Do not state prices or features of other apps in the README without checking their own websites first.
