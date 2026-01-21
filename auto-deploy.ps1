# CERES Platform - Quick Deploy
# Auto-installs Go and builds CLI

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CERES Platform v3.0.0 - Quick Deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for Go
$goCommand = Get-Command go -ErrorAction SilentlyContinue

if ($goCommand) {
    Write-Host "[OK] Go found: $(go version)" -ForegroundColor Green
} else {
    Write-Host "[WARN] Go not installed" -ForegroundColor Yellow
    Write-Host "Downloading Go 1.21.6..." -ForegroundColor Cyan
    
    $GO_VERSION = "1.21.6"
    $GO_INSTALLER = "go$GO_VERSION.windows-amd64.msi"
    $GO_URL = "https://go.dev/dl/$GO_INSTALLER"
    $TEMP_PATH = "$env:TEMP\$GO_INSTALLER"
    
    Invoke-WebRequest -Uri $GO_URL -OutFile $TEMP_PATH
    Write-Host "Installing Go..." -ForegroundColor Cyan
    Start-Process msiexec.exe -ArgumentList "/i `"$TEMP_PATH`" /quiet /norestart" -Wait -NoNewWindow
    Remove-Item $TEMP_PATH
    
    # Reload PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Verify Go is now available
    $goCommand = Get-Command go -ErrorAction SilentlyContinue
    if (!$goCommand) {
        Write-Host "[ERROR] Go installation failed - please restart PowerShell and run again" -ForegroundColor Red
        Write-Host "Or download manually from: https://go.dev/dl/" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "[OK] Go installed: $(go version)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Downloading dependencies..." -ForegroundColor Cyan
go mod download
go mod tidy

Write-Host ""
Write-Host "Building CERES CLI..." -ForegroundColor Cyan
if (!(Test-Path "bin")) {
    New-Item -ItemType Directory -Path "bin" | Out-Null
}

go build -o bin\ceres.exe .\cmd\ceres

Write-Host ""
Write-Host "[OK] Build complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Validate:  .\bin\ceres.exe validate" -ForegroundColor White
Write-Host "  2. Configure: .\bin\ceres.exe config show" -ForegroundColor White
Write-Host "  3. Deploy:    .\bin\ceres.exe deploy --cloud proxmox" -ForegroundColor White
Write-Host ""
