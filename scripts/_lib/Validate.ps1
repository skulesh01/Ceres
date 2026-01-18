<#
.SYNOPSIS
    Validate module for CERES CLI

.DESCRIPTION
    Environment and configuration validation
#>

# ============================================================================
# ENVIRONMENT VALIDATION
# ============================================================================

function Test-CeresEnvironment {
    Write-CeresSection "Validating CERES Environment"
    
    $requirements = @{
        "PowerShell" = "5.1"
        "Docker" = "20.10"
        "Terraform" = "1.0"
    }
    
    $allPass = $true
    
    foreach ($cmd in $requirements.Keys) {
        if (Test-CommandExists $cmd) {
            $version = Get-CommandVersion $cmd
            Write-CeresSuccess "$cmd version: $version"
        } else {
            Write-CeresWarning "$cmd not found"
            if ($cmd -eq "Docker") { $allPass = $false }
        }
    }
    
    return $allPass
}

# ============================================================================
# CONFLICT VALIDATION
# ============================================================================

function Test-ConfigurationConflicts {
    Write-CeresSection "Checking for Configuration Conflicts"
    
    $ports = @{
        "80" = "Caddy HTTP"
        "443" = "Caddy HTTPS"
        "5432" = "PostgreSQL"
        "6379" = "Redis"
        "8080" = "Keycloak"
    }
    
    $hasConflicts = $false
    
    foreach ($port in $ports.Keys) {
        if (Test-Port $port) {
            Write-CeresWarning "Port $port ($($ports[$port])) is in use"
            $hasConflicts = $true
        } else {
            Write-CeresSuccess "Port $port is available"
        }
    }
    
    # Check environment variables
    Write-CeresSection "Checking Environment Variables"
    
    $env = Get-CeresEnvironment
    $required = @("DOMAIN", "POSTGRES_PASSWORD", "KEYCLOAK_ADMIN_PASSWORD")
    
    foreach ($var in $required) {
        if ($env.ContainsKey($var) -and $env[$var] -ne "CHANGE_ME") {
            Write-CeresSuccess "$var is configured"
        } else {
            Write-CeresWarning "$var is not configured"
            $hasConflicts = $true
        }
    }
    
    return -not $hasConflicts
}

# ============================================================================
# PROFILE VALIDATION
# ============================================================================

function Test-DeploymentPlan {
    Write-CeresSection "Validating Deployment Plan"
    
    $plan = Get-DeploymentPlan
    if (-not $plan) {
        Write-CeresWarning "No deployment plan found"
        return $false
    }
    
    if ($plan.profile -and $plan.timestamp) {
        Write-CeresSuccess "Deployment plan is valid"
        Write-CeresInfo "Profile: $($plan.profile.name)"
        return $true
    }
    
    Write-CeresWarning "Deployment plan structure is invalid"
    return $false
}

# ============================================================================
# RESOURCE VALIDATION
# ============================================================================

function Test-ResourcesAvailable {
    param([string]$ProfileName)
    
    Write-CeresSection "Checking Resources for $ProfileName"
    
    $profilePath = Get-ProfilePath $ProfileName
    $profile = Read-JsonFile $profilePath
    
    if (-not $profile) {
        return $false
    }
    
    # Get system resources (cross-platform)
    $sysCpu = [Environment]::ProcessorCount
    $sysRam = 0
    
    # Detect OS
    $os = "Windows"
    if ($PSVersionTable.OS) {
        if ($PSVersionTable.OS -like "*Linux*") {
            $os = "Linux"
        } elseif ($PSVersionTable.OS -like "*Darwin*") {
            $os = "macOS"
        }
    }
    
    # Get memory for Windows
    if ($os -eq "Windows") {
        try {
            $sysRam = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB)
        } catch {
            $sysRam = 8
        }
    } else {
        # Linux/macOS
        if (Test-Path /proc/meminfo) {
            try {
                $memLine = Select-String "MemTotal" /proc/meminfo | Select-Object -First 1
                if ($memLine) {
                    $memKB = [long]($memLine -split '\s+')[1]
                    $sysRam = [math]::Round($memKB / 1024 / 1024)
                }
            } catch {
                $sysRam = 8
            }
        } elseif ($os -eq "macOS") {
            try {
                $sysctl = sysctl hw.memsize 2>/dev/null
                if ($sysctl) {
                    $memBytes = [long]($sysctl -split ':')[1].Trim()
                    $sysRam = [math]::Round($memBytes / 1GB)
                }
            } catch {
                $sysRam = 8
            }
        } else {
            $sysRam = 8
        }
    }
    
    Write-CeresInfo "System: $sysCpu CPU, $sysRam GB RAM ($os)"
    Write-CeresInfo "Profile needs: $($profile.resources.cpu) CPU, $($profile.resources.memory) GB RAM"
    
    $ok = $sysCpu -ge $profile.resources.cpu -and $sysRam -ge $profile.resources.memory
    
    if ($ok) {
        Write-CeresSuccess "Resources are sufficient"
    } else {
        Write-CeresWarning "Insufficient resources"
    }
    
    return $ok
}

# ============================================================================
# COMPREHENSIVE REPORT
# ============================================================================

function Get-ValidationReport {
    Write-CeresHeader "Full Validation Report"
    
    $env = Test-CeresEnvironment
    $conflicts = Test-ConfigurationConflicts
    $plan = Test-DeploymentPlan
    
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Environment: $(if ($env) { 'PASS' } else { 'FAIL' })"
    Write-Host "  No Conflicts: $(if ($conflicts) { 'PASS' } else { 'FAIL' })"
    Write-Host "  Plan Valid: $(if ($plan) { 'PASS' } else { 'FAIL' })"
    
    return $env -and $conflicts -and $plan
}

function Write-CeresHeader {
    param([string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
    Write-Host ""
}
