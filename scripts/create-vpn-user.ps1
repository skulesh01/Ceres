<#
.SYNOPSIS
    Создание VPN пользователя напрямую на WireGuard сервере (БЕЗ wg-easy)

.DESCRIPTION
    Скрипт подключается к серверу через SSH и:
    1. Генерирует ключи WireGuard
    2. Создаёт конфигурацию клиента
    3. Добавляет peer на сервер
    4. Сохраняет конфиг локально

.PARAMETER Username
    Имя пользователя (используется в имени файла)

.PARAMETER ServerIP
    IP адрес WireGuard сервера (по умолчанию: 192.168.1.3)

.EXAMPLE
    .\create-vpn-user.ps1 -Username "ivan.petrov"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$false)]
    [string]$ServerIP = "192.168.1.3",

    [Parameter(Mandatory=$false)]
    [string]$ServerPort = "51820",

    [Parameter(Mandatory=$false)]
    [string]$SSHPassword = "!r0oT3dc",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\vpn-configs"
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  🔒 СОЗДАНИЕ VPN ПОЛЬЗОВАТЕЛЯ                            ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Yellow

Write-Host "Пользователь: $Username" -ForegroundColor Cyan
Write-Host "Сервер: ${ServerIP}:${ServerPort}`n" -ForegroundColor Cyan

# Создаём директорию для конфигов
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
    Write-Host "✅ Создана директория: $OutputPath" -ForegroundColor Green
}

# Подключение через plink
$plink = ".\plink.exe"
if (-not (Test-Path $plink)) {
    Write-Host "❌ plink.exe не найден!" -ForegroundColor Red
    exit 1
}

Write-Host "📡 Подключение к серверу..." -ForegroundColor Cyan

# Скрипт для выполнения на сервере
$remoteScript = @'
#!/bin/bash
set -e

# Функция для получения следующего свободного IP
get_next_ip() {
    wg show wg0 | grep 'allowed ips' | awk '{print $3}' | cut -d'/' -f1 | sort -t . -k 4 -n | tail -n1 | awk -F. '{print $1"."$2"."$3"."($4+1)}'
}

# Получаем публичный ключ сервера
SERVER_PUBLIC_KEY=$(wg show wg0 public-key)

# Генерируем ключи клиента
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# Определяем следующий доступный IP
NEXT_IP=$(get_next_ip)
if [ -z "$NEXT_IP" ] || [ "$NEXT_IP" = "10.8.0." ]; then
    NEXT_IP="10.8.0.2"
fi

CLIENT_IP="$NEXT_IP/32"

# Добавляем peer на сервер
wg set wg0 peer "$CLIENT_PUBLIC_KEY" allowed-ips "$CLIENT_IP"

# Сохраняем конфигурацию
wg-quick save wg0 2>/dev/null || true

# Создаём конфиг для клиента
cat > /tmp/wg-USERNAME_PLACEHOLDER.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $NEXT_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = SERVERIP_PLACEHOLDER:SERVERPORT_PLACEHOLDER
AllowedIPs = 10.8.0.0/24
PersistentKeepalive = 25
EOF

# Выводим результат
echo "==CONFIG_START=="
cat /tmp/wg-USERNAME_PLACEHOLDER.conf
echo "==CONFIG_END=="
echo "CLIENT_IP=$NEXT_IP"
echo "CLIENT_PUBLIC_KEY=$CLIENT_PUBLIC_KEY"
'@

# Заменяем плейсхолдеры
$remoteScript = $remoteScript.Replace("USERNAME_PLACEHOLDER", $Username)
$remoteScript = $remoteScript.Replace("SERVERIP_PLACEHOLDER", $ServerIP)
$remoteScript = $remoteScript.Replace("SERVERPORT_PLACEHOLDER", $ServerPort)

# Выполняем скрипт на сервере
Write-Host "🔑 Генерация ключей и создание конфигурации..." -ForegroundColor Yellow

try {
    $result = & $plink -pw $SSHPassword -batch root@$ServerIP $remoteScript 2>&1
    
    # Парсим результат
    $configStart = $result -join "`n" | Select-String -Pattern "==CONFIG_START==(.*)==CONFIG_END==" -AllMatches
    
    if ($configStart.Matches.Count -gt 0) {
        $config = $configStart.Matches[0].Groups[1].Value.Trim()
        
        # Извлекаем IP клиента
        $clientIP = ($result | Select-String -Pattern "CLIENT_IP=(.+)").Matches[0].Groups[1].Value
        $clientPubKey = ($result | Select-String -Pattern "CLIENT_PUBLIC_KEY=(.+)").Matches[0].Groups[1].Value
        
        # Сохраняем конфиг локально
        $configFile = Join-Path $OutputPath "$Username.conf"
        $config | Out-File -FilePath $configFile -Encoding UTF8 -Force
        
        Write-Host "`n✅ VPN пользователь создан!" -ForegroundColor Green
        Write-Host "`n📋 ИНФОРМАЦИЯ:" -ForegroundColor Cyan
        Write-Host "   Имя: $Username" -ForegroundColor White
        Write-Host "   IP: $clientIP" -ForegroundColor White
        Write-Host "   Конфиг: $configFile" -ForegroundColor White
        Write-Host "`n📄 КОНФИГУРАЦИЯ:" -ForegroundColor Cyan
        Write-Host $config -ForegroundColor Gray
        
        Write-Host "`n🎯 СЛЕДУЮЩИЕ ШАГИ:" -ForegroundColor Yellow
        Write-Host "   1. Отправьте файл $configFile пользователю" -ForegroundColor White
        Write-Host "   2. Пользователь должен:" -ForegroundColor White
        Write-Host "      • Установить WireGuard: https://www.wireguard.com/install/" -ForegroundColor Gray
        Write-Host "      • Импортировать конфиг $Username.conf" -ForegroundColor Gray
        Write-Host "      • Активировать подключение" -ForegroundColor Gray
        Write-Host ""
        
    } else {
        Write-Host "❌ Не удалось получить конфигурацию" -ForegroundColor Red
        Write-Host "Вывод сервера:" -ForegroundColor Yellow
        Write-Host $result -ForegroundColor Gray
        exit 1
    }
    
} catch {
    Write-Host "❌ Ошибка: $_" -ForegroundColor Red
    exit 1
}
