# ✅ Pre-Deployment Checklist

Use this checklist before every deployment to ensure smooth updates.

---

## 📋 Before Running deploy.ps1

### 1. Code Quality
- [ ] All tests passing
- [ ] No lint errors: `flutter analyze`
- [ ] No compilation errors
- [ ] Tested locally with `flutter run -d chrome`

### 2. Git Status
- [ ] All changes committed
- [ ] Working directory clean
- [ ] Pushed to remote (optional but recommended)

### 3. Environment
- [ ] Firebase CLI installed: `firebase --version`
- [ ] Logged into Firebase: `firebase login`
- [ ] Correct project selected: `firebase use elimisha-90787`

### 4. Dependencies
- [ ] All packages up to date: `flutter pub get`
- [ ] No dependency conflicts

---

## 🚀 Deployment Steps

### Option A: Automated (Recommended)
```powershell
.\deploy.ps1 -Message "Your deployment message"
```

### Option B: Manual
```powershell
# 1. Update versions
#    - pubspec.yaml: version: 1.0.0+X
#    - web/version.json: {"version": "1.0.0+X"}
#    - web/index.html: APP_VERSION = 'YYYYMMDDHHMM'

# 2. Build
flutter clean
flutter pub get
flutter build web --release

# 3. Deploy
firebase deploy --only hosting
```

---

## ✅ After Deployment

### Immediate Checks (0-5 minutes)
- [ ] Website loads: https://topscoreapp.ai
- [ ] No console errors in browser (F12)
- [ ] Service worker registered (DevTools → Application)
- [ ] version.json accessible: https://topscoreapp.ai/version.json

### Update Detection Check (1-2 minutes)
- [ ] Keep old tab open while deploying
- [ ] Wait 60 seconds
- [ ] Update toast appears
- [ ] Click "Update Now" → reloads successfully
- [ ] New version loads correctly

### Functional Testing (5-10 minutes)
- [ ] Login works
- [ ] Chat functionality works
- [ ] PDF viewer works
- [ ] Image paste works (Ctrl+V)
- [ ] Navigation between screens works
- [ ] Firebase Storage uploads work

---

## 🧪 Testing the Update System

### Test 1: Service Worker Update Detection
```
1. Open app in Chrome
2. Note current version in console
3. Deploy new version (change APP_VERSION)
4. Wait ~60 seconds
5. ✅ Toast should appear automatically
```

### Test 2: Manual Service Worker Check
```
1. Open DevTools (F12)
2. Application → Service Workers
3. Click "Update" button
4. ✅ Should detect new service worker
```

### Test 3: Hard Refresh
```
1. Press Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
2. ✅ Should load latest version immediately
```

### Test 4: New User Experience
```
1. Open app in incognito/private mode
2. ✅ Should load latest version immediately
3. ✅ No update notification needed
```

### Test 5: Multiple Tabs
```
1. Open app in 3 different tabs
2. Deploy new version
3. ✅ All tabs should show notification independently
```

---

## 🐛 Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Build fails | Run `flutter clean` | Delete build folder manually |
| Deploy fails | Check Firebase login | Run `firebase login` |
| Old version loads | Check cache headers | Verify firebase.json settings |
| Toast doesn't appear | Check console logs | Look for `[TopScore]` messages |
| Service worker error | Check registration | DevTools → Application → Service Workers |

---

## 📊 Deployment Tracking

Keep a log of deployments (optional):

```
Date: 2026-02-04
Version: 1.0.0+3
Changes: Fixed login bug, added image paste
Deploy Time: 14:30 UTC
Status: ✅ Success
Notes: All tests passed, no issues reported
```

---

## 🔐 Security Checks

Before deploying sensitive changes:
- [ ] No API keys in client code
- [ ] Firebase rules up to date
- [ ] CORS configuration correct
- [ ] Authentication flows tested
- [ ] No sensitive data in console logs

---

## 📈 Monitoring After Deploy

Watch these for 24 hours after major deployments:

### Firebase Console
- [ ] Hosting traffic metrics
- [ ] Error rate in Cloud Functions
- [ ] Firestore read/write patterns
- [ ] Storage upload success rate

