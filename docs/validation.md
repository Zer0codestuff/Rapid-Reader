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
