# TopScore AI - Deployment Script with Auto-Version Bump
# This script automates version updates for the cache busting system

param(
    [string]$Message = "Update deployment"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TopScore AI - Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Generate new version string (format: YYYYMMDDHHMM)
$newVersion = Get-Date -Format "yyyyMMddHHmm"
Write-Host "[1/7] Generated version: $newVersion" -ForegroundColor Green

# 2. Read current pubspec.yaml version
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match 'version:\s+([0-9]+\.[0-9]+\.[0-9]+\+[0-9]+)') {
    $currentVersion = $matches[1]
    Write-Host "[2/7] Current app version: $currentVersion" -ForegroundColor Green
    
    # Extract and increment build number
    if ($currentVersion -match '([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)') {
        $versionNumber = $matches[1]
        $buildNumber = [int]$matches[2] + 1
        $newAppVersion = "$versionNumber+$buildNumber"
        
        # Update pubspec.yaml
        $pubspecContent = $pubspecContent -replace "version:\s+$currentVersion", "version: $newAppVersion"
        Set-Content -Path $pubspecPath -Value $pubspecContent -NoNewline
        Write-Host "[3/7] Updated pubspec.yaml to: $newAppVersion" -ForegroundColor Green
    }
} else {
    Write-Host "[2/7] Could not parse version from pubspec.yaml" -ForegroundColor Yellow
    $newAppVersion = "1.0.0+1"
}

# 3. Update version.json
$versionJsonPath = "web\version.json"
$versionJson = @{
    version = $newAppVersion
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    build = $newVersion
} | ConvertTo-Json -Depth 10

Set-Content -Path $versionJsonPath -Value $versionJson
Write-Host "[4/7] Updated web/version.json" -ForegroundColor Green

# 4. Update APP_VERSION in index.html
$indexPath = "web\index.html"
$indexContent = Get-Content $indexPath -Raw
$indexContent = $indexContent -replace "const APP_VERSION = '[0-9]+'", "const APP_VERSION = '$newVersion'"
Set-Content -Path $indexPath -Value $indexContent -NoNewline
Write-Host "[5/7] Updated web/index.html APP_VERSION" -ForegroundColor Green

# 5. Build Flutter web
Write-Host "[6/7] Building Flutter web..." -ForegroundColor Yellow
flutter build web --release --web-renderer html

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "[6/7] Build completed successfully!" -ForegroundColor Green

# 6. Deploy to Firebase
Write-Host "[7/7] Deploying to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting -m "$Message (v$newAppVersion)"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Deployment Successful! 🎉" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Version: $newAppVersion" -ForegroundColor Cyan
Write-Host "Build: $newVersion" -ForegroundColor Cyan
Write-Host ""
Write-Host "Active users will see update notification within 60 seconds." -ForegroundColor White
Write-Host "New users will automatically get the latest version." -ForegroundColor White
Write-Host ""
