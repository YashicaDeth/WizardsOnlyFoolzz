@echo off
rem Double-click: downloads Juggernaut XL, xinsir openpose and TRELLIS.2 into ComfyUI, then makes a first image through it.
rem Open ComfyUI Desktop first. If your ComfyUI folder is not Documents\ComfyUI, edit COMFY below.
set COMFY=%USERPROFILE%\Documents\ComfyUI
cd /d "%~dp0"
python tools\fetch_comfy_models.py --comfy "%COMFY%"
pause
