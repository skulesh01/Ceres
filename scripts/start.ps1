<#
.SYNOPSIS
    CERES service starter - Launches Docker Compose services with module selection

.DESCRIPTION
    Orchestrates CERES platform startup with following features:
    - Automatic environment initialization from .env.example
    - Secure secret generation for missing/placeholder values
    - Modular service composition (default) or monolithic mode (-Clean)
    - Docker daemon validation and auto-start
    - Keycloak SSO bootstrap after services start
    
    Architecture:
    - Base services: PostgreSQL, Redis (always included)
    - Modular services: core, apps, monitoring, ops, edms, edge, tunnel, vpn
    - Default modules: core, apps, monitoring, ops
    
.PARAMETER Modules
    Array of module names to start. Overrides defaults.
    Valid modules: core, apps, monitoring, ops, edms, edge, tunnel, vpn
    
.PARAMETER Clean
    Use monolithic docker-compose-CLEAN.yml instead of modular compose files
    
.EXAMPLE
    .\start.ps1
    # Starts default modules: core, apps, monitoring, ops
    
.EXAMPLE
    .\start.ps1 core apps
    # Starts only core and apps modules
    
.EXAMPLE
    .\start.ps1 core apps monitoring ops vpn
    # Starts default modules plus VPN
    
.EXAMPLE
    .\start.ps1 -Clean
    # Uses monolithic docker-compose-CLEAN.yml
    
.NOTES
    Version: 2.1
    Requires: PowerShell 5.1+, Docker Desktop
    
    SOLID Principles:
    - Single Responsibility: Each section has clear purpose
    - Open/Closed: Extensible via modules without modifying core logic
    - Dependency Inversion: Uses Ceres.ps1 library abstractions
    
    Security:
    - Auto-generates cryptographically secure secrets
    - No secrets in code or version control
    - Validates Docker availability before operations
    
.LINK
    https://github.com/yourusername/ceres
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script with color-coded user output'
)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [ValidateSet('core', 'apps', 'monitoring', 'ops', 'edms', 'edge', 'tunnel', 'vpn', IgnoreCase = $true)]
    [string[]]$Modules,
    
    [Parameter()]
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Import CERES core library
. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

# ============================================================================
# CONFIGURATION
# ============================================================================

$projectName = if ($env:CERES_PROJECT_NAME) { $env:CERES_PROJECT_NAME } else { "ceres" }
$configDir = Get-CeresConfigDir

# ============================================================================
# HELPER FUNCTIONS (Script-specific, not in shared library)
# ============================================================================

# ============================================================================
# HELPER FUNCTIONS (Script-specific, not in shared library)
# ============================================================================

<#
.SYNOPSIS
    Sets or updates a key-value pair in .env file
.DESCRIPTION
    Updates existing key or appends new one.
    Uses regex for safe replacement.
.NOTES
    Single Responsibility: Only modifies env file entries
#>
function Set-DotEnvValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $content = Get-Content -Path $Path -Raw -ErrorAction Stop
    $escapedKey = [regex]::Escape($Key)
    
    if ([regex]::IsMatch($content, "(?m)^${escapedKey}=")) {
        # Key exists - replace value
        $content = [regex]::Replace(
            $content,
            "(?m)^${escapedKey}=.*$",
            { param($m) "${Key}=${Value}" }
        )
    }
    else {
        # Key doesn't exist - append
        $content = $content.TrimEnd() + "`r`n${Key}=${Value}`r`n"
    }

    Set-Content -Path $Path -Value $content -NoNewline -ErrorAction Stop
}

<#
.SYNOPSIS
    Performs preflight checks before starting services
.DESCRIPTION
    Validates:
    - Docker version (>= 24.x)
    - Docker Compose version (>= 2.20)
    - Available disk space (warns if < 5GB)
.NOTES
    Interface Segregation: Focused validation only
