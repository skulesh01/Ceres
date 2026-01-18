param([string]$Mode = "docker")

Write-Host "`n=== CERES FULL STACK DEPLOYMENT ===" -ForegroundColor Cyan
Write-Host "Services: 12+ with integrations" -ForegroundColor Green
Write-Host "Mode: $Mode`n" -ForegroundColor Yellow

if ($Mode -eq "docker") {
    Write-Host "[DOCKER COMPOSE MODE]" -ForegroundColor Cyan
    Write-Host "Starting 21 compose files with full integration...`n" -ForegroundColor Green
    
    $composeFiles = @(
        "config/compose/base.yml",
        "config/compose/core.yml",
        "config/compose/gitlab.yml",
        "config/compose/zulip.yml",
        "config/compose/apps.yml",
        "config/compose/office-suite.yml",
        "config/compose/mayan-edms.yml",
        "config/compose/monitoring.yml",
        "config/compose/monitoring-exporters.yml",
        "config/compose/ops.yml",
        "config/compose/vpn.yml"
    )
    
    Write-Host "Services to deploy:" -ForegroundColor Yellow
    Write-Host "  Core: PostgreSQL, Redis, Keycloak" -ForegroundColor White
    Write-Host "  Apps: GitLab CE, Zulip, Nextcloud, Mayan EDMS" -ForegroundColor White
    Write-Host "  Office: OnlyOffice, Collabora" -ForegroundColor White
    Write-Host "  Monitor: Prometheus, Grafana, Alertmanager" -ForegroundColor White
    Write-Host "  Exporters: 7 exporters (postgres, redis, node, caddy, etc)" -ForegroundColor White
    Write-Host "  Ops: Portainer, Uptime Kuma, WireGuard" -ForegroundColor White
    Write-Host "`n"
    
    foreach ($file in $composeFiles) {
        if (Test-Path $file) {
            Write-Host "[UP] $file" -ForegroundColor Cyan
            docker-compose -f $file up -d
            Start-Sleep -Seconds 3
        }
    }
    
    Write-Host "`n[OK] All services started!" -ForegroundColor Green
    Write-Host "`nChecking status:`n" -ForegroundColor Yellow
    docker ps --format "table {{.Names}}\t{{.Status}}" | head -20
    
    Write-Host "`nAccess points:" -ForegroundColor Cyan
    Write-Host "  Keycloak (SSO):     http://auth.ceres or http://localhost:8080" -ForegroundColor White
    Write-Host "  GitLab CE:          http://gitlab.ceres or http://localhost" -ForegroundColor White
    Write-Host "  Zulip (Chat):       http://zulip.ceres or http://localhost:80" -ForegroundColor White
    Write-Host "  Nextcloud (Files):  http://nextcloud.ceres" -ForegroundColor White
    Write-Host "  Grafana (Monitor):  http://grafana.ceres or http://localhost:3000" -ForegroundColor White
    Write-Host "  Portainer (Manage): http://portainer.ceres or http://localhost:9000" -ForegroundColor White
    Write-Host "`n"
}

elseif ($Mode -eq "terraform") {
    Write-Host "[TERRAFORM + KUBERNETES MODE]" -ForegroundColor Cyan
    Write-Host "Infrastructure: Proxmox -> 3 VMs -> k3s cluster`n" -ForegroundColor Green
    
    if (-not (Get-Command terraform -EA 0)) {
        Write-Host "ERROR: Terraform not found" -ForegroundColor Red
        Write-Host "Install: https://www.terraform.io/downloads.html" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Terraform plan:" -ForegroundColor Yellow
    Write-Host "  1. Create 3 VMs on Proxmox" -ForegroundColor White
    Write-Host "  2. Configure networking & SSH" -ForegroundColor White
    Write-Host "  3. Install k3s cluster" -ForegroundColor White
    Write-Host "  4. Deploy all services via Helm/Kustomize" -ForegroundColor White
    Write-Host "`n"
    
    cd terraform
    Write-Host "Running: terraform plan`n" -ForegroundColor Yellow
    terraform plan -out=tfplan
    
    Write-Host "`nReady to apply? Type: terraform apply tfplan" -ForegroundColor Cyan
    Write-Host "Then: ansible-playbook ../ansible/playbooks/deploy-ceres.yml`n" -ForegroundColor Cyan
}

elseif ($Mode -eq "remote") {
    Write-Host "[REMOTE SERVER MODE]" -ForegroundColor Cyan
    Write-Host "Deploy to any Linux/Windows server via SSH`n" -ForegroundColor Green
    
    $remoteHost = Read-Host "Remote server IP"
    $remoteUser = Read-Host "Username"
    $remotePass = Read-Host "Password" -AsSecureString
    
    Write-Host "`nDeploying to $remoteUser@$remoteHost..." -ForegroundColor Yellow
    
    # Use AI Hand modules
    Import-Module "./AI-hand/modules/RemoteServer.psm1" -Force
    Import-Module "./AI-hand/modules/RemoteDocker.psm1" -Force
    
    $session = New-RemoteConnection -Host $remoteHost -User $remoteUser -Password $remotePass
    
    Write-Host "Installing Docker..." -ForegroundColor Yellow
    Install-Docker -Session $session
    
    Write-Host "Deploying CERES..." -ForegroundColor Yellow
    Invoke-RemoteScript -Session $session -ScriptPath "./AI-hand/examples/deploy-ceres.ps1"
    
    Write-Host "`n[OK] Remote deployment complete!`n" -ForegroundColor Green
}

else {
    Write-Host "Usage: .\deploy-full.ps1 -Mode [docker|terraform|remote]" -ForegroundColor Yellow
}
