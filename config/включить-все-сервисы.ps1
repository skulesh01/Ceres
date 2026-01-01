# Enable all Ceres services (Kubernetes)
# Windows PowerShell 5.1 compatible (ASCII-only file content)

param(
    [switch]$SkipValidation,
    [switch]$SkipK8s,
    [switch]$OnlyArgoCD
)

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status {
    param([string]$Message, [bool]$Ok)
    $prefix = if ($Ok) { "OK" } else { "FAIL" }
    $color = if ($Ok) { "Green" } else { "Red" }
    Write-Host ("{0} | {1}" -f $prefix, $Message) -ForegroundColor $color
}

function Test-Command {
    param([string]$Name)
    try {
        return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

Write-Header "CERES - ENABLE ALL SERVICES"

if (-not (Test-Command "kubectl")) {
    Write-Status "kubectl not found" $false
    exit 1
}

# Step 1: Validation
if (-not $SkipValidation) {
    Write-Header "STEP 1: VALIDATE"
    $validatePath = Join-Path $PSScriptRoot "validate-deployment.ps1"
    if (Test-Path -LiteralPath $validatePath) {
        & $validatePath
        Write-Status "Validation script executed" $true
    } else {
        Write-Status "validate-deployment.ps1 not found" $false
        exit 1
    }
}

# Step 2: Cluster reachability
Write-Header "STEP 2: CLUSTER CHECK"
$k8sReachable = $false
try {
    & kubectl cluster-info 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $k8sReachable = $true
    }
} catch {
    $k8sReachable = $false
}
Write-Status "Kubernetes cluster reachable" $k8sReachable

if (-not $k8sReachable -and $SkipK8s) {
    Write-Status "Cluster not reachable and -SkipK8s specified" $false
    exit 1
}

if (-not $k8sReachable -and -not $SkipK8s) {
    $deploy = Read-Host "Cluster not reachable. Run QUICK_K8S_DEPLOY.ps1 now? (y/n)"
    if ($deploy -ne "y") {
        Write-Status "Cannot continue without a cluster" $false
        exit 1
    }

    $quickDeploy = Join-Path $PSScriptRoot "QUICK_K8S_DEPLOY.ps1"
    if (-not (Test-Path -LiteralPath $quickDeploy)) {
        Write-Status "QUICK_K8S_DEPLOY.ps1 not found" $false
        exit 1
    }

    & $quickDeploy
    Start-Sleep -Seconds 10

    & kubectl cluster-info 2>$null | Out-Null
    $k8sReachable = ($LASTEXITCODE -eq 0)
    Write-Status "Cluster reachable after deploy" $k8sReachable
    if (-not $k8sReachable) { exit 1 }
}

# Step 3: Deploy Ceres manifests
if (-not $OnlyArgoCD) {
    Write-Header "STEP 3: DEPLOY CERES"
    $manifestPath = Join-Path $PSScriptRoot "ceres-k8s-manifests.yaml"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-Status "ceres-k8s-manifests.yaml not found" $false
        exit 1
    }

    & kubectl apply -f $manifestPath
    Write-Status "Applied ceres-k8s-manifests.yaml" ($LASTEXITCODE -eq 0)
}

# Step 4: Install ArgoCD
Write-Header "STEP 4: INSTALL ARGOCD"
& kubectl create namespace argocd 2>$null | Out-Null
& kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
Write-Status "ArgoCD manifests applied" ($LASTEXITCODE -eq 0)

# Step 5: Links
Write-Header "STEP 5: NEXT LINKS"
Write-Host "Docs/entry point: f:\\Ceres\\README.md" -ForegroundColor Yellow
Write-Host "Full guide:       f:\\Ceres\\MAIN_GUIDE.md" -ForegroundColor Yellow
Write-Host ""
Write-Host "Port-forward examples (run each in a separate terminal):" -ForegroundColor Cyan
Write-Host "  kubectl port-forward svc/keycloak -n ceres 8080:8080" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/gitea -n ceres 3000:3000" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/grafana -n monitoring 3001:3000" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/prometheus -n monitoring 9090:9090" -ForegroundColor Gray
Write-Host "  kubectl port-forward svc/argocd-server -n argocd 8443:443" -ForegroundColor Gray

Write-Host ""
Write-Status "Done" $true

