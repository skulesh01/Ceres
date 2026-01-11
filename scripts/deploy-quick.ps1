<#
.SYNOPSIS
    Быстрое развёртывание Ceres infrastructure за 5 минут

.DESCRIPTION
    Автоматически:
    - Проверяет доступность сервера
    - Загружает манифесты
    - Применяет конфигурацию
    - Проверяет статус pods
    - Тестирует webhook

.PARAMETER ServerIp
    IP адрес сервера (по умолчанию 192.168.1.3)

.PARAMETER Password
    Пароль root (по умолчанию из переменной)

.EXAMPLE
    .\deploy-quick.ps1
    .\deploy-quick.ps1 -ServerIp $env:DEPLOY_SERVER_IP -Password $env:DEPLOY_SERVER_PASSWORD
#>

[CmdletBinding()]
param(
    [string]$ServerIp = "192.168.1.3",
    [string]$Password = $env:DEPLOY_SERVER_PASSWORD
)

$ErrorActionPreference = "Stop"

function Write-Step { param([string]$msg) Write-Host "`n▶️  $msg" -ForegroundColor Yellow }
function Write-Success { param([string]$msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Error_ { param([string]$msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Info { param([string]$msg) Write-Host "ℹ️  $msg" -ForegroundColor Cyan }

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║      🚀 БЫСТРОЕ РАЗВЁРТЫВАНИЕ CERES (5 минут)         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

# ==================== ШАГ 1: ПРОВЕРКА ДОСТУПА ====================

Write-Step "Шаг 1/5: Проверка доступности сервера..."

try {
    $ping = Test-Connection -ComputerName $ServerIp -Count 2 -Quiet
    if (-not $ping) {
        Write-Error_ "Сервер $ServerIp не отвечает на ping!"
        exit 1
    }
    Write-Success "Ping: OK"
} catch {
    Write-Error_ "Ошибка проверки ping: $_"
    exit 1
}

try {
    $plink = ".\plink.exe"
    if (-not (Test-Path $plink)) {
        Write-Error_ "plink.exe не найден в текущей директории!"
        exit 1
    }

    $hostname = & $plink -pw $Password -batch root@$ServerIp "hostname" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Error_ "SSH подключение не удалось!"
        exit 1
    }
    Write-Success "SSH: OK (hostname: $($hostname.Trim()))"
} catch {
    Write-Error_ "Ошибка SSH: $_"
    exit 1
}

# ==================== ШАГ 2: ЗАГРУЗКА МАНИФЕСТОВ ====================

Write-Step "Шаг 2/5: Загрузка манифестов на сервер..."

try {
    $manifests = @{
        'k8s-mail-vpn-simple.yaml' = '/tmp/mail-vpn.yaml'
        'k8s-webhook-listener-fixed.yaml' = '/tmp/webhook.yaml'
    }

    foreach ($local in $manifests.Keys) {
        $remote = $manifests[$local]
        
        if (-not (Test-Path $local)) {
            Write-Error_ "Файл $local не найден!"
            exit 1
        }

        Write-Info "Загружаем $local..."
        $content = Get-Content $local -Raw
        $content | & $plink -pw $Password -batch root@$ServerIp "cat > $remote"
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error_ "Не удалось загрузить $local"
            exit 1
        }
    }
    
    Write-Success "Манифесты загружены"
} catch {
    Write-Error_ "Ошибка загрузки: $_"
    exit 1
}

# ==================== ШАГ 3: ПРИМЕНЕНИЕ МАНИФЕСТОВ ====================

Write-Step "Шаг 3/5: Применение конфигурации Kubernetes..."

try {
    $result = & $plink -pw $Password -batch root@$ServerIp @"
kubectl apply -f /tmp/mail-vpn.yaml
kubectl apply -f /tmp/webhook.yaml
"@ 2>&1 | Out-String

    Write-Host $result
    
    if ($result -match "error") {
        Write-Error_ "Ошибки при применении манифестов"
        exit 1
    }
    
    Write-Success "Манифесты применены"
} catch {
    Write-Error_ "Ошибка применения: $_"
    exit 1
}

# ==================== ШАГ 4: ОЖИДАНИЕ И ПРОВЕРКА PODS ====================

Write-Step "Шаг 4/5: Ожидание запуска pods (60 сек)..."

Start-Sleep -Seconds 60

try {
    $pods = & $plink -pw $Password -batch root@$ServerIp "kubectl get pods -n mail-vpn" 2>&1 | Out-String
    Write-Host $pods
    
    $runningCount = ([regex]::Matches($pods, "Running")).Count
    
    if ($runningCount -eq 0) {
        Write-Error_ "Ни один pod не запустился!"
        Write-Info "Проверьте логи: kubectl logs -n mail-vpn <pod-name>"
        exit 1
    }
    
    Write-Success "$runningCount pod(s) запущено"
} catch {
    Write-Error_ "Ошибка проверки pods: $_"
    exit 1
}

# ==================== ШАГ 5: ТЕСТИРОВАНИЕ ====================

Write-Step "Шаг 5/5: Тестирование системы..."

Write-Info "Тест 1: Health check webhook..."
try {
    $health = Invoke-RestMethod -Uri "http://${ServerIp}:30500/health" -ErrorAction Stop
    if ($health.status -eq "healthy") {
        Write-Success "Webhook: OK"
    } else {
        Write-Error_ "Webhook вернул некорректный статус"
    }
} catch {
    Write-Error_ "Webhook недоступен: $_"
    Write-Info "Это может быть нормально если pod ещё не готов. Подождите 1-2 минуты."
}

Write-Info "Тест 2: Создание тестового VPN пользователя..."
try {
    $body = @{
        username = "quicktest"
        email = "quicktest@ceres.local"
    } | ConvertTo-Json
    
    $result = Invoke-RestMethod -Uri "http://${ServerIp}:30500/webhook/keycloak" `
        -Method POST -Body $body -ContentType 'application/json' `
        -Headers @{'X-Webhook-Token'='change-me'} -ErrorAction Stop
    
    if ($result.status -eq "success") {
        Write-Success "VPN пользователь создан: $($result.username) ($($result.ip))"
    } else {
        Write-Error_ "Ошибка создания: $($result.reason)"
    }
} catch {
    Write-Error_ "Ошибка создания пользователя: $_"
}

Write-Info "Тест 3: Проверка WireGuard peers..."
try {
    $wgStatus = & $plink -pw $Password -batch root@$ServerIp "wg show wg0" 2>&1 | Out-String
    $peerCount = ([regex]::Matches($wgStatus, "peer:")).Count
    Write-Success "WireGuard: $peerCount peer(s)"
} catch {
    Write-Error_ "Ошибка проверки WireGuard: $_"
}

# ==================== ИТОГ ====================

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║      ✅ РАЗВЁРТЫВАНИЕ ЗАВЕРШЕНО!                       ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📋 ДОСТУПНЫЕ СЕРВИСЫ:`n" -ForegroundColor Cyan
Write-Host "   • Webhook API:    http://${ServerIp}:30500" -ForegroundColor White
Write-Host "   • WireGuard VPN:  ${ServerIp}:51820" -ForegroundColor White
Write-Host "   • K3s API:        https://${ServerIp}:6443" -ForegroundColor White

Write-Host "`n📚 ЧТО ДАЛЬШЕ:`n" -ForegroundColor Cyan
Write-Host "1. Создать пользователя: .\scripts\onboard-employee.ps1" -ForegroundColor White
Write-Host "2. Интегрировать Keycloak: см. KEYCLOAK_AUTOMATION.md" -ForegroundColor White
Write-Host "3. Настроить мониторинг: Prometheus + Grafana" -ForegroundColor White
Write-Host "4. Настроить бэкапы: .\scripts\backup.ps1" -ForegroundColor White

Write-Host "`n✅ ВСЁ ГОТОВО К РАБОТЕ!`n" -ForegroundColor Green