### Browser Analytics (if enabled)
- [ ] Page load times
- [ ] Error tracking
- [ ] User engagement metrics
- [ ] Device/browser breakdown

### User Feedback Channels
- [ ] Support tickets/emails
- [ ] App store reviews (mobile)
- [ ] Social media mentions
- [ ] In-app feedback

---

## 🎯 Key Metrics to Track

After each deployment, verify:

| Metric | Target | Check |
|--------|--------|-------|
| Update adoption | >90% in 24h | Firebase Analytics |
| Page load time | <3 seconds | Lighthouse/DevTools |
| Error rate | <0.1% | Console logs |
| Service worker registration | 100% | Application tab |
| Cache hit rate | >95% for assets | Network tab |

---

## 🚨 Emergency Rollback Procedure

If critical bug discovered after deployment:

### Quick Rollback (5 minutes):
```powershell
# 1. Checkout previous version
git checkout HEAD~1

# 2. Redeploy previous version
.\deploy.ps1 -Message "Emergency rollback"

# 3. Verify rollback worked
# Open https://topscoreapp.ai and check version
```

### Firebase Rollback (Alternative):
```powershell
# View deployment history
firebase hosting:channel:list

# Clone previous version to production
firebase hosting:clone SOURCE_SITE:SOURCE_CHANNEL DEST_SITE:live
```

---

## 📱 Platform-Specific Checks

### Web (Primary Platform)
- [ ] Works on Chrome
- [ ] Works on Firefox  
- [ ] Works on Safari
- [ ] Works on Edge
- [ ] Works on mobile browsers

### Android App (if applicable)
- [ ] APK builds successfully
- [ ] Installs without errors
- [ ] Firebase integration works

### iOS App (if applicable)
- [ ] IPA builds successfully
- [ ] Passes App Store review
- [ ] Firebase integration works

---

## 💡 Best Practices

### Do:
✅ Test in staging before production
✅ Deploy during low-traffic hours
✅ Monitor for 30 minutes after deploy
✅ Keep changelog updated
✅ Notify team of major deployments

### Don't:
❌ Deploy on Fridays (unless emergency)
❌ Skip testing
❌ Deploy multiple times rapidly
❌ Ignore error logs
❌ Deploy without version increment

---

## 🔔 Notification Templates

### Team Notification (Slack/Email):
```
🚀 New deployment: v1.0.0+3
Changes:
- Fixed login bug
- Added image paste feature
- Performance improvements

Status: ✅ Success
Time: 14:30 UTC
Monitor: https://console.firebase.google.com
```

### User Notification (if major update):
```
📱 Update Available!

We've just released a new version with:
• Faster performance
• Bug fixes
• New features

Click "Update Now" when you see the notification, or 
refresh your browser to get the latest version.
```

---

## 📝 Version Number Guidelines

When to increment what:

| Change Type | Example | Version Change |
|------------|---------|----------------|
| Typo fix | Fixed button text | 1.0.0+2 → 1.0.0+3 |
| Bug fix | Fixed crash | 1.0.0 → 1.0.1 |
| New feature | Added dark mode | 1.0.0 → 1.1.0 |
| Breaking change | New auth system | 1.0.0 → 2.0.0 |

---

## ✨ Success Criteria

Deployment is successful when:
- ✅ Website loads without errors
- ✅ All features work as expected
- ✅ Update notification appears for active users
- ✅ New users get latest version automatically
- ✅ No increase in error rates
- ✅ Performance metrics stable or improved

---

## 📞 Who to Contact

If issues arise during deployment:

| Issue Type | Contact |
|-----------|---------|
| Build errors | Dev team lead |
| Firebase issues | DevOps/Admin |
| User-facing bugs | QA team |
| Performance issues | Backend team |
| Critical bugs | Everyone! |

---

**Remember:** With the new update system, users will automatically see updates within 60 seconds. No need to tell them to "clear cache" ever again! 🎉

---

*Checklist Version: 1.0*
*Last Updated: February 4, 2026*
