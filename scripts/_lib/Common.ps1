<#
.SYNOPSIS
    Common functions for CERES CLI

.DESCRIPTION
    Shared utilities for all CERES modules
#>

# Define paths
$script:CeresRoot = if ($null -ne $CeresRoot) { $CeresRoot } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$script:ConfigPath = Join-Path $CeresRoot "config"
$script:ProfilesPath = Join-Path $ConfigPath "profiles"
$script:EnvFile = Join-Path $ConfigPath ".env"
$script:DeploymentPlanFile = Join-Path $ConfigPath "DEPLOYMENT_PLAN.json"

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-CeresInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-CeresSuccess {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-CeresWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-CeresError {
    param([string]$Message, [int]$ExitCode = 1)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit $ExitCode
}

function Write-CeresSection {
    param([string]$Text)
    Write-Host ""
    Write-Host "--- $Text ---" -ForegroundColor Yellow
}

# ============================================================================
# ENVIRONMENT FUNCTIONS
# ============================================================================

function Get-CeresEnvironment {
    $env = @{}
    if (Test-Path $EnvFile) {
        Get-Content $EnvFile | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object {
            $parts = $_ -split "=", 2
            if ($parts.Count -eq 2) {
                $key = $parts[0].Trim()
                $value = $parts[1].Trim().Trim('"', "'")
                $env[$key] = $value
            }
        }
    }
    return $env
}

function Get-DeploymentPlan {
    if (-not (Test-Path $DeploymentPlanFile)) {
        Write-CeresWarning "DEPLOYMENT_PLAN.json not found"
        return $null
    }
    try {
        return Get-Content $DeploymentPlanFile | ConvertFrom-Json
    }
    catch {
        Write-CeresError "Failed to parse DEPLOYMENT_PLAN.json: $_"
    }
}

function Save-DeploymentPlan {
    param([PSCustomObject]$Plan)
    try {
        $Plan | ConvertTo-Json -Depth 10 | Set-Content $DeploymentPlanFile -Encoding UTF8
        Write-CeresSuccess "Deployment plan saved"
    }
    catch {
        Write-CeresError "Failed to save plan: $_"
    }
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

function Get-ProfilePath {
    param([string]$ProfileName)
    return Join-Path $ProfilesPath "$ProfileName.json"
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    try {
        return Get-Content $Path | ConvertFrom-Json
    }
    catch {
        Write-CeresWarning "Failed to parse $Path"
        return $null
    }
}

# ============================================================================
# COMMAND UTILITIES
# ============================================================================

function Test-CommandExists {
    param([string]$Command)
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    if ($exists) {
        Write-CeresSuccess "$Command is installed"
    } else {
        Write-CeresWarning "$Command not found"
    }
    return $exists
}

function Get-CommandVersion {
    param([string]$Command)
    try {
        $output = & $Command --version 2>&1
        return ($output | Select-Object -First 1).ToString()
    }
    catch {
        return "unknown"
    }
}

function Test-Port {
    param([int]$Port, [string]$Host = "localhost")
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($Host, $Port)
        $tcp.Close()
        return $true
    }
    catch {
        return $false
    }
}

# ============================================================================
# PASSWORD GENERATION
# ============================================================================

function New-SecurePassword {
    param([int]$Length = 32, [bool]$Special = $true)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    if ($Special) { $chars += "!@#$%^&*" }
    
    $password = ""
    $random = [System.Random]::new()
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $chars[$random.Next($chars.Length)]
    }
    return $password
}

# ============================================================================
# PROCESS EXECUTION
# ============================================================================

function Invoke-CommandSafe {
    param(
        [string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = ""
    )
    
    try {
        if ($WorkingDirectory) { Push-Location $WorkingDirectory }
        Write-CeresInfo "Executing: $Command"
        & $Command $Arguments
        if ($LASTEXITCODE -ne 0) {
            Write-CeresWarning "Command failed (exit: $LASTEXITCODE)"
            return $false
        }
        Write-CeresSuccess "Command succeeded"
        return $true
    }
    catch {
        Write-CeresError "Execution error: $_"
        return $false
    }
    finally {
        if ($WorkingDirectory) { Pop-Location }
    }
}

function Wait-ForPort {
    param([int]$Port, [int]$Timeout = 60)
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $Timeout) {
        if (-not (Test-Port $Port)) {
            Write-CeresSuccess "Port $Port is now available"
            return $true
        }
        Start-Sleep -Seconds 2
        Write-Host "." -NoNewline -ForegroundColor Gray
    }
    Write-CeresWarning "Timeout waiting for port $Port"
    return $false
}

# ============================================================================
# FORMATTING
# ============================================================================

function Format-AsJson {
    param([PSCustomObject]$Object, [int]$Depth = 10)
    return $Object | ConvertTo-Json -Depth $Depth
}
