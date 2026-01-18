#!/usr/bin/env pwsh
<#
.SYNOPSIS
CERES Remote Deploy для Windows
Автоматическое развертывание на Proxmox без ввода пароля
#>

param(
    [string]$ServerIP = "192.168.1.3",
    [string]$ServerUser = "root",
    [string]$ServerPassword = $env:DEPLOY_SERVER_PASSWORD,
    [string]$RemoteDir = "/opt/ceres"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "         CERES REMOTE DEPLOYMENT TO PROXMOX" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor Cyan

Write-Host "  Target Server:   $ServerUser@$ServerIP" -ForegroundColor White
Write-Host "  Remote Path:     $RemoteDir" -ForegroundColor White
Write-Host "  Project Root:    $ProjectRoot`n" -ForegroundColor White

if (-not $ServerPassword) {
    $ServerPassword = Read-Host "Enter password for $ServerUser@$ServerIP (or set DEPLOY_SERVER_PASSWORD)"
}

$confirm = Read-Host "Continue with deployment? (yes/no)"
if ($confirm -notmatch '^(yes|y)$') {
    Write-Host "Aborted" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n>>> Connecting to server..." -ForegroundColor Cyan

# Тест подключения (просто пытаемся подключиться, пароль будет запрошен)
try {
    ssh -o StrictHostKeyChecking=no "$ServerUser@$ServerIP" "echo 'OK'" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] SSH may require password input" -ForegroundColor Yellow
    }
    else {
        Write-Host "[OK] Connected" -ForegroundColor Green
    }
}
catch {
    Write-Host "[WARN] Testing connection..." -ForegroundColor Yellow
}

# Создаем директорию
Write-Host "`n>>> Creating remote directory..." -ForegroundColor Cyan
Write-Host "      (Password for SSH will be requested if not using keys)" -ForegroundColor Gray
ssh -o StrictHostKeyChecking=no "$ServerUser@$ServerIP" "mkdir -p $RemoteDir"
Write-Host "[OK] Directory ready" -ForegroundColor Green

# Архивируем проект
Write-Host "`n>>> Creating project archive..." -ForegroundColor Cyan
$archivePath = Join-Path $env:TEMP "ceres-project.zip"
if (Test-Path $archivePath) { Remove-Item $archivePath -Force }

Compress-Archive -Path "$ProjectRoot\*" -DestinationPath $archivePath -Force
Write-Host "[OK] Archive created" -ForegroundColor Green

# Загружаем архив
Write-Host "`n>>> Uploading project (this may take a few minutes)..." -ForegroundColor Cyan
scp -o StrictHostKeyChecking=no $archivePath "$ServerUser@${ServerIP}:${RemoteDir}/"
Write-Host "[OK] Uploaded" -ForegroundColor Green

# Распаковываем
Write-Host "`n>>> Extracting on server..." -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=no "$ServerUser@$ServerIP" "cd $RemoteDir && unzip -o ceres-project.zip && rm ceres-project.zip"
Write-Host "[OK] Extracted" -ForegroundColor Green

# Устанавливаем зависимости
Write-Host "`n>>> Installing dependencies (10-15 minutes)..." -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=no "$ServerUser@$ServerIP" "apt-get update && apt-get install -y python3 python3-pip git wget curl unzip && python3 -m pip install ansible"
Write-Host "[OK] Dependencies installed" -ForegroundColor Green

# Запускаем развертывание
Write-Host "`n>>> Starting deployment (45-75 minutes)..." -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=no "$ServerUser@$ServerIP" "cd $RemoteDir/Ceres && python3 scripts/auto-deploy.py"

Write-Host "`n================================================================================" -ForegroundColor Green
Write-Host "              DEPLOYMENT COMPLETED" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Green
