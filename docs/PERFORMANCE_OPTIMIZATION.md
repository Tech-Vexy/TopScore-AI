# Flutter Web Performance Optimization Guide

## Recent Optimizations (Implemented)

### 1. Custom Splash Screen ✅
- **What**: Branded loading screen with TopScore AI logo and gradient background
- **Where**: `web/index.html` - Inline HTML/CSS splash screen
- **Impact**: Eliminates blank white screen during Flutter initialization (1-3 seconds)
- **Features**:
  - Animated spinner and floating logo
  - Auto-hides when Flutter loads or after 10s timeout
  - Responsive design for mobile devices

### 2. Script Loading Optimization ✅
- **Font Awesome**: Added `media="print" onload="this.media='all'"` to CSS
- **SweetAlert2**: Added `defer` to JS, lazy-load CSS
- **PDF.js**: Added `defer` attribute, initialized in DOMContentLoaded
- **Firebase SDK**: Added `defer` to all 5 scripts
- **Google Fonts**: Added `media="print" onload` for non-blocking load
- **Impact**: Reduces render-blocking resources from ~10 to ~2

### 3. Resource Preloading ✅
- **Preload**: App icon (Icon-192.png) and flutter.js
- **Preconnect**: Google Fonts domains with crossorigin
- **Impact**: Faster initial paint, prioritizes critical resources

### 4. Build Optimization Script ✅
- **File**: `build_optimized.ps1`
- **Features**:
  - Uses `--web-renderer auto` (HTML for fast load, CanvasKit when needed)
  - Includes `--source-maps` for debugging
  - Reports bundle size and suggests optimizations
  - Automated cleanup and deployment prompts

---

## Bundle Size Analysis

### Current Bundle (~2MB)
The main.dart.js file is likely large due to:
1. **CanvasKit** (~1.5MB) - High-fidelity graphics renderer
2. **Firebase SDK** - Multiple modules (auth, firestore, storage, messaging)
3. **Dependencies** - 40+ packages in pubspec.yaml

### Recommended Actions

#### A. Use HTML Renderer (When Possible)
```bash
# Build with HTML renderer (smaller bundle, faster load)
flutter build web --release --web-renderer html

# Or use auto (best of both)
flutter build web --release --web-renderer auto
```

**Trade-offs**:
- HTML: ~500KB smaller, faster load, limited graphics capabilities
- CanvasKit: Full graphics support, slower load, larger bundle
- Auto: Starts with HTML, upgrades to CanvasKit if needed

#### B. Analyze Bundle Composition
```bash
# Install analyzer
npm install -g source-map-explorer

# Build with source maps
flutter build web --release --source-maps

# Analyze
source-map-explorer build\web\main.dart.js
```

This shows which packages contribute most to bundle size.

#### C. Check for Unused Dependencies
```bash
# Install validator
dart pub global activate dependency_validator

# Run analysis
dart pub global run dependency_validator
```

**Candidates for removal** (if unused):
- `firebase_database` (if using only Firestore)
- `camera` (large package, only for mobile)
- `audioplayers` (if audio features are limited)
- `flutter_cache_manager` (if `cached_network_image` handles caching)
- `flutter_staggered_grid_view` (if not actively used)
- `confetti` (small but check usage)

#### D. Implement Deferred Loading
For large features, use lazy loading:

```dart
// In router.dart
GoRoute(
  path: '/tools/periodic-table',
  builder: (context, state) {
    // Deferred import
    return FutureBuilder(
      future: import('dart:ui').then((_) => 
        import('package:topscore_ai/screens/tools/periodic_table_screen.dart')),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return PeriodicTableScreen();
        }
        return CircularProgressIndicator();
      },
    );
  },
)
```

---

## Firebase Hosting Optimization

### Cache Headers (firebase.json)
Check your `firebase.json` for proper caching:

```json
{
  "hosting": {
    "public": "build/web",
    "headers": [
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
        "headers": [{
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }]
      },
      {
        "source": "**/*.@(js|css|woff|woff2|ttf|otf)",
        "headers": [{
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        }]
      },
      {
        "source": "**/*.@(json|ico|xml|txt)",
        "headers": [{
          "key": "Cache-Control",
          "value": "public, max-age=3600"
        }]
      }
    ]
  }
}
```

### Compression
Firebase Hosting automatically gzips/brotli compresses files. Verify:
```bash
curl -I -H "Accept-Encoding: gzip" https://topscoreapp.ai/main.dart.js
```
Look for `Content-Encoding: gzip` or `br` (brotli).

---

## Image Optimization

### Current State
- Icons use PNG format (Icon-192.png, Icon-512.png)
- Likely have images in `assets/images/`

### Recommendations
1. **Convert to WebP**: 25-35% smaller than PNG/JPEG
   ```bash
   # Install cwebp tool
   # Convert images
   cwebp -q 80 input.png -o output.webp
   ```

