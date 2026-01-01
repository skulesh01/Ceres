#Requires -Version 5.1
<#
.SYNOPSIS
    CERES - Проверка после установки
    
.DESCRIPTION
    Проверяет что все сервисы работают после установки.
    Показывает какие сервисы доступны, а какие требуют внимания.
    
.NOTES
    Версия: 1.0
    CERES Team | 2025
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-ServiceCheck {
    param(
        [string]$Name,
        [string]$URL,
        [string]$Status,
        [string]$Details = ""
    )
    
    $icon = switch ($Status) {
        "ok" { "✓"; $color = "Green" }
        "warning" { "⚠"; $color = "Yellow" }
        "error" { "✗"; $color = "Red" }
        default { "•"; $color = "Gray" }
    }
    
    Write-Host "  $icon " -ForegroundColor $color -NoNewline
    Write-Host ("{0,-20}" -f $Name) -ForegroundColor White -NoNewline
    Write-Host " $URL" -ForegroundColor Cyan
    
    if ($Details) {
        Write-Host "      $Details" -ForegroundColor Gray
    }
}

Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                              ║" -ForegroundColor Cyan
Write-Host "║         🧪 CERES - Проверка установки                        ║" -ForegroundColor Cyan
Write-Host "║                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  Проверяю доступность всех сервисов..." -ForegroundColor White
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

$services = @(
    @{Name="Keycloak (SSO)"; URL="https://auth.ceres.local"; Port=443; Category="Безопасность"},
    @{Name="Nextcloud"; URL="https://nextcloud.ceres.local"; Port=443; Category="Файлы"},
    @{Name="Redmine"; URL="https://redmine.ceres.local"; Port=443; Category="Проекты"},
    @{Name="Mattermost"; URL="https://mattermost.ceres.local"; Port=443; Category="Чат"},
    @{Name="Gitea"; URL="https://gitea.ceres.local"; Port=443; Category="Git"},
    @{Name="Wiki.js"; URL="https://wiki.ceres.local"; Port=443; Category="Документация"},
    @{Name="Grafana"; URL="https://grafana.ceres.local"; Port=443; Category="Мониторинг"},
    @{Name="Prometheus"; URL="https://prometheus.ceres.local"; Port=443; Category="Метрики"},
    @{Name="Portainer"; URL="https://portainer.ceres.local"; Port=443; Category="Управление"},
    @{Name="Uptime Kuma"; URL="https://uptime.ceres.local"; Port=443; Category="Uptime"}
)

$okCount = 0
$warningCount = 0
$errorCount = 0

foreach ($service in $services) {
    try {
        $response = Invoke-WebRequest -Uri $service.URL -Method Head -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
        
        if ($response.StatusCode -eq 200) {
            Write-ServiceCheck -Name $service.Name -URL $service.URL -Status "ok" -Details "Работает нормально"
            $okCount++
        } else {
            Write-ServiceCheck -Name $service.Name -URL $service.URL -Status "warning" -Details "HTTP $($response.StatusCode)"
            $warningCount++
        }
    } catch {
        $errorMessage = $_.Exception.Message
        
        if ($errorMessage -match "Unable to resolve") {
            Write-ServiceCheck -Name $service.Name -URL $service.URL -Status "error" -Details "Не настроен hosts файл"
        } elseif ($errorMessage -match "Unable to connect") {
            Write-ServiceCheck -Name $service.Name -URL $service.URL -Status "error" -Details "Сервис не запущен"
        } else {
            Write-ServiceCheck -Name $service.Name -URL $service.URL -Status "error" -Details "Недоступен"
        }
        $errorCount++
    }
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

# Итоги
Write-Host "  Результаты:" -ForegroundColor White
Write-Host "    ✓ Работает:    " -NoNewline -ForegroundColor Green
Write-Host "$okCount" -ForegroundColor White
Write-Host "    ⚠ С проблемами:" -NoNewline -ForegroundColor Yellow
Write-Host "$warningCount" -ForegroundColor White
Write-Host "    ✗ Недоступно:  " -NoNewline -ForegroundColor Red
Write-Host "$errorCount" -ForegroundColor White

Write-Host ""

# Рекомендации
if ($errorCount -gt 0) {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                                                              ║" -ForegroundColor Yellow
    Write-Host "║           ⚠ ТРЕБУЕТСЯ ВНИМАНИЕ                               ║" -ForegroundColor Yellow
    Write-Host "║                                                              ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    if ($errorCount -eq $services.Count) {
        Write-Host "  ✗ Все сервисы недоступны!" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Возможные причины:" -ForegroundColor Yellow
        Write-Host "    1. Не настроен hosts файл" -ForegroundColor Gray
        Write-Host "    2. VM не запущены" -ForegroundColor Gray
        Write-Host "    3. Сервисы не установлены" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Что делать:" -ForegroundColor Cyan
        Write-Host "    1. Запустите: scripts\Update-Hosts.ps1" -ForegroundColor White
        Write-Host "    2. Проверьте VM в Proxmox" -ForegroundColor White
        Write-Host "    3. Проверьте логи установки" -ForegroundColor White
    } else {
        Write-Host "  Несколько сервисов недоступны." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Распространенные решения:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1. Настроить hosts файл:" -ForegroundColor White
        Write-Host "     scripts\Update-Hosts.ps1" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Проверить контейнеры:" -ForegroundColor White
        Write-Host "     ssh root@192.168.1.11" -ForegroundColor Gray
        Write-Host "     docker compose ps" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  3. Посмотреть логи:" -ForegroundColor White
        Write-Host "     docker logs имя_сервиса" -ForegroundColor Gray
    }
    
} elseif ($warningCount -gt 0) {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                                                              ║" -ForegroundColor Yellow
    Write-Host "║           ⚠ РАБОТАЕТ С ПРЕДУПРЕЖДЕНИЯМИ                     ║" -ForegroundColor Yellow
    Write-Host "║                                                              ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Большинство сервисов работает, но есть проблемы." -ForegroundColor White
    Write-Host "  Проверьте логи проблемных сервисов." -ForegroundColor Gray
    
} else {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                              ║" -ForegroundColor Green
    Write-Host "║              ✓ ВСЁ РАБОТАЕТ ОТЛИЧНО!                         ║" -ForegroundColor Green
    Write-Host "║                                                              ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  🎉 Поздравляем! CERES успешно установлен!" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Следующие шаги:" -ForegroundColor White
    Write-Host "    1. Смените все пароли (admin/admin)" -ForegroundColor Gray
    Write-Host "    2. Настройте Keycloak и создайте пользователей" -ForegroundColor Gray
    Write-Host "    3. Настройте SMTP для почты" -ForegroundColor Gray
    Write-Host "    4. Создайте резервную копию" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Запустите мастер настройки:" -ForegroundColor Cyan
    Write-Host "    scripts\Post-Install.ps1" -ForegroundColor White
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

# Дополнительная информация
Write-Host "  💡 Полезные ссылки:" -ForegroundColor Cyan
Write-Host "    • FAQ: FAQ.md" -ForegroundColor Gray
Write-Host "    • Шпаргалка: ШПАРГАЛКА.md" -ForegroundColor Gray
Write-Host "    • Чеклист: CHECKLIST.md" -ForegroundColor Gray
Write-Host ""

Write-Host "  Нажмите любую клавишу для выхода..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
