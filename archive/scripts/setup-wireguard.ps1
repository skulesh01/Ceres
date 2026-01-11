#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Настраивает WireGuard VPN на Proxmox VM для удаленного доступа
.DESCRIPTION
    - Генерирует ключи для WireGuard сервера и клиента
    - Настраивает WireGuard на 192.168.1.3
    - Выдает клиентский конфиг для Windows
#>

# ==================== КОНФИГУРАЦИЯ ====================
$ServerIP = "192.168.1.3"
$ServerSSHUser = "root"
$ServerSSHPass = "!r0oT3dc"
$PlinkPath = "$PSScriptRoot\plink.exe"

# Проверяем plink
if (-not (Test-Path $PlinkPath)) {
    Write-Host "⚠️  plink.exe не найден. Скачиваю..." -ForegroundColor Yellow
    $PlinkUrl = "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe"
    Invoke-WebRequest -Uri $PlinkUrl -OutFile $PlinkPath -UseBasicParsing
    Write-Host "✅ plink.exe скачан" -ForegroundColor Green
}

Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   НАСТРОЙКА WIREGUARD VPN" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

# ==================== ГЕНЕРИРУЕМ КЛЮЧИ ====================
Write-Host "🔑 Генерирую WireGuard ключи..." -ForegroundColor Yellow

$setupScript = @"
#!/bin/bash
set -e

# Генерируем ключи
cd /tmp
umask 077

echo "=== Генерирую сервер ключи ==="
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIVATE=\$(cat server_private.key)
SERVER_PUBLIC=\$(cat server_public.key)

echo "=== Генерирую клиент ключи ==="
wg genkey | tee client_private.key | wg pubkey > client_public.key
CLIENT_PRIVATE=\$(cat client_private.key)
CLIENT_PUBLIC=\$(cat client_public.key)

# Выводим ключи
echo "SERVER_PRIVATE=\$SERVER_PRIVATE"
echo "SERVER_PUBLIC=\$SERVER_PUBLIC"
echo "CLIENT_PRIVATE=\$CLIENT_PRIVATE"
echo "CLIENT_PUBLIC=\$CLIENT_PUBLIC"
"@

$keysOutput = & $PlinkPath -pw $ServerSSHPass -batch $ServerSSHUser@$ServerIP $setupScript

Write-Host $keysOutput -ForegroundColor Gray

# Парсим ключи из вывода
$keysData = @{}
foreach ($line in $keysOutput -split "`n") {
    if ($line -match "^(SERVER_|CLIENT_)(PRIVATE|PUBLIC)=(.+)$") {
        $keysData[$matches[1] + $matches[2]] = $matches[3].Trim()
    }
}

$SERVER_PRIVATE = $keysData['SERVER_PRIVATE']
$SERVER_PUBLIC = $keysData['SERVER_PUBLIC']
$CLIENT_PRIVATE = $keysData['CLIENT_PRIVATE']
$CLIENT_PUBLIC = $keysData['CLIENT_PUBLIC']

if (-not $SERVER_PRIVATE) {
    Write-Host "❌ Ошибка: не удалось получить ключи от сервера" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Ключи сгенерированы`n" -ForegroundColor Green
Write-Host "   Публичный ключ сервера: $SERVER_PUBLIC" -ForegroundColor Gray
Write-Host "   Публичный ключ клиента: $CLIENT_PUBLIC`n" -ForegroundColor Gray

# ==================== НАСТРАИВАЕМ WIREGUARD НА СЕРВЕРЕ ====================
Write-Host "⚙️  Настраиваю WireGuard на сервере..." -ForegroundColor Yellow

$wg0Conf = @"
[Interface]
PrivateKey = $SERVER_PRIVATE
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUBLIC
AllowedIPs = 10.8.0.2/32
"@

# Кодируем конфиг в base64 для передачи через SSH
$wg0ConfBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($wg0Conf))

$configScript = @"
#!/bin/bash
set -e

