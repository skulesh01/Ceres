<#
Cleanup script for CERES Docker runtime (Windows PowerShell).

Goals:
- Bring down CERES stack cleanly (no data loss).
- Optionally remove known stale/conflicting containers from previous runs.

By default this script does NOT delete volumes.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script output with colors.'
)]
param(
    [string]$ProjectName = "ceres",
    [switch]$Clean,
    [string[]]$Modules,
    [switch]$RemoveKnownConflicts,
    [switch]$PruneNetworks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
$configDir = Join-Path $scriptDir "..\\config"

. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

function Remove-KnownConflictingContainer {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([string]$KeepProject)

    # Names that commonly existed when container_name was used, plus legacy/optional components.
    $knownNames = @(
        "postgres","redis","keycloak","nextcloud","gitea","mattermost",
        "grafana","prometheus","portainer","nginx",
        "traefik","vaultwarden","syncthing","node-exporter","cadvisor","alertmanager"
    )

    # Only touch containers that match both name AND a known image prefix.
    $knownImagePrefixes = @(
        "postgres:","redis:","quay.io/keycloak/keycloak:","nextcloud:","gitea/gitea:",
        "mattermost/mattermost-team-edition:","grafana/grafana:","prom/prometheus:",
        "portainer/portainer-ce:","nginx:",
        "traefik:","vaultwarden/server:","linuxserver/syncthing:","prom/node-exporter:",
        "gcr.io/cadvisor/cadvisor:","prom/alertmanager:"
    )

    $all = & docker ps -a --format "{{.ID}} {{.Names}}"
    foreach ($line in $all) {
        if (-not $line) { continue }
        $parts = $line.Split(' ',2)
        if ($parts.Count -lt 2) { continue }
        $id = $parts[0].Trim()
        $name = $parts[1].Trim()

        $isKnownByName = ($knownNames -contains $name)
        $isLegacyByPrefix = $name.StartsWith("ceres-")
        if (-not $isKnownByName -and -not $isLegacyByPrefix) { continue }

        $proj = $null
        try {
            $labelsJson = & docker inspect -f '{{json .Config.Labels}}' $id 2>$null
            if ($labelsJson) {
                $labels = $labelsJson | ConvertFrom-Json
                $proj = $labels.'com.docker.compose.project'
            }
        } catch {
            $proj = $null
        }
        if ($proj -and ($proj.Trim() -eq $KeepProject)) {
            continue
        }

        $img = & docker inspect -f '{{ .Config.Image }}' $id 2>$null
        if (-not $img) { continue }

        $isKnownImage = $false
        foreach ($p in $knownImagePrefixes) {
            if ($img.StartsWith($p)) { $isKnownImage = $true; break }
        }
        if (-not $isKnownImage) { continue }

        if ($PSCmdlet.ShouldProcess("container '$name'", "docker rm -f ($img)")) {
            Write-Host "Removing stale container '$name' ($img)" -ForegroundColor Yellow
            & docker rm -f $id | Out-Null
        }
    }
}

Assert-DockerRunning
Initialize-CeresEnv -ConfigDir $configDir -RequiredKeys @(
    "POSTGRES_PASSWORD",
    "KEYCLOAK_ADMIN_PASSWORD",
    "NEXTCLOUD_ADMIN_PASSWORD",
    "GRAFANA_ADMIN_PASSWORD"
)

Push-Location $configDir
try {
    $composeFiles = Get-CeresComposeFiles -SelectedModules $Modules -Clean:$Clean

    Write-Host "Bringing down CERES project '$ProjectName'..." -ForegroundColor Cyan
    try {
        & docker compose --env-file .env --project-name $ProjectName $composeFiles down --remove-orphans 2>$null | Out-Null
    } catch {
        Write-Host "Compose down failed (continuing cleanup): $($_.Exception.Message)" -ForegroundColor Yellow
    }

    if ($RemoveKnownConflicts) {
        Write-Host "Removing known stale containers from older runs..." -ForegroundColor Cyan
        Remove-KnownConflictingContainer -KeepProject $ProjectName
    }

    if ($PruneNetworks) {
        Write-Host "Pruning unused networks..." -ForegroundColor Cyan
        & docker network prune -f | Out-Null
    }

    Write-Host "Done." -ForegroundColor Green
}
finally {
    Pop-Location
}
