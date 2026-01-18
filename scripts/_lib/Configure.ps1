<#
.SYNOPSIS
    CERES Configuration Module
    
.DESCRIPTION
    Interactive configuration wizard and validation for CERES platform.
    Consolidates functionality from configure-ceres.ps1 and preflight checks.
    
.NOTES
    Version: 3.0
    Part of CERES unified CLI
    Requires: Common.ps1, Platform.ps1, Analyze.ps1, Validate.ps1
    Cross-platform: Windows, Linux, macOS
#>

# ============================================================================
# CONFIGURATION WIZARD
# ============================================================================

<#
.SYNOPSIS
    Interactive CERES configuration wizard
.PARAMETER PresetProfile
    Use a preset profile (small, medium, large) without prompting
.PARAMETER NonInteractive
    Use recommended profile automatically
.PARAMETER OutputFile
    Path to save deployment plan (default: DEPLOYMENT_PLAN.json)
#>
function Invoke-CeresConfiguration {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('small', 'medium', 'large')]
        [string]$PresetProfile,
        
        [Parameter()]
        [switch]$NonInteractive,
        
        [Parameter()]
        [string]$OutputFile = "DEPLOYMENT_PLAN.json"
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          CERES Configuration Wizard                             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Step 1: Analyze system resources
    Write-ConfigStep 1 "Analyzing System Resources"
    
    $resources = Get-SystemResources
    Write-Host "  CPU:    $($resources.CPU) cores" -ForegroundColor White
    Write-Host "  RAM:    $($resources.RAM) GB" -ForegroundColor White
    Write-Host "  Disk:   $($resources.Disk) GB" -ForegroundColor White
    Write-Host "  OS:     $($resources.OS)" -ForegroundColor White
    
    # Step 2: Load profiles
    Write-ConfigStep 2 "Loading Deployment Profiles"
    
    $profiles = Get-ResourceProfiles
    Write-Host "  Available profiles: $($profiles.Count)" -ForegroundColor Green
    
    # Step 3: Get recommendation
    Write-ConfigStep 3 "Analyzing Recommendations"
    
    $recommendation = Get-ProfileRecommendation -AvailableCpu $resources.CPU -AvailableRam $resources.RAM -AvailableDisk $resources.Disk
    
    if ($recommendation.FeasibleCount -eq 0) {
        Write-Host "  ❌ No profiles fit your system resources!" -ForegroundColor Red
        Write-Host "     Required: CPU 4+, RAM 8+, Storage 150+ GB" -ForegroundColor Red
        return $false
    }
    
    Write-Host "  ✅ Feasible profiles: $($recommendation.FeasibleCount)" -ForegroundColor Green
    Write-Host "  📌 Recommended: $($recommendation.Recommended)" -ForegroundColor Yellow
    
    # Step 4: Profile selection
    Write-ConfigStep 4 "Profile Selection"
    
    $selectedProfile = $null
    
    if ($PresetProfile) {
        $selectedProfile = $profiles[$PresetProfile]
        if (-not $selectedProfile) {
            Write-Host "  ❌ Profile not found: $PresetProfile" -ForegroundColor Red
            return $false
        }
        Write-Host "  Using preset: $PresetProfile" -ForegroundColor Green
    }
    elseif ($NonInteractive) {
        $selectedProfile = $profiles[$recommendation.Recommended]
        Write-Host "  Using recommended: $($recommendation.Recommended)" -ForegroundColor Green
    }
    else {
        Show-ProfileMenu -Profiles $profiles -Recommended $recommendation.Recommended
        $choice = Get-UserSelection -MaxOptions $profiles.Count
        $selectedProfile = @($profiles.Values)[$choice]
    }
    
    # Step 5: Validation
    Write-ConfigStep 5 "Validating Configuration"
    
    $validation = Test-ResourceProfile -Profile $selectedProfile
    if (-not $validation.Success) {
        Write-Host "  ❌ Validation failed!" -ForegroundColor Red
        $validation.Errors | ForEach-Object { Write-Host "     - $_" -ForegroundColor Red }
        return $false
    }
    
    Write-Host "  ✅ Configuration is valid" -ForegroundColor Green
    
    # Step 6: Show deployment plan
    Write-ConfigStep 6 "Deployment Plan"
    Show-DeploymentPlan -Profile $selectedProfile
    
    # Step 7: Export
    Write-ConfigStep 7 "Finalization"
    
    $plan = @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        profile = $selectedProfile.name
        system_resources = $resources
        details = $selectedProfile
    }
    
    $plan | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "  ✅ Deployment plan saved: $OutputFile" -ForegroundColor Green
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          Configuration Complete!                                ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
    
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review: $OutputFile" -ForegroundColor White
    Write-Host "  2. Deploy: ceres start" -ForegroundColor Yellow
    Write-Host ""
    
    return $true
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Runs preflight checks before deployment
.PARAMETER ConfigDir
    Path to config directory
.PARAMETER SkipDocker
    Skip Docker checks
.PARAMETER SkipNetwork
    Skip network checks
