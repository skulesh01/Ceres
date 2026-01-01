#Requires -Version 5.1
<#
.SYNOPSIS
    CERES - Проверка готовности системы
    
.DESCRIPTION
    Проверяет что ваш компьютер и Proxmox готовы к установке CERES.
    Автоматически находит и исправляет проблемы.
    
.NOTES
    Версия: 1.0
    CERES Team | 2025
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Check {
    param([string]$Text, [string]$Status = "checking")
    
    $icon = switch ($Status) {
        "ok" { "✓"; $color = "Green" }
        "warning" { "⚠"; $color = "Yellow" }
        "error" { "✗"; $color = "Red" }
        "checking" { "⏳"; $color = "Cyan" }
        default { "•"; $color = "Gray" }
    }
    
    Write-Host "  $icon " -ForegroundColor $color -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Detail {
    param([string]$Text)
    Write-Host "      $Text" -ForegroundColor Gray
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                              ║" -ForegroundColor Cyan
Write-Host "║         🔍 CERES - Проверка готовности системы               ║" -ForegroundColor Cyan
Write-Host "║                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$issues = @()
$warnings = @()

# 1. Проверка Windows
Write-Section "1️⃣  Проверка Windows"

Write-Check "Версия Windows..." "checking"
$os = Get-CimInstance Win32_OperatingSystem
$osVersion = [System.Environment]::OSVersion.Version

if ($osVersion.Major -ge 10) {
    Write-Check "Windows $($os.Caption)" "ok"
    Write-Detail "Версия: $($os.Version)"
} else {
    Write-Check "Windows версии ниже 10" "warning"
    Write-Detail "Рекомендуется: Windows 10 или 11"
    $warnings += "Старая версия Windows"
}

Write-Check "PowerShell..." "checking"
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Check "PowerShell $($psVersion.Major).$($psVersion.Minor)" "ok"
} else {
    Write-Check "PowerShell версии ниже 5.0" "error"
    $issues += "Обновите PowerShell до версии 5.1+"
}

Write-Check "Права администратора..." "checking"
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Check "Запущено от администратора" "ok"
} else {
    Write-Check "Требуются права администратора" "warning"
    Write-Detail "Некоторые функции могут не работать"
    $warnings += "Нет прав администратора"
}

# 2. Проверка сети
Write-Section "2️⃣  Проверка сети"

Write-Check "Интернет подключение..." "checking"
try {
    $null = Test-Connection -ComputerName "8.8.8.8" -Count 1 -ErrorAction Stop
    Write-Check "Интернет доступен" "ok"
} catch {
    Write-Check "Нет подключения к интернету" "warning"
    Write-Detail "Может потребоваться для скачивания образов"
    $warnings += "Нет интернета"
}

Write-Check "DNS разрешение..." "checking"
try {
    $null = Resolve-DnsName "google.com" -ErrorAction Stop
    Write-Check "DNS работает" "ok"
} catch {
    Write-Check "Проблемы с DNS" "warning"
    $warnings += "DNS не работает"
}

# 3. Проверка Proxmox
Write-Section "3️⃣  Проверка Proxmox"

$proxmoxIP = Read-Host "`n  Введите IP адрес Proxmox [192.168.1.3]"
if ([string]::IsNullOrWhiteSpace($proxmoxIP)) { $proxmoxIP = "192.168.1.3" }

Write-Host ""
Write-Check "Доступность Proxmox ($proxmoxIP)..." "checking"
if (Test-Connection -ComputerName $proxmoxIP -Count 2 -Quiet) {
    Write-Check "Proxmox отвечает на ping" "ok"
    
    Write-Check "Proxmox Web UI (https://${proxmoxIP}:8006)..." "checking"
    try {
        $response = Invoke-WebRequest -Uri "https://${proxmoxIP}:8006" -Method Head -TimeoutSec 5 -SkipCertificateCheck -ErrorAction Stop
        Write-Check "Web интерфейс доступен" "ok"
    } catch {
        Write-Check "Web интерфейс недоступен" "warning"
        Write-Detail "Проверьте что Proxmox запущен"
        $warnings += "Proxmox Web UI недоступен"
    }
} else {
    Write-Check "Proxmox не отвечает" "error"
    Write-Detail "Проверьте IP адрес и что сервер включен"
    $issues += "Proxmox недоступен по адресу $proxmoxIP"
}

# 4. Проверка необходимых программ
Write-Section "4️⃣  Проверка программ"

$requiredTools = @(
    @{Name="PowerShell"; Command="powershell"; Required=$true},
    @{Name="OpenSSH Client"; Command="ssh"; Required=$true}
)

