# Validation

## RSVP playback

- `swift test`: 20 tests passed on Apple Silicon, September 29, 2026.
- Playback test at 900 WPM without punctuation pauses checks measured advancement over one second and verifies no advancement after pause.
- Twenty lookups of a 28,000-word section: repeated tokenization 416 ms, cached lookups 0.013 ms. Debug core benchmark on this Mac; not a whole-app CPU measurement.
- Completion restart, chunk punctuation timing, final short chunks, and abandoned-session deallocation covered.
