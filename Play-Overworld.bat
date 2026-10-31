@echo off
rem Double-click: pulls the newest build and starts straight in the overworld (the Hunt) in daylight. No zips.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play-Latest.ps1" -Overworld
if errorlevel 1 pause
