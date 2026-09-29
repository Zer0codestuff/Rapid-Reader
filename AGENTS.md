# Rapid Reader

Native macOS 14+ SwiftUI reader. SwiftPM builds the `RapidReader` app and `RapidReaderCore` library. Core owns imports, document models, RSVP playback, and local persistence. UI and AppKit integration live in `Sources/RapidReader`.

## Work and verification

- `swift test` runs the core regression tests.
- `./script/build_and_run.sh --build-only` builds the app bundle; omit the flag to launch.
- `./script/package_dmg.sh <version>` packages a DMG.
- Use `RAPID_READER_LIBRARY_DIR` pointing to a temporary folder for runtime QA. Never test against the user's library. Launch with `open -n --env RAPID_READER_LIBRARY_DIR=... "dist/Rapid Reader.app"` so any instance started by `open` also uses it.
- Work on `improvements`. The user authorized all fixes and product ideas from T3 thread `6bd0906d-c9c0-40ef-949f-0e1a24d5db09`, with a separate commit and push after each point. New ideas need approval. Do not merge or publish a release without instructions.

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
- Validation: 38 tests pass, including playback timing and session lifetime. On this Mac, 20 lookups of 28,000 words fell from 416 ms with repeated tokenization to 0.013 ms with cached tokens. This is a core benchmark, not whole-app CPU.
- Remaining authorized work: Italian localization; release/universal packaging and CI; update support; reading statistics and themes.
- Developer ID signing, notarization, and signed update publication require the owner's credentials. Implement and verify the local workflow first, then report any missing setup.

## Constraints

Keep the existing amber identity, covers, import formats, text-mode word selection, and local storage. Default artifacts and UI copy are English. Italian localization was explicitly approved in the source thread. Keep preferences backward compatible and record validation results in `docs/validation.md`.

## Do not

- Do not overwrite unreadable library data or test with the real library.
- Do not remove existing working formats or replace native UI with a web app.
- Do not introduce cloud storage, telemetry, decorative UI, or unapproved product features.
- Do not use em dashes in agent-written content.
- Do not claim Intel, VoiceOver, notarization, or update installation was tested unless it was actually checked.
