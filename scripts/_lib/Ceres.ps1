<#
.SYNOPSIS
    CERES Core Library - Shared functions for CERES platform management

.DESCRIPTION
    This module provides core functionality for CERES platform:
    - Configuration management
    - Docker validation
    - Secret generation
    - Environment file operations
    - Compose file orchestration

.NOTES
    Version: 2.1
    Author: CERES Project
    Principles: SOLID design patterns applied
    
    Single Responsibility: Each function has one clear purpose
    Open/Closed: Extensible through parameters, closed for modification
    Liskov Substitution: Functions maintain consistent contracts
    Interface Segregation: Small, focused functions
    Dependency Inversion: Depends on abstractions (paths, params)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Path Management (Single Responsibility)

<#
.SYNOPSIS
    Gets the absolute path to CERES config directory
.DESCRIPTION
    Resolves the config directory path relative to script location.
    Ensures consistent path resolution across all scripts.
.OUTPUTS
    String - Full path to config directory
.EXAMPLE
    $configPath = Get-CeresConfigDir
#>
function Get-CeresConfigDir {
    $scriptsDir = Split-Path -Parent $PSScriptRoot
    return (Resolve-Path (Join-Path $scriptsDir "..\\config")).Path
}

#endregion

#region Environment File Operations (Single Responsibility)

#region Environment File Operations (Single Responsibility)

<#
.SYNOPSIS
    Reads and parses .env file into a hashtable
.DESCRIPTION
    Parses KEY=VALUE pairs from environment file.
    Ignores comments (#) and empty lines.
    Thread-safe and idempotent.
.PARAMETER Path
    Full path to .env file
.OUTPUTS
    Hashtable - Key-value pairs from env file
.EXAMPLE
    $envVars = Read-DotEnvFile -Path "C:\project\config\.env"
.NOTES
    Open/Closed Principle: Extensible format support without modifying core logic
#>
function Read-DotEnvFile {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        throw "Environment file not found: $Path"
    }

    $map = @{}
    foreach ($line in Get-Content -Path $Path -ErrorAction Stop) {
        $trimmed = $line.Trim()
        
        # Skip empty lines and comments
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $separatorIndex = $trimmed.IndexOf('=')
        if ($separatorIndex -lt 1) {
            continue
        }

        $key = $trimmed.Substring(0, $separatorIndex).Trim()
        $value = $trimmed.Substring($separatorIndex + 1).Trim()
        
        # Store in hashtable (last value wins for duplicates)
        $map[$key] = $value
    }

    return $map
}

#endregion

#region Docker Management (Single Responsibility)

#region Docker Management (Single Responsibility)

<#
.SYNOPSIS
    Ensures Docker daemon is running and accessible
.DESCRIPTION
    Validates Docker daemon availability.
    Attempts to start Docker Desktop if installed and daemon is not responding.
    Waits up to 2 minutes for daemon to become available.
.THROWS
    Exception if Docker is not available after timeout
.EXAMPLE
    Assert-DockerRunning
.NOTES
    Dependency Inversion: Depends on docker CLI abstraction, not specific implementation
#>
function Assert-DockerRunning {
    [CmdletBinding()]
    param()

    # Quick check if already running
    $null = & docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Verbose "Docker daemon is running"
        return
    }

    # Try to start Docker Desktop if available
    $dockerDesktopPath = "C:\\Program Files\\Docker\\Docker\\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Warning "Docker daemon not responding. Starting Docker Desktop..."
        Start-Process $dockerDesktopPath -WindowStyle Hidden
    }
    else {
        Write-Warning "Docker daemon not responding. Please start Docker manually."
    }

    # Wait for daemon with exponential backoff
    $maxAttempts = 60
    $waitSeconds = 2
    
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Start-Sleep -Seconds $waitSeconds
        
        $null = & docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Docker daemon is now available" -ForegroundColor Green
            return
        }

        if ($attempt % 10 -eq 0) {
            Write-Host "  Still waiting for Docker... ($attempt/$maxAttempts)" -ForegroundColor Gray
        }
    }

    throw "Docker daemon is not available after $($maxAttempts * $waitSeconds) seconds. Please start Docker Desktop and try again."
}

#endregion

#region Secret Generation (Single Responsibility)

#region Secret Generation (Single Responsibility)

<#
.SYNOPSIS
    Generates cryptographically secure random secret
.DESCRIPTION
    Uses .NET RNG to generate base64-encoded random bytes.
    Suitable for passwords, tokens, and other secrets.
.PARAMETER Bytes
    Number of random bytes to generate (default: 32)
