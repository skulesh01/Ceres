# Build CERES CLI using Docker (no local Go required)

$ErrorActionPreference = "Stop"

Write-Host "🐳 Building CERES CLI using Docker..." -ForegroundColor Cyan
Write-Host ""

# Check if Docker is installed
$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue

if (-not $dockerCommand) {
    Write-Host "❌ Docker is not installed!" -ForegroundColor Red
    Write-Host "Please install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
    exit 1
}

# Navigate to project root
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

# Build the Docker image
Write-Host "📦 Building Docker image..." -ForegroundColor Cyan
docker build -t ceres-builder:latest --target builder .

Write-Host ""
Write-Host "🏗️  Extracting binaries..." -ForegroundColor Cyan

# Create bin directory if it doesn't exist
if (-not (Test-Path "bin")) {
    New-Item -ItemType Directory -Path "bin" | Out-Null
}

# Run container and copy binaries
$containerId = docker create ceres-builder:latest
docker cp "${containerId}:/build/bin/." ./bin/
docker rm $containerId | Out-Null

Write-Host ""
Write-Host "✅ Build complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Available binaries:" -ForegroundColor Cyan
Get-ChildItem -Path bin -File | ForEach-Object {
    Write-Host "  $($_.Name) - $([math]::Round($_.Length / 1MB, 2)) MB" -ForegroundColor Gray
}

Write-Host ""
Write-Host "🚀 Usage:" -ForegroundColor Yellow
Write-Host "  Windows: .\bin\ceres-windows-amd64.exe --help" -ForegroundColor White
Write-Host "  Linux:   ./bin/ceres-linux-amd64 --help" -ForegroundColor White
Write-Host "  macOS:   ./bin/ceres-darwin-amd64 --help" -ForegroundColor White
