// Cache only the application shell. API responses and visual evidence stay outside Cache Storage.
const CACHE = 'wms-shell-v4';
const SHELL = ['/', '/style.css', '/app.js', '/api.js', '/media-queue.js', '/pwa.js', '/config.js', '/icon.svg', '/icon-180.png', '/icon-192.png', '/icon-512.png', '/manifest.webmanifest'];
self.addEventListener('install', event => event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL))));
// A new version activates on the next full app close/reopen; never reload an active operation.
self.addEventListener('activate', event => event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('wms-shell-') && key !== CACHE).map(key => caches.delete(key))))));
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).catch(() => caches.match('/'))); return;
  }
  if (!SHELL.includes(url.pathname)) return;
  event.respondWith(fetch(event.request).catch(() => caches.match(url.pathname)));
});
