@echo off
echo =========================================================
echo   bSafe Android APK Builder and Deployer
echo =========================================================
echo.

set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set ADB=C:\Users\mayan\AppData\Local\Android\Sdk\platform-tools\adb.exe

echo [1/3] Setting up ADB Port Forwarding...
"%ADB%" reverse tcp:8000 tcp:8000

echo.
echo [2/3] Checking connected Android Device...
"%ADB%" devices

echo.
echo [3/3] Checking Flutter SDK...
where flutter >nul 2>&1
if errorlevel 1 goto NO_FLUTTER

echo Flutter found! Building Debug APK...
call flutter build apk --debug
echo Installing APK to connected device...
"%ADB%" install -r build\app\outputs\flutter-apk\app-debug.apk
echo Deploy complete!
goto END

:NO_FLUTTER
echo WARNING: 'flutter' executable command is not currently in PATH.
echo To run directly on device 001613558002048:
echo 1. Open VS Code or Android Studio
echo 2. Open folder C:\Users\mayan\Hackathon\Flutter_bSafe
echo 3. Select target 001613558002048 and press F5

:END
pause

