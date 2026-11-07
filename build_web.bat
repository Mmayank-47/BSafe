@echo off
echo ====================================================
echo   bSafe Flutter Web Production Build for Netlify
echo ====================================================
echo.

echo [1/3] Fetching Flutter packages...
call flutter pub get
if %errorlevel% neq 0 (
    echo [ERROR] Flutter pub get failed. Please ensure Flutter is installed and added to PATH.
    pause
    exit /b %errorlevel%
)

echo.
echo [2/3] Building Flutter Web (Release mode)...
call flutter build web --release
if %errorlevel% neq 0 (
    echo [ERROR] Flutter build web failed.
    pause
    exit /b %errorlevel%
)

echo.
echo [3/3] Build completed successfully!
echo Output artifacts are located in: build\web\
echo.
echo You can now:
echo  1. Drag and drop the 'build\web' folder directly to https://app.netlify.com/drop
echo  2. Or run: npx netlify deploy --prod --dir=build/web
echo ====================================================
pause

