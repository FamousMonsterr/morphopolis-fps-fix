@echo off
rem Morphopolis FPS Fix - block the game's dead 2013 analytics server (mcro.org)
rem which black-holes connections for ~25s during level loading.
rem This step needs admin rights - the script elevates itself (UAC prompt).
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0patch.ps1','-Mode','Patch','-BlockTelemetry')"
echo.
echo If a UAC prompt appeared and was accepted, mcro.org is now blocked.
pause
