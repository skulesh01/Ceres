# Generate mTLS certificates for CERES services using Vault PKI

param(
    [string]$VaultAddr = "http://localhost:8200",
    [string]$VaultToken = $env:VAULT_TOKEN,
    [string]$CertsDir = ".\certs"
)

if (-not $VaultToken) {
    Write-Host "❌ VAULT_TOKEN environment variable not set" -ForegroundColor Red
    exit 1
}

Write-Host "`n🔐 Generating mTLS certificates for CERES services" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Vault: $VaultAddr"
Write-Host "Output: $CertsDir"
Write-Host ""

# Create certificates directory
New-Item -ItemType Directory -Force -Path $CertsDir | Out-Null

# Set Vault environment
$env:VAULT_ADDR = $VaultAddr
$env:VAULT_TOKEN = $VaultToken

# Services that need certificates
$services = @(
    "postgres.ceres.local",
    "redis.ceres.local",
    "keycloak.ceres.local",
    "nextcloud.ceres.local",
    "gitea.ceres.local",
    "mattermost.ceres.local",
    "redmine.ceres.local",
    "wikijs.ceres.local",
    "grafana.ceres.local",
    "prometheus.ceres.local",
    "loki.ceres.local",
    "caddy.ceres.local",
    "portainer.ceres.local"
)

# Generate certificates for each service
foreach ($service in $services) {
    Write-Host "✓ Generating certificate for $service..." -ForegroundColor Green
    
    $serviceName = $service.Split('.')[0]
    
    # Request certificate from Vault PKI
    $certJson = vault write -format=json pki/issue/ceres-services `
        common_name="$service" `
        ttl="8760h" `
        alt_names="$serviceName,localhost" `
        ip_sans="127.0.0.1"
    
    $certData = $certJson | ConvertFrom-Json
    
    # Extract certificate, key, and CA
    $certData.data.certificate | Out-File -FilePath "$CertsDir\$serviceName.crt" -Encoding ASCII
    $certData.data.private_key | Out-File -FilePath "$CertsDir\$serviceName.key" -Encoding ASCII
    $certData.data.issuing_ca | Out-File -FilePath "$CertsDir\$serviceName-ca.crt" -Encoding ASCII
    
    # Create combined cert+ca file
    Get-Content "$CertsDir\$serviceName.crt", "$CertsDir\$serviceName-ca.crt" | `
        Set-Content "$CertsDir\$serviceName-bundle.crt"
    
    Write-Host "  ✓ Certificate: $CertsDir\$serviceName.crt" -ForegroundColor Gray
    Write-Host "  ✓ Key: $CertsDir\$serviceName.key" -ForegroundColor Gray
    Write-Host "  ✓ CA: $CertsDir\$serviceName-ca.crt" -ForegroundColor Gray
}

# Get root CA certificate
Write-Host "`n✓ Fetching Root CA certificate..." -ForegroundColor Green
vault read -field=certificate pki/cert/ca | Out-File -FilePath "$CertsDir\root-ca.crt" -Encoding ASCII

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     mTLS CERTIFICATES GENERATED SUCCESSFULLY!              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📁 Certificates saved to: $CertsDir`n"
Write-Host "Next steps:"
Write-Host "  1. Update docker-compose files to mount certificates"
Write-Host "  2. Configure services to use mTLS"
Write-Host "  3. Restart services"
Write-Host "`nExample for PostgreSQL:"
Write-Host "  volumes:"
Write-Host "    - $CertsDir\postgres.crt:/var/lib/postgresql/server.crt:ro"
Write-Host "    - $CertsDir\postgres.key:/var/lib/postgresql/server.key:ro"
Write-Host "    - $CertsDir\root-ca.crt:/var/lib/postgresql/root.crt:ro"
