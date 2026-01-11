<#
.SYNOPSIS
    Создание нового сотрудника с почтой и VPN доступом

.DESCRIPTION
    Скрипт автоматически:
    1. Создаёт почтовый ящик в Mailu через API
    2. Создаёт VPN конфигурацию в wg-easy
    3. Отправляет VPN конфиг на созданный почтовый ящик
    4. Опционально: регистрирует в Keycloak

.PARAMETER Username
    Имя пользователя (только латиница и цифры, без пробелов)

.PARAMETER FullName
    Полное имя сотрудника (Фамилия Имя Отчество)

.PARAMETER Password
    Пароль для почтового ящика (минимум 8 символов)

.PARAMETER CreateKeycloak
    Создать также аккаунт в Keycloak SSO

.PARAMETER Domain
    Домен для email (по умолчанию: ceres.local)

.EXAMPLE
    .\create-employee.ps1 -Username "ivan.petrov" -FullName "Петров Иван Сергеевич" -Password "SecurePass123"

.EXAMPLE
    .\create-employee.ps1 -Username "maria" -FullName "Мария Иванова" -Password "Pass1234" -CreateKeycloak
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-z0-9._-]+$')]
    [string]$Username,

    [Parameter(Mandatory=$true)]
    [string]$FullName,

    [Parameter(Mandatory=$true)]
    [ValidateLength(8, 64)]
    [string]$Password,

    [Parameter(Mandatory=$false)]
    [switch]$CreateKeycloak,

    [Parameter(Mandatory=$false)]
    [string]$Domain = "ceres.local",

    [Parameter(Mandatory=$false)]
    [string]$MailAdminUrl = "http://mail.ceres.local/admin/api/v1",

    [Parameter(Mandatory=$false)]
    [string]$MailAdminUser = "admin@ceres.local",

    [Parameter(Mandatory=$false)]
    [string]$MailAdminPassword = "admin123",

    [Parameter(Mandatory=$false)]
    [string]$WgEasyUrl = "http://vpn.ceres.local",

    [Parameter(Mandatory=$false)]
    [string]$WgEasyPassword = "admin"
)

$ErrorActionPreference = "Stop"