#>
function Invoke-CeresPreflight {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigDir,
        
        [Parameter()]
        [switch]$SkipDocker,
        
        [Parameter()]
        [switch]$SkipNetwork
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          CERES Preflight Checks                                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $allPassed = $true
    
    # Check 1: Docker
    if (-not $SkipDocker) {
        Write-Host "[1/5] Docker..." -NoNewline
        try {
            $dockerVersion = & docker --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " ✅ $dockerVersion" -ForegroundColor Green
            }
            else {
                Write-Host " ❌ Not found" -ForegroundColor Red
                $allPassed = $false
            }
        }
        catch {
            Write-Host " ❌ Not installed" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    # Check 2: Docker Compose
    if (-not $SkipDocker) {
        Write-Host "[2/5] Docker Compose..." -NoNewline
        try {
            $composeVersion = & docker compose version 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " ✅ $composeVersion" -ForegroundColor Green
            }
            else {
                Write-Host " ❌ Not found" -ForegroundColor Red
                $allPassed = $false
            }
        }
        catch {
            Write-Host " ❌ Not available" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    # Check 3: Docker daemon
    if (-not $SkipDocker) {
        Write-Host "[3/5] Docker daemon..." -NoNewline
        try {
            & docker ps 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " ✅ Running" -ForegroundColor Green
            }
            else {
                Write-Host " ❌ Not running" -ForegroundColor Red
                $allPassed = $false
            }
        }
        catch {
            Write-Host " ❌ Not accessible" -ForegroundColor Red
            $allPassed = $false
        }
    }
    
    # Check 4: Disk space
    Write-Host "[4/5] Disk space..." -NoNewline
    $disk = Get-DiskSpaceGB
    if ($disk -ge 20) {
        Write-Host " ✅ ${disk}GB available" -ForegroundColor Green
    }
    else {
        Write-Host " ⚠️  Only ${disk}GB (20GB+ recommended)" -ForegroundColor Yellow
    }
    
    # Check 5: Network
    if (-not $SkipNetwork) {
        Write-Host "[5/5] Network connectivity..." -NoNewline
        try {
            $testConnection = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet 2>$null
            if ($testConnection) {
                Write-Host " ✅ Online" -ForegroundColor Green
            }
            else {
                Write-Host " ⚠️  Limited connectivity" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host " ⚠️  Cannot verify" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    if ($allPassed) {
        Write-Host "✅ All preflight checks passed!" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Some checks failed. Fix issues before deploying." -ForegroundColor Red
    }
    Write-Host ""
    
    return $allPassed
}

<#
.SYNOPSIS
    Validates CERES deployment after startup
#>
function Invoke-CeresValidateDeployment {
    [CmdletBinding()]
    param()
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Deployment Validation                                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $projectName = if ($env:CERES_PROJECT_NAME) { $env:CERES_PROJECT_NAME } else { "ceres" }
    
    # Check 1: Containers running
    Write-Host "[1/3] Checking containers..." -NoNewline
    $containers = & docker compose -p $projectName ps -q 2>$null
    $runningCount = ($containers | Measure-Object).Count
    
    if ($runningCount -gt 0) {
        Write-Host " ✅ $runningCount containers running" -ForegroundColor Green
    }
    else {
        Write-Host " ❌ No containers running" -ForegroundColor Red
        return $false
    }
    
    # Check 2: Core services
    Write-Host "[2/3] Checking core services..." -NoNewline
    $coreServices = @('postgres', 'redis', 'keycloak')
    $coreOk = $true
    
    foreach ($service in $coreServices) {
        $status = & docker compose -p $projectName ps -q $service 2>$null
        if (-not $status) {
            $coreOk = $false
            break
        }
    }
    
    if ($coreOk) {
        Write-Host " ✅ Core services healthy" -ForegroundColor Green
    }
    else {
        Write-Host " ❌ Some core services missing" -ForegroundColor Red
        return $false
    }
    
    # Check 3: Network
    Write-Host "[3/3] Checking network..." -NoNewline
    $networks = & docker network ls --filter "name=$projectName" --format "{{.Name}}" 2>$null
    
    if ($networks) {
        Write-Host " ✅ Network configured" -ForegroundColor Green
    }
    else {
        Write-Host " ⚠️  Network not found" -ForegroundColor Yellow
    }
    
    Write-Host "`n✅ Deployment validation passed!" -ForegroundColor Green
    Write-Host ""
    
    return $true
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-ConfigStep {
    param([int]$Number, [string]$Title)
    Write-Host "`n[$Number/7] $Title" -ForegroundColor Yellow
    Write-Host ("─" * 60) -ForegroundColor Gray
}

function Show-ProfileMenu {
    param([hashtable]$Profiles, [string]$Recommended)
    
    Write-Host "`nAvailable Profiles:" -ForegroundColor Cyan
    Write-Host "─────────────────────" -ForegroundColor Gray
    
    $index = 1
    foreach ($key in $Profiles.Keys | Sort-Object) {
        $profile = $Profiles[$key]
        $marker = if ($key -eq $Recommended) { " 🌟 [RECOMMENDED]" } else { "" }
        
        Write-Host "  [$index] $($profile.name)$marker" -ForegroundColor $(if ($marker) { "Green" } else { "White" })
        Write-Host "       CPU: $($profile.total_cpu), RAM: $($profile.total_ram_gb)GB" -ForegroundColor Gray
        $index++
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
    param($Profile)
    
    Write-Host "`n  Profile:    $($Profile.name)" -ForegroundColor White
    Write-Host "  VMs:        $($Profile.virtual_machines.Count)" -ForegroundColor White
    Write-Host "  Total CPU:  $($Profile.total_cpu) cores" -ForegroundColor White
    Write-Host "  Total RAM:  $($Profile.total_ram_gb) GB" -ForegroundColor White
    Write-Host ""
    Write-Host "  Virtual Machines:" -ForegroundColor Cyan
    
    foreach ($vm in $Profile.virtual_machines) {
        Write-Host "    • $($vm.name)" -ForegroundColor White
        Write-Host "      CPU: $($vm.cpu), RAM: $($vm.ram_gb)GB, Disk: $($vm.disk_gb)GB" -ForegroundColor Gray
        Write-Host "      Services: $($vm.services -join ', ')" -ForegroundColor Gray
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-CeresConfiguration',
    'Invoke-CeresPreflight',
    'Invoke-CeresValidateDeployment'
)