.OUTPUTS
    String - Base64-encoded random string
.EXAMPLE
    $password = New-SecureSecret -Bytes 32
.NOTES
    Security: Uses System.Security.Cryptography.RandomNumberGenerator (CSPRNG)
    Single Responsibility: Only generates secrets, doesn't store them
#>
function New-SecureSecret {
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Generates in-memory value only; no persistent state changes'
    )]
    param(
        [Parameter()]
        [ValidateRange(8, 256)]
        [int]$Bytes = 32
    )

    try {
        $buffer = New-Object byte[] $Bytes
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($buffer)
        $rng.Dispose()
        
        return [Convert]::ToBase64String($buffer)
    }
    catch {
        throw "Failed to generate secure secret: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Generates URL-safe random secret
.DESCRIPTION
    Similar to New-SecureSecret but encodes in URL-safe base64 format.
    Replaces +/= characters with -/_ for safe use in URLs.
.PARAMETER Bytes
    Number of random bytes to generate (default: 32)
.OUTPUTS
    String - URL-safe base64-encoded random string
.EXAMPLE
    $token = New-UrlSafeSecret -Bytes 32
.NOTES
    Open/Closed: Extends New-SecureSecret behavior without modifying it
#>
function New-UrlSafeSecret {
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Generates in-memory value only; no persistent state changes'
    )]
    param(
        [Parameter()]
        [ValidateRange(8, 256)]
        [int]$Bytes = 32
    )

    try {
        $buffer = New-Object byte[] $Bytes
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($buffer)
        $rng.Dispose()
        
        $base64 = [Convert]::ToBase64String($buffer)
        # URL-safe encoding: replace + with -, / with _, remove =
        return $base64.TrimEnd('=') -replace '\+', '-' -replace '/', '_'
    }
    catch {
        throw "Failed to generate URL-safe secret: $($_.Exception.Message)"
    }
}

#endregion

#region Environment Initialization (Single Responsibility)

#region Environment Initialization (Single Responsibility)

<#
.SYNOPSIS
    Initializes CERES environment file with secure secrets
.DESCRIPTION
    Creates .env from .env.example if missing.
    Generates secure secrets for keys that are missing or set to CHANGE_ME.
    Idempotent - safe to run multiple times.
.PARAMETER ConfigDir
    Path to config directory containing .env files
.PARAMETER RequiredKeys
    Array of environment variable names that must have secure values
.EXAMPLE
    Initialize-CeresEnv -ConfigDir "C:\ceres\config" -RequiredKeys @("POSTGRES_PASSWORD", "KEYCLOAK_ADMIN_PASSWORD")
.NOTES
    Single Responsibility: Only handles environment initialization
    Interface Segregation: Focused on env file management only
#>
function Initialize-CeresEnv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$ConfigDir,
        
        [Parameter()]
        [string[]]$RequiredKeys
    )

    $envPath = Join-Path $ConfigDir ".env"
    $examplePath = Join-Path $ConfigDir ".env.example"

    # Create .env from example if it doesn't exist
    if (-not (Test-Path $envPath)) {
        if (-not (Test-Path $examplePath)) {
            throw ".env.example not found at: $examplePath"
        }
        
        Copy-Item $examplePath $envPath -ErrorAction Stop
        Write-Warning "Created config/.env from .env.example"
    }

    # If no required keys specified, we're done
    if (-not $RequiredKeys -or $RequiredKeys.Count -eq 0) {
        return
    }

    $content = Get-Content -Path $envPath -Raw -ErrorAction Stop
    $secretsGenerated = 0

    foreach ($key in $RequiredKeys) {
        $escapedKey = [regex]::Escape($key)
        
        # Check if key exists in file
        $keyPattern = "(?m)^${escapedKey}="
        $hasKey = [regex]::IsMatch($content, $keyPattern)
        
        if (-not $hasKey) {
            # Key doesn't exist - add it with new secret
            $secret = New-SecureSecret
            $content = $content.TrimEnd() + "`r`n$key=$secret`r`n"
            $secretsGenerated++
            Write-Verbose "Added new key: $key"
            continue
        }

        # Key exists - check if it needs a value
        $placeholderPattern = "(?m)^${escapedKey}=(CHANGE_ME|)?\s*$"
        if ([regex]::IsMatch($content, $placeholderPattern)) {
            # Replace CHANGE_ME or empty value with secure secret
            $secret = New-SecureSecret
            $content = [regex]::Replace($content, $placeholderPattern, "$key=$secret")
            $secretsGenerated++
            Write-Verbose "Generated secret for: $key"
        }
    }

    if ($secretsGenerated -gt 0) {
        Set-Content -Path $envPath -Value $content -NoNewline -ErrorAction Stop
        Write-Warning "Generated $secretsGenerated secure secret(s) in config/.env (values hidden)"
    }
    else {
        Write-Verbose "All required secrets are already set"
    }
}

