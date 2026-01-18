<#
.SYNOPSIS
    CERES Kubernetes Management Module
    
.DESCRIPTION
    Provides Kubernetes/k3s operations for CERES platform:
    - k3s deployment wrapper
    - FluxCD status checking
    - GitOps operations
    
    Provides wrappers for:
    - DEPLOY.ps1
    - flux-status.ps1
    - Deploy-Kubernetes.ps1
    
.NOTES
    Version: 3.0
    Part of CERES unified CLI
    Requires: Common.ps1, Platform.ps1
    Cross-platform: Windows, Linux, macOS
#>

# ============================================================================
# K8S DEPLOYMENT
# ============================================================================

<#
.SYNOPSIS
    Deploys k3s cluster on Proxmox
.PARAMETER ServerIP
    IP address of Proxmox server
.PARAMETER ServerUser
    SSH username (default: root)
.PARAMETER ServerPassword
    SSH password (from environment)
.PARAMETER SkipNetworkConfig
    Skip network configuration
#>
function Invoke-CeresK8sDeploy {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ServerIP = $env:DEPLOY_SERVER_IP,
        
        [Parameter()]
        [string]$ServerUser = $env:DEPLOY_SERVER_USER,
        
        [Parameter()]
        [string]$ServerPassword = $env:DEPLOY_SERVER_PASSWORD,
        
        [Parameter()]
        [switch]$SkipNetworkConfig
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Kubernetes Deployment                                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Check if DEPLOY.ps1 exists
    $deployScript = Join-Path $PSScriptRoot ".." ".." "DEPLOY.ps1"
    
    if (-not (Test-Path $deployScript)) {
        Write-Host "❌ DEPLOY.ps1 not found: $deployScript" -ForegroundColor Red
        return $false
    }
    
    Write-Host "📦 Launching DEPLOY.ps1..." -ForegroundColor Cyan
    Write-Host ""
    
    # Execute DEPLOY.ps1
    $args = @()
    if ($ServerIP) { $args += "-ServerIP", $ServerIP }
    if ($ServerUser) { $args += "-ServerUser", $ServerUser }
    if ($ServerPassword) { $args += "-ServerPassword", $ServerPassword }
    if ($SkipNetworkConfig) { $args += "-SkipNetworkConfig" }
    
    & $deployScript @args
    
    return $LASTEXITCODE -eq 0
}

# ============================================================================
# FLUX STATUS
# ============================================================================

<#
.SYNOPSIS
    Checks FluxCD GitOps status
.PARAMETER RemoteHost
    Remote server IP (default: from environment)
.PARAMETER RemoteUser
    SSH username (default: from environment)
.PARAMETER RemotePassword
    SSH password (default: from environment)
#>
function Get-CeresFluxStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$RemoteHost = $env:DEPLOY_SERVER_IP,
        
        [Parameter()]
        [string]$RemoteUser = $env:DEPLOY_SERVER_USER,
        
        [Parameter()]
        [string]$RemotePassword = $env:DEPLOY_SERVER_PASSWORD
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          FluxCD Status                                          ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Check if flux-status.ps1 exists
    $fluxScript = Join-Path $PSScriptRoot ".." ".." "flux-status.ps1"
    
    if (-not (Test-Path $fluxScript)) {
        Write-Host "❌ flux-status.ps1 not found: $fluxScript" -ForegroundColor Red
        return $false
    }
    
    # Execute flux-status.ps1
    $args = @()
    if ($RemoteHost) { $args += "-RemoteHost", $RemoteHost }
    if ($RemoteUser) { $args += "-RemoteUser", $RemoteUser }
    if ($RemotePassword) { $args += "-RemotePassword", $RemotePassword }
    
    & $fluxScript @args
    
    return $LASTEXITCODE -eq 0
}

# ============================================================================
# FLUX BOOTSTRAP
# ============================================================================

<#
.SYNOPSIS
    Bootstraps FluxCD on cluster
.PARAMETER GitHubUser
    GitHub username (default: skulesh01)
.PARAMETER GitHubRepo
    GitHub repository (default: Ceres)
.PARAMETER ClusterName
    Cluster name (default: production)
#>
function Invoke-CeresFluxBootstrap {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$GitHubUser = "skulesh01",
        
        [Parameter()]
        [string]$GitHubRepo = "Ceres",
        
        [Parameter()]
        [string]$ClusterName = "production"
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          FluxCD Bootstrap                                       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Check if flux/bootstrap.ps1 exists
    $bootstrapScript = Join-Path $PSScriptRoot ".." ".." "flux" "bootstrap.ps1"
    
    if (-not (Test-Path $bootstrapScript)) {
        Write-Host "❌ flux/bootstrap.ps1 not found: $bootstrapScript" -ForegroundColor Red
        return $false
    }
    
    # Execute bootstrap.ps1
    $args = @(
        "-GitHubUser", $GitHubUser,
        "-GitHubRepo", $GitHubRepo,
        "-ClusterName", $ClusterName
    )
    
    & $bootstrapScript @args
    
    return $LASTEXITCODE -eq 0
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-CeresK8sDeploy',
    'Get-CeresFluxStatus',
    'Invoke-CeresFluxBootstrap'
)
