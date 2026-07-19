@echo off
chcp 65001 >nul
echo ========================================
echo   本地抖音 - APK 一键构建脚本
echo ========================================
echo.

:: 设置代理（v2ray）
set HTTP_PROXY=http://127.0.0.1:10808
set HTTPS_PROXY=http://127.0.0.1:10808
set http_proxy=http://127.0.0.1:10808
set https_proxy=http://127.0.0.1:10808

:: 使用国内镜像加速
set PUB_HOSTED_URL=https://pub.flutter-io.cn
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

:: 配置 git 代理
git config --global http.proxy http://127.0.0.1:10808
git config --global https.proxy http://127.0.0.1:10808

set FLUTTER_PATH=C:\Users\ZhuanZ\flutter\flutter\bin\flutter.bat

echo [1/3] 检查 Flutter 环境...
call "%FLUTTER_PATH%" --version
if %errorlevel% neq 0 (
    echo Flutter 环境检查失败！
    pause
    exit /b 1
)
echo.

echo [2/3] 安装项目依赖...
cd /d "%~dp0"
call "%FLUTTER_PATH%" pub get
if %errorlevel% neq 0 (
    echo 依赖安装失败！
    pause
    exit /b 1
)
echo.

echo [3/3] 构建 APK（Debug 模式）...
call "%FLUTTER_PATH%" build apk --debug
if %errorlevel% neq 0 (
    echo APK 构建失败！
    pause
    exit /b 1
)
echo.

echo ========================================
echo   构建成功！
echo   APK 位置: build\app\outputs\flutter-apk\app-debug.apk
echo ========================================
echo.
echo 如需构建 Release 版本，请运行:
echo   flutter build apk --release
echo.
pause