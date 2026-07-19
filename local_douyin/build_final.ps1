$ErrorActionPreference = "Stop"
$flutter = "C:\Users\ZhuanZ\flutter\flutter\bin\flutter.bat"
Set-Location "C:\Users\ZhuanZ\Documents\0\local_douyin"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Clean Build APK (Final)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "[1/3] Cleaning..." -ForegroundColor Yellow
& $flutter clean
if ($LASTEXITCODE -ne 0) { throw "clean failed" }

Write-Host "[2/3] pub get..." -ForegroundColor Yellow
& $flutter pub get
if ($LASTEXITCODE -ne 0) { throw "pub get failed" }

Write-Host "[3/3] Building APK..." -ForegroundColor Yellow
& $flutter build apk --debug
if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBUILD SUCCESS!" -ForegroundColor Green
} else {
    throw "build failed with exit code $LASTEXITCODE"
}
Read-Host "Press Enter"
