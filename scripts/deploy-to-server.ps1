<#
.SYNOPSIS
    Развертывание CERES на удаленный сервер через Ceres-Private
.DESCRIPTION
    Этот скрипт запускает развертывание через launcher.py из Ceres-Private.
    Использует credentials из Ceres-Private для безопасного доступа.
.PARAMETER Mode
    Режим работы: 'deploy', 'test', 'status'
.EXAMPLE
    .\deploy-to-server.ps1 -Mode deploy
.EXAMPLE
    .\deploy-to-server.ps1 -Mode test
#>

param(
    [Parameter(HelpMessage = "Режим: deploy, test, status")]
    [ValidateSet('deploy', 'test', 'status')]
    [string]$Mode = 'deploy'
)

$ErrorActionPreference = "Stop"
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:PrivateRoot = Join-Path (Split-Path -Parent $script:ProjectRoot) "Ceres-Private"

Write-Host "`n=== CERES DEPLOYMENT TO SERVER ===" -ForegroundColor Cyan
Write-Host "Public Project: $script:ProjectRoot" -ForegroundColor Green
Write-Host "Private Config: $script:PrivateRoot" -ForegroundColor Yellow

# Проверка существования Ceres-Private
if (-not (Test-Path $script:PrivateRoot)) {
    Write-Host "[ERROR] Ceres-Private not found at: $script:PrivateRoot" -ForegroundColor Red
    Write-Host "Please create Ceres-Private directory with credentials.json" -ForegroundColor Yellow
    exit 1
}

$launcherPath = Join-Path $script:PrivateRoot "launcher.py"
if (-not (Test-Path $launcherPath)) {
    Write-Host "[ERROR] launcher.py not found in Ceres-Private" -ForegroundColor Red
    exit 1
}

# Проверка Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $pythonCmd) {
    Write-Host "[ERROR] Python not found. Please install Python 3.7+" -ForegroundColor Red
    exit 1
}

Write-Host "`n[OK] All prerequisites found" -ForegroundColor Green

# Выбор действия в зависимости от режима
switch ($Mode) {
    'deploy' {
        Write-Host "`n>>> Starting full deployment..." -ForegroundColor Cyan
        Write-Host "This will use launcher.py from Ceres-Private" -ForegroundColor Yellow
        Write-Host "Make sure credentials.json is configured correctly!`n" -ForegroundColor Yellow
        
        # Запускаем launcher.py с выбором пункта 1 (Полное развертывание)
        Push-Location $script:PrivateRoot
        try {
            # Автоматический выбор через echo "1" в launcher.py
            # Но проще запустить напрямую deploy-to-proxmox.py
            $deployScript = Join-Path $script:PrivateRoot "deploy-to-proxmox.py"
            if (Test-Path $deployScript) {
                Write-Host "[INFO] Running deploy-to-proxmox.py directly..." -ForegroundColor Cyan
                & $pythonCmd.Path $deployScript
            } else {
                Write-Host "[INFO] Running launcher.py (will prompt for choice)..." -ForegroundColor Cyan
                Write-Host "Please select option 1 for full deployment" -ForegroundColor Yellow
                & $pythonCmd.Path $launcherPath
            }
        } finally {
            Pop-Location
        }
    }
    'test' {
        Write-Host "`n>>> Testing connection to server..." -ForegroundColor Cyan
        Push-Location $script:PrivateRoot
        try {
            & $pythonCmd.Path (Join-Path $script:PrivateRoot "deploy-to-proxmox.py") --test
        } finally {
            Pop-Location
        }
    }
    'status' {
        Write-Host "`n>>> Checking deployment status..." -ForegroundColor Cyan
        # Проверка статуса через SSH будет в отдельном скрипте
        Write-Host "[INFO] Status check - see check_status.py in Ceres-Private" -ForegroundColor Yellow
    }
}

Write-Host "`n[OK] Deployment script completed" -ForegroundColor Green
