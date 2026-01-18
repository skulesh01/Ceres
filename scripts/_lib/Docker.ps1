<#
.SYNOPSIS
    CERES Docker Management Module
    
.DESCRIPTION
    Provides unified Docker/Compose operations for CERES platform:
    - Start/Stop services with module selection
    - Status checks and health monitoring
    - Backup/Restore of databases and volumes
    - Cleanup and maintenance operations
    
    This module consolidates functionality from:
    - start.ps1
    - status.ps1
    - cleanup.ps1
    - backup.ps1
    - restore.ps1
    
.NOTES
    Version: 3.0
    Part of CERES unified CLI
    Requires: Common.ps1, Platform.ps1, Ceres.ps1
    Cross-platform: Windows, Linux, macOS
#>

# ============================================================================
# START OPERATIONS
# ============================================================================

<#
.SYNOPSIS
    Starts CERES Docker Compose services
.PARAMETER Modules
    Array of module names (core, apps, monitoring, ops, edms, edge, tunnel, vpn)
.PARAMETER Clean
    Use monolithic docker-compose-CLEAN.yml instead of modular files
.PARAMETER SkipHealthcheck
    Skip waiting for services to be healthy
#>
function Invoke-CeresStart {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('core', 'apps', 'monitoring', 'ops', 'edms', 'edge', 'tunnel', 'vpn', IgnoreCase = $true)]
        [string[]]$Modules,
        
        [Parameter()]
        [switch]$Clean,
        
        [Parameter()]
        [switch]$SkipHealthcheck
    )
    
    $projectName = if ($env:CERES_PROJECT_NAME) { $env:CERES_PROJECT_NAME } else { "ceres" }
    $configDir = Get-CeresConfigDir
    
    Write-CeresLog "Starting CERES services..." "Info"
    Write-CeresLog "Project: $projectName" "Info"
    Write-CeresLog "Mode: $($Clean ? 'Monolithic' : 'Modular')" "Info"
    
    # Preflight checks
    Assert-DockerRunning
    
    # Initialize environment
    Initialize-CeresEnv -ConfigDir $configDir -RequiredKeys @(
        "POSTGRES_PASSWORD",
        "KEYCLOAK_ADMIN_PASSWORD",
        "NEXTCLOUD_ADMIN_PASSWORD",
        "GRAFANA_ADMIN_PASSWORD"
    )
    
    # Get compose files
    $composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean
    
    Push-Location $configDir
    try {
        Write-CeresLog "Starting containers..." "Info"
        & docker compose --env-file .env --project-name $projectName $composeFiles up -d
        
        if ($LASTEXITCODE -ne 0) {
            Write-CeresLog "Failed to start services" "Error"
            return $false
        }
        
        if (-not $SkipHealthcheck) {
            Write-CeresLog "Waiting for services to be healthy..." "Info"
            Start-Sleep -Seconds 5
            
            # Wait for critical services
            $criticalServices = @('postgres', 'redis')
            foreach ($service in $criticalServices) {
                $ready = Wait-ForService -ProjectName $projectName -ServiceName $service -TimeoutSeconds 30
                if (-not $ready) {
                    Write-CeresLog "Service '$service' did not become healthy" "Warning"
                }
            }
        }
        
        Write-CeresLog "Services started successfully!" "Success"
        
        # Show running services
        Write-Host ""
        & docker compose --env-file .env --project-name $projectName $composeFiles ps
        
        return $true
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Waits for a service to be healthy
.PARAMETER ProjectName
    Docker Compose project name
.PARAMETER ServiceName
    Name of the service to wait for
.PARAMETER TimeoutSeconds
    Maximum time to wait (default: 60)
#>
function Wait-ForService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProjectName,
        
        [Parameter(Mandatory)]
        [string]$ServiceName,
        
        [Parameter()]
        [int]$TimeoutSeconds = 60
    )
    
    $elapsed = 0
    $interval = 2
    
    while ($elapsed -lt $TimeoutSeconds) {
        $status = & docker compose -p $ProjectName ps -q $ServiceName 2>$null
        if ($status) {
            $health = & docker inspect -f '{{.State.Health.Status}}' $status 2>$null
            if ($health -eq 'healthy' -or $health -eq '') {
                # healthy or no healthcheck defined
                return $true
            }
        }
        
        Start-Sleep -Seconds $interval
        $elapsed += $interval
    }
    
    return $false
}

# ============================================================================
# STOP OPERATIONS
# ============================================================================

<#
.SYNOPSIS
    Stops CERES Docker Compose services
