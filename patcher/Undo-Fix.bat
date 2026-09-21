@echo off
rem Morphopolis FPS Fix - undo patch (restores original state)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0patch.ps1" -Mode Undo
echo.
pause
