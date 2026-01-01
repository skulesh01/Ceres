<#
Export (and optionally install) Caddy internal CA root certificate.

Why: When Caddy uses `tls internal`, clients must trust the generated root CA
to avoid browser TLS warnings.

Examples:
  # Export root CA from running caddy container
  .\export-caddy-rootca.ps1 -OutFile .\ceres-caddy-rootca.crt

  # Install to LocalMachine Trusted Root (run as Administrator)
  .\export-caddy-rootca.ps1 -OutFile .\ceres-caddy-rootca.crt -Install
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script output with colors.'
)]
param(
    [string]$ProjectName = 'ceres',
    [string]$OutFile = '.\\ceres-caddy-rootca.crt',
    [switch]$Install
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Try to locate caddy container for both compose naming styles
$caddy = (docker ps --filter "name=${ProjectName}-caddy-" --format "{{.Names}}" | Select-Object -First 1)
if (-not $caddy) { $caddy = (docker ps --filter "name=${ProjectName}_caddy" --format "{{.Names}}" | Select-Object -First 1) }
if (-not $caddy) { $caddy = (docker ps --filter "name=caddy" --format "{{.Names}}" | Select-Object -First 1) }

if (-not $caddy) {
    throw "Could not find a running caddy container (project: $ProjectName). Start edge first." 
}

$certPath = '/data/caddy/pki/authorities/local/root.crt'

Write-Host "Exporting Caddy root CA from container '$caddy'..." -ForegroundColor Cyan
$cert = (docker exec $caddy sh -lc "cat $certPath")
if ($LASTEXITCODE -ne 0 -or -not $cert) {
    throw "Failed to read $certPath from container '$caddy'."
}

# Ensure output folder exists
$outDir = Split-Path -Parent (Resolve-Path -LiteralPath (Join-Path (Get-Location) '.') ).Path
try {
    $outDir = Split-Path -Parent (Resolve-Path -LiteralPath $OutFile -ErrorAction Stop)
}
catch {
    $outDir = Split-Path -Parent $OutFile
}
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

Set-Content -Path $OutFile -Value $cert -NoNewline
Write-Host "[OK] Saved: $OutFile" -ForegroundColor Green

if ($Install) {
    Write-Host "Installing to LocalMachine\\Root (requires Administrator)..." -ForegroundColor Cyan
    Import-Certificate -FilePath $OutFile -CertStoreLocation 'Cert:\\LocalMachine\\Root' | Out-Null
    Write-Host "[OK] Installed Caddy root CA." -ForegroundColor Green
}
