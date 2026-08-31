// Service worker for Lan-Don's Japanese Conjugation Drill.
// Strategy:
//  - Precore app shell (HTML, CSS, JS, data, vendored libs, icons) on install.
//  - Navigations: network-first, fall back to the cached drill page when offline.
//  - Same-origin static assets: stale-while-revalidate.
//  - Google Fonts: cache-first at runtime (optional nicety; the app falls back
//    to system Japanese fonts when they are unavailable).

const CACHE_VERSION = 'conjugation-drill-v1';

const PRECACHE_URLS = [
  './drill.html',
  './drill.css',
  './drill.js',
  './rules.js',
  './words.json',
  './count.json',
  './grp_sample.json',
  './manifest.json',
  './vendor/bootstrap.min.css',
  './vendor/jquery-3.7.1.min.js',
  './img/icons/icon-192.png',
  './img/icons/icon-512.png',
  './img/icons/icon-maskable-192.png',
  './img/icons/icon-maskable-512.png',
  './img/apple-touch-icon.png',
];

const FONT_CDN_HOSTS = ['fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION)
      .then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((key) => key !== CACHE_VERSION).map((key) => caches.delete(key))
      ))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  if (request.method !== 'GET') return;

  // Page navigations: prefer a fresh page, fall back to the cached copy.
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put('./drill.html', copy));
          return response;
        })
        .catch(() => caches.match('./drill.html'))
    );
    return;
  }

  const isFontCdn = url.protocol === 'https:' && FONT_CDN_HOSTS.includes(url.hostname);
  const isSameOrigin = url.origin === self.location.origin;

  if (isFontCdn) {
    // Cache-first: once the fonts are stored they never need the network again.
    event.respondWith(
      caches.match(request).then((cached) => cached || fetch(request).then((response) => {
        const copy = response.clone();
        caches.open(CACHE_VERSION).then((cache) => cache.put(request, copy));
        return response;
      }))
    );
    return;
  }

  if (isSameOrigin) {
    // Stale-while-revalidate: serve instantly, refresh the copy in the background.
    event.respondWith(
      caches.match(request).then((cached) => {
        const refresh = fetch(request).then((response) => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(CACHE_VERSION).then((cache) => cache.put(request, copy));
          }
          return response;
        }).catch(() => cached);
        return cached || refresh;
      })
    );
  }
});
