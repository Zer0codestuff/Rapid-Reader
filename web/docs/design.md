# Web design

The native Quiet reader is the visual reference. The web app opens directly into the reader with a library sidebar, a compact toolbar, and a large reading stage. No marketing page or sample library.

- Palette: charcoal #1c1c1e, sidebar #262628, glass #343436, ink #eeeeef, muted #99999e, amber #f4a02d. Light uses #fcfcfa and sepia uses #f5ebd6, following the native themes.
- Type: the system UI face preserves the macOS identity. RSVP uses its rounded fallback when available. Full text uses Georgia for a readable book page.
- Alignment: the pivot letter stays centered between amber focus marks. Context is centered below it. The library and full text are left aligned.
- Controls: one floating glass capsule with play, stepping, speed, section progress and options. It hides after 2.2 seconds of playback and returns on pointer movement, touch or keyboard focus.
- Small screens: the sidebar becomes a drawer. Controls wrap without clipping. The reading stage remains the main use of the screen.

```
+-------------------+-------------------------------------------+
| Library       +   | Title                RSVP Text   tools    |
| Search            +-------------------------------------------+
| Continue reading  |                     |                     |
| cover  title      |                  wo r d                   |
| cover  title      |                     |                     |
| Library           |              surrounding words            |
| cover  title      |                                           |
|                   |        [ back  play  next  speed ... ]    |
| Settings          |              remaining time               |
+-------------------+-------------------------------------------+
```

The app's amber focus point is the only visual effect. Glass and a restrained amber glow reproduce the native implementation. The sidebar selection uses amber rather than introducing a second accent. Motion answers playback and controls; reduced motion disables transitions.
