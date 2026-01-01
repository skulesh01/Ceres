# Download and setup plink for passwordless SSH automation
# plink allows passing password as argument, unlike OpenSSH

param(
    [string]$PlinkPath = "$HOME\plink.exe",
    [string]$RemoteHost = "192.168.1.3",
    [string]$RemoteUser = "root",
    [string]$RemotePassword = "!r0oT3dc"
)

Write-Host "Downloading plink.exe from PuTTY project..." -ForegroundColor Cyan

if (-not (Test-Path $PlinkPath)) {
    Write-Host "  Downloading..." -ForegroundColor Gray
    try {
        $url = "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe"
        Invoke-WebRequest -Uri $url -OutFile $PlinkPath -ErrorAction Stop
        Write-Host "  ✓ Downloaded to $PlinkPath" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Download failed: $_" -ForegroundColor Red
        Write-Host "  Manual download: https://www.putty.org/" -ForegroundColor Yellow
        exit 1
    }
}
else {
    Write-Host "  ✓ plink.exe already exists" -ForegroundColor Green
}

# Now create a helper function for SSH with password
$helperScript = @'
# Helper function to run SSH commands with plink (supports password)
function Invoke-SSHWithPassword {
    param(
        [string]$Host,
        [string]$User,
        [string]$Password,
        [string]$Command,
        [string]$PlinkPath = "$HOME\plink.exe"
    )
    
    # plink syntax: plink -pw "password" user@host "command"
    & $PlinkPath -pw $Password -batch -o "StrictHostKeyChecking=no" "$User@$Host" $Command
}

# Or use for interactive shell:
function Open-SSHShell {
    param(
        [string]$Host,
        [string]$User,
        [string]$Password,
        [string]$PlinkPath = "$HOME\plink.exe"
    )
    
    & $PlinkPath -pw $Password -o "StrictHostKeyChecking=no" "$User@$Host"
}

# Export functions
Export-ModuleMember -Function Invoke-SSHWithPassword, Open-SSHShell
'@

$modulePath = "$HOME\Documents\PowerShell\Modules\Ceres-SSH"
$moduleName = "Ceres-SSH.psm1"

New-Item -ItemType Directory -Path $modulePath -Force -ErrorAction SilentlyContinue | Out-Null
$helperScript | Out-File "$modulePath\$moduleName" -Encoding UTF8

Write-Host ""
Write-Host "✓ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Usage examples:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Import module:" -ForegroundColor Gray
Write-Host "   Import-Module $modulePath" -ForegroundColor White
Write-Host ""
Write-Host "2. Run command with password:" -ForegroundColor Gray
Write-Host "   Invoke-SSHWithPassword -Host '192.168.1.3' -User 'root' -Password '!r0oT3dc' -Command 'ls -la'" -ForegroundColor White
Write-Host ""
Write-Host "3. Open interactive shell:" -ForegroundColor Gray
Write-Host "   Open-SSHShell -Host '192.168.1.3' -User 'root' -Password '!r0oT3dc'" -ForegroundColor White
Write-Host ""
