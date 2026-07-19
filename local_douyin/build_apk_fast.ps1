Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Rebuild APK (ffmpeg_kit_flutter_new)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# China mirrors
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

# NO proxy
$env:HTTP_PROXY = $null
$env:HTTPS_PROXY = $null
$env:http_proxy = $null
$env:https_proxy = $null

$flutterPath = "C:\Users\ZhuanZ\flutter\flutter\bin\flutter.bat"
Set-Location "c:\Users\ZhuanZ\Documents\0\local_douyin"

Write-Host "[1/2] Updating dependencies..." -ForegroundColor Yellow
& $flutterPath pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAILED: pub get failed!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "[2/2] Building APK..." -ForegroundColor Yellow
& $flutterPath build apk --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESS!" -ForegroundColor Green
    Write-Host "  APK: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "BUILD FAILED with exit code $LASTEXITCODE" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"