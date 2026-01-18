# ==========================================
# Setup Webhooks for Full Integration
# ==========================================

$ErrorActionPreference = "Stop"

Write-Host "Configuring webhooks..." -ForegroundColor Cyan

# ==========================================
# GitLab → Zulip Webhook
# ==========================================
Write-Host "[1/3] Setting up GitLab → Zulip webhook..." -ForegroundColor Cyan

$projects = Invoke-RestMethod -Uri "http://localhost:8080/api/v4/projects" `
  -Headers @{"PRIVATE-TOKEN" = $env:GITLAB_API_TOKEN}

foreach ($project in $projects) {
    $webhookData = @{
        url = "https://zulip.ceres/api/v1/external/gitlab?api_key=$env:ZULIP_WEBHOOK_KEY&stream=dev"
        push_events = $true
        issues_events = $true
        merge_requests_events = $true
        wiki_page_events = $true
        pipeline_events = $true
        enable_ssl_verification = $false
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Uri "http://localhost:8080/api/v4/projects/$($project.id)/hooks" `
            -Method Post `
            -Headers @{
                "PRIVATE-TOKEN" = $env:GITLAB_API_TOKEN
                "Content-Type" = "application/json"
            } `
            -Body $webhookData | Out-Null
        Write-Host "  ✓ Webhook added to project: $($project.name)" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠ Webhook already exists for: $($project.name)" -ForegroundColor Yellow
    }
}

# ==========================================
# Uptime Kuma → Zulip Webhook
# ==========================================
Write-Host "[2/3] Setting up Uptime Kuma → Zulip..." -ForegroundColor Cyan
Write-Host "  Manual step: Configure in Uptime Kuma UI" -ForegroundColor Yellow
Write-Host "  URL: https://zulip.ceres/api/v1/messages" -ForegroundColor Gray
Write-Host "  Method: POST" -ForegroundColor Gray
Write-Host "  Auth: Basic (ZULIP_BOT_EMAIL:ZULIP_BOT_API_KEY)" -ForegroundColor Gray

# ==========================================
# Grafana → Zulip Alert Channel
# ==========================================
Write-Host "[3/3] Setting up Grafana → Zulip..." -ForegroundColor Cyan

$notifierData = @{
    name = "Zulip Notifications"
    type = "webhook"
    isDefault = $true
    sendReminder = $true
    settings = @{
        url = "https://zulip.ceres/api/v1/messages"
        httpMethod = "POST"
        username = $env:ZULIP_BOT_EMAIL
        password = $env:ZULIP_BOT_API_KEY
    }
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "http://localhost:3000/api/alert-notifications" `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $env:GRAFANA_API_KEY"
            "Content-Type" = "application/json"
        } `
        -Body $notifierData | Out-Null
    Write-Host "  ✓ Grafana alert channel created" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Grafana alert channel already exists" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Webhooks configured!" -ForegroundColor Green
Write-Host ""
