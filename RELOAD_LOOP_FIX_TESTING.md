# Service Worker Reload Loop - Testing Guide

## Quick Test for Infinite Loop Fix

### Before Testing:
1. Clear all browser data for your site
2. Unregister all service workers
3. Close all tabs of your app

### Test Procedure:

#### Test 1: Normal Update Flow (Expected: NO LOOP)
```
1. Open app in browser
2. Check console for: "[TopScore] Service Worker registered"
3. Keep tab open
4. Deploy new version (run deploy.ps1)
5. Wait 60 seconds
6. Check console for: "[TopScore] New service worker available!"
7. Toast notification should appear
8. Click "Update Now"
9. Check console for: "[TopScore] Controller changed, refreshing flag: false"
10. Page should reload ONCE
✅ Success: No additional reloads after step 10
```

#### Test 2: Already Waiting Worker (Expected: NO LOOP)
```
1. Deploy new version
2. Open app in NEW tab (while update is pending)
3. Check console for: "[TopScore] Service Worker already waiting"
4. Toast should appear immediately
5. Click "Update Now"
6. Check console for refreshing flag
7. Page should reload ONCE
✅ Success: No loop
```

#### Test 3: Multiple Rapid Updates (Expected: NO LOOP)
```
1. Open app
2. Manually trigger update in DevTools:
   - Application → Service Workers → Update
3. Immediately trigger again (click Update multiple times)
4. Check console logs
✅ Success: Should see "refreshing flag: true" preventing extra reloads
```

### Console Log Patterns:

**Good (No Loop):**
```
[TopScore] Service Worker registered: http://localhost/
[TopScore] New service worker available!
[TopScore] Controller changed, refreshing flag: false
[Navigation: Page is reloading]
[TopScore] Service Worker registered: http://localhost/
```

**Bad (Loop Detected):**
```
[TopScore] Controller changed, refreshing flag: false
[Navigation: Page is reloading]
[TopScore] Controller changed, refreshing flag: false  ← LOOP!
[Navigation: Page is reloading]
[TopScore] Controller changed, refreshing flag: false  ← LOOP!
```

### What the Fix Does:

#### Problem:
```javascript
// OLD CODE (causes loop)
navigator.serviceWorker.addEventListener('controllerchange', () => {
  window.location.reload(); // Always reloads!
});
```

Every time the page reloads, it reconnects to the service worker, fires `controllerchange` again, and reloads again → infinite loop.

#### Solution:
```javascript
// NEW CODE (prevents loop)
let refreshing = false;

navigator.serviceWorker.addEventListener('controllerchange', () => {
  if (refreshing) return; // ← STOPS HERE on 2nd trigger
  refreshing = true;
  window.location.reload(); // Only happens ONCE
});
```

The `refreshing` flag acts as a one-time lock.

### Additional Safeguards Implemented:

1. **Update Button Handler:**
```javascript
document.getElementById('refresh-btn').onclick = function() {
  if (refreshing) return; // ← Prevents double-clicks
  refreshing = true;
  // ... reload logic
};
```

2. **Existing Waiting Worker Check:**
```javascript
if (registration.waiting) {
  // Show toast immediately, don't trigger another update check
  newWorkerWaiting = registration.waiting;
  showUpdateNotification();
}
```

3. **Debug Logging:**
```javascript
console.log('[TopScore] Controller changed, refreshing flag:', refreshing);
```
This helps you verify the flag is working correctly.

### If Loop Still Occurs:

1. **Check Browser Console:**
   - Look for multiple `[TopScore] Controller changed` logs
   - Verify `refreshing flag: true` on second occurrence

2. **Clear Everything:**
```javascript
// Run in browser console:
caches.keys().then(keys => keys.forEach(key => caches.delete(key)));
navigator.serviceWorker.getRegistrations().then(regs => 
  regs.forEach(reg => reg.unregister())
);
localStorage.clear();
location.reload();
```

3. **Check Service Worker State:**
   - DevTools → Application → Service Workers
   - Should only see ONE active worker
   - No multiple "waiting" or "installing" workers

4. **Verify index.html Deployed:**
```bash
# Check if updated index.html is live
curl https://topscoreapp.ai/index.html | grep "refreshing"
# Should return: let refreshing = false;
```

### Success Indicators:

✅ Console shows `refreshing flag: false` only ONCE  
✅ Console shows `refreshing flag: true` on subsequent triggers  
✅ Page reloads exactly ONCE after clicking "Update Now"  
✅ No rapid-fire reload logs in console  
✅ Browser tab stops flickering/reloading  

### Performance Impact:

**Before Fix:**
- CPU: 100% (constant reloading)
- Network: Hundreds of requests
- User Experience: Unusable

**After Fix:**
- CPU: Normal
- Network: 1 reload request
- User Experience: Smooth update

---

## Quick Deploy & Test Script

```powershell
# Deploy with new version
.\deploy.ps1 -Message "Testing loop fix"

# Open browser to test
Start-Process "chrome" "https://topscoreapp.ai"

# Monitor Firebase logs
firebase hosting:channel:open test
```

---

**Remember:** The `refreshing` flag is a simple but critical safeguard. Without it, service worker lifecycle events can trigger multiple rapid reloads!
