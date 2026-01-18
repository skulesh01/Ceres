@echo off
setlocal
set SCRIPT_DIR=%~dp0
set CLI=%SCRIPT_DIR%scripts\ceres.ps1

rem Prefer PowerShell Core (pwsh), fallback to Windows PowerShell
where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CLI%" %*
    exit /b %errorlevel%
)

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CLI%" %*
endlocal
