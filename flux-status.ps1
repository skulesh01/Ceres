#!/usr/bin/env powershell
# Deploy and check Flux status using plink (auto-password)

param(
    [string]$RemoteHost = $env:DEPLOY_SERVER_IP,
    [string]$RemoteUser = $env:DEPLOY_SERVER_USER,
    [string]$RemotePassword = $env:DEPLOY_SERVER_PASSWORD
)

# Download plink if needed
$plinkPath = "$env:USERPROFILE\plink.exe"

if (-not (Test-Path $plinkPath)) {
    Write-Host "Downloading plink..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" `
        -OutFile $plinkPath -UseBasicParsing -ErrorAction SilentlyContinue
    
    if (-not (Test-Path $plinkPath)) {
        Write-Host "Failed to download plink!" -ForegroundColor Red
        exit 1
    }
}

function Remote-Cmd {
    param([string]$Command)
    & $plinkPath -pw $RemotePassword -batch "$RemoteUser@$RemoteHost" $Command 2>&1
}

Write-Host "Checking HelmReleases..." -ForegroundColor Cyan
Remote-Cmd "kubectl -n ceres get helmrelease -o wide"

Write-Host "`nChecking Pods..." -ForegroundColor Cyan
Remote-Cmd "kubectl -n ceres get pods -o wide"

Write-Host "`nChecking Kustomization..." -ForegroundColor Cyan
Remote-Cmd "kubectl -n flux-system get kustomization ceres-releases -o wide"

Write-Host "`nChecking Events..." -ForegroundColor Cyan
Remote-Cmd "kubectl -n ceres get events --sort-by='.lastTimestamp' | tail -10"

Write-Host "`nDone!" -ForegroundColor Green