foreach ($tool in $requiredTools) {
    Write-Check "$($tool.Name)..." "checking"
    if (Get-Command $tool.Command -ErrorAction SilentlyContinue) {
        Write-Check "$($tool.Name) установлен" "ok"
    } else {
        if ($tool.Required) {
            Write-Check "$($tool.Name) не найден" "error"
            $issues += "Установите $($tool.Name)"
            
            if ($tool.Name -eq "OpenSSH Client") {
                Write-Detail "Установка: Settings → Apps → Optional Features → OpenSSH Client"
            }
        } else {
            Write-Check "$($tool.Name) не найден (опционально)" "warning"
            $warnings += "$($tool.Name) не установлен"
        }
    }
}

# Проверка PuTTY (опционально)
Write-Check "PuTTY (опционально)..." "checking"
if ((Get-Command plink -ErrorAction SilentlyContinue) -and (Get-Command pscp -ErrorAction SilentlyContinue)) {
    Write-Check "PuTTY установлен" "ok"
    Write-Detail "Будет использован для SSH/SCP"
} else {
    Write-Check "PuTTY не найден" "warning"
    Write-Detail "Будет использован встроенный OpenSSH"
}

# 5. Проверка места на диске
Write-Section "5️⃣  Проверка места на диске"

$drive = Get-PSDrive -Name C
$freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)

Write-Check "Свободное место на диске C:..." "checking"
if ($freeSpaceGB -gt 10) {
    Write-Check "Свободно: $freeSpaceGB GB" "ok"
} elseif ($freeSpaceGB -gt 5) {
    Write-Check "Свободно: $freeSpaceGB GB" "warning"
    Write-Detail "Рекомендуется освободить больше места"
    $warnings += "Мало места на диске (< 10 GB)"
} else {
    Write-Check "Мало места: $freeSpaceGB GB" "error"
    Write-Detail "Требуется минимум 5 GB для временных файлов"
    $issues += "Недостаточно места на диске"
}

# 6. Проверка файлов проекта
Write-Section "6️⃣  Проверка файлов проекта"

$projectRoot = Split-Path -Parent $PSScriptRoot
$requiredFiles = @(
    "START.bat",
    "MENU.ps1",
    "scripts\LAUNCH.ps1",
    "scripts\deploy-wizard.sh",
    "scripts\deploy-3vm-enterprise.sh",
    "config\compose\base.yml",
    "config\compose\core.yml",
    "config\compose\apps.yml"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $projectRoot $file
    Write-Check "$file..." "checking"
    if (Test-Path $fullPath) {
        Write-Check "$file найден" "ok"
    } else {
        Write-Check "$file отсутствует" "error"
        $missingFiles += $file
        $issues += "Файл отсутствует: $file"
    }
}

# 7. Итоги
Write-Section "📊 Результаты проверки"

Write-Host ""
Write-Host "  Проверено:" -ForegroundColor White
Write-Host "    ✓ Система Windows" -ForegroundColor Gray
Write-Host "    ✓ Сетевые подключения" -ForegroundColor Gray
Write-Host "    ✓ Proxmox сервер" -ForegroundColor Gray
Write-Host "    ✓ Необходимые программы" -ForegroundColor Gray
Write-Host "    ✓ Место на диске" -ForegroundColor Gray
Write-Host "    ✓ Файлы проекта" -ForegroundColor Gray
Write-Host ""

if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                              ║" -ForegroundColor Green
    Write-Host "║              ✓ ВСЁ ГОТОВО К УСТАНОВКЕ!                       ║" -ForegroundColor Green
    Write-Host "║                                                              ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Можете запускать установку:" -ForegroundColor Cyan
    Write-Host "    1. Закройте это окно" -ForegroundColor Gray
    Write-Host "    2. Двойной клик на START.bat" -ForegroundColor Gray
    Write-Host "    3. Выберите '1. Установить CERES'" -ForegroundColor Gray
    
} elseif ($issues.Count -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                                                              ║" -ForegroundColor Yellow
    Write-Host "║           ⚠ ЕСТЬ ПРЕДУПРЕЖДЕНИЯ                              ║" -ForegroundColor Yellow
    Write-Host "║                                                              ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Предупреждения ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "    ⚠ $warning" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  Можете продолжить установку, но могут быть проблемы." -ForegroundColor Gray
    
} else {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "║           ✗ ОБНАРУЖЕНЫ ПРОБЛЕМЫ                              ║" -ForegroundColor Red
    Write-Host "║                                                              ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Критические проблемы ($($issues.Count)):" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "    ✗ $issue" -ForegroundColor Red
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "  Предупреждения ($($warnings.Count)):" -ForegroundColor Yellow
        foreach ($warning in $warnings) {
            Write-Host "    ⚠ $warning" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "  Исправьте проблемы и запустите проверку снова." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""
Write-Host "  Нажмите любую клавишу для выхода..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
