// Replace retired Flutter shell workers without touching account or model data.
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => event.waitUntil((async () => {
  for (const name of await caches.keys()) {
    if (!name.startsWith('flutter-')) continue;
    const cache = await caches.open(name);
    for (const request of await cache.keys()) {
      const url = new URL(request.url);
      if (url.origin === self.location.origin && /^\/scene\/(?:index\.html|flutter_bootstrap\.js|main\.dart\.js|flutter_service_worker\.js)$/.test(url.pathname)) await cache.delete(request);
    }
  }
  await self.clients.claim();
  await self.registration.unregister();
})()));
