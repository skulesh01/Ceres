# Add GitHub Secrets to Ceres repository
# Run this after gh CLI is installed

$keyFile = "$HOME\.ssh\ceres"
$kubeB64File = "$HOME\kubeconfig.b64"
$repo = "skulesh01/Ceres"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Adding GitHub Secrets to Ceres                       ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if files exist
if (-not (Test-Path $keyFile)) {
    Write-Host "ERROR: SSH key not found at $keyFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $kubeB64File)) {
    Write-Host "ERROR: Kubeconfig base64 not found at $kubeB64File" -ForegroundColor Red
    exit 1
}

# Check if gh CLI exists
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "ERROR: GitHub CLI (gh) not installed" -ForegroundColor Red
    Write-Host "Download from: https://cli.github.com" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/4] Setting DEPLOY_HOST..." -ForegroundColor Green
& gh secret set DEPLOY_HOST --body "192.168.1.3" --repo $repo
Write-Host "      ✓ DEPLOY_HOST set" -ForegroundColor Green

Write-Host "[2/4] Setting DEPLOY_USER..." -ForegroundColor Green
& gh secret set DEPLOY_USER --body "root" --repo $repo
Write-Host "      ✓ DEPLOY_USER set" -ForegroundColor Green

Write-Host "[3/4] Setting SSH_PRIVATE_KEY..." -ForegroundColor Green
$privKey = Get-Content $keyFile -Raw
& gh secret set SSH_PRIVATE_KEY --body $privKey --repo $repo
Write-Host "      ✓ SSH_PRIVATE_KEY set" -ForegroundColor Green

Write-Host "[4/4] Setting KUBECONFIG..." -ForegroundColor Green
$kubeB64 = Get-Content $kubeB64File -Raw
& gh secret set KUBECONFIG --body $kubeB64 --repo $repo
Write-Host "      ✓ KUBECONFIG set" -ForegroundColor Green

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✓ ALL SECRETS ADDED                                  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Verify
Write-Host "Verifying secrets..." -ForegroundColor Cyan
& gh secret list -R $repo

Write-Host ""
Write-Host "Ready to deploy!" -ForegroundColor Green
Write-Host "Run: gh workflow run ceres-deploy.yml -R $repo" -ForegroundColor Gray
Write-Host ""
