<#
.SYNOPSIS
    Interactive CERES configuration wizard for Phase 1 MVP
.DESCRIPTION
    Guides user through selecting deployment profile and generates deployment plan
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('small', 'medium', 'large')]
    [string]$PresetProfile,
    
    [Parameter()]
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib\Resource-Profiles.ps1")
. (Join-Path $PSScriptRoot "analyze-resources.ps1")

function Write-Step {
    param([int]$Number, [string]$Title)
    Write-Host ""
    Write-Host "[Step $Number] $Title" -ForegroundColor Yellow
    Write-Host ("=" * 50) -ForegroundColor Gray
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Show-ProfileMenu {
    param([array]$Profiles, [string]$Recommended)
    
    Write-Host ""
    Write-Host "Select deployment profile:" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $Profiles.Count; $i++) {
        $profile = $Profiles[$i]
        $marker = if ($profile.name -eq $Recommended) { " [RECOMMENDED]" } else { "" }
        
        Write-Host "  [$($i + 1)] $($profile.name)$marker" -ForegroundColor $(if ($marker) { "Green" } else { "White" })
        Write-Host "       VMs: $($profile.virtual_machines.Count), CPU: $($profile.total_cpu), RAM: $($profile.total_ram_gb)GB" -ForegroundColor Gray
    }
    
    Write-Host ""
}

function Get-UserSelection {
    param([int]$MaxOptions)
    
    while ($true) {
        $input = Read-Host "Enter choice (1-$MaxOptions)"
        
        if ($input -match "^\d+$" -and [int]$input -ge 1 -and [int]$input -le $MaxOptions) {
            return [int]$input - 1
        }
        
        Write-Host "Invalid selection. Try again." -ForegroundColor Red
    }
}

function Show-DeploymentPlan {
    param([PSCustomObject]$Profile)
    
    Write-Host ""
    Write-Host "[DEPLOYMENT PLAN]" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Profile Name:          $($Profile.name)"
    Write-Host "Virtual Machines:      $($Profile.virtual_machines.Count)"
    
    $totals = Get-ProfileTotals -Profile $Profile
    Write-Host "Total CPU Cores:       $($totals.cpu)"
    Write-Host "Total RAM:             $($totals.ram_gb) GB"
    Write-Host "Total Storage:         $($totals.disk_gb) GB"
    Write-Host ""
    Write-Host "VMs to be created:"
    Write-Host "-" * 50 -ForegroundColor Gray
    
    $Profile.virtual_machines | ForEach-Object {
        Write-Host "  > $($_.name)"
        Write-Host "    - CPU: $($_.cpu) cores"
        Write-Host "    - RAM: $($_.ram_gb) GB"
        Write-Host "    - Disk: $($_.disk_gb) GB"
        Write-Host "    - Services: $(($_.services -join ', '))" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "=" * 50 -ForegroundColor Cyan
}

function Export-DeploymentPlan {
    param([PSCustomObject]$Profile, [string]$OutputPath = "DEPLOYMENT_PLAN.json")
    
    $plan = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        profile = $Profile.name
        details = $Profile | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    }
    
    $plan | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Success "Deployment plan exported to: $OutputPath"
    return $OutputPath
}

