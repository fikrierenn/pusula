// BKM Panel PWA service worker — minimal (install prompt + standalone için).
// Blazor Server SignalR (/_blazor) bozulmasın diye fetch'e KARIŞMAZ — network passthrough.
self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => { /* network passthrough — cache yok */ });
