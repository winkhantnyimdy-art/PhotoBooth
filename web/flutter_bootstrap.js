{{flutter_js}}
{{flutter_build_config}}

// PhotoBooth bootstrap.
//
// Replaces Flutter's generated bootstrap for two reasons:
//
// 1. Flutter 3.47 ships a self-unregistering service worker stub and warns
//    that its service worker is going away. That would leave an installed PWA
//    unable to start offline, so we register our own worker instead.
// 2. The worker precaches the APP SHELL ONLY and structurally refuses to cache
//    captured photos. See web/photo_booth_service_worker.js.
//
// The engine is started exactly the way Flutter's default bootstrap does, so
// this file does not depend on engine initializer APIs.
registerPhotoBoothServiceWorker();

_flutter.loader.load();

function registerPhotoBoothServiceWorker() {
  if (!('serviceWorker' in navigator)) {
    return;
  }
  // iOS Safari only allows service worker registration from a secure context
  // (HTTPS or localhost), and a file:// page has no origin to scope to.
  if (!window.isSecureContext) {
    return;
  }
  window.addEventListener('load', function () {
    // The app build id busts the cache so a redeploy is always picked up by the
    // browser's service worker update check.
    const buildConfig = (window._flutter && window._flutter.buildConfig) || {};
    const buildId = buildConfig.buildId || 'dev';
    navigator.serviceWorker
      .register('photo_booth_service_worker.js?v=' + encodeURIComponent(buildId))
      .catch(function (error) {
        console.warn('PhotoBooth: service worker registration failed.', error);
      });
  });
}