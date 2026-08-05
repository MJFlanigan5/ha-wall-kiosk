// Minimal service worker: caches the app shell for offline resilience,
// but the app is under active daily development right now, so this uses
// NETWORK-FIRST (not cache-first) for the app shell — every reload gets
// the latest code when online, falling back to cache only if the network
// genuinely fails. A prior cache-first version shipped earlier tonight
// with a static, never-bumped CACHE_NAME, which meant every push since
// the first one was silently invisible on reload — that's the bug this
// rewrite fixes. Revisit cache-first once the app stops changing this
// fast; for now, staleness is worse than the offline-resilience tradeoff.
const CACHE_NAME = "ha-wall-kiosk-pwa-v2";
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
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
