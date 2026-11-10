{{flutter_js}}
{{flutter_build_config}}

// Keep the deployed application current while retaining verified model parts.
// Remove only this app's previous Flutter service worker registration.
(async () => {
  try { if ('serviceWorker' in navigator) {
    const scope = new URL('./', document.baseURI).href;
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const registration of registrations) {
      if (registration.scope === scope) await registration.unregister();
    }
  } } catch (_) { /* Storage restrictions must not block startup. */ }
  try {
    if ('caches' in window) {
      for (const name of await caches.keys()) {
        if (!name.startsWith('flutter-')) continue;
        const cache = await caches.open(name);
        for (const request of await cache.keys()) {
          const url = new URL(request.url);
          if (url.origin === location.origin && /^\/scene\/(?:index\.html|flutter_bootstrap\.js|main\.dart\.js|flutter_service_worker\.js)$/.test(url.pathname)) {
            await cache.delete(request);
          }
        }
      }
    }
  } catch (_) { /* Keep accounts, learning records and verified model caches. */ }
  const config={canvasKitBaseUrl:'canvaskit/'};
  try {
    await _flutter.loader.load({
      config,
      onEntrypointLoaded: async engineInitializer => {
        try {
          const runner=await engineInitializer.initializeEngine(config);
          await runner.runApp();
        } catch (_) { window.sceneBootFailed?.(); }
      },
    });
  } catch (_) { window.sceneBootFailed?.(); }
})();
