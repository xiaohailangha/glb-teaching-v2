{{flutter_js}}
{{flutter_build_config}}

// Local validation builds should show the latest model and motion code.
// Remove only this app's previous Flutter service worker registration.
(async () => {
  try { if ('serviceWorker' in navigator) {
    const scope = new URL('./', document.baseURI).href;
    const registrations = await navigator.serviceWorker.getRegistrations();
    for (const registration of registrations) {
      if (registration.scope === scope) await registration.unregister();
    }
  } } catch (_) { /* Storage restrictions must not block startup. */ }
  _flutter.loader.load({config:{canvasKitBaseUrl:'canvaskit/'}});
})();
