#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Автоматическое добавление CERES доменов в hosts файл Windows
    
.DESCRIPTION
    Добавляет все необходимые домены CERES платформы в системный hosts файл.
    Требует прав администратора.
    
.PARAMETER IP
    IP адрес виртуальной машины с сервисами (по умолчанию: 192.168.1.11 для apps VM)
    
.EXAMPLE
    .\Update-Hosts.ps1
    .\Update-Hosts.ps1 -IP 192.168.1.50
    
.NOTES
    Автор: CERES Team
    Версия: 1.0
#>

param(
    [string]$IP = "192.168.1.11"
)

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$backupPath = "$env:SystemRoot\System32\drivers\etc\hosts.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"

# CERES домены
$ceresDomains = @(
    "nextcloud.ceres.local",
    "gitea.ceres.local", 
    "mattermost.ceres.local",
    "redmine.ceres.local",
    "wiki.ceres.local",
    "edms.ceres.local",
    "keycloak.ceres.local",
    "grafana.ceres.local",
    "prometheus.ceres.local",
    "portainer.ceres.local",
    "vpn.ceres.local"
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-HostsEntry {
    param([string]$Domain)
    
    $content = Get-Content $hostsPath -Raw
    return $content -match [regex]::Escape($Domain)
}

function Add-HostsEntry {
    param(
        [string]$IP,
        [string]$Domain
    )
    
    $entry = "$IP`t$Domain"
    Add-Content -Path $hostsPath -Value $entry -Encoding UTF8
}

# Начало
Clear-Host
Write-ColorOutput "`n═══════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "  🔧 CERES - Обновление Hosts файла" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════════`n" "Cyan"

Write-ColorOutput "IP адрес сервера: $IP" "Yellow"
Write-ColorOutput "Файл: $hostsPath`n" "Gray"

# Проверка прав администратора
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColorOutput "❌ ОШИБКА: Требуются права администратора!" "Red"
    Write-ColorOutput "`nЗапустите скрипт от имени администратора:" "Yellow"
    Write-ColorOutput "  Правый клик → Запуск от имени администратора`n" "Gray"
    pause
    exit 1
}

# Проверка существования hosts файла
if (-not (Test-Path $hostsPath)) {
    Write-ColorOutput "❌ ОШИБКА: Hosts файл не найден!" "Red"
    exit 1
}

# Создание резервной копии
Write-ColorOutput "➤ Создаю резервную копию..." "White"
try {
    Copy-Item -Path $hostsPath -Destination $backupPath -Force
    Write-ColorOutput "✓ Резервная копия: $backupPath`n" "Green"
} catch {
    Write-ColorOutput "⚠ Не удалось создать резервную копию, продолжаю...`n" "Yellow"
}

# Добавление доменов
$added = 0
$skipped = 0

Write-ColorOutput "➤ Добавляю CERES домены...`n" "White"

foreach ($domain in $ceresDomains) {
    if (Test-HostsEntry -Domain $domain) {
        Write-ColorOutput "  ⊙ $domain - уже существует" "Gray"
        $skipped++
    } else {
        Add-HostsEntry -IP $IP -Domain $domain
        Write-ColorOutput "  ✓ $domain" "Green"
        $added++
    }
}

# Итоги
Write-ColorOutput "`n═══════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "  📊 Результат" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════════`n" "Cyan"

Write-ColorOutput "Добавлено: $added" "Green"
Write-ColorOutput "Пропущено: $skipped`n" "Yellow"

if ($added -gt 0) {
    Write-ColorOutput "✓ Hosts файл успешно обновлён!" "Green"
    Write-ColorOutput "`n💡 Изменения вступают в силу немедленно." "Cyan"
    Write-ColorOutput "   Можете открывать сервисы в браузере!`n" "Cyan"
} else {
    Write-ColorOutput "ℹ Все домены уже добавлены." "Blue"
    Write-ColorOutput "  Ничего не изменено.`n" "Gray"
}

# Показываем текущее содержимое для CERES
Write-ColorOutput "═══════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "  📝 Текущие CERES записи в hosts:" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════════`n" "Cyan"

$hostsContent = Get-Content $hostsPath
$ceresEntries = $hostsContent | Where-Object { $_ -match "ceres\.local" }

if ($ceresEntries) {
    foreach ($entry in $ceresEntries) {
        Write-ColorOutput "  $entry" "White"
    }
} else {
    Write-ColorOutput "  (записи не найдены)" "Gray"
}

Write-Host ""

# Опции
Write-ColorOutput "═══════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "  🔧 Дополнительные опции" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════════`n" "Cyan"

Write-Host "  [E] Открыть hosts файл в блокноте"
Write-Host "  [D] Удалить все CERES записи"
Write-Host "  [R] Восстановить из резервной копии"
Write-Host "  [Q] Выход"
Write-Host ""

$choice = Read-Host "Выберите опцию"

switch ($choice.ToUpper()) {
    "E" {
        Start-Process notepad.exe -ArgumentList $hostsPath
    }
    "D" {
        Write-ColorOutput "`n⚠ ВНИМАНИЕ: Все записи с 'ceres.local' будут удалены!" "Yellow"
        $confirm = Read-Host "Продолжить? (yes/no)"
        
        if ($confirm -eq "yes") {
            $content = Get-Content $hostsPath
            $filtered = $content | Where-Object { $_ -notmatch "ceres\.local" }
            $filtered | Set-Content $hostsPath -Encoding UTF8
            Write-ColorOutput "✓ CERES записи удалены из hosts файла`n" "Green"
        } else {
            Write-ColorOutput "Отменено.`n" "Gray"
        }
    }
    "R" {
        if (Test-Path $backupPath) {
            Copy-Item -Path $backupPath -Destination $hostsPath -Force
            Write-ColorOutput "✓ Hosts файл восстановлен из резервной копии`n" "Green"
        } else {
            Write-ColorOutput "❌ Резервная копия не найдена`n" "Red"
        }
    }
    default {
        Write-ColorOutput "Завершение работы.`n" "Gray"
    }
}
