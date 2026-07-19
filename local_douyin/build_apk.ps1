Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Local Douyin - APK Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Use China mirrors (NO proxy needed for China-hosted mirrors)
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

# Clear proxy to avoid v2ray intercepting China mirror traffic
$env:HTTP_PROXY = $null
$env:HTTPS_PROXY = $null
$env:http_proxy = $null
$env:https_proxy = $null

# Clear git proxy (pub uses git for some operations)
git config --global --unset http.proxy 2>$null
git config --global --unset https.proxy 2>$null

$flutterPath = "C:\Users\ZhuanZ\flutter\flutter\bin\flutter.bat"

Write-Host "[1/4] Checking Flutter..." -ForegroundColor Yellow
& $flutterPath --version
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Flutter check failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "[2/4] Installing dependencies (China mirror, no proxy)..." -ForegroundColor Yellow
Set-Location "c:\Users\ZhuanZ\Documents\0\local_douyin"
& $flutterPath pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: Dependency install failed!" -ForegroundColor Red
    Write-Host "Trying with pub.dev and proxy..." -ForegroundColor Yellow
    
    # Fallback: use pub.dev directly with v2ray proxy
    $env:PUB_HOSTED_URL = $null
    $env:FLUTTER_STORAGE_BASE_URL = $null
    $env:HTTP_PROXY = "http://127.0.0.1:10808"
    $env:HTTPS_PROXY = "http://127.0.0.1:10808"
    $env:http_proxy = "http://127.0.0.1:10808"
    $env:https_proxy = "http://127.0.0.1:10808"
    git config --global http.proxy http://127.0.0.1:10808
    git config --global https.proxy http://127.0.0.1:10808
    
    & $flutterPath pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: Both mirror and proxy methods failed!" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}
Write-Host ""

Write-Host "[3/4] Checking Android toolchain..." -ForegroundColor Yellow
& $flutterPath doctor
Write-Host ""

Write-Host "[4/4] Building APK (Debug)..." -ForegroundColor Yellow
& $flutterPath build apk --debug
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: APK build failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "  BUILD SUCCESS!" -ForegroundColor Green
Write-Host "  APK: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "For Release build, run: flutter build apk --release"
Write-Host ""
Read-Host "Press Enter to exit"