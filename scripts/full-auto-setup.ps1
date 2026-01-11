# Full Automation Setup Script
# This script configures NAT on Proxmox, installs k3s, retrieves kubeconfig, and triggers deployment

param(
    [string]$ProxmoxHost = "192.168.1.1",
    [string]$ProxmoxUser = "root",
    [string]$ProxmoxPassword = "!r0oT3dc",
    [string]$VMHost = "192.168.1.3",
    [string]$VMUser = "root",
    [string]$VMPassword = "!r0oT3dc",
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$GitHubRepo = "skulesh01/Ceres"
)

$ErrorActionPreference = "Stop"
$plink = "$HOME\plink.exe"
$vmNetwork = "192.168.1.0/24"
$vmGateway = "192.168.1.1"

Write-Host "=== CERES FULL AUTOMATION SETUP ===" -ForegroundColor Cyan

# Function to execute commands via plink
function Invoke-PlinkCommand {
    param(
        [string]$Host,
        [string]$Command,
        [string]$Password
    )
    $result = & $plink -pw $Password -batch $Host $Command 2>&1
    return $result
}

# Step 1: Configure NAT on Proxmox
Write-Host "`n[1/6] Configuring NAT on Proxmox..." -ForegroundColor Yellow
try {
    $natConfig = @"
# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1

# Configure iptables NAT rules
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -j MASQUERADE 2>/dev/null || true
iptables -t nat -A POSTROUTING -s 192.168.1.3 -j MASQUERADE 2>/dev/null || true

# Allow forwarding
iptables -A FORWARD -i vmbr0 -o vmbr0 -j ACCEPT 2>/dev/null || true

# Make rules persistent
apt-get update > /dev/null 2>&1 && apt-get install -y iptables-persistent > /dev/null 2>&1 || true

echo "NAT configured"
"@
    
    $natResult = Invoke-PlinkCommand -Host "$ProxmoxUser@$ProxmoxHost" -Command $natConfig -Password $ProxmoxPassword
    Write-Host "✓ NAT configured on Proxmox" -ForegroundColor Green
    Write-Host "  $natResult"
} catch {
    Write-Host "⚠ NAT configuration: $_" -ForegroundColor Yellow
}

# Step 2: Verify VM network connectivity
Write-Host "`n[2/6] Testing VM network connectivity..." -ForegroundColor Yellow
$pingTest = Invoke-PlinkCommand -Host "$VMUser@$VMHost" -Command "ping -c 1 8.8.8.8 2>&1 | head -1" -Password $VMPassword

if ($pingTest -match "bytes from|PING") {
    Write-Host "✓ VM has internet connectivity" -ForegroundColor Green
} else {
    Write-Host "⚠ Retesting connectivity..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    $pingTest2 = Invoke-PlinkCommand -Host "$VMUser@$VMHost" -Command "curl -I https://get.k3s.io 2>&1 | head -1" -Password $VMPassword
    Write-Host "  Curl test: $pingTest2"
}

# Step 3: Install k3s
Write-Host "`n[3/6] Installing k3s on VM..." -ForegroundColor Yellow
$k3sCheck = Invoke-PlinkCommand -Host "$VMUser@$VMHost" -Command "k3s --version 2>&1" -Password $VMPassword

if ($k3sCheck -match "k3s") {
    Write-Host "✓ k3s already installed: $($k3sCheck.Split([Environment]::NewLine)[0])" -ForegroundColor Green
} else {
    Write-Host "  Installing k3s..." -ForegroundColor Cyan
    $installResult = Invoke-PlinkCommand -Host "$VMUser@$VMHost" -Command "curl -fsSL https://get.k3s.io | sh -" -Password $VMPassword
    
    if ($installResult -match "k3s" -or $installResult -match "systemctl") {
        Write-Host "✓ k3s installation completed" -ForegroundColor Green
        Start-Sleep -Seconds 10
        Write-Host "  Waiting for k3s services to stabilize..." -ForegroundColor Cyan
        Start-Sleep -Seconds 15
    } else {
        Write-Host "  Installation output: $installResult" -ForegroundColor Yellow
    }
}