2. **Responsive Images**: Use different sizes for different screens
   ```dart
   Image.asset(
     'assets/images/logo.webp',
     width: MediaQuery.of(context).size.width < 600 ? 100 : 150,
   )
   ```

3. **Lazy Loading**: For images below fold
   ```dart
   ListView.builder(
     itemBuilder: (context, index) {
       return CachedNetworkImage(
         imageUrl: url,
         placeholder: (context, url) => CircularProgressIndicator(),
         errorWidget: (context, url, error) => Icon(Icons.error),
       );
     },
   )
   ```

---

## Performance Monitoring

### PageSpeed Insights
- **Test**: https://pagespeed.web.dev/
- **Target Scores**:
  - Performance: 90+ (mobile), 95+ (desktop)
  - Accessibility: 100
  - Best Practices: 100
  - SEO: 100

### Lighthouse CI (Automated)
Add to GitHub Actions for continuous monitoring:

```yaml
# .github/workflows/lighthouse.yml
name: Lighthouse CI
on: [push]
jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Lighthouse
        uses: treosh/lighthouse-ci-action@v9
        with:
          urls: 'https://topscoreapp.ai'
          budgetPath: './budget.json'
```

### Core Web Vitals Targets
- **LCP** (Largest Contentful Paint): < 2.5s
- **FID** (First Input Delay): < 100ms
- **CLS** (Cumulative Layout Shift): < 0.1

---

## Next Steps

### Immediate (Do Now)
1. ✅ Run optimized build: `.\build_optimized.ps1`
2. ✅ Deploy: `firebase deploy --only hosting`
3. ⏳ Test with PageSpeed Insights
4. ⏳ Compare before/after scores

### Short-term (This Week)
1. Run `dependency_validator` to find unused packages
2. Analyze bundle with `source-map-explorer`
3. Test HTML renderer: `flutter build web --web-renderer html`
4. Update firebase.json with cache headers

### Long-term (Future Sprints)
1. Implement deferred loading for heavy screens (Periodic Table, PDF Viewer, Chat)
2. Convert images to WebP format
3. Set up Lighthouse CI for automated monitoring
4. Consider code splitting by route

---

## Build & Deploy Commands

### Optimized Build (Recommended)
```powershell
.\build_optimized.ps1
```

### Manual Build Options
```bash
# Standard release build
flutter build web --release

# HTML renderer (smaller, faster)
flutter build web --release --web-renderer html

# Auto renderer (recommended)
flutter build web --release --web-renderer auto

# With source maps for analysis
flutter build web --release --source-maps --web-renderer auto
```

### Deploy
```bash
# Preview locally first
firebase serve --only hosting

# Deploy to production
firebase deploy --only hosting
```

---

## Expected Performance Gains

### Before Optimization
- **Load Time**: 5-8 seconds (mobile 3G)
- **Bundle Size**: ~2.0 MB (main.dart.js)
- **Render-blocking**: 10+ resources
- **FCP**: 3-4 seconds
- **PageSpeed Score**: 60-70 (mobile)

### After Optimization
- **Load Time**: 3-5 seconds (mobile 3G)
- **Bundle Size**: ~2.0 MB (same, but loads incrementally)
- **Render-blocking**: 2-3 resources
- **FCP**: 1-2 seconds (splash shows immediately)
- **PageSpeed Score**: 75-85 (mobile)

### With HTML Renderer
- **Load Time**: 2-3 seconds (mobile 3G)
- **Bundle Size**: ~500 KB (main.dart.js)
- **FCP**: < 1 second
- **PageSpeed Score**: 85-95 (mobile)

**Note**: HTML renderer may affect complex animations in chat, periodic table. Test thoroughly.

---

## Troubleshooting

### Issue: Splash screen doesn't disappear
- Check browser console for `flutter-first-frame` event
- Verify splash script is before `flutter_bootstrap.js`
- Fallback timeout (10s) should handle edge cases

### Issue: Scripts fail to load
- Check CDN availability (try loading URLs directly)
- Verify `defer` scripts don't break Firebase initialization
- Consider vendoring critical scripts locally

### Issue: Bundle still too large after optimization
1. Run dependency validator
2. Use source-map-explorer to find culprits
3. Consider removing camera, audioplayers for web build
4. Implement conditional imports:
   ```dart
   import 'camera_mobile.dart' if (dart.library.html) 'camera_web.dart';
   ```

---

## Resources

- [Flutter Web Performance Best Practices](https://docs.flutter.dev/perf/web-performance)
- [Firebase Hosting Cache Headers](https://firebase.google.com/docs/hosting/manage-cache)
- [PageSpeed Insights](https://pagespeed.web.dev/)
- [Web.dev Performance](https://web.dev/performance/)
- [Flutter Web Renderers](https://docs.flutter.dev/platform-integration/web/renderers)
