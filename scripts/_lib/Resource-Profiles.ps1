<#
.SYNOPSIS
    Resource profile definitions and utilities for CERES
    
.DESCRIPTION
    Loads and manages resource profiles (small, medium, large)
    Provides functions to get, validate, and work with profiles
    
.NOTES
    Profiles are stored as JSON in config/profiles/
    This library abstracts loading and validation
#>

# ============================================================================
# LOAD PROFILES FROM JSON
# ============================================================================

<#
.SYNOPSIS
    Load all available profiles from config/profiles/ directory
    
.OUTPUTS
    Hashtable with profile names as keys and profile objects as values
#>
function Get-ResourceProfiles {
    param(
        [Parameter()]
        [string]$ProfilesDir = "$PSScriptRoot\..\..\config\profiles"
    )
    
    $profiles = @{}
    
    if (-not (Test-Path $ProfilesDir)) {
        Write-Warning "Profiles directory not found: $ProfilesDir"
        return $profiles
    }
    
    Get-ChildItem "$ProfilesDir\*.json" -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $name = $_.BaseName
            $content = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $profiles[$name] = $content
        }
        catch {
            Write-Warning "Failed to load profile $($_.FullName): $_"
        }
    }
    
    return $profiles
}

<#
.SYNOPSIS
    Get specific profile by name
    
.PARAMETER ProfileName
    Name of the profile (small, medium, large, custom)
    
.OUTPUTS
    Profile object (PSCustomObject from JSON)
    
.EXAMPLE
    $profile = Get-ResourceProfile -ProfileName "medium"
#>
function Get-ResourceProfile {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,
        
        [Parameter()]
        [string]$ProfilesDir = "$PSScriptRoot\..\..\config\profiles"
    )
    
    $path = Join-Path $ProfilesDir "$ProfileName.json"
    
    if (-not (Test-Path $path)) {
        throw "Profile not found: $ProfileName (expected at $path)"
    }
    
    try {
        return Get-Content $path -Raw | ConvertFrom-Json
    }
    catch {
        throw "Failed to load profile $ProfileName : $_"
    }
}

<#
.SYNOPSIS
    List all available profile names
    
.OUTPUTS
    Array of profile names (small, medium, large, etc.)
    
.EXAMPLE
    $profiles = Get-AvailableProfiles
    # Returns: @("small", "medium", "large")
#>
function Get-AvailableProfiles {
    param(
        [Parameter()]
        [string]$ProfilesDir = "$PSScriptRoot\..\..\config\profiles"
    )
    
    $profiles = Get-ResourceProfiles -ProfilesDir $ProfilesDir
    return @($profiles.Keys | Sort-Object)
}

<#
.SYNOPSIS
    Validate resource profile
    
.PARAMETER Profile
    Profile object to validate
    
.OUTPUTS
    PSCustomObject with Success (bool) and Errors (array)
    
.EXAMPLE
    $result = Test-ResourceProfile -Profile $profile
    if ($result.Success) { "Profile is valid" }
#>
function Test-ResourceProfile {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Profile
    )
    
    $errors = @()
    
    # Required fields
    if (-not $Profile.version) { 
        $errors += "Missing: version" 
    }
    if (-not $Profile.name) { 
        $errors += "Missing: name" 
    }
    if (-not $Profile.virtual_machines) { 
        $errors += "Missing: virtual_machines array" 
    }
    
    # VM count
    if ($Profile.virtual_machines.Count -lt 1) {
        $errors += "At least 1 VM required"
    }
    
    # Validate each VM
    $vmIndex = 0
    $Profile.virtual_machines | ForEach-Object {
        $vmIndex++
        $vm = $_
        
        if (-not $vm.name) { 
            $errors += "VM ${vmIndex}: missing name" 
        }
        if (-not $vm.cpu -or $vm.cpu -lt 1) { 
            $errors += "VM $($vm.name): invalid CPU (got: $($vm.cpu), expected: >= 1)" 
        }
        if (-not $vm.ram_gb -or $vm.ram_gb -lt 1) { 
            $errors += "VM $($vm.name): invalid RAM (got: $($vm.ram_gb), expected: >= 1 GB)" 
        }
        if (-not $vm.disk_gb -or $vm.disk_gb -lt 10) { 
            $errors += "VM $($vm.name): invalid disk (got: $($vm.disk_gb), expected: >= 10 GB)" 
        }
        if (-not $vm.services -or $vm.services.Count -eq 0) { 
            $errors += "VM $($vm.name): no services defined" 
        }
    }
    
    # Validate resource allocation if exists
    if ($Profile.resource_allocation) {
        $Profile.resource_allocation.PSObject.Properties | ForEach-Object {
            $service = $_
            
            if (-not $service.Value.cpu_limit) {
                $errors += "Resource allocation for $($service.Name): missing cpu_limit"
            }
            if (-not $service.Value.memory_limit) {
                $errors += "Resource allocation for $($service.Name): missing memory_limit"
            }
        }
    }
    
    $success = $errors.Count -eq 0
    
    return @{
        Success = $success
        Errors = $errors
        ErrorCount = $errors.Count
    }
}

