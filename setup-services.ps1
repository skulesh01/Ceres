# CERES Services Setup & Integration Script (PowerShell)
# Purpose: Auto-generate secrets, setup Keycloak clients, initialize services

param(
    [switch]$SkipDeploy = $false,
    [switch]$Force = $false
)

# Color functions
function Write-Header {
    param([string]$Text)
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠ $Text" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

function Generate-Secret {
    $bytes = [byte[]]::new(24)
    [Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}

# Main execution
Write-Header "CERES Services Setup & Integration (PowerShell)"

# 1. Check if .env exists
if (-not (Test-Path ".env")) {
    Write-Warning ".env file not found"
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Success ".env created from template"
    }
    else {
        Write-Error ".env.example not found. Please create .env manually."
        exit 1
    }
}

# 2. Load current .env
$envContent = Get-Content ".env" -Raw
$envDict = @{}
foreach ($line in $envContent -split "`n") {
    if ($line -match '^([^=]+)=(.*)$') {
        $envDict[$matches[1]] = $matches[2]
    }
}

# 3. Generate missing secrets
Write-Header "Generating OIDC Secrets"

if (-not $envDict.ContainsKey("GITLAB_OIDC_SECRET") -or $envDict["GITLAB_OIDC_SECRET"] -eq "CHANGE_ME_RANDOM_STRING_32_CHARS") {
    $secret = Generate-Secret
    $envContent = $envContent -replace "GITLAB_OIDC_SECRET=.*", "GITLAB_OIDC_SECRET=$secret"
    $envDict["GITLAB_OIDC_SECRET"] = $secret
    Write-Success "GitLab OIDC Secret: $secret"
}

if (-not $envDict.ContainsKey("MM_OIDC_SECRET") -or $envDict["MM_OIDC_SECRET"] -eq "CHANGE_ME_RANDOM_STRING_32_CHARS") {
    $secret = Generate-Secret
    $envContent = $envContent -replace "MM_OIDC_SECRET=.*", "MM_OIDC_SECRET=$secret"
    $envDict["MM_OIDC_SECRET"] = $secret
    Write-Success "Mattermost OIDC Secret: $secret"
}

if (-not $envDict.ContainsKey("REDMINE_OIDC_SECRET") -or $envDict["REDMINE_OIDC_SECRET"] -eq "CHANGE_ME_RANDOM_STRING_32_CHARS") {
    $secret = Generate-Secret
    $envContent = $envContent -replace "REDMINE_OIDC_SECRET=.*", "REDMINE_OIDC_SECRET=$secret"
    $envDict["REDMINE_OIDC_SECRET"] = $secret
    Write-Success "Redmine OIDC Secret: $secret"
}

if (-not $envDict.ContainsKey("WIKIJS_OIDC_SECRET") -or $envDict["WIKIJS_OIDC_SECRET"] -eq "CHANGE_ME_RANDOM_STRING_32_CHARS") {
    $secret = Generate-Secret
    $envContent = $envContent -replace "WIKIJS_OIDC_SECRET=.*", "WIKIJS_OIDC_SECRET=$secret"
    $envDict["WIKIJS_OIDC_SECRET"] = $secret
    Write-Success "Wiki.js OIDC Secret: $secret"
}

# Save updated .env
$envContent | Set-Content ".env"

# 4. Extract domain
$domain = if ($envDict.ContainsKey("DOMAIN")) { $envDict["DOMAIN"] } else { "ceres.local" }

# 5. Create Docker network if not exists
Write-Header "Docker Network Setup"

try {
    $networkExists = docker network inspect compose_internal 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Network 'compose_internal' already exists"
    }
}
catch {
    docker network create compose_internal --driver bridge
    Write-Success "Network 'compose_internal' created"
}

# 6. Display service URLs
Write-Header "Service Access URLs"

Write-Host "Using Domain: $domain" -ForegroundColor Yellow
Write-Host ""

