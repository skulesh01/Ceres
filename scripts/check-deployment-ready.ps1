<#
.SYNOPSIS
    Проверка готовности к развертыванию Ceres
.DESCRIPTION
    Проверяет все предварительные требования для развертывания:
    - Git репозиторий
    - GitHub remote
    - Ceres-Private
    - Python
    - Скрипты развертывания
#>

$ErrorActionPreference = "Continue"
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:PrivateRoot = Join-Path (Split-Path -Parent $script:ProjectRoot) "Ceres-Private"

Write-Host "`n" + "="*70 -ForegroundColor Cyan
Write-Host "  CERES: DEPLOYMENT READINESS CHECK" -ForegroundColor Cyan
Write-Host "="*70 -ForegroundColor Cyan
Write-Host ""

$allOk = $true
$warnings = @()
$errors = @()

# 1. Проверка Git репозитория
Write-Host "[1/7] Checking Git repository..." -ForegroundColor Yellow
Push-Location $script:ProjectRoot
try {
    $gitExists = Test-Path ".git"
    if (-not $gitExists) {
        $errors += "Git repository not initialized in Ceres"
        Write-Host "  [FAIL] Git repository not initialized" -ForegroundColor Red
        $allOk = $false
    } else {
        Write-Host "  [OK] Git repository found" -ForegroundColor Green
        
        # Проверка remote
        $remoteUrl = git remote get-url origin 2>&1
        if ($LASTEXITCODE -ne 0) {
            $warnings += "GitHub remote 'origin' not configured"
            Write-Host "  [WARN] GitHub remote 'origin' not configured" -ForegroundColor Yellow
            Write-Host "         Run: git remote add origin https://github.com/YOUR_USERNAME/Ceres.git" -ForegroundColor Gray
        } else {
            Write-Host "  [OK] Remote configured: $remoteUrl" -ForegroundColor Green
        }
        
        # Проверка branch
        $branch = git rev-parse --abbrev-ref HEAD 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Current branch: $branch" -ForegroundColor Green
        }
    }
} catch {
    $errors += "Git check failed: $($_.Exception.Message)"
    Write-Host "  [FAIL] Git check error: $($_.Exception.Message)" -ForegroundColor Red
    $allOk = $false
} finally {
    Pop-Location
}

# 2. Проверка Ceres-Private
Write-Host "`n[2/7] Checking Ceres-Private..." -ForegroundColor Yellow
if (-not (Test-Path $script:PrivateRoot)) {
    $errors += "Ceres-Private directory not found"
    Write-Host "  [FAIL] Ceres-Private not found at: $script:PrivateRoot" -ForegroundColor Red
    Write-Host "         Expected location: $script:PrivateRoot" -ForegroundColor Gray
    $allOk = $false
} else {
    Write-Host "  [OK] Ceres-Private directory found" -ForegroundColor Green
    
    # Проверка credentials.json
    $credsPath = Join-Path $script:PrivateRoot "credentials.json"
    if (-not (Test-Path $credsPath)) {
        $warnings += "credentials.json not found in Ceres-Private"
        Write-Host "  [WARN] credentials.json not found" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] credentials.json found" -ForegroundColor Green
    }
    
    # Проверка launcher.py
    $launcherPath = Join-Path $script:PrivateRoot "launcher.py"
    if (-not (Test-Path $launcherPath)) {
        $warnings += "launcher.py not found in Ceres-Private"
        Write-Host "  [WARN] launcher.py not found" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] launcher.py found" -ForegroundColor Green
    }
    
    # Проверка deploy-to-proxmox.py
    $deployPath = Join-Path $script:PrivateRoot "deploy-to-proxmox.py"
    if (-not (Test-Path $deployPath)) {
        $warnings += "deploy-to-proxmox.py not found in Ceres-Private"
        Write-Host "  [WARN] deploy-to-proxmox.py not found" -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] deploy-to-proxmox.py found" -ForegroundColor Green
    }
}

# 3. Проверка Python
Write-Host "`n[3/7] Checking Python..." -ForegroundColor Yellow
$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $pythonCmd) {
    $errors += "Python not found in PATH"
    Write-Host "  [FAIL] Python not found. Install Python 3.7+" -ForegroundColor Red
    $allOk = $false
} else {
    $pythonVersion = & $pythonCmd.Path --version 2>&1
    Write-Host "  [OK] Python found: $pythonVersion" -ForegroundColor Green
}

# 4. Проверка скриптов развертывания
Write-Host "`n[4/7] Checking deployment scripts..." -ForegroundColor Yellow
$scriptsPath = Join-Path $script:ProjectRoot "scripts"
$deployScript = Join-Path $scriptsPath "deploy-to-server.ps1"
$pushScript = Join-Path $scriptsPath "git-auto-push.ps1"
$syncScript = Join-Path $scriptsPath "deploy-and-sync.ps1"

