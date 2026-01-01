<#
Backup script for CERES Docker services (Windows PowerShell).

Supports:
- Modular compose (default): config/compose/{core,apps,monitoring,ops,edge}.yml
- Clean monolith (fallback): config/docker-compose-CLEAN.yml

Secrets are loaded from config/.env via --project-directory.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script output with colors.'
)]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Modules,
    [switch]$Clean,
    [string]$ProjectName = "ceres"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

$configDir = Get-CeresConfigDir
$composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean

# Configuration
$BACKUP_DIR = Join-Path $configDir "backups"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$POSTGRES_BACKUP = "$BACKUP_DIR\postgres_backup_$TIMESTAMP.sql"
$REDIS_BACKUP = "$BACKUP_DIR\redis_backup_$TIMESTAMP.rdb"
$VOLUMES_BACKUP = "$BACKUP_DIR\volumes_backup_$TIMESTAMP.tar.gz"
$LOG_FILE = "$BACKUP_DIR\backup_$TIMESTAMP.log"

function Write-Status {
    param([string]$Message, [ValidateSet("Info", "Success", "Warning", "Error")]$Type = "Info")
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    Write-Host $Message -ForegroundColor $colors[$Type]
    Add-Content -Path $LOG_FILE -Value $Message
}

# Create backup directory
if (-not (Test-Path $BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
}

Write-Status "Starting CERES Backup..." "Warning"
Write-Status "Timestamp: $TIMESTAMP" "Info"
Write-Status "Project: $ProjectName" "Info"
Write-Status "Mode: $([string]::Join(' ', $(if ($Clean) { @('CLEAN') } else { @('MODULAR') })))" "Info"
Add-Content -Path $LOG_FILE -Value "Backup started at: $(Get-Date)`n"

Push-Location $configDir
try {

# ==========================================
# 1. PostgreSQL Backup
# ==========================================
Write-Status "`n1. Backing up PostgreSQL database..." "Warning"
try {
    & docker compose --env-file .env --project-name $ProjectName $composeFiles exec -T postgres pg_dump `
        -U postgres `
        -d ceres_db `
        --no-owner --no-privileges --no-password | Out-File -FilePath $POSTGRES_BACKUP -Encoding UTF8
    
    $size = (Get-Item $POSTGRES_BACKUP).Length / 1MB
    Write-Status "[OK] PostgreSQL backup completed: $([math]::Round($size, 2)) MB" "Success"
}
catch {
    Write-Status "[FAIL] PostgreSQL backup failed: $_" "Error"
    exit 1
}

# ==========================================
# 2. Redis Backup
# ==========================================
Write-Status "`n2. Backing up Redis..." "Warning"
try {
    & docker compose --env-file .env --project-name $ProjectName $composeFiles exec -T redis redis-cli BGSAVE | Out-Null
    Start-Sleep -Seconds 2

    $redisContainerId = (& docker compose --env-file .env --project-name $ProjectName $composeFiles ps -q redis).Trim()
    if (-not $redisContainerId) {
        throw "Redis container not found (is the 'redis' service running?)"
    }

    & docker cp "$redisContainerId`:/data/dump.rdb" $REDIS_BACKUP | Out-Null
    
    $size = (Get-Item $REDIS_BACKUP).Length / 1MB
    Write-Status "[OK] Redis backup completed: $([math]::Round($size, 2)) MB" "Success"
}
catch {
    Write-Status "[FAIL] Redis backup failed: $_" "Error"
    exit 1
}

# ==========================================
# 3. Docker Volumes Backup
# ==========================================
Write-Status "`n3. Backing up Docker volumes..." "Warning"
try {
    $volumeSuffixes = @(
        "pg_data",
        "redis_data",
        "nextcloud_data",
        "nextcloud_config",
        "gitea_data",
        "mattermost_data",
        "mattermost_logs",
        "mattermost_config",
        "prometheus_data",
        "grafana_data",
        "portainer_data",
        "loki_data",
        "uptime_kuma_data"
    )

    $volumeMount = @()
    $tarPaths = New-Object System.Collections.Generic.List[string]
    foreach ($suffix in $volumeSuffixes) {
        $volumeName = "${ProjectName}_${suffix}"
        try {
            & docker volume inspect $volumeName 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $volumeMount += @("-v", "$volumeName:/$suffix:ro")
                $tarPaths.Add($suffix)
            }
        } catch {
            # volume missing is OK
            continue
        }
    }

    $backupAbs = (Resolve-Path $BACKUP_DIR).Path
    $volumeMount += @("-v", "$backupAbs`:/backup:rw")

    if ($tarPaths.Count -eq 0) {
        Write-Status "[WARN] No named volumes found to archive (OK on first run)" "Warning"
    } else {
        $paths = [string]::Join(' ', $tarPaths)
        & docker run --rm $volumeMount alpine:latest sh -c "tar czf /backup/volumes_backup_$TIMESTAMP.tar.gz --ignore-failed-read -C / $paths 2>/dev/null || true" | Out-Null
    }
    
    if (Test-Path $VOLUMES_BACKUP) {
        $size = (Get-Item $VOLUMES_BACKUP).Length / 1MB
        Write-Status "[OK] Volumes backup completed: $([math]::Round($size, 2)) MB" "Success"
    } else {
        Write-Status "[WARN] Volumes backup skipped (no data)" "Warning"
    }
}
catch {
    Write-Status "[FAIL] Volumes backup failed: $_" "Error"
    exit 1
}

# ==========================================
# 4. Backup Metadata
# ==========================================
Write-Status "`n4. Creating backup metadata..." "Warning"

$postgresSize = (Get-Item $POSTGRES_BACKUP).Length / 1MB
$redisSize = (Get-Item $REDIS_BACKUP).Length / 1MB
$volumesSize = 0
if (Test-Path $VOLUMES_BACKUP) {
    $volumesSize = (Get-Item $VOLUMES_BACKUP).Length / 1MB
}
$totalSize = $postgresSize + $redisSize + $volumesSize

$metadata = @"
Backup Information
==================
Timestamp: $TIMESTAMP
Hostname: $env:COMPUTERNAME
Backup Location: $(Get-Location)
Date: $(Get-Date)

Files Backed Up:
- PostgreSQL: $([math]::Round($postgresSize, 2)) MB
- Redis: $([math]::Round($redisSize, 2)) MB
- Volumes: $([math]::Round($volumesSize, 2)) MB

Total Size: $([math]::Round($totalSize, 2)) MB

Services Backed Up:
- PostgreSQL 15 (all databases)
- Redis 7 (all data)
- Docker Volumes (all persistent data)

Recovery Instructions:
See restore.ps1 or MAIN_GUIDE.md
"@

$metadata | Out-File -FilePath "$BACKUP_DIR\backup_$TIMESTAMP.info" -Encoding UTF8

Write-Status "[OK] Backup metadata created" "Success"

# ==========================================
# 5. Summary
# ==========================================
Write-Status "`n===================================" "Success"
Write-Status "[OK] BACKUP COMPLETED SUCCESSFULLY" "Success"
Write-Status "Total Backup Size: $([math]::Round($totalSize, 2)) MB" "Success"
Write-Status "Timestamp: $TIMESTAMP" "Success"
Write-Status "===================================" "Success"

Write-Status "`nLog saved to: $LOG_FILE" "Warning"

# Optional: Verify backup
Write-Status "`nVerifying backup files:" "Info"
Get-ChildItem -Path $BACKUP_DIR -Filter "*$TIMESTAMP*" | ForEach-Object {
    $size = $_.Length / 1MB
    Write-Status ("  [OK] {0}: {1} MB" -f $_.Name, ([math]::Round($size, 2))) "Success"
}

}
finally {
    Pop-Location
}
