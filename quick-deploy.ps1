# Quick deployment script for CERES Platform
# Auto-detects environment and chooses best build method

$ErrorActionPreference = "Stop"

Write-Host "🚀 CERES Platform v3.0.0 - Quick Deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Detect if Docker is available
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue

if ($dockerCommand) {
    Write-Host "✅ Docker found - using Docker build" -ForegroundColor Green
    Write-Host "📦 Building CERES CLI with Docker (no Go installation needed)..." -ForegroundColor Cyan
    & ".\scripts\docker-build.ps1"
} else {
    Write-Host "⚠️  Docker not found - using auto-install" -ForegroundColor Yellow
    Write-Host "📥 Installing Go and building CERES CLI..." -ForegroundColor Cyan
    & ".\scripts\setup-go.ps1"
}

Write-Host ""
Write-Host "✅ CERES CLI deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 Next steps:" -ForegroundColor Yellow
Write-Host "  1. Validate: .\bin\ceres.exe validate" -ForegroundColor White
Write-Host "  2. Configure: .\bin\ceres.exe config show" -ForegroundColor White
Write-Host "  3. Deploy: .\bin\ceres.exe deploy --dry-run" -ForegroundColor White
Write-Host ""
