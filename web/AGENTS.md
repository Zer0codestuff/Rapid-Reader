# Rapid Reader web

Browser counterpart to the macOS app. Keep the native app intact. React and TypeScript render the Quiet reader UI; Vite builds it. `src/core` owns playback, text ranges, search and IndexedDB. `src/import` parses files locally. The Express server serves the app and fetches public article URLs using Mozilla Readability.

## Work and verification

- Node.js 24. `npm ci`, then `npm run dev` opens the frontend on port 5173 with the article server on 3001.
- `npm test` runs core, imports, persistence and article-service tests. `npm run build` checks TypeScript and builds the offline app. `npm start` serves it on `PORT` or 3001.
- After `npx playwright install chromium webkit`, `npm run test:browser` runs isolated browser QA on port 4174. `RAPID_READER_QA_BROWSER=webkit` selects WebKit. `RAPID_READER_QA_URL` targets a running site. Screenshots go to ignored `../build/web-qa/`.
- Railway project **Rapid Reader**, environment **live**, service **rapid-reader**, domain `https://rapid-reader.up.railway.app`. Deploy from `main` after merging PR #1 and build only `/web` with Railpack, Node.js 24, `npm run build` and `npm start`. Set `PORT=3001`, route port 3001, use `/api/health` and watch `/web/**`. Configuration is applied through the Railway plugin; new services reject legacy `railway.toml`. Keep the domain stable.

## Status and constraints

- RSVP and text share cached UTF-16 token ranges. Playback uses absolute deadlines, per-document pacing, automatic pause when hidden or leaving a document, and throttled metadata reports.
- Text mode uses CSS Custom Highlights and a plain text node on current browsers; older browsers use cached word spans. Search runs off the UI thread. The library has local imports, covers, chapters, progress, favorites, notes and backup restore. Themes and default reading settings are app-wide. Statistics track completed displayed words and active playback time.
- Storage is local IndexedDB, with separate content and metadata stores and transactional import and deletion. Identical content preserves progress. Unreadable metadata is backed up and kept intact.
- Article import is the only content-related server operation. Keep DNS pinning, redirect checks, public-address restrictions, timeouts, response-size bounds and rate/concurrency limits. The server does not store articles.
- Browser permissions govern clipboard, fullscreen, persistent storage and installation. Scanned PDFs need OCR outside the app. Paywalls, logins, encrypted files and scripted articles may need manual text import.
- Validation on 2026-10-07: 23 tests, build, clean dependency install and audit pass. Complete Chromium and WebKit browser QA passes, including cached reload with the WebKit test server stopped. Native Safari, Firefox, physical mobile devices and assistive technologies were not tested.
- This is a separate web app, not a replacement for the macOS app. The libraries do not sync. Preserve amber, English copy and native visual identity. Record verification in root `docs/validation.md`.

## Do not

- Do not add accounts, cloud document storage, telemetry, sample libraries or unrelated features.
- Do not upload local documents or paste text to the server.
- Do not erase unreadable data, overwrite existing progress during restore, or test against the native library.
- Do not cache article API responses in the service worker.
- Do not change a published domain casually; existing browser libraries belong to the old origin.
- Do not use em dashes in agent-written content or claim browser engines, platforms or assistive technologies were tested without evidence.
