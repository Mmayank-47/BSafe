@echo off
echo ===================================================
echo   bSafe Agentic Real-Time Safety Backend Launcher
echo ===================================================
echo.

echo [1/2] Setting up ADB Port Forwarding (Port 8000)...
"C:\Users\mayan\AppData\Local\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000

echo.
echo [2/2] Launching FastAPI Agentic Backend Server on http://0.0.0.0:8000...
py -3 -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload

pause
