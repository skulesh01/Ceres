# ==========================================
# Keycloak Full Bootstrap - All OIDC Clients
# ==========================================

$ErrorActionPreference = "Stop"

Write-Host "Configuring Keycloak SSO for all services..." -ForegroundColor Cyan

# Wait for Keycloak
Write-Host "Waiting for Keycloak..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Login to Keycloak admin CLI
docker exec keycloak /opt/keycloak/bin/kcadm.sh config credentials `
  --server http://localhost:8080 `
  --realm master `
  --user admin `
  --password $env:KEYCLOAK_ADMIN_PASSWORD

# Create realm if not exists
Write-Host "Creating 'ceres' realm..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create realms `
  -s realm=ceres `
  -s enabled=true `
  -s displayName="CERES Platform" 2>$null

# ==========================================
# GitLab OIDC Client
# ==========================================
Write-Host "[1/8] Creating GitLab OIDC client..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r ceres `
  -s clientId=gitlab `
  -s enabled=true `
  -s clientAuthenticatorType=client-secret `
  -s secret=$env:GITLAB_OIDC_SECRET `
  -s 'redirectUris=["https://gitlab.ceres/users/auth/openid_connect/callback"]' `
  -s protocol=openid-connect `
  -s standardFlowEnabled=true `
  -s publicClient=false 2>$null
Write-Host "  ✓ GitLab client created" -ForegroundColor Green

# ==========================================
# Zulip OIDC Client
# ==========================================
Write-Host "[2/8] Creating Zulip OIDC client..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r ceres `
  -s clientId=zulip `
  -s enabled=true `
  -s clientAuthenticatorType=client-secret `
  -s secret=$env:ZULIP_OIDC_SECRET `
  -s 'redirectUris=["https://zulip.ceres/complete/oidc/"]' `
  -s protocol=openid-connect `
  -s standardFlowEnabled=true `
  -s publicClient=false 2>$null
Write-Host "  ✓ Zulip client created" -ForegroundColor Green

# ==========================================
# Nextcloud OIDC Client
# ==========================================
Write-Host "[3/8] Creating Nextcloud OIDC client..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r ceres `
  -s clientId=nextcloud `
  -s enabled=true `
  -s clientAuthenticatorType=client-secret `
  -s secret=$env:NEXTCLOUD_OIDC_SECRET `
  -s 'redirectUris=["https://nextcloud.ceres/apps/oidc_login/redirect"]' `
  -s protocol=openid-connect `
  -s standardFlowEnabled=true `
  -s publicClient=false 2>$null
Write-Host "  ✓ Nextcloud client created" -ForegroundColor Green

# ==========================================
# Grafana OIDC Client
# ==========================================
Write-Host "[4/8] Creating Grafana OIDC client..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r ceres `
  -s clientId=grafana `
  -s enabled=true `
  -s clientAuthenticatorType=client-secret `
  -s secret=$env:GRAFANA_OIDC_SECRET `
  -s 'redirectUris=["https://grafana.ceres/login/generic_oauth"]' `
  -s protocol=openid-connect `
  -s standardFlowEnabled=true `
  -s publicClient=false 2>$null
Write-Host "  ✓ Grafana client created" -ForegroundColor Green

# ==========================================
# Portainer OAuth Client
# ==========================================
Write-Host "[5/8] Creating Portainer OAuth client..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r ceres `
  -s clientId=portainer `
  -s enabled=true `
  -s clientAuthenticatorType=client-secret `
  -s secret=$env:PORTAINER_OIDC_SECRET `
  -s 'redirectUris=["https://portainer.ceres/"]' `
  -s protocol=openid-connect `
  -s standardFlowEnabled=true `
  -s publicClient=false 2>$null
Write-Host "  ✓ Portainer client created" -ForegroundColor Green

# ==========================================
# Mayan EDMS OIDC Client
# ==========================================
Write-Host "[6/8] Creating Mayan EDMS OIDC client..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r ceres `
  -s clientId=mayan `
  -s enabled=true `
  -s clientAuthenticatorType=client-secret `
  -s secret=$env:MAYAN_OIDC_SECRET `
  -s 'redirectUris=["https://mayan.ceres/authentication/oidc/callback/"]' `
  -s protocol=openid-connect `
  -s standardFlowEnabled=true `
  -s publicClient=false 2>$null
Write-Host "  ✓ Mayan EDMS client created" -ForegroundColor Green

# ==========================================
# Uptime Kuma OAuth Client
# ==========================================
Write-Host "[7/8] Creating Uptime Kuma OAuth client..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh create clients -r ceres `
  -s clientId=uptime `
  -s enabled=true `
  -s clientAuthenticatorType=client-secret `
  -s secret=$env:UPTIME_OIDC_SECRET `
  -s 'redirectUris=["https://uptime.ceres/auth/callback"]' `
  -s protocol=openid-connect `
  -s standardFlowEnabled=true `
  -s publicClient=false 2>$null
Write-Host "  ✓ Uptime Kuma client created" -ForegroundColor Green

# ==========================================
# Configure SMTP in Keycloak
# ==========================================
Write-Host "[8/8] Configuring SMTP in Keycloak..." -ForegroundColor Cyan
docker exec keycloak /opt/keycloak/bin/kcadm.sh update realms/ceres `
  -s 'smtpServer.host=mail.ceres' `
  -s 'smtpServer.port=587' `
  -s 'smtpServer.from=keycloak@ceres' `
  -s 'smtpServer.fromDisplayName=CERES Keycloak' `
  -s 'smtpServer.replyTo=noreply@ceres' `
  -s "smtpServer.user=keycloak@ceres" `
  -s "smtpServer.password=$env:KEYCLOAK_SMTP_PASSWORD" `
  -s 'smtpServer.starttls=true' `
  -s 'smtpServer.auth=true' 2>$null
Write-Host "  ✓ SMTP configured" -ForegroundColor Green

Write-Host ""
Write-Host "✅ Keycloak SSO configured for all services!" -ForegroundColor Green
Write-Host ""
Write-Host "OIDC Clients created:" -ForegroundColor Cyan
Write-Host "  • GitLab CE" -ForegroundColor White
Write-Host "  • Zulip" -ForegroundColor White
Write-Host "  • Nextcloud" -ForegroundColor White
Write-Host "  • Grafana" -ForegroundColor White
Write-Host "  • Portainer" -ForegroundColor White
Write-Host "  • Mayan EDMS" -ForegroundColor White
Write-Host "  • Uptime Kuma" -ForegroundColor White
Write-Host ""
