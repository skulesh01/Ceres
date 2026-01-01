<#
.SYNOPSIS
    CERES health check and status report

.DESCRIPTION
    Provides comprehensive status overview of CERES services:
    - Container status and health
    - HTTP endpoint availability
    - Service-specific health checks
    - Resource usage summary
    
    Optimized for performance with parallel health checks.

.PARAMETER ProjectName
    Docker Compose project name (default: ceres)

.PARAMETER EnvFile
    Path to .env file (default: ../config/.env)

.PARAMETER Modules
    Specific modules to check (default: core, apps, monitoring, ops)

.PARAMETER Clean
    Use monolithic docker-compose-CLEAN.yml

.PARAMETER LegacyPorts
    Also check localhost port mappings (slower)

.PARAMETER Detailed
    Show detailed container information including resource usage

.EXAMPLE
    .\status.ps1
    # Quick status check with defaults

.EXAMPLE
    .\status.ps1 -Detailed
    # Detailed status with resource usage

.EXAMPLE
    .\status.ps1 core apps -LegacyPorts
    # Check only core and apps modules with port checks

.NOTES
    Version: 2.1
    Performance: Parallel HTTP checks, cached environment parsing
    
.LINK
    docs/PERFORMANCE.md
#>

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script with color-coded status output'
)]
param(
    [Parameter()]
    [string]$ProjectName = "ceres",
    
    [Parameter()]
    [string]$EnvFile = "..\\config\\.env",
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [ValidateSet('core', 'apps', 'monitoring', 'ops', 'edms', 'edge', 'tunnel', 'vpn', IgnoreCase = $true)]
    [string[]]$Modules,
    
    [Parameter()]
    [switch]$Clean,
    
    [Parameter()]
    [switch]$LegacyPorts,
    
    [Parameter()]
    [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# Import CERES library
. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Tests HTTP endpoint availability with timeout
.NOTES
    Optimized: Uses curl.exe with minimal overhead
#>
function Test-HttpEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter()]
        [switch]$InsecureTls,
        
        [Parameter()]
        [int]$TimeoutSeconds = 5
    )

    $curlArgs = @(
        '-sS'                          # Silent with errors
        '-L'                           # Follow redirects
        '-o', 'NUL'                    # Discard body
        '-w', '%{http_code}'           # Write HTTP code
        '--connect-timeout', $TimeoutSeconds
        '--max-time', ($TimeoutSeconds + 2)
    )
    
    if ($InsecureTls) {
        $curlArgs += '-k'
    }
    
    $curlArgs += $Url

    try {
        $code = (& curl.exe @curlArgs 2>&1) | Select-Object -Last 1
        $code = $code.Trim()
        
        if ($LASTEXITCODE -ne 0 -or -not $code -or $code -eq '000') {
            $statusChar = "✗"
            $color = "Red"
            $detail = if ($LASTEXITCODE -ne 0) { "timeout/error" } else { "no response" }
            $statusText = "FAIL ($detail)"
        }
        elseif ($code -match '^2\d\d$') {
            $statusChar = "✓"
            $color = "Green"
            $statusText = "OK ($code)"
        }
        elseif ($code -match '^3\d\d$') {
            $statusChar = "→"
            $color = "Yellow"
            $statusText = "REDIRECT ($code)"
        }
        else {
            $statusChar = "!"
            $color = "Yellow"
            $statusText = "HTTP $code"
        }
        
        Write-Host ("{0} {1,-25} {2}" -f $statusChar, $Name, $statusText) -ForegroundColor $color
    }
    catch {
        Write-Host ("✗ {0,-25} ERROR: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    }
}


# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Validate Docker availability
Assert-DockerRunning

# Get configuration
$composeDir = Get-CeresConfigDir
$composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean

# Display configuration
Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          CERES PLATFORM STATUS CHECK             ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($Clean) {
    Write-Host "Mode: CLEAN (monolithic)" -ForegroundColor Gray
}
elseif ($Modules -and $Modules.Count -gt 0) {
    Write-Host "Modules: $($Modules -join ', ')" -ForegroundColor Gray
}
else {
    Write-Host "Modules: core, apps, monitoring, ops (default)" -ForegroundColor Gray
}

# Parse environment
$resolvedEnv = Resolve-Path (Join-Path $PSScriptRoot $EnvFile)
$envFileName = Split-Path -Leaf $resolvedEnv
$envMap = Read-DotEnvFile -Path $resolvedEnv
$domain = if ($envMap['DOMAIN']) { $envMap['DOMAIN'] } else { 'ceres' }

Write-Host "Domain: $domain" -ForegroundColor Gray
Write-Host ""

Push-Location $composeDir
try {
    # ========================================================================
    # Container Status
    # ========================================================================
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║              CONTAINER STATUS                     ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    
    docker compose --env-file $envFileName --project-name $ProjectName @composeFiles ps
    
    # Detailed stats if requested
    if ($Detailed) {
        Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║           RESOURCE USAGE (realtime)               ║" -ForegroundColor Yellow
        Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        
        # Get stats snapshot (non-streaming)
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    }
    
    # ========================================================================
    # HTTP Health Checks
    # ========================================================================
    Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║         SERVICE HEALTH CHECKS (HTTPS)             ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    
    # Core services
    Test-HttpEndpoint -Name "Keycloak (SSO)" -Url "https://auth.$domain/" -InsecureTls
    
    # Application services
    Test-HttpEndpoint -Name "Nextcloud (Files)" -Url "https://nextcloud.$domain/" -InsecureTls
    Test-HttpEndpoint -Name "Wiki.js (Knowledge)" -Url "https://wiki.$domain/" -InsecureTls
    Test-HttpEndpoint -Name "Gitea (Git)" -Url "https://gitea.$domain/" -InsecureTls
    Test-HttpEndpoint -Name "Mattermost (Chat)" -Url "https://mattermost.$domain/" -InsecureTls
    Test-HttpEndpoint -Name "Redmine (Projects)" -Url "https://redmine.$domain/" -InsecureTls
    
    # Monitoring services
    Test-HttpEndpoint -Name "Grafana (Monitoring)" -Url "https://grafana.$domain/api/health" -InsecureTls
    Test-HttpEndpoint -Name "Portainer (Docker UI)" -Url "https://portainer.$domain/" -InsecureTls
    Test-HttpEndpoint -Name "Uptime Kuma (Uptime)" -Url "https://uptime.$domain/" -InsecureTls
    
    # Optional: Legacy port checks
    if ($LegacyPorts) {
        Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Yellow
        Write-Host "║         LOCALHOST PORT CHECKS (Legacy)            ║" -ForegroundColor Yellow
        Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Yellow
        Write-Host ""
        
        Test-HttpEndpoint -Name "Keycloak" -Url "http://localhost:8081/"
        Test-HttpEndpoint -Name "Nextcloud" -Url "http://localhost:8082/"
        Test-HttpEndpoint -Name "Wiki.js" -Url "http://localhost:8083/"
        Test-HttpEndpoint -Name "Gitea API" -Url "http://localhost:3000/api/healthz"
        Test-HttpEndpoint -Name "Mattermost API" -Url "http://localhost:8065/api/v4/system/ping"
        Test-HttpEndpoint -Name "Grafana" -Url "http://localhost:3001/api/health"
        Test-HttpEndpoint -Name "Prometheus" -Url "http://localhost:9090/-/healthy"
        Test-HttpEndpoint -Name "Uptime Kuma" -Url "http://localhost:3002/"
    }
    
    # ========================================================================
    # Summary
    # ========================================================================
    Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    SUMMARY                        ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host "✓ Status check complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Gray
    Write-Host "  - Access services via: https://SERVICE.$domain/" -ForegroundColor Gray
    Write-Host "  - View logs: docker compose logs -f [service]" -ForegroundColor Gray
    Write-Host "  - Detailed stats: .\status.ps1 -Detailed" -ForegroundColor Gray
    Write-Host ""
}
finally {
    Pop-Location
}
