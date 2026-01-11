<#
.SYNOPSIS
    Простое создание VPN пользователя
    
.EXAMPLE
    .\add-vpn-user.ps1 -Username "ivan"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Username
)

$plink = ".\plink.exe"
$ServerIP = "192.168.1.3"
$ServerPort = "51820"
$SSHPassword = $env:DEPLOY_SERVER_PASSWORD
$OutputPath = ".\vpn-configs"

# Создаём директорию
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

Write-Host "`n🔒 Создание VPN для: $Username`n" -ForegroundColor Cyan

# Выполняем команды на сервере
& $plink -pw $SSHPassword -batch root@$ServerIP @"
cd /tmp
# Генерация ключей
PRIV=\`$(wg genkey)
PUB=\`$(echo "\$PRIV" | wg pubkey)
# Получаем IP следующего клиента
LAST_IP=\`$(wg show wg0 | grep 'allowed ips' | tail -1 | awk '{print \$3}' | cut -d'/' -f1 | cut -d'.' -f4)
if [ -z "\$LAST_IP" ]; then LAST_IP=1; fi
NEXT_IP=\`$((LAST_IP + 1))
CLIENT_IP="10.8.0.\$NEXT_IP"
# Добавляем peer
wg set wg0 peer "\$PUB" allowed-ips "\$CLIENT_IP/32"
# Получаем публичный ключ сервера
SERVER_PUB=\`$(wg show wg0 public-key)
# Создаём конфиг
cat > /tmp/$Username.conf <<EOFCONF
[Interface]
PrivateKey = \$PRIV
Address = \$CLIENT_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = \$SERVER_PUB
Endpoint = ${ServerIP}:${ServerPort}
AllowedIPs = 10.8.0.0/24
PersistentKeepalive = 25
EOFCONF
cat /tmp/$Username.conf
"@

# Скачиваем конфиг
Write-Host "`nСкачиваем конфиг..." -ForegroundColor Yellow
& $plink -pw $SSHPassword -batch root@$ServerIP "cat /tmp/$Username.conf" | Out-File -FilePath "$OutputPath\$Username.conf" -Encoding UTF8

Write-Host "✅ Готово!" -ForegroundColor Green
Write-Host "   Конфиг: $OutputPath\$Username.conf" -ForegroundColor Cyan
Write-Host ""
