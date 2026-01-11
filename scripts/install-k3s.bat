@echo off
REM CERES - K3s Installation via SSH (Batch version)
REM This batch file calls PowerShell to execute SSH installation

setlocal enabledelayedexpansion

echo.
echo ════════════════════════════════════════════════════════
echo   CERES - K3s Installation
echo ════════════════════════════════════════════════════════
echo.
echo NOTE: Set DEPLOY_SERVER_PASSWORD in .env; scripts will use it automatically.
echo.

REM Execute SSH installation
ssh -o StrictHostKeyChecking=no %DEPLOY_SERVER_USER%@%DEPLOY_SERVER_IP% "curl -fsSL https://get.k3s.io | sh -"

echo.
echo Installation started! This may take 5-10 minutes.
echo.
echo Check status with:
echo   ssh %DEPLOY_SERVER_USER%@%DEPLOY_SERVER_IP% "kubectl get nodes"
echo.
pause
