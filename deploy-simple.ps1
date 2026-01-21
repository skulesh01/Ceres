# CERES Platform - Complete Deploy
# Deploys PostgreSQL + Redis

$ErrorActionPreference = "Stop"

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "CERES Core - Deployment" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[STEP 1] Setup..." -ForegroundColor Cyan
& ".\remote-deploy.ps1"

Write-Host ""
Write-Host "[STEP 2] Deploy PostgreSQL..." -ForegroundColor Cyan
& kubectl apply -f deployment/postgresql-fixed.yaml
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "[STEP 3] Deploy Redis..." -ForegroundColor Cyan
& kubectl apply -f deployment/redis.yaml
Start-Sleep -Seconds 20

Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
& kubectl get all -n ceres-core
