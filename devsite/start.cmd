@echo off
setlocal
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo   Node is not installed, or not on PATH.
  echo   Install Node 18 or newer from nodejs.org, then run this again.
  echo.
  pause
  exit /b 1
)

echo.
echo   Wizards Only Fools - local dev site
echo   http://127.0.0.1:4317
echo.
echo   Notes and art are saved in devsite\content\.
echo   Close this window or press Ctrl+C to stop.
echo.

node server.js 4317 --open
if errorlevel 1 pause
endlocal
