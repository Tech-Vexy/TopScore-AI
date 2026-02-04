# Cache Busting & Update System Implementation Guide

## Overview
This Flutter web app now implements a robust multi-layered update detection system that prevents users from seeing stale cached content after deployments.

## Strategy Summary: "Good, Better, Best"

### 1. **Foundation: Cache Busting** ✅ Implemented
- **Hashed Filenames**: Flutter automatically generates content-hashed filenames (e.g., `main.dart.js_1.part.js`)
- **Cache-Control Headers**: Configured in `firebase.json`
  - `index.html`: `no-cache, no-store, must-revalidate` (always fetch latest)
  - `version.json`: `no-cache, no-store, must-revalidate` (never cached)
  - JS/CSS/Images: `public, max-age=31536000, immutable` (cached forever since filenames change)
  - Service Workers: `no-cache` (must check for updates)

### 2. **Better: Service Worker Update Notification** ✅ Implemented
The app detects when a new version is available and shows a user-friendly toast notification.

#### How It Works:
1. **Service Worker Registration** (`web/index.html`):
   - Registers `/flutter_service_worker.js` on page load
   - Polls for updates every 60 seconds via `registration.update()`

2. **Update Detection**:
   - When new service worker detected: Enters "waiting" state
   - Shows animated toast notification: "🎉 New Version Available!"
   - User chooses: **Update Now** or **Later**

3. **Update Flow**:
   ```
   User clicks "Update Now" 
   → Send SKIP_WAITING message to service worker
   → Clear all caches
   → Reload page with fresh content
   ```

### 3. **Best: Multi-Source Update Detection** ✅ Implemented

The system uses **three update detection methods**:

#### Method 1: Service Worker (Primary)
- File: `web/index.html` (lines 238-371)
- Checks: `/flutter_service_worker.js` changes
- Frequency: Every 60 seconds
- Best for: Detecting Flutter code changes

#### Method 2: Flutter Dart Polling (Secondary)
- File: `lib/services/update/update_service_web.dart`
- Checks: `/version.json` endpoint
- Frequency: Every 5 minutes
- Best for: Server-side version updates

#### Method 3: Version String Fallback (Tertiary)
- File: `web/index.html` (localStorage check)
- Checks: Hardcoded `APP_VERSION` in HTML
- Frequency: On page load
- Best for: Non-service-worker browsers

## Files Modified

### 1. `firebase.json`
```json
// Separated JSON caching rules
"source": "**/*.json",
"headers": [{ "key": "Cache-Control", "value": "public, max-age=300" }]

// version.json override - never cached
"source": "/version.json",
"headers": [{ "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }]
```

### 2. `web/index.html`
- Added comprehensive service worker registration
- Beautiful gradient toast notification (purple gradient)
- Smooth animations (slideIn with bounce effect)
- Listens for Flutter-triggered events (`topscoreai-update-available`)
- Clears caches before reload for clean updates

**Key Features:**
- Prevents duplicate toasts with `updateToastShown` flag
- Hover effects on buttons for better UX
- Graceful dismissal with slideOut animation
- Logs all actions with `[TopScore]` prefix

### 3. `lib/services/update/update_service_web.dart`
- Reduced polling to 5 minutes (service worker handles frequent checks)
- Dispatches custom JavaScript events when update detected
- Uses `dart:js_interop` for seamless Dart↔JavaScript communication
- Checks for existing update toast to avoid conflicts

**New Dependencies:**
```dart
import 'dart:js_interop';  // For .jsify() and CustomEvent
```

### 4. `web/flutter_service_worker_handler.js` (NEW)
- Handles `SKIP_WAITING` messages from client
- Immediately claims all clients on activation
- Provides fetch error recovery

## Deployment Workflow

### Every Deployment:
1. **Update Version String** in `web/index.html`:
   ```javascript
   const APP_VERSION = '2026020401'; // Change to current date/build number
   ```

2. **Update version.json** in web root:
   ```json
   {
     "version": "1.0.0+3"
   }
   ```

3. **Build & Deploy**:
   ```bash
   flutter build web --release
   firebase deploy --only hosting
   ```

### What Happens:
1. Service worker detects new `flutter_service_worker.js` hash
2. Toast notification appears automatically for active users
3. User clicks "Update Now" → Page reloads with new code
4. Users who dismissed can refresh manually or see it next time

## User Experience

### Active Users (Tab Open):
- See elegant toast notification within 60 seconds of deployment
- Can click "Update Now" or "Later"
- No interruption if they're in the middle of something