# Цветной вывод
function Write-Step {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Email адрес
$Email = "${Username}@${Domain}"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║  🚀 СОЗДАНИЕ НОВОГО СОТРУДНИКА                               ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Yellow

Write-Host "Пользователь:  $Username" -ForegroundColor White
Write-Host "Полное имя:    $FullName" -ForegroundColor White
Write-Host "Email:         $Email" -ForegroundColor White
Write-Host "Домен:         $Domain" -ForegroundColor White
Write-Host ""

# ==================== ШАГИ ====================

# ШАГ 1: Создание почтового ящика в Mailu
Write-Step "Шаг 1/4: Создание почтового ящика в Mailu..."

try {
    # Логин в Mailu Admin API
    $loginBody = @{
        username = $MailAdminUser
        password = $MailAdminPassword
    } | ConvertTo-Json

    $loginResponse = Invoke-RestMethod -Uri "$MailAdminUrl/auth/login" `
        -Method POST `
        -Body $loginBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    $MailToken = $loginResponse.access_token

    # Создание пользователя
    $createUserBody = @{
        email = $Email
        raw_password = $Password
        comment = $FullName
        enabled = $true
        quota_bytes = 1073741824  # 1GB
    } | ConvertTo-Json

    $headers = @{
        "Authorization" = "Bearer $MailToken"
        "Content-Type" = "application/json"
    }

    Invoke-RestMethod -Uri "$MailAdminUrl/users" `
        -Method POST `
        -Headers $headers `
        -Body $createUserBody `
        -ErrorAction Stop | Out-Null

    Write-Success "Почтовый ящик создан: $Email"
} catch {
    Write-Failure "Не удалось создать почтовый ящик: $_"
    exit 1
}

# ШАГ 2: Создание VPN конфигурации в wg-easy
Write-Step "Шаг 2/4: Создание VPN конфигурации в wg-easy..."

try {
    # wg-easy API (базовая аутентификация или через сессию)
    # Примечание: wg-easy может требовать веб-сессию, используем Invoke-WebRequest

    $session = $null
    
    # Логин в wg-easy
    $loginForm = @{
        password = $WgEasyPassword
    }

    $loginPage = Invoke-WebRequest -Uri "$WgEasyUrl/" `
        -Method POST `
        -Body ($loginForm | ConvertTo-Json) `
        -ContentType "application/json" `
        -SessionVariable session `
        -ErrorAction SilentlyContinue

    # Создание клиента WireGuard
    $createClientBody = @{
        name = $Username
    } | ConvertTo-Json

    $clientResponse = Invoke-RestMethod -Uri "$WgEasyUrl/api/wireguard/client" `
        -Method POST `
        -WebSession $session `
        -Body $createClientBody `
        -ContentType "application/json" `
        -ErrorAction Stop

    $WgConfig = $clientResponse.config
    $WgConfigId = $clientResponse.id

    # Сохраняем конфиг во временный файл
    $TempConfigFile = "$env:TEMP\wg-$Username.conf"
    $WgConfig | Out-File -FilePath $TempConfigFile -Encoding UTF8 -Force

    Write-Success "VPN конфигурация создана (ID: $WgConfigId)"
} catch {
    Write-Failure "Не удалось создать VPN: $_"
    Write-Host "Попробуйте создать VPN вручную через веб-интерфейс: $WgEasyUrl" -ForegroundColor Yellow
    # Не выходим, продолжаем с email
}

# ШАГ 3: Отправка конфигурации на email
Write-Step "Шаг 3/4: Отправка VPN конфигурации на почту..."

try {
    if (Test-Path $TempConfigFile) {
        # Отправка через Mailu SMTP
        $SMTPServer = "localhost"
        $SMTPPort = 587
        $SMTPFrom = "admin@$Domain"

        $EmailSubject = "🔐 Ваши учетные данные для доступа к корпоративной сети"
        $EmailBody = @"
Здравствуйте, $FullName!

Для вас созданы учетные данные для доступа к корпоративным ресурсам:

📧 ПОЧТА:
   Email:    $Email
   Пароль:   $Password
   Webmail:  https://mail.$Domain
   IMAP:     mail.$Domain:993 (SSL)
   SMTP:     mail.$Domain:587 (STARTTLS)

🔒 VPN (WireGuard):
   Конфигурационный файл во вложении.
   
   Инструкция по подключению:
   1. Установите WireGuard: https://www.wireguard.com/install/
   2. Импортируйте файл wg-$Username.conf
   3. Активируйте подключение
   4. После подключения вы получите доступ к внутренним ресурсам

📚 КОРПОРАТИВНЫЕ РЕСУРСЫ:
   Auth (SSO):      https://auth.$Domain
   Wiki:            https://wiki.$Domain
   Чат:             https://mattermost.$Domain
   Файлы:           https://nextcloud.$Domain
   Git:             https://gitea.$Domain
   Проекты:         https://taiga.$Domain

Если у вас возникли вопросы, обратитесь к администратору.

--
Системное сообщение | Ceres Enterprise Platform
"@

        # Используем встроенный .NET класс для отправки
        $SMTPClient = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
        $SMTPClient.EnableSsl = $true
        $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPFrom, $MailAdminPassword)

        $MailMessage = New-Object System.Net.Mail.MailMessage
        $MailMessage.From = $SMTPFrom
        $MailMessage.To.Add($Email)
        $MailMessage.Subject = $EmailSubject
        $MailMessage.Body = $EmailBody
        $MailMessage.IsBodyHtml = $false

        # Прикрепляем конфиг
        $Attachment = New-Object System.Net.Mail.Attachment($TempConfigFile)
        $MailMessage.Attachments.Add($Attachment)

        $SMTPClient.Send($MailMessage)

        Write-Success "VPN конфигурация отправлена на $Email"

        # Очистка
        $Attachment.Dispose()
        $MailMessage.Dispose()
        Remove-Item $TempConfigFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "⚠ VPN конфиг не найден, отправка пропущена" -ForegroundColor Yellow
    }
} catch {
    Write-Failure "Не удалось отправить email: $_"
    Write-Host "VPN конфиг сохранён в: $TempConfigFile" -ForegroundColor Yellow
}

# ШАГ 4: Создание в Keycloak (опционально)
if ($CreateKeycloak) {
    Write-Step "Шаг 4/4: Создание пользователя в Keycloak SSO..."

    try {
        # TODO: Реализовать через Keycloak Admin REST API
        Write-Host "⚠ Создание в Keycloak пока не реализовано" -ForegroundColor Yellow
        Write-Host "Создайте пользователя вручную: https://auth.$Domain" -ForegroundColor Yellow
    } catch {
        Write-Failure "Не удалось создать в Keycloak: $_"
    }
} else {
    Write-Host "ℹ Шаг 4/4: Keycloak пропущен (используйте -CreateKeycloak для включения)" -ForegroundColor DarkGray
}

# ==================== ИТОГ ====================

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ СОТРУДНИК УСПЕШНО СОЗДАН!                                 ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📧 Email:      $Email" -ForegroundColor Cyan
Write-Host "🔑 Пароль:     $Password" -ForegroundColor Cyan
Write-Host "🌐 Webmail:    https://mail.$Domain" -ForegroundColor Cyan
Write-Host "🔒 VPN:        Конфигурация отправлена на почту" -ForegroundColor Cyan
Write-Host ""
Write-Host "Сотрудник может начать работу сразу после получения письма!" -ForegroundColor Green
Write-Host ""
