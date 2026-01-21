# CERES Platform - Deploy without local build
# Uses remote kubectl/helm to deploy to K3s cluster

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CERES Platform - Remote Deploy to K3s" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$PROXMOX_IP = "192.168.1.3"
$PROXMOX_USER = "root"
$NAMESPACE = "ceres"

Write-Host "[1/7] Checking Proxmox connection..." -ForegroundColor Cyan
$ping = Test-Connection -ComputerName $PROXMOX_IP -Count 1 -Quiet
if (!$ping) {
    Write-Host "[ERROR] Proxmox server not reachable at $PROXMOX_IP" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Proxmox online" -ForegroundColor Green

Write-Host ""
Write-Host "[2/7] Copying kubeconfig from Proxmox..." -ForegroundColor Cyan
$kubeconfigPath = "$env:USERPROFILE\.kube"
if (!(Test-Path $kubeconfigPath)) {
    New-Item -ItemType Directory -Path $kubeconfigPath | Out-Null
}

$ErrorActionPreference = "Continue"
$sshCmd = "cat /etc/rancher/k3s/k3s.yaml"
$kubeconfig = & cmd /c "echo. | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL $PROXMOX_USER@$PROXMOX_IP `"$sshCmd`" 2>NUL"
$ErrorActionPreference = "Stop"

if (!$kubeconfig) {
    Write-Host "[ERROR] Failed to get kubeconfig" -ForegroundColor Red
    exit 1
}

$kubeconfig = $kubeconfig -join "`n"
$kubeconfig = $kubeconfig -replace "127.0.0.1", $PROXMOX_IP
$kubeconfig | Out-File "$kubeconfigPath\config" -Encoding UTF8 -Force
Write-Host "[OK] Kubeconfig copied to $kubeconfigPath\config" -ForegroundColor Green

Write-Host ""
Write-Host "[3/7] Checking kubectl..." -ForegroundColor Cyan
$kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
if (!$kubectl) {
    Write-Host "[WARN] kubectl not found - installing..." -ForegroundColor Yellow
    $kubectlUrl = "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"
    if (!(Test-Path "bin")) {
        New-Item -ItemType Directory -Path "bin" | Out-Null
    }
    Invoke-WebRequest -Uri $kubectlUrl -OutFile "bin\kubectl.exe"
    $env:Path += ";$PWD\bin"
    Write-Host "[OK] kubectl installed" -ForegroundColor Green
} else {
    Write-Host "[OK] kubectl found" -ForegroundColor Green
}

Write-Host ""
Write-Host "[4/7] Testing K3s connection..." -ForegroundColor Cyan
$env:KUBECONFIG = "$kubeconfigPath\config"
try {
    $nodes = & kubectl get nodes -o name 2>$null
    Write-Host "[OK] K3s cluster accessible: $nodes" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Cannot connect to K3s cluster" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[5/7] Creating namespaces..." -ForegroundColor Cyan
& kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - 2>$null
& kubectl create namespace "${NAMESPACE}-core" --dry-run=client -o yaml | kubectl apply -f - 2>$null
& kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - 2>$null
Write-Host "[OK] Namespaces ready" -ForegroundColor Green

Write-Host ""
Write-Host "[6/7] Checking Helm..." -ForegroundColor Cyan
$helm = Get-Command helm -ErrorAction SilentlyContinue
if (!$helm) {
    Write-Host "[WARN] Helm not found - install from https://helm.sh/docs/intro/install/" -ForegroundColor Yellow
    Write-Host "[INFO] Continuing without Helm (manual chart deployment needed)" -ForegroundColor Yellow
} else {
    Write-Host "[OK] Helm found" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "[7/7] Adding Helm repositories..." -ForegroundColor Cyan
    & helm repo add bitnami https://charts.bitnami.com/bitnami 2>$null
    & helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>$null
    & helm repo add jetstack https://charts.jetstack.io 2>$null
    & helm repo update 2>$null
    Write-Host "[OK] Helm repos ready" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "[OK] CERES Platform Ready for Deploy" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Cluster Info:" -ForegroundColor Cyan
& kubectl cluster-info
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy services: kubectl apply -f deployment/" -ForegroundColor White
Write-Host "  2. Check status:    kubectl get pods -n $NAMESPACE" -ForegroundColor White
if ($helm) {
    Write-Host "  3. Install charts:  helm install postgresql bitnami/postgresql -n $NAMESPACE" -ForegroundColor White
}
Write-Host ""