<#
.SYNOPSIS
    Calculate total resources for a profile
    
.PARAMETER Profile
    Profile object
    
.OUTPUTS
    PSCustomObject with totals (cpu, ram_gb, disk_gb, vm_count)
    
.EXAMPLE
    $totals = Get-ProfileTotals -Profile $profile
    Write-Host "Total CPU: $($totals.cpu) cores"
#>
function Get-ProfileTotals {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Profile
    )
    
    $totalCpu = 0
    $totalRam = 0
    $totalDisk = 0
    $vmCount = $Profile.virtual_machines.Count
    
    $Profile.virtual_machines | ForEach-Object {
        $totalCpu += $_.cpu
        $totalRam += $_.ram_gb
        $totalDisk += $_.disk_gb
    }
    
    return @{
        cpu = $totalCpu
        ram_gb = $totalRam
        disk_gb = $totalDisk
        vm_count = $vmCount
    }
}

<#
.SYNOPSIS
    Compare profile requirements with available system resources
    
.PARAMETER Profile
    Profile object
    
.PARAMETER AvailableCpu
    Available CPU cores
    
.PARAMETER AvailableRam
    Available RAM in GB
    
.PARAMETER AvailableDisk
    Available disk space in GB
    
.OUTPUTS
    PSCustomObject with comparison results
    
.EXAMPLE
    $result = Compare-ProfileToResources -Profile $medium -AvailableCpu 16 -AvailableRam 32
    if ($result.IsFeasible) { "Profile fits!" }
#>
function Compare-ProfileToResources {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Profile,
        
        [Parameter(Mandatory = $true)]
        [int]$AvailableCpu,
        
        [Parameter(Mandatory = $true)]
        [int]$AvailableRam,
        
        [Parameter(Mandatory = $true)]
        [int]$AvailableDisk
    )
    
    $totals = Get-ProfileTotals -Profile $Profile
    
    $cpuFits = $totals.cpu -le $AvailableCpu
    $ramFits = $totals.ram_gb -le $AvailableRam
    $diskFits = $totals.disk_gb -le $AvailableDisk
    
    $isFeasible = $cpuFits -and $ramFits -and $diskFits
    
    $warnings = @()
    if (-not $cpuFits) {
        $warnings += "CPU: need $($totals.cpu), available $AvailableCpu"
    }
    if (-not $ramFits) {
        $warnings += "RAM: need $($totals.ram_gb) GB, available $AvailableRam GB"
    }
    if (-not $diskFits) {
        $warnings += "Disk: need $($totals.disk_gb) GB, available $AvailableDisk GB"
    }
    
    return @{
        IsFeasible = $isFeasible
        CpuFits = $cpuFits
        RamFits = $ramFits
        DiskFits = $diskFits
        Warnings = $warnings
        WarningCount = $warnings.Count
        ProfileTotals = $totals
    }
}

<#
.SYNOPSIS
    Get profile recommendations based on available resources
    
.PARAMETER AvailableCpu
    Available CPU cores
    
.PARAMETER AvailableRam
    Available RAM in GB
    
.PARAMETER AvailableDisk
    Available disk space in GB
    
.OUTPUTS
    PSCustomObject with feasible profiles and recommendation
    
.EXAMPLE
    $rec = Get-ProfileRecommendation -AvailableCpu 16 -AvailableRam 32 -AvailableDisk 500
    Write-Host "Recommended: $($rec.Recommended)"
#>
function Get-ProfileRecommendation {
    param(
        [Parameter(Mandatory = $true)]
        [int]$AvailableCpu,
        
        [Parameter(Mandatory = $true)]
        [int]$AvailableRam,
        
        [Parameter(Mandatory = $true)]
        [int]$AvailableDisk
    )
    
    $profiles = Get-ResourceProfiles
    $feasibleProfiles = @()
    $recommended = $null
    
    # Check each profile
    foreach ($name in @('small', 'medium', 'large')) {
        if ($profiles.ContainsKey($name)) {
            $profile = $profiles[$name]
            $comparison = Compare-ProfileToResources `
                -Profile $profile `
                -AvailableCpu $AvailableCpu `
                -AvailableRam $AvailableRam `
                -AvailableDisk $AvailableDisk
            
            if ($comparison.IsFeasible) {
                $feasibleProfiles += $name
                
                # Set recommended to medium if available, otherwise highest feasible
                if ($name -eq 'medium') {
                    $recommended = $name
                }
            }
        }
    }
    
    # If medium not available, pick highest feasible
    if (-not $recommended -and $feasibleProfiles.Count -gt 0) {
        $recommended = $feasibleProfiles[-1]
    }
    
    return @{
        FeasibleProfiles = @($feasibleProfiles)
        Recommended = $recommended
        FeasibleCount = $feasibleProfiles.Count
    }
}
