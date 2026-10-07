import { readdir, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
const assets = (await readdir(new URL("../dist/assets/", import.meta.url))).map(
  (f) => `/assets/${f}`,
);
const hash = createHash("sha256")
  .update(assets.join("\n"))
  .digest("hex")
  .slice(0, 12);
const files = [
  "/",
  "/index.html",
  "/icon.png",
  "/manifest.webmanifest",
  ...assets,
];
const source = `const CACHE = 'rapid-reader-${hash}';
const FILES = ${JSON.stringify(files)};
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES))));
self.addEventListener('activate', event => event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k.startsWith('rapid-reader-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('message', event => { if (event.data === 'ACTIVATE_UPDATE') self.skipWaiting(); });
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin || url.pathname.startsWith('/api/')) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).then(response => { if (response.ok) { const copy = response.clone(); caches.open(CACHE).then(cache => cache.put('/index.html', copy)); } return response; }).catch(() => caches.match('/index.html')));
  } else event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request)));
});
`;
await writeFile(new URL("../dist/sw.js", import.meta.url), source);
