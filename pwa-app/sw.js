// Minimal service worker: caches the app shell so it launches instantly
// and works offline for the UI itself (live HA data still needs a real
// connection — this doesn't cache or fake entity state).
const CACHE_NAME = "ha-wall-kiosk-pwa-v1";
const APP_SHELL = [
  "./index.html",
  "./config.js",
  "./ha-client.js",
  "./rooms.config.js",
  "./manifest.json",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  // App shell: cache-first. Everything else (including any future push to
  // the HA REST API): network, not intercepted.
  const url = new URL(event.request.url);
  if (url.origin === self.location.origin) {
    event.respondWith(
      caches.match(event.request).then((cached) => cached || fetch(event.request))
    );
  }
});
