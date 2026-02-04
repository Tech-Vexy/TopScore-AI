/**
 * Enhanced Flutter Service Worker Handler
 * Handles SKIP_WAITING messages from client for immediate updates
 */

// Listen for SKIP_WAITING message from client
self.addEventListener('message', function(event) {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[Service Worker] SKIP_WAITING received');
    self.skipWaiting();
  }
});

// When this service worker becomes active, claim all clients immediately
self.addEventListener('activate', function(event) {
  console.log('[Service Worker] Activating new service worker');
  event.waitUntil(
    self.clients.claim().then(function() {
      console.log('[Service Worker] Claimed all clients');
    })
  );
});

// Optional: Add chunk load error recovery
self.addEventListener('fetch', function(event) {
  // If a chunk fails to load (404), the client will handle retry logic
  event.respondWith(
    fetch(event.request).catch(function(error) {
      console.log('[Service Worker] Fetch failed for:', event.request.url, error);
      // Let the error propagate to trigger client-side retry
      throw error;
    })
  );
});
