<#
.SYNOPSIS
    Analyze system resources and recommend CERES profile
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('local', 'proxmox')]
    [string]$Environment = 'local',
    
    [Parameter()]
    [string]$ProxmoxHost,
    
    [Parameter()]
    [string]$ProxmoxUser = 'root',
    
    [Parameter()]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib\Resource-Profiles.ps1")

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    
    if ($Json) { return }
    
    $colors = @{'INFO'='Cyan'; 'SUCCESS'='Green'; 'WARNING'='Yellow'; 'ERROR'='Red'}
    Write-Host "[$Level] $Message" -ForegroundColor $colors[$Level]
}

function Get-LocalResources {
    Write-Log "Analyzing local system..." INFO
    
    try {
        $cpus = Get-CimInstance Win32_Processor
        $totalCores = 0
        $cpus | ForEach-Object { $totalCores += $_.NumberOfLogicalProcessors }
        
        $ram = Get-CimInstance Win32_ComputerSystem
        $totalRamGb = [Math]::Round($ram.TotalPhysicalMemory / 1GB)
        
        $cDrive = Get-Volume -DriveLetter C
        $totalDiskGb = [Math]::Round($cDrive.Size / 1GB)
        $freeDiskGb = [Math]::Round($cDrive.SizeRemaining / 1GB)
        
        return @{
            type = "local"
            platform = "windows"
            total_cpu = $totalCores
            total_ram_gb = $totalRamGb
            total_storage_gb = $totalDiskGb
            free_storage_gb = $freeDiskGb
            available_cpu = $totalCores
            available_ram_gb = $totalRamGb
            available_storage_gb = $freeDiskGb
        }
    }
    catch {
        throw "Failed to analyze local resources: $_"
    }
}

function Get-Recommendations {
    param([hashtable]$Resources)
    
    $recommendation = Get-ProfileRecommendation `
        -AvailableCpu $Resources.available_cpu `
        -AvailableRam $Resources.available_ram_gb `
        -AvailableDisk $Resources.available_storage_gb
    
    $warnings = @()
    
    if ($Resources.available_ram_gb -lt 8) {
        $warnings += "Low RAM: Minimum 8GB recommended"
    }
    
    if ($Resources.available_storage_gb -lt 150) {
        $warnings += "Limited storage: Minimum 150GB recommended"
    }
    
    if ($Resources.available_cpu -lt 4) {
        $warnings += "Limited CPU: Minimum 4 cores recommended"
    }
    
    return @{
        feasible = $recommendation.FeasibleProfiles
        recommended = $recommendation.Recommended
        feasible_count = $recommendation.FeasibleCount
        warnings = $warnings
        warning_count = $warnings.Count
    }
}

function Format-TextOutput {
    param([hashtable]$Resources, [hashtable]$Recommendations)
    
    Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
    Write-Host "CERES Resource Analysis" -ForegroundColor Cyan
    Write-Host ("=" * 60) + "`n" -ForegroundColor Cyan
    
    Write-Log "System Resources:" SUCCESS
    Write-Host "  Environment:  $($Resources.type)"
    Write-Host "  Total CPU:    $($Resources.total_cpu) cores"
    Write-Host "  Total RAM:    $($Resources.total_ram_gb) GB"
    Write-Host "  Total Disk:   $($Resources.total_storage_gb) GB"
    Write-Host ""
    Write-Log "Profile Recommendations:" SUCCESS
    Write-Host "  Feasible:     $($Recommendations.feasible -join ', ')"
    Write-Host "  Recommended:  $($Recommendations.recommended) *"
    
    if ($Recommendations.warning_count -gt 0) {
        Write-Host ""
        Write-Log "Warnings:" WARNING
        $Recommendations.warnings | ForEach-Object {
            Write-Host "  - $_"
        }
    }
    
    Write-Host ""
    Write-Log "Next Steps:" INFO
    Write-Host "  1. Run: .\scripts\configure-ceres.ps1"
    Write-Host "  2. Select profile and configure"
    Write-Host "  3. Run: .\DEPLOY.ps1"
    
    Write-Host "`n" + ("=" * 60) + "`n" -ForegroundColor Cyan
}

function Format-JsonOutput {
    param([hashtable]$Resources, [hashtable]$Recommendations)
    
    $timeStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $output = @{
        success = $true
        analysis_time = $timeStr
        resources = $Resources
        recommendations = $Recommendations
    }
    
    return ($output | ConvertTo-Json -Depth 3)
}

try {
    Write-Log "Starting CERES resource analysis..." INFO
    
    if ($Environment -eq 'local') {
        $resources = Get-LocalResources
    }
    else {
        if (-not $ProxmoxHost) {
            throw "ProxmoxHost parameter required"
        }
        Write-Log "Proxmox analysis not yet implemented" WARNING
        $resources = @{type="proxmox"; available_cpu=0; available_ram_gb=0; available_storage_gb=0}
    }
    
    $recommendations = Get-Recommendations -Resources $resources
    
    if ($Json) {
        Format-JsonOutput -Resources $resources -Recommendations $recommendations
    }
    else {
        Format-TextOutput -Resources $resources -Recommendations $recommendations
        Write-Log "Analysis complete" SUCCESS
    }
    
    exit 0
}
catch {
    $msg = $_.ToString()
    if ($Json) {
        $timeStr = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $error_obj = @{success=$false; error=$msg; analysis_time=$timeStr}
        $error_obj | ConvertTo-Json
    }
    else {
        Write-Log "Analysis failed: $msg" ERROR
    }
    exit 1
}