### Returning Users (Closed Tab):
- Automatically get latest version on next visit
- `index.html` is never cached, so it fetches new hashed JS files

### Edge Cases Handled:
- **Chunk Load Errors**: If user navigates during deployment, Flutter's error boundary handles it
- **No Service Worker Support**: Falls back to version check on page load
- **Multiple Tabs**: Each tab independently detects and shows notification
- **Slow Networks**: Cache clearing happens async, won't block reload

## Testing the System

### Test Update Detection:
1. Build and deploy current version
2. Change something in Flutter code
3. Update `APP_VERSION` in index.html and version.json
4. Build and deploy again
5. Wait 60 seconds on a running instance
6. Toast should appear automatically

### Test Manual Update:
1. Open DevTools → Application → Service Workers
2. Click "Update" button manually
3. Should trigger the notification flow

### Test Cache Clearing:
1. Open DevTools → Application → Cache Storage
2. Click "Update Now" in toast
3. Verify all caches are cleared before reload

## Technical Details

### Why This Approach?
- **User-Friendly**: No forced reloads, users choose when to update
- **Reliable**: Three detection methods ensure updates aren't missed
- **Performance**: Caches static assets forever, only checks version markers
- **Graceful**: Handles all browsers, including those without service worker support

### Why 60-Second Polling?
- Balances freshness with server load
- Most users won't be affected by 1-minute delay
- Can be adjusted: Change `60000` in `setInterval()` calls

### Why Multiple Detection Methods?
- Service Worker: Best for code changes (Flutter rebuilds SW on every build)
- version.json: Best for backend version changes
- localStorage: Safety net for browsers without SW support

## Maintenance

### To Increase Update Frequency:
Change in `web/index.html`:
```javascript
setInterval(function() {
  registration.update();
}, 30000); // 30 seconds instead of 60
```

### To Customize Toast Appearance:
Edit `showUpdateNotification()` in `web/index.html` (lines 247-326)

### To Add Update Analytics:
Add tracking in the update button click handler:
```javascript
document.getElementById('refresh-btn').onclick = function() {
  // Add your analytics here
  console.log('User clicked update');
  // ... existing code
};
```

## Troubleshooting

### Toast Doesn't Appear:
- Check browser console for `[TopScore]` logs
- Verify service worker is registered: DevTools → Application → Service Workers
- Ensure `APP_VERSION` changed between deployments

### Update Doesn't Work:
- Check `version.json` is accessible: Open `/version.json` in browser
- Verify cache headers: DevTools → Network → Check response headers
- Clear browser cache manually: Ctrl+Shift+Delete

### Old Code Still Loads:
- Check `index.html` cache headers are set to `no-cache`
- Verify Firebase hosting deployed correctly
- Try hard refresh: Ctrl+Shift+R

### Infinite Reload Loop:
**Symptoms:** Page keeps reloading continuously after deployment
**Cause:** `refreshing` flag not properly set before reload
**Solution:** The fix is already implemented in `web/index.html`:
```javascript
let refreshing = false; // At top of script

// Before ANY reload
if (refreshing) return;
refreshing = true;
window.location.reload();
```

**What was fixed:**
- Added `refreshing` check in "Update Now" button handler
- Added check for existing waiting worker on page load
- Added console logging for debugging controller changes
- Prevents multiple rapid reload triggers

**If still occurring:**
1. Clear all service workers: DevTools → Application → Service Workers → Unregister
2. Clear all caches: DevTools → Application → Clear storage
3. Hard refresh: Ctrl+Shift+R
4. Check console for `[TopScore] Controller changed, refreshing flag: true/false`

## Future Enhancements

### Possible Additions:
1. **Release Notes**: Show changelog in toast notification
2. **Automatic Update**: Update automatically after X minutes if user doesn't respond
3. **Background Sync**: Pre-fetch new version while user continues working
4. **A/B Testing**: Show update to percentage of users first
5. **Update History**: Track update adoption rate in analytics

### Not Recommended:
- **Forced Immediate Reload**: Bad UX, interrupts user workflow
- **Silent Updates**: Can cause confusion if UI suddenly changes
- **Aggressive Polling**: <30 seconds wastes bandwidth and battery

## Summary

Your Flutter web app now has:
✅ Proper cache headers for optimal performance
✅ Service worker-based update detection
✅ Beautiful user-facing update notification
✅ Multiple fallback detection methods
✅ Clean cache clearing on update
✅ No manual user intervention required (but allowed)

Users will **never need to manually clear cache** again! 🎉
