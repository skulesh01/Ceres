<#
.SYNOPSIS
    Полный скрипт для добавления нового сотрудника:
    1. Создание VPN конфигурации
    2. Отправка email с инструкциями

.EXAMPLE
    .\onboard-employee.ps1 -Username "ivan.petrov" -FullName "Иван Петров" -Email "ivan@company.com" -EmailSmtpServer "smtp.gmail.com"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$FullName,

    [Parameter(Mandatory=$true)]
    [string]$Email,

    [Parameter(Mandatory=$false)]
    [string]$WgServerIp = "192.168.1.3",

    [Parameter(Mandatory=$false)]
    [string]$WgServerPort = "51820",

    [Parameter(Mandatory=$false)]
    [string]$EmailSmtpServer = "192.168.1.3",

    [Parameter(Mandatory=$false)]
    [int]$EmailSmtpPort = 25,

    [Parameter(Mandatory=$false)]
    [switch]$EmailUseSsl = $false,

    [Parameter(Mandatory=$false)]
    [string]$EmailSmtpUser,

    [Parameter(Mandatory=$false)]
    [string]$EmailSmtpPassword,

    [Parameter(Mandatory=$false)]
    [string]$EmailFrom = "admin@ceres.local",

    [Parameter(Mandatory=$false)]
    [string]$SshPassword = "!r0oT3dc",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\vpn-configs"
)

$ErrorActionPreference = "Stop"