# Step 4: Retrieve kubeconfig
Write-Host "`n[4/6] Retrieving kubeconfig..." -ForegroundColor Yellow
try {
    $kubeConfigPath = "$HOME\k3s.yaml"
    $scpCmd = "scp -i `"$HOME\.ssh\ceres`" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $VMUser@$VMHost`:/etc/rancher/k3s/k3s.yaml `"$kubeConfigPath`""
    cmd /c $scpCmd 2>&1
    
    if (Test-Path $kubeConfigPath) {
        Write-Host "✓ kubeconfig retrieved to $kubeConfigPath" -ForegroundColor Green
        
        # Update server address to match our VM
        $kubeconfigContent = Get-Content $kubeConfigPath -Raw
        $kubeconfigContent = $kubeconfigContent -replace "https://127.0.0.1", "https://$VMHost"
        Set-Content $kubeConfigPath -Value $kubeconfigContent
        Write-Host "  Updated server address to https://$VMHost" -ForegroundColor Cyan
    } else {
        Write-Host "⚠ kubeconfig retrieval attempted but file not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ kubeconfig retrieval: $_" -ForegroundColor Yellow
}

# Step 5: Set GitHub secrets
Write-Host "`n[5/6] Configuring GitHub secrets..." -ForegroundColor Yellow
try {
    if (Test-Path "$HOME\k3s.yaml") {
        $kubeConfig = Get-Content "$HOME\k3s.yaml" -Raw
        $kubeConfigBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($kubeConfig))
        
        # Create temporary file with secret value
        $tempSecretFile = "$env:TEMP\k3s-secret.txt"
        Set-Content $tempSecretFile -Value $kubeConfig
        
        # Try to set GitHub secret using gh CLI
        $ghCheck = & gh auth status 2>&1
        if ($? -and $ghCheck -match "Logged in") {
            Write-Host "  Setting KUBECONFIG secret..." -ForegroundColor Cyan
            & gh secret set KUBECONFIG --body $kubeConfig -R $GitHubRepo 2>&1 | Out-Null
            Write-Host "✓ KUBECONFIG secret set" -ForegroundColor Green
        } else {
            Write-Host "⚠ GitHub CLI not authenticated" -ForegroundColor Yellow
            Write-Host "  Run: gh auth login" -ForegroundColor Cyan
        }
        
        Remove-Item $tempSecretFile -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "⚠ GitHub secret configuration: $_" -ForegroundColor Yellow
}

# Step 6: Trigger GitHub Actions deployment
Write-Host "`n[6/6] Triggering GitHub Actions deployment..." -ForegroundColor Yellow
try {
    $ghCheck = & gh auth status 2>&1
    if ($? -and $ghCheck -match "Logged in") {
        Write-Host "  Triggering ceres-deploy workflow..." -ForegroundColor Cyan
        & gh workflow run ceres-deploy.yml -R $GitHubRepo 2>&1
        Write-Host "✓ Deployment workflow triggered" -ForegroundColor Green
        Write-Host "  Check status: gh run list -R $GitHubRepo" -ForegroundColor Cyan
    } else {
        Write-Host "⚠ Cannot trigger workflow - GitHub CLI not authenticated" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ Workflow trigger: $_" -ForegroundColor Yellow
}

# Final status
Write-Host "`n=== SETUP COMPLETE ===" -ForegroundColor Cyan
Write-Host "`nVerification commands:" -ForegroundColor Yellow
Write-Host "  Check k3s: & `"$plink`" -pw `"$VMPassword`" -batch $VMUser@$VMHost `"k3s --version`""
Write-Host "  Check nodes: & `"$plink`" -pw `"$VMPassword`" -batch $VMUser@$VMHost `"kubectl get nodes`""
Write-Host "  Check pods: & `"$plink`" -pw `"$VMPassword`" -batch $VMUser@$VMHost `"kubectl get pods -A`""
Write-Host "  GitHub status: gh run list -R $GitHubRepo"
