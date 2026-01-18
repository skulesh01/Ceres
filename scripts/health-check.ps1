# ==========================================
# Health Check Script for All Services
# ==========================================

$ErrorActionPreference = "Continue"

function Test-ServiceHealth {
    param(
        [string]$Name,
        [string]$Url,
        [string]$Container
    )
    
    Write-Host "`n[$Name]" -ForegroundColor Cyan
    
    # Container check
    $containerStatus = docker ps --filter "name=$Container" --format "{{.Status}}" 2>$null
    if ($containerStatus) {
        Write-Host "  Container: " -NoNewline
        Write-Host "✅ Running ($containerStatus)" -ForegroundColor Green
    } else {
        Write-Host "  Container: " -NoNewline
        Write-Host "❌ Not running" -ForegroundColor Red
        return $false
    }
    
    # HTTP check
    if ($Url) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            Write-Host "  HTTP: " -NoNewline
            Write-Host "✅ $($response.StatusCode)" -ForegroundColor Green
        } catch {
            Write-Host "  HTTP: " -NoNewline
            Write-Host "❌ Failed ($($_.Exception.Message))" -ForegroundColor Red
            return $false
        }
    }
    
    # Resource usage
    $stats = docker stats $Container --no-stream --format "{{.CPUPerc}} {{.MemUsage}}" 2>$null
    if ($stats) {
        $cpu, $mem = $stats -split ' ', 2
        Write-Host "  Resources: CPU=$cpu MEM=$mem" -ForegroundColor Gray
    }
    
    return $true
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CERES HEALTH CHECK" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan

# ==========================================
# Core Services
# ==========================================
Write-Host "`n🔵 CORE SERVICES" -ForegroundColor Blue
Write-Host "────────────────────────────────────────" -ForegroundColor Gray

$coreResults = @{}
$coreResults['PostgreSQL'] = Test-ServiceHealth -Name "PostgreSQL" -Container "postgres"
$coreResults['Redis'] = Test-ServiceHealth -Name "Redis" -Container "redis"
$coreResults['Keycloak'] = Test-ServiceHealth -Name "Keycloak" -Url "http://localhost:8080/health" -Container "keycloak"

# ==========================================
# Application Services
# ==========================================
Write-Host "`n🟢 APPLICATION SERVICES" -ForegroundColor Green
Write-Host "────────────────────────────────────────" -ForegroundColor Gray

$appResults = @{}
$appResults['GitLab'] = Test-ServiceHealth -Name "GitLab CE" -Url "http://localhost:8080/-/health" -Container "gitlab"
$appResults['Zulip'] = Test-ServiceHealth -Name "Zulip" -Url "http://localhost:8000/health" -Container "zulip"
$appResults['Nextcloud'] = Test-ServiceHealth -Name "Nextcloud" -Url "http://localhost/status.php" -Container "nextcloud"

# ==========================================
# Monitoring Services
# ==========================================
Write-Host "`n🟡 MONITORING SERVICES" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────" -ForegroundColor Gray

$monResults = @{}
$monResults['Prometheus'] = Test-ServiceHealth -Name "Prometheus" -Url "http://localhost:9090/-/healthy" -Container "prometheus"
$monResults['Grafana'] = Test-ServiceHealth -Name "Grafana" -Url "http://localhost:3000/api/health" -Container "grafana"

# ==========================================
# Edge Services
# ==========================================
Write-Host "`n🟣 EDGE & OPERATIONS" -ForegroundColor Magenta
Write-Host "────────────────────────────────────────" -ForegroundColor Gray

$edgeResults = @{}
$edgeResults['Caddy'] = Test-ServiceHealth -Name "Caddy" -Url "http://localhost" -Container "caddy"
$edgeResults['Portainer'] = Test-ServiceHealth -Name "Portainer" -Url "http://localhost:9000/api/status" -Container "portainer"

# ==========================================
# Integration Checks
# ==========================================
Write-Host "`n🔗 INTEGRATION CHECKS" -ForegroundColor Cyan
Write-Host "────────────────────────────────────────" -ForegroundColor Gray

# GitLab → Zulip webhook
Write-Host "`n[GitLab → Zulip Webhook]" -ForegroundColor Cyan
try {
    $headers = @{"PRIVATE-TOKEN" = $env:GITLAB_API_TOKEN}
    $webhooks = Invoke-RestMethod -Uri "http://localhost:8080/api/v4/projects/1/hooks" -Headers $headers
    $zulipWebhooks = $webhooks | Where-Object { $_.url -like "*zulip*" }
    if ($zulipWebhooks) {
        Write-Host "  ✅ $($zulipWebhooks.Count) webhook(s) configured" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  No Zulip webhooks found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Failed to check webhooks" -ForegroundColor Red
}

# Keycloak OIDC clients
Write-Host "`n[Keycloak OIDC Clients]" -ForegroundColor Cyan
$expectedClients = @("gitlab", "zulip", "nextcloud", "grafana", "portainer")
Write-Host "  Expected: $($expectedClients -join ', ')" -ForegroundColor Gray
Write-Host "  ℹ️  Manual verification required via Keycloak admin" -ForegroundColor Cyan

# Prometheus targets
Write-Host "`n[Prometheus Targets]" -ForegroundColor Cyan
try {
    $targets = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets"
    $activeTargets = $targets.data.activeTargets
    $upTargets = ($activeTargets | Where-Object { $_.health -eq 'up' }).Count
    Write-Host "  ✅ $upTargets / $($activeTargets.Count) targets UP" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Failed to check Prometheus targets" -ForegroundColor Red
}

# ==========================================
# Summary
# ==========================================
Write-Host "`n════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SUMMARY" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan

$allResults = $coreResults + $appResults + $monResults + $edgeResults
$totalServices = $allResults.Count
$healthyServices = ($allResults.Values | Where-Object { $_ -eq $true }).Count
$healthPercentage = [math]::Round(($healthyServices / $totalServices) * 100, 0)

Write-Host ""
Write-Host "  Services: $healthyServices / $totalServices healthy ($healthPercentage%)" -ForegroundColor $(if ($healthPercentage -ge 90) { "Green" } elseif ($healthPercentage -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($healthPercentage -eq 100) {
    Write-Host "  🎉 All services are healthy!" -ForegroundColor Green
} elseif ($healthPercentage -ge 80) {
    Write-Host "  ⚠️  Some services need attention" -ForegroundColor Yellow
} else {
    Write-Host "  ❌ Critical: Multiple services down!" -ForegroundColor Red
}

Write-Host ""
Write-Host "💡 For detailed logs: docker logs <container-name>" -ForegroundColor Cyan
Write-Host "💡 To restart service: docker-compose restart <service>" -ForegroundColor Cyan
Write-Host ""