function Write-Success { param([string]$msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Info { param([string]$msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }
function Write-Step { param([string]$msg) Write-Host "▶️  $msg" -ForegroundColor Yellow }
function Write-Error_ { param([string]$msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Warn { param([string]$msg) Write-Host "⚠️  $msg" -ForegroundColor DarkYellow }

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║      🚀 ДОБАВЛЕНИЕ НОВОГО СОТРУДНИКА                  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Info "Пользователь: $Username"
Write-Info "ФИО: $FullName"
Write-Info "Email: $Email"
Write-Info "VPN Сервер: $WgServerIp:$WgServerPort`n"

# Создаём директорию для конфигов
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
    Write-Success "Создана директория: $OutputPath"
}

# ==================== ШАГ 1: СОЗДАНИЕ VPN КОНФИГА ====================

Write-Step "Шаг 1/3: Создание VPN конфигурации..."

try {
    $plink = ".\plink.exe"
    if (-not (Test-Path $plink)) {
        Write-Error_ "plink.exe не найден!"
        exit 1
    }

    # Bash скрипт для генерации на сервере
    $bashScript = @'
#!/bin/bash
set -e

    command -v wg >/dev/null 2>&1 || { echo "wg not found" >&2; exit 1; }
    ip link show wg0 >/dev/null 2>&1 || { echo "wg0 interface not found" >&2; exit 1; }

# Генерируем ключи
PRIV=$(wg genkey)
PUB=$(echo "$PRIV" | wg pubkey)

# Получаем последний использованный IP устойчивым способом
LAST_IP=$(wg show wg0 allowed-ips | awk '{print $3}' | awk -F'/' '{print $1}' | awk -F'.' '{print $4}' | sort -n | tail -1)
if [ -z "$LAST_IP" ] || [ "$LAST_IP" = "0" ]; then
    LAST_IP=1
fi
NEXT_IP=$((LAST_IP + 1))
CLIENT_IP="10.8.0.$NEXT_IP"

# Добавляем peer на сервер
wg set wg0 peer "$PUB" allowed-ips "$CLIENT_IP/32"
wg-quick save wg0 2>/dev/null || true

# Получаем публичный ключ сервера
SERVER_PUB=$(wg show wg0 public-key)

# Выводим результаты
echo "===BEGIN_CONFIG==="
echo "[Interface]"
echo "PrivateKey = $PRIV"
echo "Address = $CLIENT_IP/24"
echo "DNS = 1.1.1.1"
echo ""
echo "[Peer]"
echo "PublicKey = $SERVER_PUB"
echo "Endpoint = ENDPOINT_PLACEHOLDER"
echo "AllowedIPs = 10.8.0.0/24"
echo "PersistentKeepalive = 25"
echo "===END_CONFIG==="
echo "CLIENT_IP=$CLIENT_IP"
'@

    # Заменяем плейсхолдер
    $bashScript = $bashScript.Replace("ENDPOINT_PLACEHOLDER", "$WgServerIp:$WgServerPort")

    # Выполняем на сервере
    $result = & $plink -pw $SshPassword -batch root@$WgServerIp $bashScript 2>&1 | Out-String

    # Парсим результат
    if ($result -match "===BEGIN_CONFIG===(.*?)===END_CONFIG===") {
        $config = $matches[1].Trim()
        
        # Извлекаем IP
        if ($result -match "CLIENT_IP=(.+)") {
            $clientIp = $matches[1].Trim()
            Write-Success "VPN конфигурация создана: $clientIp"
        }
        
        # Сохраняем локально
        $configFile = Join-Path $OutputPath "$Username.conf"
        $config | Out-File -FilePath $configFile -Encoding UTF8 -Force
        Write-Success "Конфиг сохранён: $configFile"
        
    } else {
        Write-Error_ "Не удалось создать конфиг"
        Write-Host $result
        exit 1
    }

} catch {
    Write-Error_ "Ошибка при создании VPN: $_"
    exit 1
}

# ==================== ШАГ 2: ПОДГОТОВКА ПИСЬМА ====================

Write-Step "Шаг 2/3: Подготовка письма..."

$configContent = Get-Content $configFile -Raw

$emailBody = @"
Здравствуйте, $FullName!

Для вас созданы учетные данные для доступа к корпоративной сети Ceres.

🔒 VPN (WIREGUARD)
Конфигурационный файл во вложении: $Username.conf

Инструкция по подключению:
1. Скачайте WireGuard для вашей ОС: https://www.wireguard.com/install/
2. Импортируйте файл $Username.conf
3. Активируйте подключение
4. Проверьте доступ к внутренним ресурсам

📚 КОРПОРАТИВНЫЕ РЕСУРСЫ (доступны через VPN):
   • Wiki:        https://wiki.ceres.local
   • Чат:         https://mattermost.ceres.local
   • Файлы:       https://nextcloud.ceres.local
   • Git:         https://gitea.ceres.local
   • Проекты:     https://taiga.ceres.local

⚙️ РЕКОМЕНДАЦИИ:
   • Используйте VPN при подключении снаружи корпоративной сети
   • Сохраняйте конфиг в безопасном месте
   • Если потеряли конфиг, обратитесь к администратору

При возникновении вопросов обращайтесь в служу поддержки.

--
Ceres Enterprise Platform
Автоматическое сообщение
"@

Write-Success "Письмо подготовлено"

# ==================== ШАГ 3: ОТПРАВКА EMAIL ====================

Write-Step "Шаг 3/3: Отправка email..."

try {
    $smtpClient = New-Object System.Net.Mail.SmtpClient($EmailSmtpServer, $EmailSmtpPort)
    $smtpClient.EnableSsl = [bool]$EmailUseSsl
    
    $mailMessage = New-Object System.Net.Mail.MailMessage
    $mailMessage.From = $EmailFrom
    $mailMessage.To.Add($Email)
    $mailMessage.Subject = "🔐 Ваши учетные данные для доступа к корпоративной сети"
    $mailMessage.Body = $emailBody
    $mailMessage.IsBodyHtml = $false

    if ($EmailSmtpUser -and $EmailSmtpPassword) {
        $smtpClient.Credentials = New-Object System.Net.NetworkCredential($EmailSmtpUser, $EmailSmtpPassword)
    }

    # Прикрепляем конфиг
    $attachment = New-Object System.Net.Mail.Attachment($configFile)
    $mailMessage.Attachments.Add($attachment)

    $smtpClient.Send($mailMessage)
    Write-Success "Email отправлен на $Email"

    $attachment.Dispose()
    $mailMessage.Dispose()
    $smtpClient.Dispose()

} catch {
    Write-Error_ "Не удалось отправить email: $_"
    Write-Host "Но конфиг файл сохранён: $configFile" -ForegroundColor Yellow
    Write-Host "Отправьте его вручную сотруднику" -ForegroundColor Yellow
}

# ==================== ИТОГ ====================

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ СОТРУДНИК УСПЕШНО ДОБАВЛЕН!                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Info "Имя: $FullName ($Username)"
Write-Info "Email: $Email"
Write-Info "VPN IP: 10.8.0.x"
Write-Info "Конфиг: $configFile"

Write-Host "`n📋 СЛЕДУЮЩИЕ ШАГИ:`n" -ForegroundColor Cyan
Write-Host "1. Сотрудник получит письмо на $Email" -ForegroundColor White
Write-Host "2. Сотрудник скачает и импортирует $Username.conf в WireGuard" -ForegroundColor White
Write-Host "3. После активации VPN сотрудник получит доступ к сети" -ForegroundColor White
Write-Host "`n✅ ВСЁ ГОТОВО!`n" -ForegroundColor Green
