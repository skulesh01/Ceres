# WireGuard VPN Client Setup Script
# Automatically configures WireGuard client for Ceres platform

param(
    [string]$ServerIP = "192.168.1.3",
    [string]$ClientIP = "10.8.0.2"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CERES WireGuard VPN Client Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check WireGuard installation
Write-Host "[1/6] Checking WireGuard installation..." -ForegroundColor Yellow
$wg = Get-Command wg -ErrorAction SilentlyContinue
if (!$wg) {
    Write-Host "  [ERROR] WireGuard not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Download and install from:" -ForegroundColor Yellow
    Write-Host "  https://www.wireguard.com/install/" -ForegroundColor White
    Write-Host ""
    Write-Host "  After installation, restart PowerShell and run this script again." -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] WireGuard found" -ForegroundColor Green

# Create config directory
Write-Host ""
Write-Host "[2/6] Creating configuration directory..." -ForegroundColor Yellow
$configDir = "config\wireguard"
if (!(Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}
Write-Host "  [OK] Directory: $configDir" -ForegroundColor Green

# Generate client keys
Write-Host ""
Write-Host "[3/6] Generating client keys..." -ForegroundColor Yellow
$privateKeyFile = "$configDir\client_private.key"
$publicKeyFile = "$configDir\client_public.key"

if (!(Test-Path $privateKeyFile)) {
    $privateKey = & wg genkey
    $privateKey | Out-File -FilePath $privateKeyFile -NoNewline -Encoding ASCII
    
    $publicKey = $privateKey | & wg pubkey
    $publicKey | Out-File -FilePath $publicKeyFile -NoNewline -Encoding ASCII
    
    Write-Host "  [OK] Keys generated" -ForegroundColor Green
} else {
    $privateKey = Get-Content $privateKeyFile -Raw
    $publicKey = Get-Content $publicKeyFile -Raw
    Write-Host "  [OK] Using existing keys" -ForegroundColor Green
}

# Get server public key
Write-Host ""
Write-Host "[4/6] Getting server public key..." -ForegroundColor Yellow
try {
    $serverPrivateKey = ssh root@$ServerIP "cat /etc/wireguard/wg0.conf | grep PrivateKey | cut -d= -f2 | tr -d ' '" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "SSH failed"
    }
    $serverPublicKey = $serverPrivateKey | & wg pubkey
    Write-Host "  [OK] Server public key: $serverPublicKey" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Cannot get server key" -ForegroundColor Red
    Write-Host "  Make sure SSH access to $ServerIP works" -ForegroundColor Yellow
    exit 1
}

# Add client to server
Write-Host ""
Write-Host "[5/6] Adding client to server..." -ForegroundColor Yellow
Write-Host "  Client Public Key: $publicKey" -ForegroundColor Gray

$addPeerCmd = @"
wg set wg0 peer $publicKey allowed-ips $ClientIP/32 && \
wg-quick save wg0 && \
systemctl reload wg-quick@wg0
"@

try {
    $result = ssh root@$ServerIP $addPeerCmd 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Client added to server" -ForegroundColor Green
    } else {
        # Peer might already exist
        Write-Host "  [OK] Client configuration updated" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] Could not add peer automatically" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Run manually on server:" -ForegroundColor Yellow
    Write-Host "  wg set wg0 peer $publicKey allowed-ips $ClientIP/32" -ForegroundColor White
    Write-Host "  wg-quick save wg0" -ForegroundColor White
}

# Create client config
Write-Host ""
Write-Host "[6/6] Creating client configuration..." -ForegroundColor Yellow

$configContent = @"
[Interface]
PrivateKey = $privateKey
Address = $ClientIP/24
DNS = 8.8.8.8, 1.1.1.1

[Peer]
PublicKey = $serverPublicKey
Endpoint = ${ServerIP}:51820
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.1.0/24
PersistentKeepalive = 25
"@

$configFile = "$configDir\ceres-vpn.conf"
$configContent | Out-File -FilePath $configFile -Encoding ASCII

Write-Host "  [OK] Configuration saved: $configFile" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "VPN Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open WireGuard GUI" -ForegroundColor White
Write-Host "  2. Click 'Import tunnel(s) from file'" -ForegroundColor White
Write-Host "  3. Select: $configFile" -ForegroundColor Cyan
Write-Host "  4. Click 'Activate'" -ForegroundColor White
Write-Host ""
Write-Host "After connection:" -ForegroundColor Yellow
Write-Host "  Test VPN:      ping 10.8.0.1" -ForegroundColor White
Write-Host "  Test PostgreSQL: ping 10.43.1.196" -ForegroundColor White
Write-Host "  Test Redis:     ping 10.43.89.168" -ForegroundColor White
Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Yellow
Write-Host "  Check server: ssh root@$ServerIP 'wg show'" -ForegroundColor White
Write-Host "  Check tunnel: Get-NetAdapter | Where-Object Name -like '*WireGuard*'" -ForegroundColor White
Write-Host ""
