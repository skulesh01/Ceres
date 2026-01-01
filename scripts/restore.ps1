<#
Restore script for CERES Docker services (Windows PowerShell).

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
    [Parameter(Mandatory = $true)]
    [string]$RestoreTimestamp,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Modules,

    [switch]$Clean,
    [string]$ProjectName = "ceres",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

$configDir = Get-CeresConfigDir
$composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean

# Configuration
$BACKUP_DIR = Join-Path $configDir "backups"
$POSTGRES_BACKUP = "$BACKUP_DIR\postgres_backup_$RestoreTimestamp.sql"
$REDIS_BACKUP = "$BACKUP_DIR\redis_backup_$RestoreTimestamp.rdb"
$VOLUMES_BACKUP = "$BACKUP_DIR\volumes_backup_$RestoreTimestamp.tar.gz"
$LOG_FILE = "$BACKUP_DIR\restore_$RestoreTimestamp.log"

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

Write-Status "Starting CERES Restore..." "Warning"
Write-Status "Restore Timestamp: $RestoreTimestamp" "Info"
Write-Status "Project: $ProjectName" "Info"
Add-Content -Path $LOG_FILE -Value "Restore started at: $(Get-Date)`n"

Push-Location $configDir
try {

# Verify backup files exist
Write-Status "`nVerifying backup files..." "Warning"
foreach ($file in @($POSTGRES_BACKUP, $REDIS_BACKUP, $VOLUMES_BACKUP)) {
    if (-not (Test-Path $file)) {
        Write-Status "[FAIL] Missing backup file: $file" "Error"
        exit 1
    }
    $size = (Get-Item $file).Length / 1MB
    Write-Status "[OK] Found: $file ($([math]::Round($size, 2)) MB)" "Success"
}

# Confirm restore
if (-not $Force) {
    Write-Status "`n[WARN] WARNING: This will overwrite all data!" "Warning"
    Write-Status "Services will be stopped and data will be restored." "Warning"
    
    $response = Read-Host "Continue with restore? (yes/no)"
    if ($response -ne "yes") {
        Write-Status "Restore cancelled" "Warning"
        exit 0
    }
}

# Stop services
Write-Status "`n1. Stopping services..." "Warning"
try {
    & docker compose --env-file .env --project-name $ProjectName $composeFiles down --remove-orphans 2>&1 | Out-Null
    Write-Status "[OK] Services stopped" "Success"
}
catch {
    Write-Status "[WARN] Error stopping services (may be OK): $_" "Warning"
}

# Remove old PostgreSQL volume
Write-Status "`n2. Removing old PostgreSQL volume..." "Warning"
try {
    & docker volume rm "${ProjectName}_pg_data" 2>&1 | Out-Null
    Write-Status "[OK] Old PostgreSQL volume removed" "Success"
}
catch {
    Write-Status "[WARN] Volume may not exist (OK): $_" "Warning"
}

# Start only database services
Write-Status "`n3. Starting database services..." "Warning"
try {
    & docker compose --env-file .env --project-name $ProjectName $composeFiles up -d postgres redis 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    Write-Status "[OK] Database services started" "Success"
}
catch {
    Write-Status "[FAIL] Failed to start database services: $_" "Error"
    exit 1
}

# ==========================================
# Restore PostgreSQL
# ==========================================
Write-Status "`n4. Restoring PostgreSQL database..." "Warning"
try {
    $pgDump = Get-Content -Path $POSTGRES_BACKUP -Raw
    $pgDump | & docker compose --env-file .env --project-name $ProjectName $composeFiles exec -T postgres psql `
        -U postgres `
        -d ceres_db `
        --no-password 2>&1 | Out-Null
    
    Write-Status "[OK] PostgreSQL restore completed" "Success"
}
catch {
    Write-Status "[FAIL] PostgreSQL restore failed: $_" "Error"
    exit 1
}

# ==========================================
# Restore Redis
# ==========================================
Write-Status "`n5. Restoring Redis data..." "Warning"
try {
    $redisContainerId = (& docker compose --env-file .env --project-name $ProjectName $composeFiles ps -q redis).Trim()
    if (-not $redisContainerId) {
        throw "Redis container not found (is the 'redis' service running?)"
    }
    & docker cp $REDIS_BACKUP "$redisContainerId`:/data/dump.rdb" 2>&1 | Out-Null
    & docker compose --env-file .env --project-name $ProjectName $composeFiles restart redis 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    
    Write-Status "[OK] Redis restore completed" "Success"
}
catch {
    Write-Status "[FAIL] Redis restore failed: $_" "Error"
    exit 1
}

# ==========================================
# Restore Volumes
# ==========================================
Write-Status "`n6. Restoring volumes..." "Warning"
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
    foreach ($suffix in $volumeSuffixes) {
        $volumeMount += @("-v", ("{0}_{1}:/{1}" -f $ProjectName, $suffix))
    }

    $backupAbs = (Resolve-Path $BACKUP_DIR).Path
    $volumeMount += @("-v", "$backupAbs`:/backup:ro")

    & docker run --rm $volumeMount alpine:latest tar xzf "/backup/volumes_backup_$RestoreTimestamp.tar.gz" -C / 2>&1 | Out-Null
    
    Write-Status "[OK] Volumes restore completed" "Success"
}
catch {
    Write-Status "[FAIL] Volumes restore failed: $_" "Error"
    exit 1
}

# ==========================================
# Start all services
# ==========================================
Write-Status "`n7. Starting all services..." "Warning"
try {
    & docker compose --env-file .env --project-name $ProjectName $composeFiles up -d 2>&1 | Out-Null
    Start-Sleep -Seconds 5
    
    Write-Status "`n===================================" "Success"
    Write-Status "[OK] RESTORE COMPLETED SUCCESSFULLY" "Success"
    Write-Status "===================================" "Success"
    
    Write-Status "`nAll services are starting up..." "Warning"
    & docker compose --env-file .env --project-name $ProjectName $composeFiles ps | Tee-Object -FilePath $LOG_FILE -Append
}
catch {
    Write-Status "[FAIL] Failed to start services: $_" "Error"
    exit 1
}

Write-Status "`nLog saved to: $LOG_FILE" "Warning"
finally {
    Pop-Location
}
