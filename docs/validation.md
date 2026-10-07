# Validation

## RSVP playback

- `swift test`: 20 tests passed on Apple Silicon, September 29, 2026.
- Playback test at 900 WPM without punctuation pauses checks measured advancement over one second and verifies no advancement after pause.
- Twenty lookups of a 28,000-word section: repeated tokenization 416 ms, cached lookups 0.013 ms. Debug core benchmark on this Mac; not a whole-app CPU measurement.
- Completion restart, chunk punctuation timing, final short chunks, and abandoned-session deallocation covered.

## Shared word positions

- `swift test`: 21 tests passed. Unicode, nonbreaking spaces, zero-width spaces, punctuation-only separators, and quoted punctuation covered.
- Full-text rendering now uses exactly the RSVP token ranges and keeps its attributed document between word selections.

## Keyboard focus

- `swift build` passed. In the native app with an isolated library, typing `Reader`, pressing Left twice, and typing `X` produced `ReadXer`; the reader remained at word 0.
- Playback buttons now expose Play/Pause, Back, Forward, and Favorite labels in the accessibility tree.

## Library deletion

- `swift test`: 21 tests passed, including content removal and selection persistence. `swift build` passed for the context menu, Delete command, and confirmation dialog.
- Deletion now writes the index before deleting document files.

## HTML and articles

- Existing 21 tests and three new extraction tests pass after correcting a test expectation to retain paragraph breaks.
- Covered nested article markup, Wikipedia navigation, entities, inline emphasis, and paragraph boundaries. No JavaScript or external HTML resources are loaded.

## EPUB chapters

- Four import regressions and two navigation fixtures pass. Checked EPUB 3 nav and EPUB 2 NCX chapter anchors, nonlinear spine entries, and existing cover extraction.

## PDF import

- The initial PDFKit-generated fixture lost its outline when saved. A corrected PDF fixture with explicit outline objects passes both tests. Checked: repeated margins/dehyphenation and a generated two-page PDF with a real outline. Outline boundaries are at page granularity; pages containing multiple outline destinations remain one section.

## Imports and titles

- Duplicate selection and punctuation-only clipboard rejection tests pass. Existing storage tests pass after separating the fixture title from its body. Identical text retains progress; changed text can be imported separately.

## Notes and small UI fixes

- Notes persistence test passed for editing, position retention, reload, and deletion. App build passed with URL focus, a submission guard, and a visible Done action. Native runtime checks continue after the layout/defaults changes.

## Defaults and layout

- `swift build` passed. Native screenshot checked with the adaptive controls; no overflow at the observed 1060-point window. The window minimum is reduced to 740x560; see "Minimum window size" below for the follow-up check.
- Native URL sheet accepted typing without a field click. Notes exposes Done and an accessible New note editor.

## macOS import integration

- `swift build` and shell syntax checks pass. Finder document types and the text/URL Service are declared in the app bundle. End-to-end Finder and Services registration checks remain part of final bundle QA.

## Remaining time

- Six reader session tests passed. Estimates update after seeking and changing WPM without re-tokenizing the book.

## Optional pacing and rewind

- `swift test`: 34 tests passed. Covered warm-up, long-word scaling, defaults off for older library data, rewind after a playback pause, and no rewind after seeking.
- Native app with an isolated library: the Reading options popover opens from the reader and shows the three controls.

## Single library window

- Found in native QA: opening a document from Finder while the app ran created a second window with a second reader session on the same library. The app now uses one `Window` scene.
- Checked with an isolated library: Finder open keeps one window; closing the window keeps the process running; Dock reopen and Finder open both show the window again in the same process.

## Search in document

- `swift test`: 38 tests passed. Covered word index mapping across sections, case and diacritic folding, phrases across words, result limits, and context trimming.
- Native app with an isolated library: Cmd+F opens the popover with the field focused (focus needed a short delay because the popover is not key on appear). "vocabulary appears" returned 200 matches in a 2,800-word document; clicking the fourth result closed the popover and RSVP showed "vocabulary".

## Reader themes

- `swift build` passed. Native screenshots with an isolated library checked System, Light, Dark, and Sepia in RSVP mode, and Sepia and Dark in text mode (text color and current-word highlight). The setting was restored to System after QA.
- The progress slider drew one tick per word, which formed a dense striped bar that stood out on light backgrounds. It now uses a continuous track; the value is still rounded to a word index.

## Reading statistics

- `swift test`: 41 tests passed. Covered per-day grouping across local midnight, ignored empty or sub-second segments, summaries, persistence, keeping an unreadable file aside, and session word counting.
- Native app with an isolated library: 4 s of playback at 350 WPM recorded 21 words (about 304 WPM measured, consistent with punctuation pauses). The sheet was checked with seeded history: tiles, 14-day chart, hover tooltip kept inside the plot, day labels aligned under their bars.
- Chart colors: the brand amber #F29E38 failed contrast on light (2.1:1) and the lightness band on dark in `validate_palette.js`; #C2700F (light) and #CC7A18 (dark) pass both.
- Quitting during playback now pauses the session and flushes progress before exit, so the last run and position are saved.

## Release packaging

