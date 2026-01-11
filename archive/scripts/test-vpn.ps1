#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Проверяет подключение к WireGuard VPN и доступность сервисов Ceres
.DESCRIPTION
    Тестирует:
    - Подключение к VPN серверу (10.8.0.1)
    - Доступность Kubernetes (192.168.1.3:6443)
    - Статус сервисов через kubectl
#>

Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       ПРОВЕРКА WIREGUARD VPN ПОДКЛЮЧЕНИЯ           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ==================== ПРОВЕРКА VPN СЕТИ ====================
Write-Host "🔍 Проверка VPN подключения..." -ForegroundColor Yellow

# Проверяем маршруты
$vpnRoutes = Get-NetRoute | Where-Object { $_.DestinationPrefix -like "10.8.0.0*" -or $_.DestinationPrefix -like "192.168.1.0*" }

if ($vpnRoutes) {
    Write-Host "✅ VPN маршруты найдены:" -ForegroundColor Green
    $vpnRoutes | Format-Table -Property DestinationPrefix, NextHop, InterfaceAlias -AutoSize
} else {
    Write-Host "⚠️  VPN маршруты не найдены - убедитесь, что WireGuard активирован!" -ForegroundColor Yellow
}

# ==================== PING ТЕСТОВ ====================
Write-Host "`n🌐 Проверка доступности сервисов..." -ForegroundColor Yellow

$testIPs = @(
    @{ IP = "10.8.0.1"; Name = "VPN сервер" },
    @{ IP = "192.168.1.3"; Name = "Kubernetes сервер" },
    @{ IP = "192.168.1.1"; Name = "Сетевой шлюз" }
)

foreach ($test in $testIPs) {
    try {
        $ping = Test-Connection -ComputerName $test.IP -Count 1 -ErrorAction Stop
        Write-Host "✅ $($test.Name) ($($test.IP)) - ДОСТУПЕН" -ForegroundColor Green
        Write-Host "   Время отклика: $($ping.ResponseTime)ms" -ForegroundColor Gray
    } catch {
        Write-Host "❌ $($test.Name) ($($test.IP)) - НЕДОСТУПЕН" -ForegroundColor Red
    }
}

# ==================== KUBECTL ПРОВЕРКА ====================
Write-Host "`n⚙️  Проверка Kubernetes сервисов..." -ForegroundColor Yellow

$kubeconfig = "C:\Users\Admin\k3s.yaml"

if (Test-Path $kubeconfig) {
    Write-Host "📋 Сервисы в namespace 'ceres':" -ForegroundColor Cyan
    
    try {
        $services = & kubectl --kubeconfig $kubeconfig get svc -n ceres -o json | ConvertFrom-Json
        
        foreach ($svc in $services.items) {
            $name = $svc.metadata.name
            $type = $svc.spec.type
            $clusterIP = $svc.spec.clusterIP
            
            # Получаем порты
            $ports = $svc.spec.ports | ForEach-Object { "$($_.port)/$($_.protocol)" }
            
            Write-Host "  • $name ($type) [$clusterIP] ports: $($ports -join ', ')" -ForegroundColor White
        }
        
        Write-Host "`n✅ Все сервисы доступны через kubectl" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Не удалось получить список сервисов (возможно kubectl не запущен или нет сети)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Kubeconfig не найден по пути: $kubeconfig" -ForegroundColor Yellow
}

# ==================== СТАТУС ПОДОВ ====================
Write-Host "`n📦 Статус подов в namespace 'ceres':" -ForegroundColor Yellow

try {
    $pods = & kubectl --kubeconfig $kubeconfig get pods -n ceres -o json | ConvertFrom-Json
    
    $running = 0
    $pending = 0
    $failed = 0
    $other = 0
    
    foreach ($pod in $pods.items) {
        $status = $pod.status.phase
        
        switch ($status) {
            "Running" { 
                Write-Host "  ✅ $($pod.metadata.name) - ЗАПУЩЕН" -ForegroundColor Green
                $running++
            }
            "Pending" { 
                Write-Host "  ⏳ $($pod.metadata.name) - ОЖИДАНИЕ" -ForegroundColor Yellow
                $pending++
            }
            "Failed" { 
                Write-Host "  ❌ $($pod.metadata.name) - ОШИБКА" -ForegroundColor Red
                $failed++
            }
            default {
                Write-Host "  ⚪ $($pod.metadata.name) - $status" -ForegroundColor Gray
                $other++
            }
        }
    }
    
    Write-Host "`n📊 Статистика:" -ForegroundColor Cyan
    Write-Host "   Запущено: $running ✅" -ForegroundColor Green
    Write-Host "   Ожидание: $pending ⏳" -ForegroundColor Yellow
    Write-Host "   Ошибки: $failed ❌" -ForegroundColor Red
    Write-Host "   Прочее: $other ⚪" -ForegroundColor Gray
    
} catch {
    Write-Host "⚠️  Не удалось получить статус подов" -ForegroundColor Yellow
}

# ==================== РЕКОМЕНДАЦИИ ====================
Write-Host "`n💡 Рекомендации:" -ForegroundColor Cyan

$vpnActive = Get-NetRoute | Where-Object { $_.DestinationPrefix -like "10.8.0.0*" }
$k8sReachable = Test-Connection -ComputerName "192.168.1.3" -Count 1 -ErrorAction SilentlyContinue

if ($vpnActive -and $k8sReachable) {
    Write-Host "   ✅ Все системы работают корректно!" -ForegroundColor Green
    Write-Host "   • Вы можете подключаться к сервисам Ceres" -ForegroundColor White
    Write-Host "   • Выполняйте kubectl команды для управления кластером" -ForegroundColor White
} elseif (-not $vpnActive) {
    Write-Host "   ⚠️  WireGuard VPN не активен" -ForegroundColor Yellow
    Write-Host "   • Откройте приложение WireGuard" -ForegroundColor White
    Write-Host "   • Активируйте туннель 'Ceres'" -ForegroundColor White
    Write-Host "   • Повторите проверку" -ForegroundColor White
} else {
    Write-Host "   ⚠️  Проблемы с подключением" -ForegroundColor Yellow
    Write-Host "   • Проверьте, активирована ли VPN (зеленый значок)" -ForegroundColor White
    Write-Host "   • Перезагрузите WireGuard" -ForegroundColor White
    Write-Host "   • Проверьте конфиг в: E:\Новая папка\Ceres\wg-client-vpn.conf" -ForegroundColor White
}

Write-Host "`n════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Предлагаем дальнейшие действия
Write-Host "🚀 Дальнейшие действия:" -ForegroundColor Cyan
Write-Host "   1. Откройте браузер: http://192.168.1.3" -ForegroundColor White
Write-Host "   2. Проверьте статус сервисов: kubectl get all -n ceres" -ForegroundColor Gray
Write-Host "   3. Смотрите логи: kubectl logs -n ceres -f`n" -ForegroundColor Gray

Read-Host "Нажмите Enter для выхода"
