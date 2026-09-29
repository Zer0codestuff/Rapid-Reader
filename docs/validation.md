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

- `swift build` passed. Native screenshot checked with the adaptive controls; no overflow at the observed 1060-point window. The window minimum is reduced to 740x560; resizing through the automation tool did not change the window, so minimum-size QA remains pending.
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