.PARAMETER Modules
    Specific modules to stop (default: all)
.PARAMETER Clean
    Use monolithic docker-compose-CLEAN.yml
.PARAMETER RemoveVolumes
    Also remove named volumes (DESTRUCTIVE)
.PARAMETER RemoveKnownConflicts
    Remove known stale containers from previous runs
#>
function Invoke-CeresStop {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Modules,
        
        [Parameter()]
        [switch]$Clean,
        
        [Parameter()]
        [switch]$RemoveVolumes,
        
        [Parameter()]
        [switch]$RemoveKnownConflicts
    )
    
    $projectName = if ($env:CERES_PROJECT_NAME) { $env:CERES_PROJECT_NAME } else { "ceres" }
    $configDir = Get-CeresConfigDir
    
    Write-CeresLog "Stopping CERES services..." "Info"
    
    Assert-DockerRunning
    Initialize-CeresEnv -ConfigDir $configDir -RequiredKeys @("POSTGRES_PASSWORD")
    
    $composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean
    
    Push-Location $configDir
    try {
        $downArgs = @('--remove-orphans')
        if ($RemoveVolumes) {
            Write-CeresLog "WARNING: Removing volumes (data will be lost!)" "Warning"
            $downArgs += '-v'
        }
        
        & docker compose --env-file .env --project-name $projectName $composeFiles down @downArgs
        
        if ($RemoveKnownConflicts) {
            Write-CeresLog "Removing known stale containers..." "Info"
            Remove-KnownConflictingContainer -KeepProject $projectName
        }
        
        Write-CeresLog "Services stopped" "Success"
        return $true
    }
    catch {
        Write-CeresLog "Error stopping services: $_" "Error"
        return $false
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Removes known conflicting containers from previous runs
#>
function Remove-KnownConflictingContainer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$KeepProject
    )
    
    $knownNames = @(
        "postgres", "redis", "keycloak", "nextcloud", "gitea", "mattermost",
        "grafana", "prometheus", "portainer", "nginx"
    )
    
    $all = & docker ps -a --format "{{.ID}} {{.Names}}"
    foreach ($line in $all) {
        if (-not $line) { continue }
        $parts = $line.Split(' ', 2)
        if ($parts.Count -lt 2) { continue }
        
        $id = $parts[0].Trim()
        $name = $parts[1].Trim()
        
        if ($knownNames -notcontains $name -and -not $name.StartsWith("ceres-")) {
            continue
        }
        
        # Check if it's part of our current project
        try {
            $labelsJson = & docker inspect -f '{{json .Config.Labels}}' $id 2>$null
            if ($labelsJson) {
                $labels = $labelsJson | ConvertFrom-Json
                $proj = $labels.'com.docker.compose.project'
                if ($proj -and $proj.Trim() -eq $KeepProject) {
                    continue
                }
            }
        }
        catch {
            # Continue to removal
        }
        
        Write-CeresLog "Removing stale container: $name" "Warning"
        & docker rm -f $id | Out-Null
    }
}

# ============================================================================
# STATUS OPERATIONS
# ============================================================================

<#
.SYNOPSIS
    Shows status of CERES services
.PARAMETER Modules
    Specific modules to check
.PARAMETER Detailed
    Show detailed information including resource usage
.PARAMETER Json
    Output in JSON format
#>
function Invoke-CeresStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Modules,
        
        [Parameter()]
        [switch]$Clean,
        
        [Parameter()]
        [switch]$Detailed,
        
        [Parameter()]
        [switch]$Json
    )
    
    $projectName = if ($env:CERES_PROJECT_NAME) { $env:CERES_PROJECT_NAME } else { "ceres" }
    $configDir = Get-CeresConfigDir
    
    Assert-DockerRunning
    
    if ($Json) {
        # JSON output
        $containers = & docker compose -p $projectName ps --format json 2>$null | ConvertFrom-Json
        return $containers | ConvertTo-Json -Depth 10
    }
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              CERES STATUS REPORT                                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Get container status
    Write-Host "Container Status:" -ForegroundColor Yellow
    Write-Host "════════════════" -ForegroundColor Yellow
    
    $psOutput = & docker compose -p $projectName ps 2>$null
    if ($psOutput) {
        $psOutput | ForEach-Object { Write-Host $_ }
    }
    else {
        Write-Host "  No running containers found" -ForegroundColor Red
    }
    
    if ($Detailed) {
        Write-Host "`nResource Usage:" -ForegroundColor Yellow
        Write-Host "═══════════════" -ForegroundColor Yellow
        
        $stats = & docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" $(& docker compose -p $projectName ps -q) 2>$null
        if ($stats) {
            $stats | ForEach-Object { Write-Host $_ }
        }
    }
    
    Write-Host ""
}

