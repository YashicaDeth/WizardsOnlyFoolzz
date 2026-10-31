@echo off
rem Double-click: pulls the newest build branch and plays it from source. No zips.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play-Latest.ps1"
if errorlevel 1 pause