#>
function Invoke-CeresPreflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigDir,
        
        [Parameter()]
        [bool]$UseEdge,
        
        [Parameter()]
        [bool]$UseMonitoring,
        
        [Parameter()]
        [bool]$UseOps,
        
        [Parameter()]
        [bool]$UseApps
    )

    Write-Host "Preflight: checking environment..." -ForegroundColor Cyan

    # Docker Server Version
    $serverVerRaw = (& docker version --format '{{.Server.Version}}' 2>$null)
    if (-not $serverVerRaw) {
        throw "Docker is not available (version check failed)"
    }
    
    $serverVer = [version]($serverVerRaw -replace '[^0-9\.]', '')
    if ($serverVer.Major -lt 24) {
        throw "Docker Server $serverVerRaw is too old; require 24.x or newer"
    }
    Write-Verbose "Docker Server version: $serverVerRaw ✓"

    # Docker Compose Version
    $composeVerRaw = (& docker compose version --short 2>$null)
    if (-not $composeVerRaw) {
        throw "Docker Compose V2 plugin is missing"
    }
    
    $composeVer = [version]($composeVerRaw -replace '[^0-9\.]', '')
    if ($composeVer.Major -lt 2 -or ($composeVer.Major -eq 2 -and $composeVer.Minor -lt 20)) {
        throw "Docker Compose $composeVerRaw is too old; require 2.20 or newer"
    }
    Write-Verbose "Docker Compose version: $composeVerRaw ✓"

    # Disk Space Warning
    $drive = (Get-Item $ConfigDir).PSDrive
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    
    if ($drive.Free -lt 5GB) {
        Write-Warning "Low disk space on $($drive.Name): only ${freeGB} GB free (recommend 10GB+)"
    }
    else {
        Write-Verbose "Disk space: ${freeGB} GB free ✓"
    }

    Write-Host "✓ Preflight checks passed" -ForegroundColor Green
}

    # .env sanity
    $envPath = Join-Path $ConfigDir '.env'
    if (-not (Test-Path $envPath)) { throw "config/.env is missing (after init)." }
    $hasPlaceholders = Select-String -Path $envPath -Pattern 'CHANGE_ME' -SimpleMatch -ErrorAction SilentlyContinue
    if ($hasPlaceholders) {
        throw "config/.env still contains CHANGE_ME placeholders."
    }

    # Port collisions when edge is enabled
    if ($UseEdge) {
        foreach ($port in 80,443) {
            $binds = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue
            if ($binds) {
                throw "Port $port is already in use (edge requires it). Free the port or disable edge."
            }
        }
    }

    # Quick reminder about memory when monitoring/ops/apps chosen
    if ($UseMonitoring -or $UseOps -or $UseApps) {
        $memGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB,1)
        if ($memGB -lt 8) {
            Write-Warning "Total RAM ${memGB}GB — consider starting only core/apps first."
        }
    }

    Write-Host "Preflight: ok." -ForegroundColor Green
}

