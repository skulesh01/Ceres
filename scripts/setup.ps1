$RemoteHost = "192.168.1.3"
$RemoteUser = "root"
$SSHKeyPath = "$HOME\.ssh\ceres"
$Repo = "skulesh01/Ceres"

Write-Host "`n========== CERES Setup ==========" -ForegroundColor Cyan

# Step 1
Write-Host "[1/5] SSH key..." -ForegroundColor Green
if (-not (Test-Path $SSHKeyPath)) {
    New-Item -ItemType Directory -Path (Split-Path $SSHKeyPath) -Force | Out-Null
    ssh-keygen -t ed25519 -f $SSHKeyPath -N "" -q
}
Write-Host "OK" -ForegroundColor Gray

# Step 2
Write-Host "[2/5] Register key..." -ForegroundColor Green
$pubKey = Get-Content "$SSHKeyPath.pub" -Raw
ssh -o StrictHostKeyChecking=no $RemoteUser@$RemoteHost "mkdir -p ~/.ssh; echo `'$pubKey`' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys" 2>&1 | Out-Null
Write-Host "OK" -ForegroundColor Gray

# Step 3
Write-Host "[3/5] Install Docker/k3s..." -ForegroundColor Green
ssh -i $SSHKeyPath $RemoteUser@$RemoteHost "curl -fsSL https://raw.githubusercontent.com/skulesh01/Ceres/main/scripts/install.sh | bash" 2>&1 | Out-Null
Write-Host "OK" -ForegroundColor Gray

# Step 4
Write-Host "[4/5] Get kubeconfig..." -ForegroundColor Green
$kubeConfigPath = "$HOME\k3s.yaml"
scp -i $SSHKeyPath -o StrictHostKeyChecking=no "$RemoteUser@$RemoteHost`:/etc/rancher/k3s/k3s.yaml" $kubeConfigPath 2>&1 | Out-Null
$kubeContent = Get-Content $kubeConfigPath -Raw
$kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeContent))
Write-Host "OK" -ForegroundColor Gray

# Step 5
Write-Host "[5/5] GitHub secrets..." -ForegroundColor Green
$privKey = Get-Content $SSHKeyPath -Raw
if (Get-Command gh -ErrorAction SilentlyContinue) {
    gh secret set DEPLOY_HOST --body "192.168.1.3" --repo $Repo 2>&1 | Out-Null
    gh secret set DEPLOY_USER --body "root" --repo $Repo 2>&1 | Out-Null
    gh secret set SSH_PRIVATE_KEY --body $privKey --repo $Repo 2>&1 | Out-Null
    gh secret set KUBECONFIG --body $kubeB64 --repo $Repo 2>&1 | Out-Null
    Write-Host "OK" -ForegroundColor Gray
}

Write-Host "`nDone! Deploy with:" -ForegroundColor Green
Write-Host "  gh workflow run ceres-deploy.yml -R $Repo`n" -ForegroundColor Cyan
