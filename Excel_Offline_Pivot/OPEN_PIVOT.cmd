@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0OPEN_PIVOT.ps1"
if errorlevel 1 pause
endlocal