#endregion

#region Docker Compose Orchestration (Single Responsibility)

#region Docker Compose Orchestration (Single Responsibility)

<#
.SYNOPSIS
    Builds Docker Compose file argument list based on selected modules
.DESCRIPTION
    Constructs -f file arguments for docker compose based on:
    - Clean mode: uses docker-compose-CLEAN.yml monolith
    - Modular mode: combines base.yml with selected module files
    
    Default modules: core, apps, monitoring, ops
    Optional modules: edms, edge, tunnel, vpn
.PARAMETER SelectedModules
    Array of module names to include
.PARAMETER Clean
    Use monolithic docker-compose-CLEAN.yml instead of modular approach
.OUTPUTS
    String[] - Array of arguments for docker compose command
.EXAMPLE
    $files = Get-CeresComposeFiles -SelectedModules @("core", "apps", "monitoring")
    & docker compose @files up -d
.NOTES
    Open/Closed Principle: Easy to add new modules without modifying core logic
    Liskov Substitution: Always returns valid compose file arguments
#>
function Get-CeresComposeFiles {
    [CmdletBinding()]
    [OutputType([string[]])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseSingularNouns',
        '',
        Justification = 'Returns array of file paths; plural name is semantically correct'
    )]
    param(
        [Parameter()]
        [string[]]$SelectedModules,
        
        [Parameter()]
        [switch]$Clean
    )

    # Clean mode: use monolithic compose file
    if ($Clean) {
        Write-Verbose "Using Clean (monolithic) mode"
        return @("-f", "docker-compose-CLEAN.yml")
    }

    # Modular mode: build file list
    $files = [System.Collections.Generic.List[string]]::new()
    
    # Base is always required
    $files.Add("-f")
    $files.Add("compose/base.yml")

    # Module to file mapping
    $moduleMap = @{
        "core"       = "compose/core.yml"
        "apps"       = "compose/apps.yml"
        "monitoring" = "compose/monitoring.yml"
        "ops"        = "compose/ops.yml"
        "edms"       = "compose/edms.yml"
        "edge"       = "compose/edge.yml"
        "tunnel"     = "compose/tunnel.yml"
        "vpn"        = "compose/vpn.yml"
    }

    # Default modules if none specified
    $defaultModules = @("core", "apps", "monitoring", "ops")
    $modulesToUse = if ($SelectedModules -and $SelectedModules.Count -gt 0) {
        $SelectedModules
    }
    else {
        $defaultModules
    }

    # Add selected modules
    foreach ($module in $modulesToUse) {
        $normalizedModule = $module.ToLowerInvariant()
        
        if (-not $moduleMap.ContainsKey($normalizedModule)) {
            $validModules = ($moduleMap.Keys | Sort-Object) -join ", "
            throw "Unknown module '$module'. Valid modules: $validModules. Or use -Clean for monolithic mode."
        }
        
        $files.Add("-f")
#endregion

#region Remote SSH Operations

<#
.SYNOPSIS
    Executes command on remote host via SSH with cached password
.DESCRIPTION
    Maintains password cache for SSH session to avoid repeated password prompts.
.PARAMETER Host
    SSH host (user@hostname)
.PARAMETER Command
    Command to execute on remote host
.PARAMETER Password
    Optional password
#>
function Invoke-RemoteCommand {
    param(
        [string]$Host,
        [string]$Command,
        [string]$Password
    )
    
    if ($Password) {
        $script:CachedSSHPassword = $Password
    }
    
    $pass = $script:CachedSSHPassword
    echo $pass | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $Host $Command 2>&1
}

function Set-RemoteSSHCredentials {
    param(
        [string]$Host,
        [string]$Password
    )
    $script:CachedSSHPassword = $Password
    Write-Host "SSH credentials cached for $Host"
}

#endregion

Export-ModuleMember -Function @(
    'Get-CeresConfigDir',
    'Read-DotEnvFile',
    'Assert-DockerRunning',
    'New-SecureSecret',
    'New-UrlSafeSecret',
    'Initialize-CeresEnv',
    'Get-CeresComposeFiles',
    'Invoke-RemoteCommand',
    'Set-RemoteSSHCredentials'
)
