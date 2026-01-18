param([switch]$Execute = $false)
$root = Split-Path $PSScriptRoot
Write-Host "CERES CLEANUP" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan
if (-not $Execute) {
    Write-Host "[DRY RUN] No changes" -ForegroundColor Yellow
    Write-Host "Execute: .\cleanup.ps1 -Execute" -ForegroundColor Cyan
    exit 0
}
Write-Host "[OK] Starting..." -ForegroundColor Green
$backup = "$root\backups\backup-$(Get-Date -f yyyy-MM-dd-HHmmss)"
mkdir $backup | Out-Null
$files = @("ANALYSIS_COMPLETE.txt", "ANALYZE_MODULE_PLAN.md", "PHASE_1_COMPLETE.md")
foreach ($f in $files) {
    $p = "$root\$f"
    if (Test-Path $p) {
        Copy-Item $p $backup -Force
        Remove-Item $p -Force
        Write-Host "  - $f" -ForegroundColor Green
    }
}
mkdir "$root\docs" -EA 0 | Out-Null
mkdir "$root\docs\services" -EA 0 | Out-Null
cd $root
git add -A 2>$null
git commit -m "cleanup" 2>$null
Write-Host "[OK] Done! Run: .\DEPLOY.ps1" -ForegroundColor Green
