# FluxCD Bootstrap Script for CERES (PowerShell)

param(
    [string]$GitHubUser = "skulesh01",
    [string]$GitHubRepo = "Ceres",
    [string]$ClusterName = "production"
)

Write-Host "🚀 Bootstrapping FluxCD for CERES" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "GitHub User: $GitHubUser"
Write-Host "Repository: $GitHubRepo"
Write-Host "Cluster: $ClusterName"
Write-Host ""

# Check prerequisites
$commands = @('kubectl', 'flux')
foreach ($cmd in $commands) {
    if (!(Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Host "❌ $cmd is required but not installed." -ForegroundColor Red
        exit 1
    }
}

# Check cluster connectivity
Write-Host "✓ Checking Kubernetes cluster connectivity..." -ForegroundColor Green
try {
    kubectl cluster-info | Out-Null
} catch {
    Write-Host "❌ Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}

# Bootstrap Flux
Write-Host "✓ Bootstrapping FluxCD..." -ForegroundColor Green
flux bootstrap github `
    --owner="$GitHubUser" `
    --repository="$GitHubRepo" `
    --branch=main `
    --path="./flux/clusters/$ClusterName" `
    --personal `
    --components-extra=image-reflector-controller,image-automation-controller

# Wait for Flux
Write-Host "✓ Waiting for FluxCD to be ready..." -ForegroundColor Green
kubectl wait --for=condition=ready --timeout=5m `
    -n flux-system `
    kustomization/flux-system

# Create namespace
Write-Host "✓ Creating CERES namespace..." -ForegroundColor Green
kubectl create namespace ceres --dry-run=client -o yaml | kubectl apply -f -

kubectl label namespace ceres `
    monitoring=enabled `
    --overwrite

Write-Host ""
Write-Host "✅ FluxCD Bootstrap Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Check status:"
Write-Host "  flux get sources git"
Write-Host "  flux get kustomizations"
Write-Host "  kubectl -n ceres-system get all"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Commit your changes to Git"
Write-Host "  2. Flux will automatically sync and deploy CERES"
Write-Host "  3. Monitor with: flux logs --follow"
