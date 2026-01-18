<#
.SYNOPSIS
    Запуск развертывания Ceres с онлайн логами и прогресс-барами
.DESCRIPTION
    Этот скрипт запускает deploy-to-proxmox.py из Ceres-Private с реальным временным выводом.
    Все логи и прогресс отображаются в реальном времени.
#>

$ErrorActionPreference = "Stop"
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "`n" + "="*80 -ForegroundColor Cyan
Write-Host "  CERES DEPLOYMENT - STARTING WITH LIVE LOGS" -ForegroundColor Cyan
Write-Host "="*80 -ForegroundColor Cyan
Write-Host ""

# Найти Ceres-Private
$privateRoot = Join-Path (Split-Path -Parent $script:ProjectRoot) "Ceres-Private"
if (-not (Test-Path $privateRoot)) {
    Write-Host "[ERROR] Ceres-Private not found at: $privateRoot" -ForegroundColor Red
    Write-Host "Please ensure Ceres-Private directory exists next to Ceres" -ForegroundColor Yellow
    exit 1
}

$deployScript = Join-Path $privateRoot "deploy-to-proxmox.py"
if (-not (Test-Path $deployScript)) {
    Write-Host "[ERROR] deploy-to-proxmox.py not found in Ceres-Private" -ForegroundColor Red
    exit 1
}

$credentialsFile = Join-Path $privateRoot "credentials.json"
if (-not (Test-Path $credentialsFile)) {
    Write-Host "[ERROR] credentials.json not found in Ceres-Private" -ForegroundColor Red
    Write-Host "Please create credentials.json with Proxmox credentials" -ForegroundColor Yellow
    exit 1
}

Write-Host "[INFO] Found Ceres-Private: $privateRoot" -ForegroundColor Green
Write-Host "[INFO] Found deploy script: $deployScript" -ForegroundColor Green
Write-Host "[INFO] Found credentials: $credentialsFile" -ForegroundColor Green
Write-Host ""

# Проверка Python
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $pythonCmd) {
    Write-Host "[ERROR] Python not found. Please install Python 3.7+" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Using Python: $($pythonCmd.Path)" -ForegroundColor Cyan
Write-Host "[INFO] Python version: $(& $pythonCmd.Path --version)" -ForegroundColor Cyan
Write-Host ""

Write-Host "="*80 -ForegroundColor Yellow
Write-Host "  DEPLOYMENT WILL SHOW:" -ForegroundColor Yellow
Write-Host "  - Progress bars for each stage" -ForegroundColor White
Write-Host "  - Real-time logs from server" -ForegroundColor White
Write-Host "  - Live output from all commands" -ForegroundColor White
Write-Host "="*80 -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Start deployment? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "[INFO] Deployment cancelled by user" -ForegroundColor Yellow
    exit 0
}

Write-Host "`n>>> Starting deployment..." -ForegroundColor Cyan
Write-Host ">>> All output will be shown in real-time" -ForegroundColor Cyan
Write-Host ""

# Запуск развертывания
Push-Location $privateRoot
try {
    # Запускаем напрямую deploy-to-proxmox.py
    # Это выведет все в реальном времени с прогресс-барами и логами
    & $pythonCmd.Path $deployScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n" + "="*80 -ForegroundColor Green
        Write-Host "  [SUCCESS] Deployment completed successfully!" -ForegroundColor Green
        Write-Host "="*80 -ForegroundColor Green
    } else {
        Write-Host "`n" + "="*80 -ForegroundColor Red
        Write-Host "  [ERROR] Deployment failed with exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "="*80 -ForegroundColor Red
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "[ERROR] Deployment exception: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host ""
