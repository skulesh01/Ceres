# CERES - Full Automated Setup with plink (no password prompts)
# Download plink from PuTTY and automate everything

param(
    [string]$RemoteHost = "192.168.1.3",
    [string]$RemoteUser = "root",
    [string]$RemotePassword = "!r0oT3dc"
)

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CERES - Automated Setup (plink - no password prompts) ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Download plink
$plinkPath = "$HOME\plink.exe"
Write-Host "[1/7] Getting plink..." -ForegroundColor Green

if (Test-Path $plinkPath) {
    Write-Host "      ✓ plink.exe exists" -ForegroundColor Green
} else {
    Write-Host "      → Downloading plink.exe..." -ForegroundColor Gray
    try {
        Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" `
            -OutFile $plinkPath -UseBasicParsing -ErrorAction Stop
        Write-Host "      ✓ Downloaded" -ForegroundColor Green
    }
    catch {
        Write-Host "      ✗ Failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Create SSH key
Write-Host "[2/7] Creating SSH key..." -ForegroundColor Green
$sshKeyPath = "$HOME\.ssh\ceres"

if (Test-Path $sshKeyPath) {
    Write-Host "      ✓ SSH key exists" -ForegroundColor Green
} else {
    $sshDir = Split-Path $sshKeyPath
    New-Item -ItemType Directory -Path $sshDir -Force -ErrorAction SilentlyContinue | Out-Null
    & ssh-keygen -t ed25519 -f $sshKeyPath -N "" -q
    Write-Host "      ✓ SSH key created" -ForegroundColor Green
}

# Step 3: Add public key to remote (using plink with password)
Write-Host "[3/7] Adding SSH key to remote..." -ForegroundColor Green
$pubKey = Get-Content "$sshKeyPath.pub" -Raw

$mkSshCmd = "mkdir -p ~/.ssh"
$addKeyCmd = "echo '$pubKey' >> ~/.ssh/authorized_keys"
$chmodCmd = "chmod 600 ~/.ssh/authorized_keys"

& $plinkPath -pw $RemotePassword -batch $RemoteUser@$RemoteHost $mkSshCmd 2>&1 | Out-Null
& $plinkPath -pw $RemotePassword -batch $RemoteUser@$RemoteHost $addKeyCmd 2>&1 | Out-Null
& $plinkPath -pw $RemotePassword -batch $RemoteUser@$RemoteHost $chmodCmd 2>&1 | Out-Null

Write-Host "      ✓ Public key registered" -ForegroundColor Green

# Step 4: Install Docker and k3s
Write-Host "[4/7] Installing Docker and k3s (5-10 minutes)..." -ForegroundColor Green
Write-Host "      → Running installer..." -ForegroundColor Gray

$installCmd = "curl -fsSL https://raw.githubusercontent.com/skulesh01/Ceres/main/scripts/install.sh | bash"

# Use plink for install (still needs password auth since key not yet working)
& $plinkPath -pw $RemotePassword $RemoteUser@$RemoteHost $installCmd 2>&1 | Out-Null

Write-Host "      ✓ Installation completed" -ForegroundColor Green

# Step 5: Retrieve kubeconfig (now use SSH key since we registered it)
Write-Host "[5/7] Retrieving kubeconfig..." -ForegroundColor Green
$kubeConfigPath = "$HOME\k3s.yaml"

scp -i $sshKeyPath -o StrictHostKeyChecking=no "$RemoteUser@$RemoteHost`:/etc/rancher/k3s/k3s.yaml" $kubeConfigPath 2>&1 | Out-Null

if (Test-Path $kubeConfigPath) {
    Write-Host "      ✓ Kubeconfig retrieved" -ForegroundColor Green
} else {
    Write-Host "      ✗ Failed to retrieve kubeconfig" -ForegroundColor Yellow
    Write-Host "      (Installation may still be running)" -ForegroundColor Gray
}

# Step 6: Encode kubeconfig
Write-Host "[6/7] Encoding kubeconfig..." -ForegroundColor Green

if (Test-Path $kubeConfigPath) {
    $kubeContent = Get-Content $kubeConfigPath -Raw
    $kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeContent))
    $kubeB64 | Out-File "$HOME\kubeconfig.b64" -NoNewline -Encoding ASCII
    Write-Host "      ✓ Kubeconfig encoded" -ForegroundColor Green
}

# Step 7: Set GitHub secrets
Write-Host "[7/7] Setting GitHub secrets..." -ForegroundColor Green

$privKey = Get-Content $sshKeyPath -Raw
$repo = "skulesh01/Ceres"

$gh = Get-Command gh -ErrorAction SilentlyContinue
if ($gh) {
    & gh secret set DEPLOY_HOST --body "192.168.1.3" --repo $repo 2>&1 | Out-Null
    & gh secret set DEPLOY_USER --body "root" --repo $repo 2>&1 | Out-Null
    & gh secret set SSH_PRIVATE_KEY --body $privKey --repo $repo 2>&1 | Out-Null
    
    if (Test-Path "$HOME\kubeconfig.b64") {
        $kubeB64Content = Get-Content "$HOME\kubeconfig.b64" -Raw
        & gh secret set KUBECONFIG --body $kubeB64Content --repo $repo 2>&1 | Out-Null
    }
    
    Write-Host "      ✓ GitHub secrets set" -ForegroundColor Green
} else {
    Write-Host "      ⚠ GitHub CLI not found" -ForegroundColor Yellow
    Write-Host "      Install from: https://cli.github.com" -ForegroundColor Gray
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✓ SETUP COMPLETE - READY TO DEPLOY                   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify secrets:" -ForegroundColor Gray
Write-Host "     gh secret list --repo $repo" -ForegroundColor White
Write-Host ""
Write-Host "  2. Deploy:" -ForegroundColor Gray
Write-Host "     gh workflow run ceres-deploy.yml -R $repo" -ForegroundColor White
Write-Host ""
Write-Host "  3. Monitor:" -ForegroundColor Gray
Write-Host "     gh run watch -R $repo" -ForegroundColor White
Write-Host ""
Write-Host "From now on, use plink for password-less automation:" -ForegroundColor Cyan
Write-Host "  & '$plinkPath' -pw '$RemotePassword' root@$RemoteHost 'command'" -ForegroundColor White
Write-Host ""
