# CERES v3.0.0 - Automatic Deployment via SSH
# Run from Windows to deploy on Proxmox server

param(
    [string]$ServerIP = "192.168.1.3",
    [string]$ServerUser = "root",
    [string]$Action = "deploy"  # deploy, status, vpn-setup
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 CERES v3.0.0 - Remote Deployment" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""

# Check SSH connectivity
Write-Host "📡 Checking connection to $ServerIP..." -ForegroundColor Yellow
$sshTest = ssh -o ConnectTimeout=5 "$ServerUser@$ServerIP" "echo OK" 2>$null
if ($sshTest -ne "OK") {
    Write-Host "❌ Cannot connect to $ServerIP" -ForegroundColor Red
    Write-Host "   Please check:"
    Write-Host "   1. Server is powered on (try Wake-on-LAN)"
    Write-Host "   2. SSH is accessible"
    Write-Host "   3. Server IP is correct"
    exit 1
}
Write-Host "✅ Connected to $ServerIP" -ForegroundColor Green

# Copy CERES code to server
Write-Host ""
Write-Host "📦 Syncing code to server..." -ForegroundColor Yellow
$localPath = "e:\Новая папка\All_project\Ceres"
$remotePath = "/root/ceres"

# Create remote directory
ssh "$ServerUser@$ServerIP" "mkdir -p $remotePath"

# Sync only necessary files (exclude .git, bin, etc.)
scp -r `
    "$localPath\cmd" `
    "$localPath\pkg" `
    "$localPath\deployment" `
    "$localPath\go.mod" `
    "$localPath\go.sum" `
    "$ServerUser@$ServerIP`:$remotePath\" 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to copy files" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Code synced" -ForegroundColor Green

# Build CLI on server
Write-Host ""
Write-Host "🔨 Building CERES CLI on server..." -ForegroundColor Yellow
ssh "$ServerUser@$ServerIP" @"
cd $remotePath && \
go build -o /usr/local/bin/ceres ./cmd/ceres && \
chmod +x /usr/local/bin/ceres && \
echo OK
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Build successful" -ForegroundColor Green

# Execute action
Write-Host ""
switch ($Action) {
    "deploy" {
        Write-Host "🚢 Deploying CERES platform..." -ForegroundColor Cyan
        Write-Host ""
        ssh -t "$ServerUser@$ServerIP" "ceres deploy --cloud proxmox"
    }
    "status" {
        Write-Host "📊 Getting deployment status..." -ForegroundColor Cyan
        Write-Host ""
        ssh -t "$ServerUser@$ServerIP" "ceres status"
    }
    "vpn-setup" {
        Write-Host "🔐 Setting up VPN..." -ForegroundColor Cyan
        Write-Host ""
        # VPN setup needs to run locally, but we can get config
        ssh "$ServerUser@$ServerIP" "cat /etc/wireguard/wg0.conf" > "$env:TEMP\wg0.conf"
        Write-Host "✅ WireGuard config saved to: $env:TEMP\wg0.conf"
        Write-Host ""
        Write-Host "To connect:"
        Write-Host "1. Install WireGuard: https://www.wireguard.com/install/"
        Write-Host "2. Import config: $env:TEMP\wg0.conf"
        Write-Host "3. Activate tunnel"
    }
    default {
        Write-Host "❌ Unknown action: $Action" -ForegroundColor Red
        Write-Host "   Valid actions: deploy, status, vpn-setup"
        exit 1
    }
}

Write-Host ""
Write-Host "✅ Done!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  - Access services: http://$ServerIP`:30080/<service>"
Write-Host "  - Check status: .\deploy-remote.ps1 -Action status"
Write-Host "  - Setup VPN: .\deploy-remote.ps1 -Action vpn-setup"
Write-Host ""
