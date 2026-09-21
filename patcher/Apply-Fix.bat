@echo off
rem Morphopolis FPS Fix - apply patch (no admin rights needed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch.ps1" -Mode Patch
echo.
pause
