#!/usr/bin/env pwsh
# Automated CERES deployment setup script
# This script prepares the server for Kubernetes deployment

param(
    [string]$RemoteHost = "192.168.1.3",
    [string]$RemoteUser = "root",
    [string]$RemotePassword = "",
    [string]$SSHKeyPath = "$HOME\.ssh\ceres"
)

$ErrorActionPreference = "Continue"

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  CERES Automated Deployment Setup                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Generate SSH key (if not exists)
Write-Host "Step 1: Preparing SSH authentication..." -ForegroundColor Green
if (-not (Test-Path $SSHKeyPath)) {
    Write-Host "  Generating SSH key..."
    ssh-keygen -t ed25519 -f $SSHKeyPath -N "" -q
    Write-Host "  ✓ SSH key generated at $SSHKeyPath" -ForegroundColor Green
} else {
    Write-Host "  ✓ SSH key already exists" -ForegroundColor Green
}

# Step 2: Test SSH connectivity
Write-Host "Step 2: Testing SSH connectivity..." -ForegroundColor Green
$testSSH = ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new -i $SSHKeyPath root@$RemoteHost "echo OK" 2>&1
if ($testSSH -contains "OK") {
    Write-Host "  ✓ SSH connection successful (using key)" -ForegroundColor Green
    $useKey = $true
} else {
    Write-Host "  ! Key auth failed, will try with password" -ForegroundColor Yellow
    $useKey = $false
}

# Step 3: Add public key to remote (if using password)
if (-not $useKey) {
    Write-Host "Step 3: Adding public key to remote authorized_keys..." -ForegroundColor Green
    $pubKey = Get-Content "$SSHKeyPath.pub" -Raw
    
    # Create a script to run on remote
    $remoteCmds = @(
        "mkdir -p ~/.ssh",
        "chmod 700 ~/.ssh",
        "echo '$pubKey' >> ~/.ssh/authorized_keys",
        "chmod 600 ~/.ssh/authorized_keys",
        "echo '✓ Key added successfully'"
    )
    
    Write-Host "  Note: You will be prompted for password. Enter: !r0oT3dc" -ForegroundColor Yellow
    
    foreach ($cmd in $remoteCmds) {
        ssh root@$RemoteHost $cmd
    }
}

# Step 4: Install dependencies on remote
Write-Host "Step 4: Installing dependencies on remote server..." -ForegroundColor Green
$sshOpts = if ($useKey) { @("-i", $SSHKeyPath) } else { @() }

$installCmd = @"
curl -fsSL https://raw.githubusercontent.com/skulesh01/Ceres/main/scripts/install.sh | bash
"@

Write-Host "  Running: curl https://raw.githubusercontent.com/skulesh01/Ceres/main/scripts/install.sh | bash" -ForegroundColor Cyan
ssh @sshOpts root@$RemoteHost $installCmd

# Step 5: Get kubeconfig
Write-Host "Step 5: Retrieving kubeconfig from remote..." -ForegroundColor Green
$kubeConfigPath = "$HOME\k3s.yaml"
scp @sshOpts -o StrictHostKeyChecking=accept-new root@$RemoteHost`:/etc/rancher/k3s/k3s.yaml $kubeConfigPath 2>&1 | Where-Object { $_ -notmatch "^debug" }

if (Test-Path $kubeConfigPath) {
    Write-Host "  ✓ kubeconfig saved to $kubeConfigPath" -ForegroundColor Green
} else {
    Write-Host "  ! Could not retrieve kubeconfig" -ForegroundColor Yellow
}

# Step 6: Encode kubeconfig to base64
Write-Host "Step 6: Encoding kubeconfig for GitHub secrets..." -ForegroundColor Green
if (Test-Path $kubeConfigPath) {
    $kubeContent = Get-Content $kubeConfigPath -Raw
    $kubeBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeContent))
    
    # Save to file for reference
    $kubeBase64 | Out-File "$HOME\kubeconfig.base64" -NoNewline
    Write-Host "  ✓ Encoded kubeconfig saved to $HOME\kubeconfig.base64" -ForegroundColor Green
    Write-Host "  ✓ Copy this value for KUBECONFIG secret:" -ForegroundColor Cyan
    Write-Host "  " + $kubeBase64.Substring(0, 80) + "..." -ForegroundColor Gray
}

# Step 7: Add GitHub secrets
Write-Host "Step 7: Adding secrets to GitHub Actions..." -ForegroundColor Green
Write-Host "  Checking GitHub CLI..." -ForegroundColor Cyan

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "  ! GitHub CLI not found. Install from: https://github.com/cli/cli" -ForegroundColor Yellow
    Write-Host "  Manual secret setup required" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ GitHub CLI found" -ForegroundColor Green
    
    # Check if authenticated
    $ghStatus = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ GitHub authenticated" -ForegroundColor Green
        
        # Get repo
        $repo = gh repo view --json nameWithOwner -q
        Write-Host "  Repository: $repo" -ForegroundColor Cyan
        
        # Add secrets
        Write-Host "  Adding secrets..." -ForegroundColor Cyan
        
        gh secret set DEPLOY_HOST --body "192.168.1.3" --repo $repo
        gh secret set DEPLOY_USER --body "root" --repo $repo
        
        $privKey = Get-Content "$SSHKeyPath" -Raw
        gh secret set SSH_PRIVATE_KEY --body $privKey --repo $repo
        
        if (Test-Path "$HOME\kubeconfig.base64") {
            $kubeB64 = Get-Content "$HOME\kubeconfig.base64" -Raw
            gh secret set KUBECONFIG --body $kubeB64 --repo $repo
        }
        
        Write-Host "  ✓ Secrets added successfully" -ForegroundColor Green
    } else {
        Write-Host "  ! Not authenticated to GitHub. Run: gh auth login" -ForegroundColor Yellow
    }
}

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Setup Complete! Ready for Deployment                 ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify secrets in GitHub: https://github.com/skulesh01/Ceres/settings/secrets/actions" -ForegroundColor Gray
Write-Host "  2. Run deployment: https://github.com/skulesh01/Ceres/actions" -ForegroundColor Gray
Write-Host "  3. Monitor logs: gh run watch -R skulesh01/Ceres" -ForegroundColor Gray
Write-Host ""
