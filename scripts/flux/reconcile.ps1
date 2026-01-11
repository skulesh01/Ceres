param(
    [switch]$UseSsh
)

$ErrorActionPreference = 'Stop'

# Load environment variables from .env if helper exists
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$loadEnv = Join-Path (Join-Path $repoRoot 'scripts') '_lib/Load-Env.ps1'
if (Test-Path $loadEnv) {
    . $loadEnv
}

# Validate required env vars
$required = @('DEPLOY_SERVER_USER','DEPLOY_SERVER_IP','DEPLOY_SERVER_PASSWORD')
$missing = @()
foreach ($k in $required) {
    $val = [Environment]::GetEnvironmentVariable($k)
    if ([string]::IsNullOrWhiteSpace($val)) { $missing += $k }
}
if ($missing.Count -gt 0 -and -not $UseSsh) {
    Write-Warning ("Нет переменных: {0}. Укажите их в .env или запустите с -UseSsh при наличии SSH-ключей." -f ($missing -join ', '))
}

# Read releases content
$releasesPath = Join-Path $repoRoot 'config/flux/flux-releases.yml'
if (-not (Test-Path $releasesPath)) { throw "Файл не найден: $releasesPath" }
$releasesContent = Get-Content $releasesPath -Raw

# Remote command
$cmd = @"
cat > /tmp/flux-releases.yml << 'EOF'
$releasesContent
EOF
kubectl apply -f /tmp/flux-releases.yml
kubectl -n flux-system annotate kustomization/ceres-releases reconcile.fluxcd.io/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
kubectl -n ceres get helmrelease -o wide
kubectl -n ceres get pods -o wide
"@

function Invoke-WithPlink {
    $plink = Get-Command plink -ErrorAction SilentlyContinue
    if (-not $plink) { $plink = Get-Command plink.exe -ErrorAction SilentlyContinue }
    if (-not $plink) { return $false }
    $target = "{0}@{1}" -f $env:DEPLOY_SERVER_USER, $env:DEPLOY_SERVER_IP
    & $plink.Source -pw $env:DEPLOY_SERVER_PASSWORD -batch $target $cmd
    return $true
}

function Invoke-WithSsh {
    $target = "{0}@{1}" -f $env:DEPLOY_SERVER_USER, $env:DEPLOY_SERVER_IP
    & ssh -o StrictHostKeyChecking=no -o BatchMode=yes $target $cmd
}

$done = $false
if (-not $UseSsh) { $done = Invoke-WithPlink }
if (-not $done) { Invoke-WithSsh }
