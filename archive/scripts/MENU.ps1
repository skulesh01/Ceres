#Requires -Version 5.1
<#
.SYNOPSIS
    CERES - Главное меню управления
    
.DESCRIPTION
    Интерактивное меню для всех операций с CERES платформой.
    Простой и понятный интерфейс для людей без опыта программирования.
    
.NOTES
    Версия: 1.0
    CERES Team | 2025
#>

# Установка кодировки для корректного отображения русского языка
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "CERES Control Panel"

# Цвета
function Write-Header {
    param([string]$Text)
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║            🚀 CERES - Панель управления                      ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    if ($Text) {
        Write-Host "  $Text" -ForegroundColor Yellow
        Write-Host ""
    }
}

function Write-MenuOption {
    param(
        [string]$Number,
        [string]$Title,
        [string]$Description
    )
    Write-Host "  [$Number] " -ForegroundColor Green -NoNewline
    Write-Host "$Title" -ForegroundColor White
    Write-Host "      $Description" -ForegroundColor Gray
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Text -ForegroundColor Gray
}

function Write-Warning-Custom {
    param([string]$Text)
    Write-Host "⚠ " -ForegroundColor Yellow -NoNewline
    Write-Host $Text -ForegroundColor Yellow
}

function Pause-And-Continue {
    Write-Host ""
    Write-Host "Нажмите любую клавишу для продолжения..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Проверка запуска от администратора
function Test-Administrator {
    $user = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $user.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Главное меню
function Show-MainMenu {
    while ($true) {
        Write-Header
        
        # Статус система
        $proxmoxReachable = Test-Connection -ComputerName "192.168.1.3" -Count 1 -Quiet -ErrorAction SilentlyContinue
        
        Write-Host "  Статус:" -ForegroundColor Gray
        if ($proxmoxReachable) {
            Write-Host "    • Proxmox: " -NoNewline -ForegroundColor Gray
            Write-Host "✓ Доступен" -ForegroundColor Green
        } else {
            Write-Host "    • Proxmox: " -NoNewline -ForegroundColor Gray
            Write-Host "○ Не найден" -ForegroundColor Yellow
        }
        Write-Host ""
        
        Write-Host "  Выберите действие:" -ForegroundColor Cyan
        Write-Host ""
        
        Write-MenuOption "1" "🚀 Установить CERES" "Первый запуск - установка на Proxmox сервер"
        Write-MenuOption "2" "🔧 Настроить доступ" "Добавить домены в hosts файл (после установки)"
        Write-MenuOption "3" "⚙️  Первая настройка" "Пошаговая настройка после установки"
        Write-MenuOption "4" "📊 Проверить статус" "Узнать состояние всех сервисов"
        Write-MenuOption "5" "💾 Создать резервную копию" "Сохранить все данные"
        Write-MenuOption "6" "♻️  Восстановить из копии" "Вернуть данные из резервной копии"
        Write-MenuOption "7" "🧹 Очистка и обслуживание" "Удалить старые данные, освободить место"
        Write-MenuOption "8" "� Проверить систему" "Проверка готовности перед установкой"
        Write-MenuOption "9" "📚 Документация" "Открыть руководства и справочники"
        Write-MenuOption "A" "❓ Помощь и FAQ" "Ответы на частые вопросы"
        Write-MenuOption "0" "🚪 Выход" "Закрыть программу"
        
        Write-Host "══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        $choice = Read-Host "  Введите номер"
        
        switch ($choice) {
            "1" { Install-Ceres }
            "2" { Setup-Access }
            "3" { First-Setup }
            "4" { Check-Status }
            "5" { Create-Backup }
            "6" { Restore-Backup }
            "7" { Cleanup-System }
            "8" { Check-System-Ready }
            "9" { Show-Documentation }
            "A" { Show-Help }
            "a" { Show-Help }
            "0" { 
                Write-Header "До свидания!"
                Write-Host "  Спасибо за использование CERES!" -ForegroundColor Cyan
                Write-Host ""
                exit 0
            }
            default {
                Write-Host ""
                Write-Warning-Custom "Неверный выбор. Введите число от 0 до 9."
                Start-Sleep -Seconds 2
            }
        }
    }
}

# 1. Установка CERES
function Install-Ceres {
    Write-Header "🚀 Установка CERES"
    
    if (-not (Test-Administrator)) {
        Write-Warning-Custom "Требуются права администратора!"
        Write-Host ""
        Write-Host "Перезапустите программу от имени администратора:" -ForegroundColor Yellow
        Write-Host "  Правый клик → Запуск от имени администратора" -ForegroundColor Gray
        Pause-And-Continue
        return
    }
    
    Write-Host "  Это установит CERES на ваш Proxmox сервер." -ForegroundColor White
    Write-Host ""
    Write-Info "Вам понадобится:"
    Write-Host "    • IP адрес Proxmox (например: 192.168.1.3)" -ForegroundColor Gray
    Write-Host "    • Пароль root от Proxmox" -ForegroundColor Gray
    Write-Host ""
    Write-Info "Время установки: ~20 минут"
    Write-Host ""
    
    $confirm = Read-Host "  Продолжить? (yes/no)"
    if ($confirm -notmatch '^(y|yes|да|д)$') {
        Write-Host "  Отменено." -ForegroundColor Gray
        Pause-And-Continue
        return
    }
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\LAUNCH.ps1"
    if (Test-Path $scriptPath) {
        Write-Host ""
        Write-Success "Запускаю установщик..."
        Write-Host ""
        & $scriptPath
    } else {
        Write-Warning-Custom "Файл LAUNCH.ps1 не найден!"
        Write-Host "  Проверьте папку scripts\" -ForegroundColor Gray
    }
    
    Pause-And-Continue
}

# 2. Настройка доступа
function Setup-Access {
    Write-Header "🔧 Настройка доступа к сервисам"
    
    if (-not (Test-Administrator)) {
        Write-Warning-Custom "Требуются права администратора!"
        Write-Host ""
        Write-Host "Перезапустите программу от имени администратора." -ForegroundColor Yellow
        Pause-And-Continue
        return
    }
    
    Write-Host "  Этот скрипт добавит домены CERES в hosts файл Windows." -ForegroundColor White
    Write-Host ""
    Write-Info "После этого вы сможете открывать сервисы по адресам:"
    Write-Host "    • https://nextcloud.ceres.local" -ForegroundColor Gray
    Write-Host "    • https://redmine.ceres.local" -ForegroundColor Gray
    Write-Host "    • https://grafana.ceres.local" -ForegroundColor Gray
    Write-Host "    • и другие..." -ForegroundColor Gray
    Write-Host ""
    
    $ip = Read-Host "  IP адрес сервера с приложениями [192.168.1.11]"
    if ([string]::IsNullOrWhiteSpace($ip)) { $ip = "192.168.1.11" }
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\Update-Hosts.ps1"
    if (Test-Path $scriptPath) {
        Write-Host ""
        Write-Success "Запускаю настройку..."
        Write-Host ""
        & $scriptPath -IP $ip
    } else {
        Write-Warning-Custom "Файл Update-Hosts.ps1 не найден!"
    }
    
    Pause-And-Continue
}

# 3. Первая настройка
function First-Setup {
    Write-Header "⚙️ Первая настройка после установки"
    
    Write-Host "  Пошаговый мастер настройки CERES после установки." -ForegroundColor White
    Write-Host ""
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\Post-Install.ps1"
    if (Test-Path $scriptPath) {
        Write-Success "Запускаю мастер настройки..."
        Write-Host ""
        & $scriptPath
    } else {
        Write-Info "Ручная настройка:"
        Write-Host ""
        Write-Host "  1. Откройте https://nextcloud.ceres.local" -ForegroundColor White
        Write-Host "     Войдите: admin / admin" -ForegroundColor Gray
        Write-Host "     Смените пароль!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  2. Откройте https://auth.ceres.local" -ForegroundColor White
        Write-Host "     Войдите: admin / admin" -ForegroundColor Gray
        Write-Host "     Смените пароль!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  3. Настройте почту в Keycloak" -ForegroundColor White
        Write-Host "     См. docs/MAIL_SMTP_DAY1.md" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  4. Создайте пользователей" -ForegroundColor White
        Write-Host "     В Keycloak → Users → Add user" -ForegroundColor Gray
    }
    
    Pause-And-Continue
}

# 4. Проверка статуса
function Check-Status {
    Write-Header "📊 Проверка статуса сервисов"
    
    Write-Host "  Проверяю доступность сервисов..." -ForegroundColor White
    Write-Host ""
    
    $services = @(
        @{Name="Nextcloud"; URL="https://nextcloud.ceres.local"},
        @{Name="Redmine"; URL="https://redmine.ceres.local"},
        @{Name="Mattermost"; URL="https://mattermost.ceres.local"},
        @{Name="Gitea"; URL="https://gitea.ceres.local"},
        @{Name="Grafana"; URL="https://grafana.ceres.local"},
        @{Name="Keycloak"; URL="https://auth.ceres.local"}
    )
    
    foreach ($service in $services) {
        Write-Host "  Проверяю $($service.Name)... " -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri $service.URL -Method Head -TimeoutSec 5 -SkipCertificateCheck -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "✓ Работает" -ForegroundColor Green
            } else {
                Write-Host "⚠ Код: $($response.StatusCode)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "✗ Недоступен" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Info "Для подробной проверки откройте Grafana:"
    Write-Host "  https://grafana.ceres.local" -ForegroundColor Cyan
    
    Pause-And-Continue
}

# 5. Резервное копирование
function Create-Backup {
    Write-Header "💾 Создание резервной копии"
    
    Write-Host "  Создание резервной копии всех данных CERES." -ForegroundColor White
    Write-Host ""
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\backup.ps1"
    if (Test-Path $scriptPath) {
        Write-Success "Запускаю резервное копирование..."
        Write-Host ""
        & $scriptPath
    } else {
        Write-Warning-Custom "Файл backup.ps1 не найден!"
        Write-Host ""
        Write-Info "Ручное резервное копирование:"
        Write-Host "  1. Подключитесь к серверу: ssh root@192.168.1.11" -ForegroundColor Gray
        Write-Host "  2. Выполните: cd /opt/Ceres && bash scripts/backup.sh" -ForegroundColor Gray
    }
    
    Pause-And-Continue
}

# 6. Восстановление
function Restore-Backup {
    Write-Header "♻️ Восстановление из резервной копии"
    
    Write-Host "  Восстановление данных из резервной копии." -ForegroundColor White
    Write-Host ""
    Write-Warning-Custom "ВНИМАНИЕ: Текущие данные будут заменены!"
    Write-Host ""
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\restore.ps1"
    if (Test-Path $scriptPath) {
        $confirm = Read-Host "  Продолжить? (yes/no)"
        if ($confirm -match '^(y|yes|да|д)$') {
            Write-Success "Запускаю восстановление..."
            Write-Host ""
            & $scriptPath
        }
    } else {
        Write-Warning-Custom "Файл restore.ps1 не найден!"
    }
    
    Pause-And-Continue
}

# 7. Очистка
function Cleanup-System {
    Write-Header "🧹 Очистка и обслуживание"
    
    Write-Host "  Удаление старых данных и освобождение места." -ForegroundColor White
    Write-Host ""
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\cleanup.ps1"
    if (Test-Path $scriptPath) {
        Write-Success "Запускаю очистку..."
        Write-Host ""
        & $scriptPath
    } else {
        Write-Warning-Custom "Файл cleanup.ps1 не найден!"
    }
    
    Pause-And-Continue
}

# 8. Проверка системы
function Check-System-Ready {
    Write-Header "🧹 Очистка и обслуживание"
    
    Write-Host "  Удаление старых данных и освобождение места." -ForegroundColor White
    Write-Host ""
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\cleanup.ps1"
    if (Test-Path $scriptPath) {
        Write-Success "Запускаю очистку..."
        Write-Host ""
        & $scriptPath
    } else {
        Write-Warning-Custom "Файл cleanup.ps1 не найден!"
    }
    
    Pause-And-Continue
}

    Write-Header "🔍 Проверка готовности системы"
    
    Write-Host "  Проверим что всё готово к установке CERES." -ForegroundColor White
    Write-Host ""
    
    $scriptPath = Join-Path $PSScriptRoot "scripts\Check-System.ps1"
    if (Test-Path $scriptPath) {
        Write-Success "Запускаю проверку..."
        Write-Host ""
        & $scriptPath
    } else {
        Write-Warning-Custom "Файл Check-System.ps1 не найден!"
        Write-Host ""
        Write-Info "Основные требования:"
        Write-Host "  • Windows 10/11" -ForegroundColor Gray
        Write-Host "  • PowerShell 5.0+" -ForegroundColor Gray
        Write-Host "  • Proxmox сервер" -ForegroundColor Gray
        Write-Host "  • 10+ GB свободного места" -ForegroundColor Gray
    }
    
    Pause-And-Continue
}

# 9. Документация
function Show-Documentation {
    Write-Header "📚 Документация"
    
    Write-Host "  Доступная документация:" -ForegroundColor White
    Write-Host ""
    
    $docs = @(
        @{File="НАЧАЛО.md"; Desc="Самое простое руководство"},
        @{File="QUICKSTART.md"; Desc="Подробное руководство для новичков"},
        @{File="CHECKLIST.md"; Desc="Чеклист установки"},
        @{File="ШПАРГАЛКА.md"; Desc="Быстрый справочник"},
        @{File="INDEX.md"; Desc="Навигатор по документации"},
        @{File="README.md"; Desc="Полная техническая документация"}
    )
    
    $i = 1
    foreach ($doc in $docs) {
        $path = Join-Path $PSScriptRoot $doc.File
        if (Test-Path $path) {
            Write-Host "  [$i] $($doc.File)" -ForegroundColor Green
            Write-Host "      $($doc.Desc)" -ForegroundColor Gray
            Write-Host ""
            $i++
        }
    }
    
    Write-Host "  [0] Назад" -ForegroundColor Yellow
    Write-Host ""
    
    $choice = Read-Host "  Открыть документ (номер)"
    
    if ($choice -eq "0") { return }
    
    $index = [int]$choice - 1
    if ($index -ge 0 -and $index -lt $docs.Count) {
        $docPath = Join-Path $PSScriptRoot $docs[$index].File
        if (Test-Path $docPath) {
            Start-Process notepad.exe -ArgumentList $docPath
        }
    }
    
    Pause-And-Continue
}

# A. Помощь
function Show-Help {
    Write-Header "❓ Помощь и FAQ"
    
    Write-Host "  Часто задаваемые вопросы:" -ForegroundColor White
    Write-Host ""
    
    Write-Host "  [1] Как установить CERES?" -ForegroundColor Green
    Write-Host "  [2] Сайты не открываются" -ForegroundColor Green
    Write-Host "  [3] Забыл пароль" -ForegroundColor Green
    Write-Host "  [4] Как создать пользователя?" -ForegroundColor Green
    Write-Host "  [5] Как настроить почту?" -ForegroundColor Green
    Write-Host "  [6] Сервис не работает" -ForegroundColor Green
    Write-Host "  [7] Нужно больше места" -ForegroundColor Green
    Write-Host "  [0] Назад" -ForegroundColor Yellow
    Write-Host ""
    
    $choice = Read-Host "  Выберите вопрос"
    
    Write-Host ""
    
    switch ($choice) {
        "1" {
            Write-Host "  КАК УСТАНОВИТЬ CERES?" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  1. В главном меню выберите '1 - Установить CERES'" -ForegroundColor White
            Write-Host "  2. Введите IP адрес Proxmox" -ForegroundColor White
            Write-Host "  3. Введите пароль root" -ForegroundColor White
            Write-Host "  4. Следуйте инструкциям на экране" -ForegroundColor White
            Write-Host ""
            Write-Host "  Подробнее: НАЧАЛО.md или QUICKSTART.md" -ForegroundColor Gray
        }
        "2" {
            Write-Host "  САЙТЫ НЕ ОТКРЫВАЮТСЯ" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Решение:" -ForegroundColor White
            Write-Host "  1. В главном меню выберите '2 - Настроить доступ'" -ForegroundColor White
            Write-Host "  2. Очистите кэш браузера (Ctrl+Shift+Delete)" -ForegroundColor White
            Write-Host "  3. Проверьте что VM работают в Proxmox" -ForegroundColor White
            Write-Host "  4. Попробуйте открыть http://192.168.1.12" -ForegroundColor White
        }
        "3" {
            Write-Host "  ЗАБЫЛ ПАРОЛЬ" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Nextcloud:" -ForegroundColor White
            Write-Host "    ssh root@192.168.1.11" -ForegroundColor Gray
            Write-Host "    docker exec -it nextcloud php occ user:resetpassword admin" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Grafana:" -ForegroundColor White
            Write-Host "    ssh root@192.168.1.12" -ForegroundColor Gray
            Write-Host "    docker exec -it grafana grafana-cli admin reset-admin-password newpass" -ForegroundColor Gray
        }
        "4" {
            Write-Host "  КАК СОЗДАТЬ ПОЛЬЗОВАТЕЛЯ?" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  1. Откройте https://auth.ceres.local" -ForegroundColor White
            Write-Host "  2. Войдите как admin" -ForegroundColor White
            Write-Host "  3. Users → Add user" -ForegroundColor White
            Write-Host "  4. Заполните данные и Save" -ForegroundColor White
            Write-Host ""
            Write-Host "  Пользователь сможет войти во все сервисы с одним паролем (SSO)" -ForegroundColor Gray
        }
        "5" {
            Write-Host "  КАК НАСТРОИТЬ ПОЧТУ?" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  Смотрите подробную инструкцию:" -ForegroundColor White
            Write-Host "    docs\MAIL_SMTP_DAY1.md" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Или используйте скрипт:" -ForegroundColor White
            Write-Host "    scripts\keycloak-smtp.ps1" -ForegroundColor Gray
        }
        "6" {
            Write-Host "  СЕРВИС НЕ РАБОТАЕТ" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  1. Проверьте статус: выберите '4 - Проверить статус' в меню" -ForegroundColor White
            Write-Host "  2. Посмотрите Grafana: https://grafana.ceres.local" -ForegroundColor White
            Write-Host "  3. Проверьте логи:" -ForegroundColor White
            Write-Host "     ssh root@192.168.1.11" -ForegroundColor Gray
            Write-Host "     docker logs имя_сервиса" -ForegroundColor Gray
        }
        "7" {
            Write-Host "  НУЖНО БОЛЬШЕ МЕСТА" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  1. Используйте '7 - Очистка' в меню" -ForegroundColor White
            Write-Host "  2. Или увеличьте диск VM в Proxmox:" -ForegroundColor White
            Write-Host "     • Выключите VM" -ForegroundColor Gray
            Write-Host "     • Hardware → Hard Disk → Resize" -ForegroundColor Gray
            Write-Host "     • Запустите VM" -ForegroundColor Gray
        }
        "0" {
            return
        }
    }
    
    Pause-And-Continue
}

# Проверка на запуск из правильной папки
$currentPath = Get-Location
$scriptPath = Split-Path -Parent $PSCommandPath

if ($currentPath.Path -ne $scriptPath) {
    Set-Location $scriptPath
}

# Запуск главного меню
Show-MainMenu
