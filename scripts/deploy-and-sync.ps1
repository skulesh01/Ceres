<#
.SYNOPSIS
    Комплексный скрипт: развертывание + синхронизация с GitHub
.DESCRIPTION
    Выполняет развертывание на сервер и затем пушит изменения на GitHub.
    Удобный скрипт для регулярного использования при оптимизациях.
.PARAMETER DeployMode
    Режим развертывания: 'deploy', 'test', 'skip'
.PARAMETER PushChanges
    Пуш изменений на GitHub после развертывания
.PARAMETER CommitMessage
    Сообщение коммита для GitHub
.EXAMPLE
    .\deploy-and-sync.ps1 -DeployMode deploy -PushChanges
#>

param(
    [Parameter(HelpMessage = "Режим развертывания: deploy, test, skip")]
    [ValidateSet('deploy', 'test', 'skip')]
    [string]$DeployMode = 'deploy',
    
    [Parameter(HelpMessage = "Пуш изменений на GitHub")]
    [switch]$PushChanges,
    
    [Parameter(HelpMessage = "Сообщение коммита")]
    [string]$CommitMessage = ""
)

$ErrorActionPreference = "Stop"
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "  CERES: DEPLOY + SYNC TO GITHUB" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

# Шаг 1: Развертывание
if ($DeployMode -ne 'skip') {
    Write-Host "`n[STEP 1/2] Deploying to server..." -ForegroundColor Yellow
    $deployScript = Join-Path $script:ProjectRoot "scripts\deploy-to-server.ps1"
    
    if (Test-Path $deployScript) {
        & $deployScript -Mode $DeployMode
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Deployment failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[WARN] deploy-to-server.ps1 not found, skipping deployment" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[STEP 1/2] Deployment skipped" -ForegroundColor Yellow
}

# Шаг 2: Синхронизация с GitHub
if ($PushChanges) {
    Write-Host "`n[STEP 2/2] Syncing to GitHub..." -ForegroundColor Yellow
    $pushScript = Join-Path $script:ProjectRoot "scripts\git-auto-push.ps1"
    
    if (Test-Path $pushScript) {
        $pushParams = @{ AutoCommit = $true }
        if ($CommitMessage) {
            $pushParams['Message'] = $CommitMessage
        }
        
        & $pushScript @pushParams
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] GitHub sync failed" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[WARN] git-auto-push.ps1 not found" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n[STEP 2/2] GitHub sync skipped (use -PushChanges to enable)" -ForegroundColor Yellow
}

Write-Host "`n" + "="*60 -ForegroundColor Green
Write-Host "  [OK] All operations completed successfully!" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Green
