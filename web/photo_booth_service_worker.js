/*
 * PhotoBooth service worker.
 *
 * Scope: cache the application shell only, so an installed PWA starts offline.
 *
 * PRIVACY RULE FOR THIS APP: a user's captured photos must never be written to
 * the Cache Storage API. Photos live in `blob:` URLs created by `canvas.toBlob`
 * and are held in tab memory only. They are never requested over the network,
 * so they can never reach a fetch handler here. The allowlist below makes that
 * structural rather than incidental: anything that is not an explicitly listed
 * app-shell file is served straight from the network and never stored.
 */

'use strict';

const CACHE_PREFIX = 'photobooth-shell-';

/**
 * The application shell.
 *
 * Static, build-produced assets only. No user content is or can be listed here.
 */
const APP_SHELL = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'main.dart.js',
  'flutter.js',
  'manifest.json',
  'favicon.png',
  'version.json',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
  'icons/Icon-maskable-192.png',
  'icons/Icon-maskable-512.png',
  'assets/AssetManifest.bin',
  'assets/AssetManifest.bin.json',
  'assets/FontManifest.json',
  'assets/fonts/MaterialIcons-Regular.otf',
];

/**
 * Cache-busting token.
 *
 * Taken from the `?v=` query that the bootstrap appends to the registration
 * URL, so a new deploy always yields a new worker script and therefore a new
 * cache name. Superseded caches are dropped on activate.
 */
const VERSION = new URL(self.location.href).searchParams.get('v') || 'dev';
const CACHE_NAME = CACHE_PREFIX + VERSION;

self.addEventListener('install', function (event) {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(function (cache) {
      // addAll is all-or-nothing; add individually so one missing optional file
      // cannot abort the whole install.
      return Promise.all(
        APP_SHELL.map(function (asset) {
          return cache.add(new Request(asset, { cache: 'reload' })).catch(function (error) {
            console.warn('PhotoBooth SW: could not precache ' + asset, error);
          });
        }),
      );
    }),
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    (async function () {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter(function (name) {
            return name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME;
          })
          .map(function (name) {
            return caches.delete(name);
          }),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', function (event) {
  const request = event.request;

  // Only GET requests are ever considered. Everything else (the camera stream,
  // share calls) bypasses the worker entirely.
  if (request.method !== 'GET') {
    return;
  }

  const url = new URL(request.url);

  // Same-origin only. In particular this keeps the gstatic.com CanvasKit
  // download out of Cache Storage.
  if (url.origin !== self.location.origin) {
    return;
  }

  // Never cache non-http(s) schemes. A captured photo's `blob:` URL would land
  // here if it were ever fetched; this makes that a hard no-op.
  if (url.protocol !== 'http:' && url.protocol !== 'https:') {
    return;
  }

  // Structural privacy guarantee: only files on the app-shell allowlist are
  // eligible for the cache. Everything else, including any user content that
  // might later be routed through a URL, goes straight to the network and is
  // never written to Cache Storage.
  const relativePath = url.pathname.replace(/^\/+/, '');
  const isAppShell = relativePath === '' || APP_SHELL.indexOf(relativePath) !== -1;

  if (!isAppShell) {
    return;
  }

  event.respondWith(
    caches.match(request).then(function (cached) {
      if (cached) {
        return cached;
      }
      return fetch(request).then(function (response) {
        // Only persist complete, successful, same-origin responses.
        if (response && response.status === 200 && response.type === 'basic') {
          const copy = response.clone();
          caches.open(CACHE_NAME).then(function (cache) {
            cache.put(request, copy);
          });
        }
        return response;
      });
    }),
  );
});