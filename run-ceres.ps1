# CERES v3.0.0 - Deploy Runner
# Этот скрипт ТОЛЬКО загружает код и запускает приложение ceres на сервере
# Вся логика развертывания находится в Go приложении

param(
    [string]$Action = "interactive"
)

$Server = "192.168.1.3"
$RemotePath = "/root/ceres"
$LocalPath = $PSScriptRoot

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  CERES v3.0.0 - Deploy Runner                " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Sync code to server
Write-Host "[*] Syncing code to server..." -ForegroundColor Yellow
scp -r "$LocalPath\cmd" "root@${Server}:${RemotePath}/"
scp -r "$LocalPath\pkg" "root@${Server}:${RemotePath}/"
scp -r "$LocalPath\deployment" "root@${Server}:${RemotePath}/"
scp "$LocalPath\go.mod" "root@${Server}:${RemotePath}/"
scp "$LocalPath\go.sum" "root@${Server}:${RemotePath}/" 2>$null

Write-Host "[+] Code synced successfully" -ForegroundColor Green

# 1.5. Install Go dependencies
Write-Host "[*] Installing Go dependencies..." -ForegroundColor Yellow
ssh root@$Server "cd $RemotePath && /usr/local/go/bin/go mod download" 2>$null
Write-Host "[+] Dependencies ready" -ForegroundColor Green
Write-Host ""

# 2. Run CERES application on server
Write-Host "[*] Running CERES on server..." -ForegroundColor Yellow
Write-Host ""

switch ($Action) {
    "deploy" {
        ssh root@$Server "cd $RemotePath && /usr/local/go/bin/go run cmd/ceres/main.go deploy"
    }
    "status" {
        ssh root@$Server "cd $RemotePath && /usr/local/go/bin/go run cmd/ceres/main.go status"
    }
    "fix" {
        ssh root@$Server "cd $RemotePath && /usr/local/go/bin/go run cmd/ceres/main.go fix"
    }
    "diagnose" {
        ssh root@$Server "cd $RemotePath && /usr/local/go/bin/go run cmd/ceres/main.go diagnose"
    }
    default {
        # Interactive menu
        ssh -t root@$Server "cd $RemotePath && /usr/local/go/bin/go run cmd/ceres/main.go"
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
