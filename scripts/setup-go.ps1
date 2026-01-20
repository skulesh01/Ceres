# Auto-install Go if not present on Windows target system

$ErrorActionPreference = "Stop"

$GO_VERSION = "1.21.6"
$GO_ARCH = "amd64"

Write-Host "🔍 Checking for Go installation..." -ForegroundColor Cyan

$goCommand = Get-Command go -ErrorAction SilentlyContinue

if ($goCommand) {
    $currentVersion = (go version) -replace '.*go(\d+\.\d+\.\d+).*', '$1'
    Write-Host "✅ Go $currentVersion is already installed" -ForegroundColor Green
    
    # Check if version is sufficient (1.21+)
    $requiredVersion = [version]"1.21.0"
    $installedVersion = [version]$currentVersion
    
    if ($installedVersion -ge $requiredVersion) {
        Write-Host "✅ Go version is sufficient" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "⚠️  Go version is too old (required: 1.21+, current: $currentVersion)" -ForegroundColor Yellow
        Write-Host "📥 Updating Go..." -ForegroundColor Cyan
    }
} else {
    Write-Host "❌ Go is not installed" -ForegroundColor Red
    Write-Host "📥 Installing Go $GO_VERSION..." -ForegroundColor Cyan
}

# Download and install Go
$GO_INSTALLER = "go$GO_VERSION.windows-$GO_ARCH.msi"
$GO_URL = "https://go.dev/dl/$GO_INSTALLER"
$TEMP_PATH = "$env:TEMP\$GO_INSTALLER"

Write-Host "📥 Downloading Go from $GO_URL..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $GO_URL -OutFile $TEMP_PATH

Write-Host "📦 Installing Go..." -ForegroundColor Cyan
Start-Process msiexec.exe -ArgumentList "/i `"$TEMP_PATH`" /quiet /norestart" -Wait -NoNewWindow

Remove-Item $TEMP_PATH

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host "✅ Go $GO_VERSION installed successfully!" -ForegroundColor Green
go version

Write-Host ""
Write-Host "🔧 Installing Go dependencies..." -ForegroundColor Cyan
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
go mod download
Write-Host "✅ Dependencies installed!" -ForegroundColor Green

Write-Host ""
Write-Host "🏗️  Building CERES CLI..." -ForegroundColor Cyan
go build -o bin\ceres.exe .\cmd\ceres
Write-Host "✅ CERES CLI built successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Run: .\bin\ceres.exe --help" -ForegroundColor Yellow
