# ==========================================
# Enhanced Backup Script with S3 Upload
# ==========================================

$ErrorActionPreference = "Stop"

$BACKUP_DIR = "backups/full-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$S3_BUCKET = $env:S3_BACKUP_BUCKET
$S3_ENDPOINT = $env:S3_ENDPOINT

Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CERES FULL BACKUP" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null

# ==========================================
# Backup Databases
# ==========================================
Write-Host "📦 Backing up databases..." -ForegroundColor Yellow

$databases = @("gitlab", "zulip", "nextcloud", "keycloak", "grafana")
foreach ($db in $databases) {
    Write-Host "  → $db..." -ForegroundColor Cyan
    docker exec postgres pg_dump -U postgres $db > "$BACKUP_DIR/$db-db.sql" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✅ $db backup complete" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️  $db backup skipped (database may not exist)" -ForegroundColor Yellow
    }
}

# Full PostgreSQL backup
Write-Host "  → Full PostgreSQL dump..." -ForegroundColor Cyan
docker exec postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres-full.sql"
Write-Host "    ✅ Full PostgreSQL backup complete" -ForegroundColor Green

# ==========================================
# Backup Service Data
# ==========================================
Write-Host ""
Write-Host "📁 Backing up service data..." -ForegroundColor Yellow

$services = @{
    "gitlab" = "/var/opt/gitlab"
    "zulip" = "/data"
    "nextcloud" = "/var/www/html/data"
    "grafana" = "/var/lib/grafana"
}

foreach ($service in $services.Keys) {
    Write-Host "  → $service data..." -ForegroundColor Cyan
    $path = $services[$service]
    docker exec $service tar czf /tmp/$service-data.tar.gz $path 2>$null
    if ($LASTEXITCODE -eq 0) {
        docker cp "${service}:/tmp/$service-data.tar.gz" "$BACKUP_DIR/"
        Write-Host "    ✅ $service data backup complete" -ForegroundColor Green
    } else {
        Write-Host "    ⚠️  $service data backup skipped" -ForegroundColor Yellow
    }
}

# ==========================================
# Backup Configurations
# ==========================================
Write-Host ""
Write-Host "⚙️  Backing up configurations..." -ForegroundColor Yellow

$configs = @(
    "config/compose",
    "config/caddy",
    "config/prometheus",
    "config/grafana",
    "config/.env"
)

foreach ($config in $configs) {
    if (Test-Path $config) {
        Write-Host "  → $config..." -ForegroundColor Cyan
        $dest = Join-Path $BACKUP_DIR "configs"
        Copy-Item -Path $config -Destination $dest -Recurse -Force
        Write-Host "    ✅ $config backed up" -ForegroundColor Green
    }
}

# ==========================================
# Create Archive
# ==========================================
Write-Host ""
Write-Host "📦 Creating backup archive..." -ForegroundColor Yellow
$archivePath = "$BACKUP_DIR.zip"
Compress-Archive -Path $BACKUP_DIR -DestinationPath $archivePath
$archiveSize = (Get-Item $archivePath).Length / 1MB
Write-Host "  ✅ Archive created: $archivePath ($([math]::Round($archiveSize, 2)) MB)" -ForegroundColor Green

# ==========================================
# Upload to S3 (if configured)
# ==========================================
if ($S3_BUCKET -and $S3_ENDPOINT) {
    Write-Host ""
    Write-Host "☁️  Uploading to S3..." -ForegroundColor Yellow
    
    try {
        # Using AWS CLI
        aws s3 cp $archivePath "s3://$S3_BUCKET/ceres-backups/" --endpoint-url $S3_ENDPOINT
        Write-Host "  ✅ Uploaded to S3: s3://$S3_BUCKET/ceres-backups/" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  S3 upload failed: $_" -ForegroundColor Yellow
        Write-Host "  Backup is saved locally: $archivePath" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "ℹ️  S3 upload skipped (not configured)" -ForegroundColor Cyan
    Write-Host "  To enable: Set S3_BACKUP_BUCKET and S3_ENDPOINT in .env" -ForegroundColor Gray
}

# ==========================================
# Backup Verification
# ==========================================
Write-Host ""
Write-Host "🔍 Verifying backup..." -ForegroundColor Yellow

$files = Get-ChildItem -Path $BACKUP_DIR -Recurse -File
$totalSize = ($files | Measure-Object -Property Length -Sum).Sum / 1MB

Write-Host "  Files: $($files.Count)" -ForegroundColor Cyan
Write-Host "  Total size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor Cyan

# ==========================================
# Cleanup Old Backups
# ==========================================
Write-Host ""
Write-Host "🧹 Cleaning up old backups..." -ForegroundColor Yellow

$retention = 7 # Keep last 7 days
$cutoffDate = (Get-Date).AddDays(-$retention)
$oldBackups = Get-ChildItem -Path "backups" -Filter "full-*.zip" | Where-Object { $_.LastWriteTime -lt $cutoffDate }

if ($oldBackups) {
    foreach ($backup in $oldBackups) {
        Write-Host "  → Removing $($backup.Name)..." -ForegroundColor Gray
        Remove-Item $backup.FullName -Force
    }
    Write-Host "  ✅ Removed $($oldBackups.Count) old backups" -ForegroundColor Green
} else {
    Write-Host "  ℹ️  No old backups to remove" -ForegroundColor Cyan
}

# ==========================================
# Summary
# ==========================================
Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ BACKUP COMPLETE!" -ForegroundColor Green
Write-Host "════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "📍 Backup location:" -ForegroundColor Cyan
Write-Host "  Local: $archivePath" -ForegroundColor White
if ($S3_BUCKET) {
    Write-Host "  S3: s3://$S3_BUCKET/ceres-backups/$(Split-Path $archivePath -Leaf)" -ForegroundColor White
}
Write-Host ""
Write-Host "📊 Backup stats:" -ForegroundColor Cyan
Write-Host "  Files: $($files.Count)" -ForegroundColor White
Write-Host "  Size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor White
Write-Host "  Archive: $([math]::Round($archiveSize, 2)) MB" -ForegroundColor White
Write-Host ""
Write-Host "💡 To restore: powershell -File scripts/restore-backup.ps1 $archivePath" -ForegroundColor Yellow
Write-Host ""
