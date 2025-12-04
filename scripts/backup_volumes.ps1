# Backup named Docker volumes to host via temporary containers
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outDir = Join-Path -Path "F:\Ceres\artifacts\backups" -ChildPath $timestamp
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$volumes = @(
    'config_pg_data',
    'config_gitea_data',
    'config_minio_data',
    'config_traefik_letsencrypt'
)
foreach ($vol in $volumes) {
    try {
        Write-Output "Backing up volume: $vol"
        $ctr = "backup_$vol"
        # Create a temporary container that tars the volume contents to /backup.tar
        & docker run --name $ctr -v "$($vol):/data" alpine sh -c 'cd /data && tar czf /backup.tar .'
        $dest = Join-Path $outDir "$vol.tar.gz"
        & docker cp ("$ctr" + ':/backup.tar') $dest
        & docker rm $ctr | Out-Null
        Write-Output "Saved $vol -> $dest"
    } catch {
        $err = ($_ | Out-String).Trim()
        Write-Output ("Error backing up " + $vol + ": " + $err)
        try { & docker rm -f $ctr | Out-Null } catch { }
    }
}
Write-Output "Backup completed: $outDir"
