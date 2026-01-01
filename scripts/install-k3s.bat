@echo off
REM CERES - K3s Installation via SSH (Batch version)
REM This batch file calls PowerShell to execute SSH installation

setlocal enabledelayedexpansion

echo.
echo ════════════════════════════════════════════════════════
echo   CERES - K3s Installation
echo ════════════════════════════════════════════════════════
echo.
echo NOTE: SSH will ask for password. Enter: !r0oT3dc
echo.

REM Execute SSH installation
ssh -o StrictHostKeyChecking=no root@192.168.1.3 "curl -fsSL https://get.k3s.io | sh -"

echo.
echo Installation started! This may take 5-10 minutes.
echo.
echo Check status with:
echo   ssh root@192.168.1.3 "kubectl get nodes"
echo.
pause
