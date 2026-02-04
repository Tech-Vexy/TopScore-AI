# TopScore AI - Optimized Web Build Script
# This script builds the Flutter web app with optimal performance settings

Write-Host "[BUILD] Starting optimized Flutter web build..." -ForegroundColor Cyan

# Clean previous build
Write-Host "`n[CLEAN] Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "`n[DEPS] Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Extract version from pubspec.yaml
$pubspec = Get-Content pubspec.yaml
$versionLine = $pubspec | Select-String "version: "
$version = $versionLine.ToString().Split(":")[1].Trim()
Write-Host "`n[VERSION] Version detected: $version" -ForegroundColor Cyan

# Create version.json in web/ folder (so it's copied to build/web)
$versionJson = @{
    version = $version
    build_date = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
} | ConvertTo-Json

$versionFile = "web\version.json"
$versionJson | Out-File $versionFile -Encoding utf8
Write-Host "[FILE] Generated $versionFile" -ForegroundColor Cyan

# Build with optimizations
Write-Host "`n[BUILD] Building with optimizations..." -ForegroundColor Yellow
Write-Host "   - Release mode (minification + tree shaking)" -ForegroundColor Gray
Write-Host "   - Auto renderer (Flutter 3.38+ default: HTML for fast load, CanvasKit for complex graphics)" -ForegroundColor Gray
Write-Host "   - Source maps for debugging" -ForegroundColor Gray

flutter build web --release --source-maps

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Build completed successfully!" -ForegroundColor Green
    
    # Show build size
    $mainDartJs = "build\web\main.dart.js"
    if (Test-Path $mainDartJs) {
        $size = (Get-Item $mainDartJs).Length / 1MB
        Write-Host "`n[SIZE] Bundle size: $($size.ToString('0.00')) MB" -ForegroundColor Cyan
        
        if ($size -gt 2) {
            Write-Host "   [WARN] Large bundle detected. Consider:" -ForegroundColor Yellow
            Write-Host "   - Running 'flutter pub run dependency_validator' to check unused dependencies" -ForegroundColor Gray
            Write-Host "   - Analyzing with 'source-map-explorer build\web\main.dart.js'" -ForegroundColor Gray
            Write-Host "   - Using deferred loading for large features" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n[OUTPUT] Build output: build\web\" -ForegroundColor Green
    Write-Host "[DEPLOY] Deploy with: firebase deploy --only hosting" -ForegroundColor Cyan
} else {
    Write-Host "`n[ERROR] Build failed!" -ForegroundColor Red
    exit 1
}
