# CERES Platform - Deploy All Services
# Deploys complete platform with all applications

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CERES Platform - Full Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run basic deployment first
Write-Host "[PHASE 1] Core Infrastructure..." -ForegroundColor Cyan
& ".\deploy-simple.ps1"

Write-Host ""
Write-Host "[PHASE 2] Network & Ingress..." -ForegroundColor Cyan
Write-Host "  [2.1] Deploying Ingress NGINX..." -ForegroundColor White
& kubectl apply -f deployment/ingress-nginx.yaml
Write-Host "  Waiting for Ingress Controller..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
$ingressReady = & kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>$null
if ($ingressReady -eq "True") {
    Write-Host "  [OK] Ingress NGINX ready" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Ingress might still be starting..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[PHASE 3] Applications..." -ForegroundColor Cyan

# Create keycloak database first
Write-Host "  [3.1] Creating Keycloak database..." -ForegroundColor White
$createDB = @"
kubectl exec postgresql-0 -n ceres-core -- bash -c "PGPASSWORD=ceres_postgres_2025 psql -U postgres -h localhost -c 'CREATE DATABASE keycloak;' 2>/dev/null || echo 'Database exists'"
"@
Invoke-Expression $createDB | Out-Null
Write-Host "  [OK] Database ready" -ForegroundColor Green

Write-Host "  [3.2] Deploying Keycloak..." -ForegroundColor White
& kubectl apply -f deployment/keycloak.yaml
Write-Host "  Waiting for Keycloak..." -ForegroundColor Yellow
Start-Sleep -Seconds 60
& kubectl get pods -n ceres | Select-String keycloak
Write-Host "  [OK] Keycloak deployed (may take 2-3 minutes to fully start)" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "[OK] CERES Platform Deployed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Show all services
Write-Host "Deployed Services:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Core Infrastructure (ceres-core):" -ForegroundColor Yellow
& kubectl get all -n ceres-core

Write-Host ""
Write-Host "Applications (ceres):" -ForegroundColor Yellow
& kubectl get all -n ceres

Write-Host ""
Write-Host "Ingress (ingress-nginx):" -ForegroundColor Yellow
& kubectl get all -n ingress-nginx

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Access Information" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get service IPs
$pgIP = & kubectl get svc postgresql -n ceres-core -o jsonpath='{.spec.clusterIP}' 2>$null
$redisIP = & kubectl get svc redis -n ceres-core -o jsonpath='{.spec.clusterIP}' 2>$null
$keycloakIP = & kubectl get svc keycloak -n ceres -o jsonpath='{.spec.clusterIP}' 2>$null
$nodeIP = "192.168.1.3"

Write-Host "Internal Access (ClusterIP):" -ForegroundColor Yellow
Write-Host "  PostgreSQL: ${pgIP}:5432" -ForegroundColor White
Write-Host "  Redis:      ${redisIP}:6379" -ForegroundColor White
Write-Host "  Keycloak:   ${keycloakIP}:8080" -ForegroundColor White
Write-Host ""

Write-Host "External Access (NodePort):" -ForegroundColor Yellow
Write-Host "  Ingress HTTP:  http://${nodeIP}:30080" -ForegroundColor White
Write-Host "  Ingress HTTPS: https://${nodeIP}:30443" -ForegroundColor White
Write-Host ""

Write-Host "Web Applications (через Ingress):" -ForegroundColor Yellow
Write-Host "  Keycloak: http://${nodeIP}:30080 (Host: keycloak.ceres.local)" -ForegroundColor White
Write-Host ""

Write-Host "Credentials:" -ForegroundColor Yellow
Write-Host "  PostgreSQL:" -ForegroundColor Cyan
Write-Host "    User: postgres" -ForegroundColor Gray
Write-Host "    Password: ceres_postgres_2025" -ForegroundColor Gray
Write-Host ""
Write-Host "  Redis:" -ForegroundColor Cyan
Write-Host "    Password: ceres_redis_2025" -ForegroundColor Gray
Write-Host ""
Write-Host "  Keycloak:" -ForegroundColor Cyan
Write-Host "    User: admin" -ForegroundColor Gray
Write-Host "    Password: K3yClo@k!2025" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VPN Access Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "For direct access to services:" -ForegroundColor Yellow
Write-Host "  1. Setup VPN: .\scripts\setup-vpn.ps1" -ForegroundColor White
Write-Host "  2. Import config to WireGuard" -ForegroundColor White
Write-Host "  3. Connect to VPN" -ForegroundColor White
Write-Host "  4. Access services directly via ClusterIP" -ForegroundColor White
Write-Host ""
Write-Host "After VPN connection:" -ForegroundColor Yellow
Write-Host "  PostgreSQL: psql -h ${pgIP} -U postgres" -ForegroundColor White
Write-Host "  Keycloak:   http://keycloak.ceres.local (add to hosts file)" -ForegroundColor White
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  VPN Setup:     docs/VPN_SETUP.md" -ForegroundColor White
Write-Host "  Service Access: docs/ACCESS_SERVICES.md" -ForegroundColor White
Write-Host "  Deployment Plan: DEPLOYMENT_PLAN.md" -ForegroundColor White
Write-Host ""