- `./script/package_dmg.sh 1.1.0-test` built a release DMG; `lipo -archs` reports `x86_64 arm64`, and `Info.plist` has `CFBundleShortVersionString` 1.1.0-test and `CFBundleVersion` 21. The universal release build took 77 s on this Mac.
- Fixed resource packaging: SwiftPM resources had been copied to `Contents/Resources/Contents/Resources`, so the empty-library artwork was missing. The release build now shows it (checked with an isolated empty library).
- Only the arm64 slice was run. The x86_64 slice was built but not launched on an Intel Mac or under Rosetta.
- Workflow YAML parses. The workflows have not run on GitHub from this branch; tags and releases were not created. Developer ID signing and notarization paths are implemented but untested because no credentials were used.

## Updates

- Built with a throwaway EdDSA key kept in a file under /tmp (the keychain was not used). Old build 1.0.1 (build 100) was copied to a temporary folder; the new DMG 1.0.2 (build 101) and a signed appcast were served from 127.0.0.1.
- Checked in the native app: Check for Updates offered 1.0.2, Install Update downloaded the DMG, and Install and Relaunch replaced the app in place. The relaunched process reported 1.0.2 (build 101). `launchctl setenv` kept the relaunch on the isolated library; the variable, Sparkle defaults, and Sparkle cache were removed afterwards.
- Without `SPARKLE_PUBLIC_KEY`, Info.plist has no update keys and neither the menu item nor the Settings section appears. With a key, Settings shows automatic checks and Check Now.
- Not tested: updates between Developer ID signed builds, the notarized path, the GitHub-hosted feed, and the release workflow's appcast step.

## English only

- An Italian localization was built and checked, then removed at the owner's request: the project and the app stay entirely in English. The revert restores the previous English-only strings and build script; no `.lproj` or String Catalog ships.

## Minimum window size

- Resizing to 600x400 through System Events stops at 740x612. At that size the header gave the title about 50 points (the position text wrapped one character per line) and the controls panel was cut off at the bottom.
- The header now switches to a compact variant (no cover, Notes as an icon with an accessibility label) and the RSVP area can shrink to 96 points. Screenshots at 740x612 and 1100x760 checked: title and position on one line, controls fully visible, regular header unchanged at normal size.

## Redesign

- Built on macOS 27 (Xcode 27) with the isolated library `/tmp/rr-qa2`; 41 tests pass. Screens checked natively through screenshots: library sidebar, RSVP stage, text mode, reading options popover, notes sheet (empty and with notes), statistics sheet, article import sheet, document search popover, and both Settings tabs. README screenshots were retaken from this build (dark appearance).
- At 740x612 (the minimum window size) the header, stage, and control capsule all fit.
- Liquid Glass is only exercised here on macOS 27. The macOS 14 to 25 material fallback compiles behind `#available` but was not run on those systems. The light theme was checked on the notes sheet and text reader only; Sepia, Intel, and VoiceOver were not rechecked in this pass.
- The new icon was rendered through LaunchServices to check the Icon Composer output and the `.icns` fallback; the icon in the Dock and Finder was viewed on this Mac only.
- A thin outline pill sometimes appeared at the bottom edge of screenshots taken while a popover was open; it did not reproduce otherwise and was not investigated further.

## Web version, 2026-10-07

- Implemented on `web-reader`, entirely under `web/`. Native source, imports, storage and preferences were not changed. Native tests were not rerun for this independent web implementation.
- `npm test`: 23 tests pass across playback timing and lifetime, UTF-16 token ranges, diacritic search, EPUB fragments, HTML and RTF extraction, import deduplication, transactional backups and deletion, unreadable-data preservation, statistics and article-service address validation.
- `npm run build`: TypeScript and the deployable Vite build pass. A clean `npm ci --ignore-scripts` build passed. `npm audit`: zero vulnerabilities in production and development dependencies.
- Full browser QA passes in Playwright Chromium and WebKit 26.6 on this Mac. Fresh browser contexts imported EPUB, PDF, DOCX, RTF, HTML, Markdown and TXT fixtures, then checked search and jump, note creation and editing, favorites, playback, control hiding, text click-to-seek, statistics, backup download, deletion cancellation, actual deletion and restore. No uncaught browser errors.
- Layouts checked at 1280x800, 740x560 and 390x844, with Light, Dark and Sepia themes and the mobile drawer. The content stays inside the viewport. The system theme was used during initial shared-browser inspection. Assistive technologies, Firefox and physical mobile devices were not tested.
- Offline QA: Chromium reloaded with networking disabled, reopened the saved library and imported a local file. WebKit did the same after its isolated app server stopped. Playwright's WebKit offline emulation fails navigation before the service worker runs, so the test uses a real connection failure and verifies that a new cached document loaded. The native Safari app was not tested.
- The shared browser also imported the full Project Gutenberg Pride and Prejudice EPUB: cover and author preserved, 69 sections and 127,082 words. Alice's Adventures in Wonderland and Frankenstein were imported for visual evidence. They are QA data only, never bundled into the website. Wikipedia article import succeeded through the local service. A three-page outlined PDF preserved chapter titles, removed repeated margins and page labels, and rejoined lowercase hyphenated words.
- A 28,000-word synthetic chapter renders as one text node with CSS Custom Highlights. Browser QA measured 6.2 ms in Chromium and 5 ms in WebKit to mount the text view, with no word elements. The initial span-based implementation measured 103.5 ms and created 28,000 elements in the shared browser. These are individual DOM-render measurements in different browser contexts, not a controlled whole-app CPU or memory benchmark.
- Local screenshots are in ignored `build/web-qa/`, including `rapid-reader-web-desktop.png`, `rapid-reader-web-text.png`, `rapid-reader-web-mobile.png` and browser QA evidence. The native library was not accessed.
