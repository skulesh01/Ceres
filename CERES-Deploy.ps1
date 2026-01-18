#!/usr/bin/env pwsh
<#
.SYNOPSIS
CERES Deploy Launcher for Windows
Checks Python and starts main application
#>

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PYTHON_APP = Join-Path $SCRIPT_DIR "ceres-deploy.py"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  CERES Platform - Starting Deployment Center" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Проверка Python
function Test-Python {
    $commands = @("python", "python3", "py")
    
    foreach ($cmd in $commands) {
        try {
            $version = & $cmd --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Python found: $version" -ForegroundColor Green
                return $cmd
            }
        }
        catch {
            continue
        }
    }
    
    return $null
}

# Установка Python
function Install-Python {
    Write-Host "[WARN] Python not found. Installing..." -ForegroundColor Yellow
    
    # Определяем архитектуру
    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }
    
    # URL последней версии Python
    $pythonUrl = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-$arch.exe"
    $installerPath = "$env:TEMP\python-installer.exe"
    
    Write-Host "Downloading Python installer..." -ForegroundColor White
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath -ErrorAction Stop
    }
    catch {
        Write-Host "[ERROR] Failed to download Python installer" -ForegroundColor Red
        Write-Host "Please install Python manually from https://www.python.org/downloads/" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Installing Python..." -ForegroundColor White
    Start-Process -FilePath $installerPath -Args "/quiet InstallAllUsers=1 PrependPath=1" -Wait
    
    # Удаляем инсталлятор
    Remove-Item $installerPath -Force
    
    # Обновляем PATH в текущей сессии
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    # Проверяем установку
    $pythonCmd = Test-Python
    if ($pythonCmd) {
        Write-Host "[OK] Python successfully installed" -ForegroundColor Green
        return $pythonCmd
    }
    else {
        Write-Host "[ERROR] Failed to install Python" -ForegroundColor Red
        Write-Host "Please restart your terminal or install Python manually" -ForegroundColor Yellow
        exit 1
    }
}

# Проверка зависимостей Python
function Install-PythonDeps {
    param([string]$PythonCmd)
    
    Write-Host "Checking Python dependencies..." -ForegroundColor White
    
    # Проверяем psutil
    $hasPsutil = & $PythonCmd -c "import psutil" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing psutil..." -ForegroundColor White
        & $PythonCmd -m pip install psutil --quiet
    }
}

# Основная логика
$pythonCmd = Test-Python

if (-not $pythonCmd) {
    $pythonCmd = Install-Python
}

# Проверка зависимостей
Install-PythonDeps -PythonCmd $pythonCmd

# Запуск главного приложения
Write-Host ""
Write-Host "Starting CERES Deploy..." -ForegroundColor Green
Write-Host ""

& $pythonCmd $PYTHON_APP $args