function Main {
    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "CERES Configuration Wizard - Phase 1 MVP" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Step 1: Analyze system
    Write-Step 1 "Analyzing System Resources"
    Write-Host "Please wait..." -ForegroundColor Gray
    
    try {
        $cpus = Get-CimInstance Win32_Processor
        $totalCores = 0
        $cpus | ForEach-Object { $totalCores += $_.NumberOfLogicalProcessors }
        
        $ram = Get-CimInstance Win32_ComputerSystem
        $totalRamGb = [Math]::Round($ram.TotalPhysicalMemory / 1GB)
        
        $cDrive = Get-Volume -DriveLetter C
        $freeDiskGb = [Math]::Round($cDrive.SizeRemaining / 1GB)
        
        Write-Success "System has: $totalCores CPU, $totalRamGb GB RAM, $freeDiskGb GB free disk"
    }
    catch {
        Write-Host "Error analyzing system: $_" -ForegroundColor Red
        return
    }
    
    # Step 2: Load profiles
    Write-Step 2 "Loading Available Profiles"
    
    try {
        $profilesHash = Get-ResourceProfiles
        $profiles = @($profilesHash.Values | Sort-Object { $_.name })
        Write-Success "Loaded $($profiles.Count) profiles"
    }
    catch {
        Write-Host "Error loading profiles: $_" -ForegroundColor Red
        return
    }
    
    # Step 3: Get recommendation
    Write-Step 3 "Analyzing Profile Recommendations"
    
    $recommendation = Get-ProfileRecommendation -AvailableCpu $totalCores -AvailableRam $totalRamGb -AvailableDisk $freeDiskGb
    
    if ($recommendation.FeasibleCount -eq 0) {
        Write-Host "ERROR: No profiles fit your system resources!" -ForegroundColor Red
        Write-Host "Required: CPU 4+, RAM 8+, Storage 150+ GB" -ForegroundColor Red
        return
    }
    
    Write-Success "Found $($recommendation.FeasibleCount) feasible profile(s)"
    Write-Host "Recommended: $($recommendation.Recommended)" -ForegroundColor Green
    
    # Step 4: User selection
    Write-Step 4 "Profile Selection"
    
    $selectedIdx = 0
    if ($PresetProfile) {
        $selectedIdx = [Array]::FindIndex($profiles, [Predicate[object]] { $args[0].name -eq $PresetProfile })
        if ($selectedIdx -eq -1) {
            Write-Host "Profile not found: $PresetProfile" -ForegroundColor Red
            return
        }
        Write-Host "Using preset profile: $PresetProfile" -ForegroundColor Green
    }
    elseif ($NonInteractive) {
        $selectedIdx = [Array]::FindIndex($profiles, [Predicate[object]] { $args[0].name -eq $recommendation.Recommended })
        Write-Host "Using recommended profile (non-interactive mode): $($profiles[$selectedIdx].name)" -ForegroundColor Green
    }
    else {
        Show-ProfileMenu -Profiles $profiles -Recommended $recommendation.Recommended
        $selectedIdx = Get-UserSelection -MaxOptions $profiles.Count
    }
    
    $selectedProfile = $profiles[$selectedIdx]
    
    # Step 5: Validation
    Write-Step 5 "Validating Configuration"
    
    $validation = Test-ResourceProfile -Profile $selectedProfile
    if (-not $validation.Success) {
        Write-Host "Validation failed!" -ForegroundColor Red
        $validation.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        return
    }
    
    Write-Success "Configuration is valid"
    
    # Step 6: Show deployment plan
    Write-Step 6 "Deployment Plan"
    Show-DeploymentPlan -Profile $selectedProfile
    
    # Step 7: Confirmation and export
    Write-Step 7 "Finalization"
    
    if ($NonInteractive -or $PresetProfile) {
        Write-Host "Exporting deployment plan..." -ForegroundColor Gray
        Export-DeploymentPlan -Profile $selectedProfile
        Write-Host ""
        Write-Success "Configuration complete. Ready to deploy."
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Review DEPLOYMENT_PLAN.json"
        Write-Host "  2. Run: .\DEPLOY.ps1" -ForegroundColor Yellow
        Write-Host ""
    }
    else {
        Write-Host "Export deployment plan? (Y/n): " -NoNewline -ForegroundColor Cyan
        $response = Read-Host
        
        if ($response -ne "n") {
            Export-DeploymentPlan -Profile $selectedProfile
        }
        
        Write-Host ""
        Write-Success "Configuration wizard complete."
    }
    
    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host ""
}

try {
    Main
}
catch {
    Write-Host "Fatal error: $_" -ForegroundColor Red
    exit 1
}