function Wait-CeresHealth {
    param(
        [string]$ProjectName,
        [string[]]$Services,
        [int]$TimeoutSec = 240
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $missing = @()
    $unhealthy = @()

    $existing = & docker ps --format '{{.Names}}'

    foreach ($svc in $Services) {
        $name = "${ProjectName}-${svc}-1"
        if (-not ($existing -contains $name)) { continue }

        while ((Get-Date) -lt $deadline) {
            $state = (& docker inspect -f '{{.State.Health.Status}}' $name 2>$null)
            if (-not $state -or $state -eq 'healthy') { break }
            Start-Sleep -Seconds 5
        }

        $stateFinal = (& docker inspect -f '{{.State.Health.Status}}' $name 2>$null)
        if ($stateFinal -and $stateFinal -ne 'healthy') {
            $unhealthy += "$svc ($stateFinal)"
        }
    }

    if ($unhealthy.Count -gt 0) {
        Write-Warning ("Healthcheck timeout: " + ($unhealthy -join ', '))
    }
}

Push-Location $configDir
try {
    Assert-DockerRunning
    Initialize-CeresEnv -ConfigDir $configDir -RequiredKeys @(
        "POSTGRES_PASSWORD",
        "KEYCLOAK_ADMIN_PASSWORD",
        "NEXTCLOUD_ADMIN_PASSWORD",
        "GRAFANA_ADMIN_PASSWORD",
        "GRAFANA_OIDC_CLIENT_SECRET",
        "WIKIJS_OIDC_CLIENT_SECRET"
    )

    $useTunnel = $false
    $useEdge = $false
    $useVpn = $false
    $useEdms = $false
    if (-not $Clean -and $Modules) {
        foreach ($m in $Modules) {
            if ($m -and $m.ToLowerInvariant() -eq 'tunnel') { $useTunnel = $true }
            if ($m -and $m.ToLowerInvariant() -eq 'edge') { $useEdge = $true }
            if ($m -and $m.ToLowerInvariant() -eq 'vpn') { $useVpn = $true }
            if ($m -and $m.ToLowerInvariant() -eq 'edms') { $useEdms = $true }
        }
    }

    if ($useEdms) {
        Initialize-CeresEnv -ConfigDir $configDir -RequiredKeys @(
            "MAYAN_REDIS_PASSWORD",
            "MAYAN_RABBITMQ_PASSWORD"
        )
    }

    if ($useTunnel) {
        $envMap = Read-DotEnvFile -Path (Join-Path $configDir '.env')
        $token = $envMap['CLOUDFLARED_TOKEN']
        if (-not $token -or $token -eq 'CHANGE_ME') {
            throw "Module 'tunnel' selected but CLOUDFLARED_TOKEN is not set in config/.env. Create a Cloudflare Tunnel and paste its token."
        }

        $caddyTunnel = Join-Path $configDir 'caddy\Caddyfile.tunnel'
        $caddyActive = Join-Path $configDir 'caddy\Caddyfile'
        if (Test-Path $caddyTunnel) {
            Copy-Item -Force $caddyTunnel $caddyActive
            Write-Host 'Edge: using Caddyfile.tunnel (Cloudflare origin HTTP).' -ForegroundColor Gray
        }
    }

    if ($useVpn) {
        Initialize-CeresEnv -ConfigDir $configDir -RequiredKeys @(
            "WG_EASY_PASSWORD"
        )
        $envPath = Join-Path $configDir '.env'
        $envMap = Read-DotEnvFile -Path $envPath
        $wgHost = $envMap['WG_HOST']
        if (-not $wgHost -or $wgHost -eq 'CHANGE_ME') {
            throw "Module 'vpn' selected but WG_HOST is not set in config/.env. Set WG_HOST to your public IP or DNS name that employees will reach from the Internet."
        }

        $wgPass = $envMap['WG_EASY_PASSWORD']
        if (-not $wgPass -or $wgPass -eq 'CHANGE_ME') {
            throw "Module 'vpn' selected but WG_EASY_PASSWORD is not set in config/.env (it should be auto-generated)."
        }

        $wgHash = $envMap['WG_EASY_PASSWORD_HASH']

        # Docker Compose interpolates '$VAR' and '${VAR}' patterns even inside substituted values.
        # bcrypt hashes contain '$' (e.g. $2a$12$...), so we must escape '$' as '$$' in config/.env.
        if ($wgHash -and $wgHash -ne 'CHANGE_ME' -and $wgHash.StartsWith('$')) {
            $wgHashEscaped = $wgHash.Replace('$', '$$')
            if ($wgHashEscaped -ne $wgHash) {
                Write-Host 'VPN: escaping WG_EASY_PASSWORD_HASH for Docker Compose ($ -> $$)...' -ForegroundColor Gray
                Set-DotEnvValue -Path $envPath -Key 'WG_EASY_PASSWORD_HASH' -Value $wgHashEscaped
                $wgHash = $wgHashEscaped
            }
        }

        if (-not $wgHash -or $wgHash -eq 'CHANGE_ME') {
            Write-Host "VPN: generating WG_EASY_PASSWORD_HASH for wg-easy (value hidden)..." -ForegroundColor Cyan
            $out = (& docker run --rm ghcr.io/wg-easy/wg-easy:latest wgpw $wgPass) | Select-Object -First 1
            if (-not $out) {
                throw "Failed to generate password hash via wg-easy 'wgpw' helper."
            }

            if ($out -match "PASSWORD_HASH='(.+)'\s*$") {
                $hash = $Matches[1]
            } else {
                throw "Unexpected wgpw output: $out"
            }

            $hashEscaped = $hash.Replace('$', '$$')
            Set-DotEnvValue -Path $envPath -Key 'WG_EASY_PASSWORD_HASH' -Value $hashEscaped
        }
    }

    $composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean

    # Normalize module flags for preflight/health
    $selectedModules = if (-not $Clean -and $Modules -and $Modules.Count -gt 0) { $Modules } else { @('core','apps','monitoring','ops') }
    $selectedLower = $selectedModules | ForEach-Object { $_.ToLowerInvariant() }
    $UseMonitoring = $selectedLower -contains 'monitoring'
    $UseOps = $selectedLower -contains 'ops'
    $UseApps = $selectedLower -contains 'apps'

    Invoke-CeresPreflight -ConfigDir $configDir -UseEdge:$useEdge -UseMonitoring:$UseMonitoring -UseOps:$UseOps -UseApps:$UseApps

    Write-Host "Starting CERES (project: $projectName)..." -ForegroundColor Cyan
    & docker compose --env-file .env --project-name $projectName $composeFiles up -d

    # Wait for key services to become healthy (best-effort)
    $healthSet = @('postgres','redis','keycloak','nextcloud','gitea','mattermost','redmine','wikijs')
    if ($UseMonitoring) { $healthSet += @('prometheus','grafana') }
    if ($UseOps) { $healthSet += @('portainer','uptime-kuma') }
    if ($useEdge) { $healthSet += 'caddy' }
    Wait-CeresHealth -ProjectName $projectName -Services $healthSet -TimeoutSec 240

    if ($useEdge) {
        Write-Host "Edge: reloading Caddy configuration (best-effort)..." -ForegroundColor Gray
        try {
            $caddyContainer = ("{0}-caddy-1" -f $projectName)
            & docker exec $caddyContainer caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile | Out-Null
        }
        catch {
            Write-Host "Caddy reload skipped/failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    Write-Host "Container status:" -ForegroundColor Cyan
    & docker compose --env-file .env --project-name $projectName $composeFiles ps

    $bootstrap = Join-Path $PSScriptRoot "keycloak-bootstrap.ps1"
    if (Test-Path $bootstrap) {
        Write-Host "Bootstrapping Keycloak clients (best-effort)..." -ForegroundColor Cyan
        try {
            if ($useEdge -and -not $useTunnel) {
                & $bootstrap -EnvFile (Join-Path $configDir ".env") -ProjectName $projectName -InsecureTls
            } else {
                & $bootstrap -EnvFile (Join-Path $configDir ".env") -ProjectName $projectName
            }
        }
        catch {
            Write-Host "Keycloak bootstrap skipped/failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    Write-Host "Done." -ForegroundColor Green
    Write-Host "Hint: .\\start.ps1 core apps    OR    .\\start.ps1 -Clean" -ForegroundColor Gray
}
finally {
    Pop-Location
}