# Проверяем наличие WireGuard
if ! command -v wg &> /dev/null; then
    echo "Устанавливаю WireGuard..."
    apt-get update >/dev/null 2>&1
    apt-get install -y wireguard wireguard-tools >/dev/null 2>&1
fi

# Создаем конфиг
mkdir -p /etc/wireguard
echo "$wg0ConfBase64" | base64 -d > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

# Включаем IP forwarding
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Запускаем WireGuard
systemctl enable wg-quick@wg0 >/dev/null 2>&1
systemctl restart wg-quick@wg0

# Проверяем
sleep 2
wg show

echo "✅ WireGuard настроен и запущен"
"@

& $PlinkPath -pw $ServerSSHPass -batch $ServerSSHUser@$ServerIP $configScript

Write-Host "✅ WireGuard запущен на сервере`n" -ForegroundColor Green

# ==================== СОЗДАЕМ КЛИЕНТСКИЙ КОНФИГ ====================
Write-Host "📝 Создаю клиентский конфиг..." -ForegroundColor Yellow

$clientConf = @"
[Interface]
PrivateKey = $CLIENT_PRIVATE
Address = 10.8.0.2/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = $SERVER_PUBLIC
AllowedIPs = 10.8.0.0/24, 192.168.1.0/24
Endpoint = $($ServerIP):51820
PersistentKeepalive = 25
"@

# Сохраняем конфиг
$clientConfPath = "$PSScriptRoot\wg-client-vpn.conf"
$clientConf | Out-File -FilePath $clientConfPath -Encoding UTF8 -Force

Write-Host "✅ Клиентский конфиг сохранен: $clientConfPath`n" -ForegroundColor Green

# ==================== ИНСТРУКЦИИ ДЛЯ ПОЛЬЗОВАТЕЛЯ ====================
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "   WIREGUARD VPN ГОТОВ К ИСПОЛЬЗОВАНИЮ!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Green

Write-Host "📲 УСТАНОВКА НА WINDOWS:" -ForegroundColor Cyan
Write-Host "   1. Скачайте WireGuard для Windows: https://www.wireguard.com/install/" -ForegroundColor White
Write-Host "   2. Установите приложение" -ForegroundColor White
Write-Host "   3. Откройте файл: $clientConfPath" -ForegroundColor White
Write-Host "   4. WireGuard автоматически импортирует конфиг`n" -ForegroundColor White

Write-Host "🚀 ЗАПУСК:" -ForegroundColor Cyan
Write-Host "   Нажмите 'Activate' в WireGuard или включите в системном трее`n" -ForegroundColor White

Write-Host "✅ ПОСЛЕ ПОДКЛЮЧЕНИЯ:" -ForegroundColor Cyan
Write-Host "   - Вы сможете доступить на 192.168.1.0/24 сеть" -ForegroundColor White
Write-Host "   - Откройте браузер: http://192.168.1.3" -ForegroundColor White
Write-Host "   - Kubernetes услуги доступны через 10.8.0.1 (VPN сервер)`n" -ForegroundColor White

Write-Host "🔍 ПРОВЕРКА:" -ForegroundColor Cyan
Write-Host "   После подключения в консоли:" -ForegroundColor White
Write-Host "   ping 192.168.1.3" -ForegroundColor Gray
Write-Host "   ping 10.8.0.1 (сервер VPN)`n" -ForegroundColor Gray

Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Green

# Сохраняем ключи в файл для справки
$keysFile = "$PSScriptRoot\wg-keys-backup.txt"
@"
=== WireGuard VPN Ключи (Резервная копия) ===
Дата создания: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')

Сервер публичный ключ: $SERVER_PUBLIC
Клиент приватный ключ: $CLIENT_PRIVATE
Сервер IP: $ServerIP
VPN сеть: 10.8.0.0/24

ВНИМАНИЕ: Сохраняйте эти ключи в безопасности!
"@ | Out-File -FilePath $keysFile -Encoding UTF8 -Force

Write-Host "💾 Ключи сохранены: $keysFile`n" -ForegroundColor Gray
Write-Host "Press Enter для выхода..." -ForegroundColor Gray
Read-Host