if (Test-Path $deployScript) {
    Write-Host "  [OK] deploy-to-server.ps1 found" -ForegroundColor Green
} else {
    $warnings += "deploy-to-server.ps1 not found"
    Write-Host "  [WARN] deploy-to-server.ps1 not found" -ForegroundColor Yellow
}

if (Test-Path $pushScript) {
    Write-Host "  [OK] git-auto-push.ps1 found" -ForegroundColor Green
} else {
    $warnings += "git-auto-push.ps1 not found"
    Write-Host "  [WARN] git-auto-push.ps1 not found" -ForegroundColor Yellow
}

if (Test-Path $syncScript) {
    Write-Host "  [OK] deploy-and-sync.ps1 found" -ForegroundColor Green
} else {
    $warnings += "deploy-and-sync.ps1 not found"
    Write-Host "  [WARN] deploy-and-sync.ps1 not found" -ForegroundColor Yellow
}

# 5. Проверка Docker Compose файлов
Write-Host "`n[5/7] Checking Docker Compose files..." -ForegroundColor Yellow
$composeBase = Join-Path $script:ProjectRoot "config\compose\base.yml"
$composeCore = Join-Path $script:ProjectRoot "config\compose\core.yml"

if (Test-Path $composeBase) {
    Write-Host "  [OK] base.yml found" -ForegroundColor Green
} else {
    $errors += "base.yml not found"
    Write-Host "  [FAIL] base.yml not found" -ForegroundColor Red
    $allOk = $false
}

if (Test-Path $composeCore) {
    Write-Host "  [OK] core.yml found" -ForegroundColor Green
} else {
    $warnings += "core.yml not found"
    Write-Host "  [WARN] core.yml not found" -ForegroundColor Yellow
}

# 6. Проверка .gitignore
Write-Host "`n[6/7] Checking .gitignore..." -ForegroundColor Yellow
$gitignorePath = Join-Path $script:ProjectRoot ".gitignore"
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw
    if ($gitignoreContent -match "Ceres-Private") {
        Write-Host "  [OK] .gitignore protects Ceres-Private" -ForegroundColor Green
    } else {
        $warnings += ".gitignore may not protect Ceres-Private"
        Write-Host "  [WARN] .gitignore may not protect Ceres-Private" -ForegroundColor Yellow
    }
} else {
    $warnings += ".gitignore not found"
    Write-Host "  [WARN] .gitignore not found" -ForegroundColor Yellow
}

# 7. Проверка изменений в репозитории
Write-Host "`n[7/7] Checking repository status..." -ForegroundColor Yellow
Push-Location $script:ProjectRoot
try {
    if (Test-Path ".git") {
        $statusOutput = git status --porcelain 2>&1
        if ($statusOutput) {
            $changeCount = ($statusOutput -split "`n" | Where-Object { $_ -notmatch '^\s*$' }).Count
            Write-Host "  [INFO] $changeCount uncommitted changes found" -ForegroundColor Cyan
        } else {
            Write-Host "  [OK] No uncommitted changes" -ForegroundColor Green
        }
    }
} catch {
    # Ignore git status errors if not a git repo
} finally {
    Pop-Location
}

# Итоговый отчет
Write-Host "`n" + "="*70 -ForegroundColor Cyan
if ($allOk -and $errors.Count -eq 0) {
    Write-Host "  [SUCCESS] Basic requirements met!" -ForegroundColor Green
    if ($warnings.Count -gt 0) {
        Write-Host "  [WARNINGS] Some optional items need attention" -ForegroundColor Yellow
    }
} elseif ($errors.Count -gt 0) {
    Write-Host "  [FAILED] Critical issues found" -ForegroundColor Red
    $allOk = $false
}

Write-Host "="*70 -ForegroundColor Cyan

if ($errors.Count -gt 0) {
    Write-Host "`nErrors ($($errors.Count)):" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "`nWarnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  • $warning" -ForegroundColor Yellow
    }
}

Write-Host ""

# Рекомендации
if (-not $allOk -or $warnings.Count -gt 0) {
    Write-Host "Recommended actions:" -ForegroundColor Cyan
    if ($errors -match "Git repository not initialized") {
        Write-Host "  1. Initialize Git: cd Ceres; git init" -ForegroundColor White
    }
    if ($warnings -match "GitHub remote") {
        Write-Host "  2. Add GitHub remote: git remote add origin https://github.com/YOUR_USERNAME/Ceres.git" -ForegroundColor White
    }
    if ($errors -match "Ceres-Private") {
        Write-Host "  3. Ensure Ceres-Private directory exists next to Ceres" -ForegroundColor White
    }
    if ($errors -match "Python") {
        Write-Host "  4. Install Python 3.7+ and add to PATH" -ForegroundColor White
    }
    Write-Host ""
}

exit $($allOk ? 0 : 1)
