// Duck Tracker service worker — bump CACHE when you change any file
const CACHE = "duck-tracker-v5";
const FILES = ["./", "./index.html", "./manifest.json", "./icon.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

// App files, fonts, Leaflet and map tiles: cache-first, refresh in background.
// Weather and Supabase requests: always network (never cached).
self.addEventListener("fetch", e => {
  if (e.request.method !== "GET") return;
  const url = new URL(e.request.url);
  if (url.hostname.includes("open-meteo.com") || url.hostname.includes("supabase")) return;
  const cacheable = url.origin === location.origin || /gstatic\.com|googleapis\.com|cdnjs\.cloudflare\.com|tile\.openstreetmap\.org$/.test(url.hostname);
  e.respondWith(
    caches.match(e.request).then(cached => {
      const fetched = fetch(e.request).then(res => {
        if (res && res.ok && cacheable) caches.open(CACHE).then(c => c.put(e.request, res.clone()));
        return res;
      }).catch(() => cached);
      return cached || fetched;
    })
  );
});
