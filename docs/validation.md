# Validation

## RSVP playback

- `swift test`: 20 tests passed on Apple Silicon, September 29, 2026.
- Playback test at 900 WPM without punctuation pauses checks measured advancement over one second and verifies no advancement after pause.
- Twenty lookups of a 28,000-word section: repeated tokenization 416 ms, cached lookups 0.013 ms. Debug core benchmark on this Mac; not a whole-app CPU measurement.
- Completion restart, chunk punctuation timing, final short chunks, and abandoned-session deallocation covered.

## Shared word positions

- `swift test`: 21 tests passed. Unicode, nonbreaking spaces, zero-width spaces, punctuation-only separators, and quoted punctuation covered.
- Full-text rendering now uses exactly the RSVP token ranges and keeps its attributed document between word selections.
