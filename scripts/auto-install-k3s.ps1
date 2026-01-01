# CERES - Automated K3s Installation via SSH with WebRequest
# This script downloads install.sh to remote server and runs it

$host = "192.168.1.3"
$user = "root"
$pass = "!r0oT3dc"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CERES - Automated K3s Installation                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check connectivity
Write-Host "[1/5] Testing SSH connection..." -ForegroundColor Green
try {
    $testResult = & ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$user@$host" "echo OK" 2>&1 | Out-String
    if ($testResult -match "OK") {
        Write-Host "      ✓ SSH connection successful" -ForegroundColor Green
    } else {
        throw "SSH failed"
    }
} catch {
    Write-Host "      ✗ SSH connection failed" -ForegroundColor Red
    Write-Host "      Make sure password is correct: !r0oT3dc" -ForegroundColor Yellow
    exit 1
}

# Step 2: Check if k3s already installed
Write-Host "[2/5] Checking for existing k3s installation..." -ForegroundColor Green
$k3sCheck = & ssh -o StrictHostKeyChecking=no "$user@$host" "command -v k3s 2>/dev/null && echo FOUND || echo NOT_FOUND" 2>&1 | Out-String
if ($k3sCheck -match "FOUND") {
    Write-Host "      ✓ K3s already installed" -ForegroundColor Green
} else {
    Write-Host "      • K3s not found, will install" -ForegroundColor Yellow
}

# Step 3: Download install script from GitHub
Write-Host "[3/5] Downloading k3s installer..." -ForegroundColor Green
$installUrl = "https://get.k3s.io"
$localScript = "$env:TEMP\k3s-install.sh"

try {
    Invoke-WebRequest -Uri $installUrl -OutFile $localScript -UseBasicParsing -ErrorAction Stop
    Write-Host "      ✓ Downloaded to $localScript" -ForegroundColor Green
} catch {
    Write-Host "      ✗ Download failed: $_" -ForegroundColor Red
    exit 1
}

# Step 4: Upload script to remote server
Write-Host "[4/5] Uploading script to remote server..." -ForegroundColor Green
try {
    # Using scp to upload
    & scp -o StrictHostKeyChecking=no $localScript "$user@$host`:/tmp/k3s-install.sh" 2>&1 | Out-Null
    Write-Host "      ✓ Script uploaded" -ForegroundColor Green
} catch {
    Write-Host "      ⚠ SCP may have issues, trying direct curl instead..." -ForegroundColor Yellow
}

# Step 5: Execute installation on remote
Write-Host "[5/5] Running k3s installation (5-10 minutes)..." -ForegroundColor Green
Write-Host "      Please wait..." -ForegroundColor Gray

$installCmd = "if [ -f /tmp/k3s-install.sh ]; then bash /tmp/k3s-install.sh; else curl -fsSL https://get.k3s.io | bash; fi"
$installOutput = & ssh -o StrictHostKeyChecking=no "$user@$host" $installCmd 2>&1 | Out-String

if ($installOutput -match "installed successfully|K3s is running" -or $LASTEXITCODE -eq 0) {
    Write-Host "      ✓ Installation completed" -ForegroundColor Green
} else {
    Write-Host "      ⚠ Installation in progress (may continue in background)" -ForegroundColor Yellow
}

Write-Host ""

# Verify installation
Write-Host "Verifying installation..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$verifyCmd = "k3s --version 2>&1 && kubectl get nodes 2>&1"
$verifyOutput = & ssh -o StrictHostKeyChecking=no "$user@$host" $verifyCmd 2>&1 | Out-String

if ($verifyOutput -match "v1\." -and $verifyOutput -match "Ready") {
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✓ K3S INSTALLATION SUCCESSFUL!                       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "K3s version:" -ForegroundColor Cyan
    Write-Host $verifyOutput.Split("`n")[0] -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Get kubeconfig: scp -o StrictHostKeyChecking=no $user@$host:/etc/rancher/k3s/k3s.yaml ~/" -ForegroundColor Gray
    Write-Host "  2. Set GitHub secret: gh secret set KUBECONFIG --body (Get-Content ~/k3s.yaml -Raw) -R $repo" -ForegroundColor Gray
    Write-Host "  3. Deploy: gh workflow run ceres-deploy.yml -R skulesh01/Ceres" -ForegroundColor Gray
} elseif ($verifyOutput -match "v1\.") {
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  ⚠ K3S INSTALLED BUT STILL INITIALIZING                ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "K3s is running but Kubernetes may still be initializing." -ForegroundColor Gray
    Write-Host "Wait 30-60 seconds and run:" -ForegroundColor Gray
    Write-Host "  ssh $user@$host 'kubectl get nodes'" -ForegroundColor White
} else {
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  ⚠ INSTALLATION MAY BE IN PROGRESS                    ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Check status manually:" -ForegroundColor Gray
    Write-Host "  ssh $user@$host 'systemctl status k3s'" -ForegroundColor White
    Write-Host "  ssh $user@$host 'journalctl -u k3s -f'" -ForegroundColor White
}

Write-Host ""