Write-Host "Initial Setup (Direct Ports):" -ForegroundColor Yellow
Write-Host "  Keycloak       → http://localhost:8080"
Write-Host "  GitLab         → http://localhost:8081"
Write-Host "  Nextcloud      → http://localhost:8082"
Write-Host "  Redmine        → http://localhost:8083"
Write-Host "  Wiki.js        → http://localhost:8084"
Write-Host "  Mattermost     → http://localhost:8085"
Write-Host "  GitLab SSH     → ssh -p 2222 git@localhost"
Write-Host ""

Write-Host "Production (Reverse Proxy):" -ForegroundColor Yellow
Write-Host "  Keycloak       → https://auth.$domain"
Write-Host "  GitLab         → https://gitlab.$domain"
Write-Host "  Nextcloud      → https://nextcloud.$domain"
Write-Host "  Redmine        → https://redmine.$domain"
Write-Host "  Wiki.js        → https://wiki.$domain"
Write-Host "  Mattermost     → https://chat.$domain"
Write-Host ""

# 7. Check prerequisites
Write-Header "Checking Prerequisites"

$checksPassed = 0
$checksTotal = 0

# Check Docker
$checksTotal++
try {
    $dockerVersion = docker --version
    Write-Success "Docker installed: $dockerVersion"
    $checksPassed++
}
catch {
    Write-Error "Docker not installed"
}

# Check Docker Compose
$checksTotal++
try {
    $dcVersion = docker compose version 2>&1
    Write-Success "Docker Compose installed"
    $checksPassed++
}
catch {
    Write-Error "Docker Compose not installed"
}

Write-Host ""
Write-Host "Prerequisites check: $checksPassed/$checksTotal passed" -ForegroundColor Cyan

# 8. Deployment confirmation
Write-Header "Ready to Deploy"

Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host "  • Domain: $domain"
Write-Host "  • Database: PostgreSQL + 6 dedicated databases"
Write-Host "  • Cache: Redis with session store"
Write-Host "  • Auth: Keycloak OIDC provider"
Write-Host "  • Services: GitLab, Nextcloud, Mattermost, Redmine, Wiki.js"
Write-Host ""

if ($SkipDeploy -or $Force) {
    $deploy = if ($Force) { $true } else { $false }
}
else {
    $response = Read-Host "Deploy CERES services now? (yes/no)"
    $deploy = ($response -eq "yes" -or $response -eq "y")
}

if ($deploy) {
    Write-Header "Starting Deployment"
    
    $composeFiles = @(
        "config/compose/base.yml",
        "config/compose/core.yml",
        "config/compose/apps.yml"
    )
    
    Write-Host "Running docker-compose up -d..."
    docker-compose `
        --env-file .env `
        -f $composeFiles[0] `
        -f $composeFiles[1] `
        -f $composeFiles[2] `
        up -d
    
    Write-Success "Deployment started!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Wait 30-60 seconds for services to initialize"
    Write-Host "  2. Check status: docker-compose ps"
    Write-Host "  3. Access Keycloak: http://localhost:8080"
    Write-Host "  4. Login with: admin / (check KEYCLOAK_ADMIN_PASSWORD in .env)"
    Write-Host "  5. Configure OIDC clients for each service"
    Write-Host "  6. See SERVICES_INTEGRATION_GUIDE.md for detailed setup"
    Write-Host ""
    
    # Show service startup status
    Write-Header "Service Startup Status"
    Start-Sleep -Seconds 5
    docker-compose `
        --env-file .env `
        -f $composeFiles[0] `
        -f $composeFiles[1] `
        -f $composeFiles[2] `
        ps
}
else {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To deploy manually, run:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  docker-compose --env-file .env \" -ForegroundColor DarkYellow
    Write-Host "    -f config/compose/base.yml \" -ForegroundColor DarkYellow
    Write-Host "    -f config/compose/core.yml \" -ForegroundColor DarkYellow
    Write-Host "    -f config/compose/apps.yml \" -ForegroundColor DarkYellow
    Write-Host "    up -d" -ForegroundColor DarkYellow
    Write-Host ""
}

Write-Header "Setup Complete!"
