# 🚀 Quick Deployment Guide

## Automatic Deployment (Recommended)

Simply run the deployment script:
```powershell
.\deploy.ps1 -Message "Fixed login bug"
```

This will:
- ✅ Auto-increment version numbers
- ✅ Update all version files
- ✅ Build the Flutter web app
- ✅ Deploy to Firebase Hosting
- ✅ Users see update notification within 60 seconds

## Manual Deployment

If you need manual control:

### 1. Update Version Numbers
Edit three files:

**pubspec.yaml:**
```yaml
version: 1.0.0+3  # Increment build number
```

**web/version.json:**
```json
{
  "version": "1.0.0+3"
}
```

**web/index.html:**
```javascript
const APP_VERSION = '2026020401';  // Use date: YYYYMMDDHHMM
```

### 2. Build & Deploy
```powershell
flutter build web --release
firebase deploy --only hosting
```

## What Users See

### Active Users (App Open)
Within 60 seconds, they see:
```
┌──────────────────────────────────────┐
│ 🎉 New Version Available!           │
│ Click update to get the latest      │
│ features and improvements           │
│                                     │
│  [Update Now]  [Later]              │
└──────────────────────────────────────┘
```

### New/Returning Users
- Automatically get latest version
- No action needed

## Testing Updates

### Option 1: DevTools
1. Open Chrome DevTools (F12)
2. Application → Service Workers
3. Click "Update"
4. Should see update notification

### Option 2: Wait
1. Deploy new version
2. Keep app open
3. Wait ~60 seconds
4. Toast appears automatically

### Option 3: Hard Refresh
- Press `Ctrl+Shift+R` (Windows/Linux)
- Press `Cmd+Shift+R` (Mac)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Toast doesn't appear | Check browser console for `[TopScore]` logs |
| Old code still loads | Verify `version.json` is accessible |
| Build fails | Run `flutter clean` then rebuild |
| Deploy fails | Check Firebase login: `firebase login` |

## Version Numbering

**Format:** `MAJOR.MINOR.PATCH+BUILD`

Examples:
- `1.0.0+1` - Initial release
- `1.0.0+2` - Small fix, no new features
- `1.1.0+3` - Added new feature
- `2.0.0+1` - Major redesign

**When to increment:**
- **BUILD (+1)**: Every deployment (automatic)
- **PATCH (x.x.+1)**: Bug fixes
- **MINOR (x.+1.0)**: New features
- **MAJOR (+1.0.0)**: Breaking changes

## Cache Headers Reference

| File Type | Cache-Control | Why |
|-----------|--------------|-----|
| `index.html` | `no-cache` | Always check for updates |
| `*.js`, `*.css` | `max-age=31536000, immutable` | Cached forever (hashed names) |
| `version.json` | `no-cache` | Never cache |
| Service Workers | `no-cache` | Must check for updates |
| Images | `max-age=31536000, immutable` | Long cache (rarely change) |

## Update Detection Methods

The app uses **3 methods** to detect updates:

1. **Service Worker** (Primary)
   - Checks every 60 seconds
   - Detects code changes automatically

2. **Version Polling** (Secondary)
   - Checks every 5 minutes
   - Fetches `/version.json`

3. **Version String** (Fallback)
   - Checks on page load
   - localStorage comparison

## Important Files

```
TopScore-AI/
├── pubspec.yaml              # App version
├── deploy.ps1                # Auto-deployment script
├── firebase.json             # Cache headers config
├── web/
│   ├── index.html            # Update detection logic
│   ├── version.json          # Current version info
│   └── flutter_service_worker_handler.js
└── lib/services/update/
    └── update_service_web.dart  # Dart update checker
```

## Best Practices

✅ **DO:**
- Use `deploy.ps1` for consistent deployments
- Test in staging before production
- Monitor update adoption in analytics
- Keep release notes for major versions

❌ **DON'T:**
- Deploy during peak usage hours
- Skip version number updates
- Force immediate reloads
- Cache `index.html` or `version.json`

## Emergency Rollback

If deployment breaks:

```powershell
# 1. Revert to previous build
git checkout HEAD~1 web/

# 2. Redeploy
firebase deploy --only hosting

# 3. Or deploy specific version
firebase hosting:clone YOUR_PROJECT:live YOUR_PROJECT:VERSION
```

## Support

For issues or questions:
- Check logs in browser console (`[TopScore]` prefix)
- Review `UPDATE_SYSTEM_GUIDE.md` for technical details
- Test with DevTools → Application → Service Workers

---

**Remember:** Users will NEVER need to manually clear cache again! 🎉
