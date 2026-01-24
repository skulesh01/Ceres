# CERES v3.0.0 - Deploy Runner
# Этот скрипт ТОЛЬКО загружает код и запускает приложение ceres на сервере
# Вся логика развертывания находится в Go приложении

param(
    [string]$Action = "interactive"
)

$Server = "192.168.1.3"
$RemotePath = "/root/Ceres"
$RepoUrl = "https://github.com/skulesh01/Ceres.git"
$LocalPath = $PSScriptRoot

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  CERES v3.0.0 - Deploy Runner                " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Update code on server (git pull)
Write-Host "[*] Updating code on server (git pull)..." -ForegroundColor Yellow
ssh root@$Server "if [ ! -d $RemotePath/.git ]; then git clone $RepoUrl $RemotePath; fi; cd $RemotePath && git pull --ff-only" 2>$null
Write-Host "[+] Code updated" -ForegroundColor Green
Write-Host ""

# 2. Run CERES application on server
Write-Host "[*] Running CERES on server..." -ForegroundColor Yellow
Write-Host ""

switch ($Action) {
    "deploy" {
        ssh root@$Server "cd $RemotePath && CERES_ROOT=$RemotePath /usr/local/go/bin/go run cmd/ceres/main.go deploy"
    }
    "status" {
        ssh root@$Server "cd $RemotePath && CERES_ROOT=$RemotePath /usr/local/go/bin/go run cmd/ceres/main.go status"
    }
    "fix" {
        ssh root@$Server "cd $RemotePath && CERES_ROOT=$RemotePath /usr/local/go/bin/go run cmd/ceres/main.go fix"
    }
    "diagnose" {
        ssh root@$Server "cd $RemotePath && CERES_ROOT=$RemotePath /usr/local/go/bin/go run cmd/ceres/main.go diagnose"
    }
    default {
        # Interactive menu
        ssh -t root@$Server "cd $RemotePath && CERES_ROOT=$RemotePath /usr/local/go/bin/go run cmd/ceres/main.go"
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
