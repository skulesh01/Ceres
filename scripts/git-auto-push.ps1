<#
.SYNOPSIS
    Автоматический коммит и пуш изменений на GitHub
.DESCRIPTION
    Скрипт для регулярного коммита и пуша оптимизаций и улучшений на GitHub.
    Проверяет изменения, создает коммит с описанием и пушит на GitHub.
.PARAMETER Message
    Сообщение коммита (если не указано, будет сгенерировано автоматически)
.PARAMETER AutoCommit
    Автоматически коммитить изменения без запроса подтверждения
.PARAMETER Force
    Принудительный пуш (использовать с осторожностью)
.EXAMPLE
    .\git-auto-push.ps1 -Message "feat: оптимизация скриптов развертывания"
.EXAMPLE
    .\git-auto-push.ps1 -AutoCommit
#>

param(
    [Parameter(HelpMessage = "Сообщение коммита")]
    [string]$Message = "",
    
    [Parameter(HelpMessage = "Автоматический коммит без подтверждения")]
    [switch]$AutoCommit,
    
    [Parameter(HelpMessage = "Принудительный пуш (опасно!)")]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "`n=== CERES GIT AUTO-PUSH ===" -ForegroundColor Cyan
Write-Host "Project: $script:ProjectRoot`n" -ForegroundColor Green

# Проверка что мы в git репозитории
Push-Location $script:ProjectRoot
try {
    $gitStatus = git rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] Not a git repository. Initializing..." -ForegroundColor Yellow
        git init
        Write-Host "[OK] Git repository initialized" -ForegroundColor Green
    }
    
    # Проверка remote
    $remoteUrl = git remote get-url origin 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] No remote 'origin' configured" -ForegroundColor Yellow
        Write-Host "Please configure GitHub remote:" -ForegroundColor Cyan
        Write-Host "  git remote add origin https://github.com/YOUR_USERNAME/Ceres.git" -ForegroundColor White
        exit 1
    }
    
    Write-Host "[INFO] Remote: $remoteUrl" -ForegroundColor Cyan
    
    # Получение статуса изменений
    git fetch origin 2>&1 | Out-Null
    $statusOutput = git status --porcelain
    $branch = git rev-parse --abbrev-ref HEAD
    
    if ([string]::IsNullOrWhiteSpace($statusOutput)) {
        Write-Host "[INFO] No changes to commit" -ForegroundColor Yellow
        
        # Проверка есть ли unpushed commits
        $unpushed = git log origin/$branch..HEAD --oneline 2>&1
        if ($unpushed) {
            Write-Host "[INFO] Found unpushed commits, pushing..." -ForegroundColor Cyan
            if ($Force) {
                git push origin $branch --force
            } else {
                git push origin $branch
            }
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Changes pushed successfully" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] Push failed" -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "[OK] Repository is up to date" -ForegroundColor Green
        }
        exit 0
    }
    
    # Показываем что изменилось
    Write-Host "`nChanges detected:" -ForegroundColor Cyan
    git status --short | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    
    # Генерация сообщения коммита если не указано
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $changedFiles = git diff --name-only --cached
        if ([string]::IsNullOrWhiteSpace($changedFiles)) {
            $changedFiles = git diff --name-only
        }
        
        # Определяем тип изменений
        $filesList = $changedFiles -split "`n" | Where-Object { $_ -notmatch '^\s*$' }
        $scriptCount = ($filesList | Where-Object { $_ -match '\.(ps1|sh|py)$' }).Count
        $configCount = ($filesList | Where-Object { $_ -match 'config/' }).Count
        $docCount = ($filesList | Where-Object { $_ -match '\.(md|txt)$' }).Count
        
        if ($scriptCount -gt 0) {
            $Message = "refactor: оптимизация скриптов развертывания"
        } elseif ($configCount -gt 0) {
            $Message = "config: обновление конфигураций"
        } elseif ($docCount -gt 0) {
            $Message = "docs: обновление документации"
        } else {
            $Message = "chore: обновления и улучшения проекта"
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        $Message = "$Message`n`n[Auto-push: $timestamp]"
    }
    
    Write-Host "`nCommit message:" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor White
    
    # Подтверждение (если не AutoCommit)
    if (-not $AutoCommit) {
        $confirm = Read-Host "`nCommit and push? (y/N)"
        if ($confirm -ne 'y' -and $confirm -ne 'Y') {
            Write-Host "[INFO] Cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Добавление файлов
    Write-Host "`n>>> Staging changes..." -ForegroundColor Cyan
    git add .
    
    # Коммит
    Write-Host ">>> Creating commit..." -ForegroundColor Cyan
    git commit -m $Message
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Commit failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OK] Commit created" -ForegroundColor Green
    
    # Пуш
    Write-Host ">>> Pushing to GitHub..." -ForegroundColor Cyan
    if ($Force) {
        Write-Host "[WARN] Using --force flag!" -ForegroundColor Yellow
        git push origin $branch --force
    } else {
        git push origin $branch
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n[OK] Changes pushed successfully to GitHub!" -ForegroundColor Green
        Write-Host "Repository: $remoteUrl" -ForegroundColor Cyan
    } else {
        Write-Host "[ERROR] Push failed. Check your credentials and network." -ForegroundColor Red
        Write-Host "You may need to configure GitHub credentials:" -ForegroundColor Yellow
        Write-Host "  git config --global credential.helper wincred" -ForegroundColor White
        exit 1
    }
    
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}

Write-Host "`n[OK] Git auto-push completed successfully" -ForegroundColor Green
