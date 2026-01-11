# Final Installation Script - Direct Server Setup
# Этот скрипт устанавливает Docker и k3s напрямую

param(
    [string]$RemoteHost = "192.168.1.3",
    [string]$RemoteUser = "root",
    [string]$RemotePassword = $env:DEPLOY_SERVER_PASSWORD
)

# Используем PuTTY plink для выполнения команд
$plinkPath = "$HOME\plink.exe"

if (-not (Test-Path $plinkPath)) {
    Write-Host "Downloading plink..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" `
        -OutFile $plinkPath -UseBasicParsing -ErrorAction SilentlyContinue
}

function Run-RemoteCommand {
    param([string]$Command)
    
    Write-Host "  Executing: $Command" -ForegroundColor Gray
    
    # Используем echo и bash чтобы избежать интерактивного режима
    $fullCmd = "bash -c '$Command'"
    $output = & $plinkPath -pw $RemotePassword -batch $RemoteUser@$RemoteHost $fullCmd 2>&1
    
    return $output
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Docker + k3s Installation Script                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Updating package manager..." -ForegroundColor Green
Run-RemoteCommand "apt-get update -qq" | Out-Null
Run-RemoteCommand "apt-get install -y curl wget" | Out-Null
Write-Host "  ✓ Done" -ForegroundColor Green

Write-Host "[2/4] Installing Docker..." -ForegroundColor Green
$dockerCmd = @"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh -
    systemctl start docker
    systemctl enable docker
    echo 'Docker installed'
else
    echo 'Docker already installed'
fi
"@
Run-RemoteCommand $dockerCmd | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
Write-Host "  ✓ Done" -ForegroundColor Green

Write-Host "[3/4] Installing k3s (this takes 3-5 minutes)..." -ForegroundColor Green
$k3sCmd = @"
if ! command -v k3s &> /dev/null; then
    curl -sfL https://get.k3s.io | sh -
    systemctl restart k3s || true
    echo 'k3s installed'
else
    echo 'k3s already installed'
fi
"@
Run-RemoteCommand $k3sCmd | ForEach-Object { Write-Host "  $_" }
Write-Host "  ✓ Done" -ForegroundColor Green

Write-Host "[4/4] Verifying installation..." -ForegroundColor Green
Write-Host ""

$verifyCmd = "docker --version && echo '---' && k3s --version && echo '---' && kubectl get nodes"
$verify = Run-RemoteCommand $verifyCmd
Write-Host $verify

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✓ Installation Complete!                             ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Получить kubeconfig
Write-Host "Retrieving kubeconfig..." -ForegroundColor Cyan
$kubeCmd = "cat /etc/rancher/k3s/k3s.yaml"
$kubeContent = Run-RemoteCommand $kubeCmd

if ($kubeContent -match "apiVersion") {
    $kubeContent | Out-File "$HOME\k3s.yaml" -Encoding UTF8
    Write-Host "✓ kubeconfig saved to $HOME\k3s.yaml" -ForegroundColor Green
    
    # Encode to base64
    $kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeContent))
    $kubeB64 | Out-File "$HOME\kubeconfig.b64" -NoNewline -Encoding ASCII
    Write-Host "✓ Base64 version saved to $HOME\kubeconfig.b64" -ForegroundColor Green
}

Write-Host ""
Write-Host "Installation successful!" -ForegroundColor Green
