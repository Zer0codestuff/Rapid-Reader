# Rapid Reader for the web

A browser version of the native macOS reader. It keeps the amber focus point, quiet reading stage, library covers and floating controls. All UI and documentation are in English.

## Run

Use Node.js 24.

```sh
cd web
npm ci
npm run dev
```

Open `http://localhost:5173`. Vite forwards article imports to the local server on port 3001.

For the deployable build:

```sh
npm run build
npm start
```

Open `http://localhost:3001`. The server uses `PORT` when supplied by Railway. The build generates the offline service worker.

## Verify

```sh
npm test
npm run build
npx playwright install chromium webkit
npm run test:browser
RAPID_READER_QA_BROWSER=webkit npm run test:browser
```

The browser check starts a separate server on port 4174 and uses a fresh, temporary browser context. It imports generated fixtures, checks playback, search, notes, statistics, backups, deletion, responsiveness and offline reading. Chromium uses offline emulation. WebKit stops the isolated server to check cached reloads because Playwright's offline emulation blocks its service worker before navigation. Evidence goes to the ignored root `build/web-qa/` directory. It never accesses the native library. Set `RAPID_READER_QA_URL` to run the same check against an existing site; that skips WebKit's server-stop check.

## Reading

- RSVP playback from 100 to 900 WPM, with one to four words at a time and a pivot letter fixed on the focus line.
- Text mode with click-to-seek and a shared word index. Current browsers use [CSS Custom Highlights](https://developer.mozilla.org/en-US/docs/Web/API/CSS_Custom_Highlight_API); older browsers use a word-span fallback.
- Context, focus mode, punctuation pauses, optional warm-up, long-word pacing and rewind on resume. Preferences are kept per document; Settings defines defaults for new imports.
- Chapters, document search, favorites, editable notes with position jumps, reading progress, remaining-time estimates and daily statistics with a 14-day chart.
- System, Light, Dark and Sepia themes, keyboard shortcuts, a mobile library drawer and fullscreen where the browser allows it.
- Local EPUB, PDF, DOCX, RTF, HTML, Markdown and TXT imports, file drops, pasted text and article URLs. EPUBs keep covers and navigation; PDFs use outlines and heuristic margin cleanup. Scanned PDFs need OCR elsewhere. Password-protected PDFs and DRM-protected EPUBs need an unlocked copy.

The browser replaces Finder and macOS Services with file selection, drops and clipboard access. Browser updates replace Sparkle. An installable app manifest and service worker support reading offline after the first successful load. Clipboard and fullscreen depend on browser permissions and support.

## Your library

IndexedDB stores each document's content separately from its metadata. Content, progress, notes, reading settings, covers and statistics remain in this browser, on this origin. There are no accounts, cloud sync, analytics or document uploads. The web and native libraries are independent.

Settings can export and restore a JSON backup. Restore adds missing documents, keeps existing document progress and notes, restores reading defaults and theme, and avoids duplicating daily statistics. Unreadable metadata is copied into a backup store and kept intact. Use Export backup to preserve that data before attempting repairs.

Browser data can be cleared by the user or browser. Export a backup before changing browsers, domains, or devices. The Protect library button requests persistent storage; the browser decides whether to grant it. Private browsing may discard data at the end of the session.

Article import sends only the URL to the Express server, which retrieves public HTML and extracts prose using [Mozilla Readability](https://github.com/mozilla/readability). Pages requiring login, scripts or payment may need to be pasted manually. The endpoint checks public IP addresses at every redirect, pins DNS resolution, limits response size, concurrency and import rate, and never retains article text.

## Architecture and Railway

`src/core` owns models, token ranges, playback, search and IndexedDB. `src/import` owns browser document parsing, including [PDF.js](https://mozilla.github.io/pdf.js/) in a worker and JSZip for EPUB and DOCX. `src/components` contains the reader UI. `server` serves the built app, healthcheck and article importer.

Deploy the repository's `web/` directory with `railway.toml`, Node.js 24, `npm run build` and `npm start`. The healthcheck is `/api/health`. No database service, volume or application secrets are required. Rename the generated service domain to `rapid-reader` or an available `rapid-reader-*` label before sharing it. Keep the hostname stable because browser storage is scoped to it.

The source is covered by the repository's [MIT license](../LICENSE).
