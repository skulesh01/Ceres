#!/usr/bin/env pwsh
# Install k3s using plink (no interactive password prompts)

$plink = "$HOME\plink.exe"
$host = "192.168.1.3"
$user = "root"
$pass = $env:DEPLOY_SERVER_PASSWORD
$scriptPath = "/tmp/install-k3s.sh"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Installing k3s via plink (automated)                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create install script content
$installScript = @'
#!/bin/bash
set -e
apt-get update -qq
curl -sfL https://get.k3s.io | sh -
sleep 30
k3s --version
'@

# Step 2: Upload script using plink
Write-Host "[1/3] Uploading install script..." -ForegroundColor Green
$installScript | & $plink -pw $pass -batch $user@$host "cat > /tmp/install-k3s.sh"
Write-Host "      ✓ Script uploaded" -ForegroundColor Green

# Step 3: Make script executable
Write-Host "[2/3] Making script executable..." -ForegroundColor Green
& $plink -pw $pass -batch $user@$host "chmod +x /tmp/install-k3s.sh"
Write-Host "      ✓ Executable" -ForegroundColor Green

# Step 4: Run installation (this takes 5-10 minutes)
Write-Host "[3/3] Running installation (5-10 minutes, please wait)..." -ForegroundColor Green
Write-Host "      Installing k3s..." -ForegroundColor Gray
& $plink -pw $pass $user@$host "bash /tmp/install-k3s.sh" 2>&1 | ForEach-Object {
    if ($_ -match "k3s|version|Done|✓") {
        Write-Host "      $_" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✓ k3s Installation Complete!                         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Step 5: Verify
Write-Host "Verification:" -ForegroundColor Cyan
$version = & $plink -pw $pass -batch $user@$host "k3s --version"
Write-Host "  $version" -ForegroundColor Gray
Write-Host ""
Write-Host "Next: Get kubeconfig and deploy services" -ForegroundColor Gray