# ============================================================================
# BACKUP OPERATIONS
# ============================================================================

<#
.SYNOPSIS
    Creates backup of CERES data
.PARAMETER Modules
    Modules to backup (affects which volumes are backed up)
.PARAMETER Clean
    Use monolithic compose file
#>
function Invoke-CeresBackup {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Modules,
        
        [Parameter()]
        [switch]$Clean
    )
    
    $projectName = if ($env:CERES_PROJECT_NAME) { $env:CERES_PROJECT_NAME } else { "ceres" }
    $configDir = Get-CeresConfigDir
    $composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean
    
    $BACKUP_DIR = Join-Path $configDir "backups"
    $TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
    $POSTGRES_BACKUP = "$BACKUP_DIR\postgres_backup_$TIMESTAMP.sql"
    $REDIS_BACKUP = "$BACKUP_DIR\redis_backup_$TIMESTAMP.rdb"
    $VOLUMES_BACKUP = "$BACKUP_DIR\volumes_backup_$TIMESTAMP.tar.gz"
    $LOG_FILE = "$BACKUP_DIR\backup_$TIMESTAMP.log"
    
    # Create backup directory
    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
    }
    
    Write-CeresLog "Starting backup..." "Info"
    Write-CeresLog "Timestamp: $TIMESTAMP" "Info"
    
    Push-Location $configDir
    try {
        # 1. PostgreSQL Backup
        Write-CeresLog "Backing up PostgreSQL..." "Info"
        & docker compose --env-file .env --project-name $projectName $composeFiles exec -T postgres pg_dump `
            -U postgres -d ceres_db --no-owner --no-privileges --no-password | Out-File -FilePath $POSTGRES_BACKUP -Encoding UTF8
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $POSTGRES_BACKUP)) {
            $size = (Get-Item $POSTGRES_BACKUP).Length / 1MB
            Write-CeresLog "PostgreSQL backup: $([math]::Round($size, 2)) MB" "Success"
        }
        else {
            Write-CeresLog "PostgreSQL backup failed" "Error"
            return $false
        }
        
        # 2. Redis Backup
        Write-CeresLog "Backing up Redis..." "Info"
        & docker compose --env-file .env --project-name $projectName $composeFiles exec -T redis redis-cli BGSAVE | Out-Null
        Start-Sleep -Seconds 2
        
        $redisContainerId = (& docker compose --env-file .env --project-name $projectName $composeFiles ps -q redis).Trim()
        if ($redisContainerId) {
            & docker cp "$redisContainerId`:/data/dump.rdb" $REDIS_BACKUP | Out-Null
            $size = (Get-Item $REDIS_BACKUP).Length / 1MB
            Write-CeresLog "Redis backup: $([math]::Round($size, 2)) MB" "Success"
        }
        else {
            Write-CeresLog "Redis container not found" "Warning"
        }
        
        # 3. Volumes Backup
        Write-CeresLog "Backing up volumes..." "Info"
        $volumeSuffixes = @(
            "pg_data", "redis_data", "nextcloud_data", "nextcloud_config",
            "gitea_data", "mattermost_data", "mattermost_logs", "mattermost_config",
            "prometheus_data", "grafana_data", "portainer_data", "loki_data", "uptime_kuma_data"
        )
        
        $volumeMount = @()
        $tarPaths = [System.Collections.Generic.List[string]]::new()
        
        foreach ($suffix in $volumeSuffixes) {
            $volumeName = "${projectName}_${suffix}"
            try {
                & docker volume inspect $volumeName 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    $volumeMount += @("-v", "$volumeName`:/$suffix`:ro")
                    $tarPaths.Add($suffix)
                }
            }
            catch { continue }
        }
        
        if ($tarPaths.Count -gt 0) {
            $backupAbs = (Resolve-Path $BACKUP_DIR).Path
            $volumeMount += @("-v", "$backupAbs`:/backup:rw")
            $paths = [string]::Join(' ', $tarPaths)
            
            & docker run --rm $volumeMount alpine:latest sh -c "tar czf /backup/volumes_backup_$TIMESTAMP.tar.gz --ignore-failed-read -C / $paths 2>/dev/null || true" | Out-Null
            
            if (Test-Path $VOLUMES_BACKUP) {
                $size = (Get-Item $VOLUMES_BACKUP).Length / 1MB
                Write-CeresLog "Volumes backup: $([math]::Round($size, 2)) MB" "Success"
            }
        }
        
        Write-CeresLog "Backup completed successfully!" "Success"
        Write-CeresLog "Location: $BACKUP_DIR" "Info"
        return $true
    }
    catch {
        Write-CeresLog "Backup failed: $_" "Error"
        return $false
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# RESTORE OPERATIONS
# ============================================================================

<#
.SYNOPSIS
    Restores CERES data from backup
.PARAMETER Timestamp
    Backup timestamp to restore (format: yyyyMMdd_HHmmss)
.PARAMETER Force
    Skip confirmation prompt
#>
function Invoke-CeresRestore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Timestamp,
        
        [Parameter()]
        [string[]]$Modules,
        
        [Parameter()]
        [switch]$Clean,
        
        [Parameter()]
        [switch]$Force
    )
    
    $projectName = if ($env:CERES_PROJECT_NAME) { $env:CERES_PROJECT_NAME } else { "ceres" }
    $configDir = Get-CeresConfigDir
    $composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean
    
    $BACKUP_DIR = Join-Path $configDir "backups"
    $POSTGRES_BACKUP = "$BACKUP_DIR\postgres_backup_$Timestamp.sql"
    $REDIS_BACKUP = "$BACKUP_DIR\redis_backup_$Timestamp.rdb"
    $VOLUMES_BACKUP = "$BACKUP_DIR\volumes_backup_$Timestamp.tar.gz"
    
    # Verify backup files
    Write-CeresLog "Verifying backup files..." "Info"
    foreach ($file in @($POSTGRES_BACKUP, $REDIS_BACKUP)) {
        if (-not (Test-Path $file)) {
            Write-CeresLog "Missing backup file: $file" "Error"
            return $false
        }
    }
    
    # Confirm restore
    if (-not $Force) {
        Write-Host "`n⚠️  WARNING: This will overwrite all current data!" -ForegroundColor Yellow
        Write-Host "   Services will be stopped and data restored from backup." -ForegroundColor Yellow
        $response = Read-Host "`nContinue with restore? (yes/no)"
        
        if ($response -ne "yes") {
            Write-CeresLog "Restore cancelled" "Info"
            return $false
        }
    }
    
    Push-Location $configDir
    try {
        # Stop services
        Write-CeresLog "Stopping services..." "Info"
        & docker compose --env-file .env --project-name $projectName $composeFiles down --remove-orphans 2>&1 | Out-Null
        
        # Start databases
        Write-CeresLog "Starting database services..." "Info"
        & docker compose --env-file .env --project-name $projectName $composeFiles up -d postgres redis 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        
        # Restore PostgreSQL
        Write-CeresLog "Restoring PostgreSQL..." "Info"
        $pgDump = Get-Content -Path $POSTGRES_BACKUP -Raw
        $pgDump | & docker compose --env-file .env --project-name $projectName $composeFiles exec -T postgres psql `
            -U postgres -d ceres_db --no-password 2>&1 | Out-Null
        Write-CeresLog "PostgreSQL restored" "Success"
        
        # Restore Redis
        Write-CeresLog "Restoring Redis..." "Info"
        $redisContainerId = (& docker compose --env-file .env --project-name $projectName $composeFiles ps -q redis).Trim()
        & docker cp $REDIS_BACKUP "$redisContainerId`:/data/dump.rdb" 2>&1 | Out-Null
        & docker compose --env-file .env --project-name $projectName $composeFiles restart redis 2>&1 | Out-Null
        Write-CeresLog "Redis restored" "Success"
        
        # Start all services
        Write-CeresLog "Starting all services..." "Info"
        & docker compose --env-file .env --project-name $projectName $composeFiles up -d 2>&1 | Out-Null
        
        Write-CeresLog "Restore completed successfully!" "Success"
        return $true
    }
    catch {
        Write-CeresLog "Restore failed: $_" "Error"
        return $false
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Colored logging helper
#>
function Write-CeresLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }
    
    $prefix = switch ($Level) {
        'Info'    { 'ℹ️ ' }
        'Success' { '✅' }
        'Warning' { '⚠️ ' }
        'Error'   { '❌' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $colors[$Level]
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-CeresStart',
    'Invoke-CeresStop',
    'Invoke-CeresStatus',
    'Invoke-CeresBackup',
    'Invoke-CeresRestore'
)
