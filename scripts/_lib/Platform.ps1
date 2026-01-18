# CERES Platform Detection Module
# Detect OS and provide cross-platform utilities

function Get-PlatformInfo {
    <#
    .SYNOPSIS
        Detect current platform and return platform information
    .RETURNS
        hashtable with: OS, IsWindows, IsLinux, IsMacOS, PowerShellVersion
    #>
    
    $os = "Windows"  # Default for PS 5.1
    
    # PowerShell Core 6.0+ has $PSVersionTable.OS
    if ($PSVersionTable.OS) {
        if ($PSVersionTable.OS -like "*Linux*") {
            $os = "Linux"
        } elseif ($PSVersionTable.OS -like "*Darwin*") {
            $os = "macOS"
        } else {
            $os = "Windows"
        }
    }
    
    $osInfo = @{
        OS                = $os
        IsWindows         = $os -eq "Windows"
        IsLinux           = $os -eq "Linux"
        IsMacOS           = $os -eq "macOS"
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PSEdition         = $PSVersionTable.PSEdition
    }
    
    return $osInfo
}

function Test-CommandOnPlatform {
    <#
    .SYNOPSIS
        Check if command exists on current platform
    .PARAMETER Command
        Command name to check
    .RETURNS
        $true if command exists, $false otherwise
    #>
    param([string]$Command)
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    return $exists
}

function Get-MemoryGB {
    <#
    .SYNOPSIS
        Get available memory in GB (cross-platform)
    .RETURNS
        [long] GB of RAM available
    #>
    
    try {
        # Detect platform
        $platform = Get-PlatformInfo
        
        if ($platform.IsWindows) {
            return [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB)
        }
        elseif ($platform.IsLinux -and (Test-Path /proc/meminfo)) {
            $memLine = Select-String "MemTotal" /proc/meminfo | Select-Object -First 1
            if ($memLine) {
                $memKB = [long]($memLine -split '\s+')[1]
                return [math]::Round($memKB / 1024 / 1024)
            }
        }
        elseif ($platform.IsMacOS) {
            $result = sysctl hw.memsize 2>/dev/null
            if ($result) {
                $memBytes = [long]($result -split ':')[1].Trim()
                return [math]::Round($memBytes / 1GB)
            }
        }
    }
    catch {
        # Silently return default
    }
    
    return 8  # Default fallback
}

function Get-CPUCores {
    <#
    .SYNOPSIS
        Get number of CPU cores (cross-platform)
    .RETURNS
        [int] number of logical cores
    #>
    
    return [Environment]::ProcessorCount
}

function Get-DiskSpaceGB {
    <#
    .SYNOPSIS
        Get available disk space in GB (cross-platform)
    .PARAMETER Path
        Path to check (default: root or C:)
    .RETURNS
        [long] GB of available space
    #>
    param([string]$Path = "")
    
    try {
        if ([string]::IsNullOrEmpty($Path)) {
            $platform = Get-PlatformInfo
            $Path = if ($platform.IsWindows) { "C:\" } else { "/" }
        }
        
        if (Test-Path $Path) {
            $platform = Get-PlatformInfo
            
            if ($platform.IsWindows) {
                $drive = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq ($Path[0]) } | Select-Object -First 1
                if ($drive) {
                    return [math]::Round($drive.SizeRemaining / 1GB)
                }
            }
            else {
                # Linux/macOS - use df
                $dfOutput = df -B1 $Path 2>/dev/null | Select-Object -Last 1
                if ($dfOutput) {
                    $parts = $dfOutput -split '\s+' | Where-Object { $_ }
                    if ($parts.Count -ge 4) {
                        return [math]::Round([long]$parts[3] / 1GB)
                    }
                }
            }
        }
    }
    catch {
        # Silently return default
    }
    
    return 100  # Default fallback
}

function Invoke-OSCommand {
    <#
    .SYNOPSIS
        Execute OS-specific command
    .PARAMETER WindowsCmd
        Command to run on Windows
    .PARAMETER UnixCmd
        Command to run on Linux/macOS
    .RETURNS
        Command output
    #>
    param(
        [string]$WindowsCmd,
        [string]$UnixCmd
    )
    
    try {
        if ($PSVersionTable.Platform -eq "Win32NT") {
            Invoke-Expression $WindowsCmd
        }
        else {
            Invoke-Expression $UnixCmd
        }
    }
    catch {
        Write-Host "Error executing OS command: $_" -ForegroundColor Red
    }
}

function Get-EnvironmentPath {
    <#
    .SYNOPSIS
        Get cross-platform environment path
    .RETURNS
        hashtable with standard paths
    #>
    
    $platform = Get-PlatformInfo
    
    if ($platform.IsWindows) {
        return @{
            Home      = $env:USERPROFILE
            Temp      = $env:TEMP
            Separator = "\"
        }
    }
    else {
        return @{
            Home      = $env:HOME
            Temp      = $env:TMPDIR -or "/tmp"
            Separator = "/"
        }
    }
}

function Test-DockerAvailable {
    <#
    .SYNOPSIS
        Check if Docker is installed and running
    .RETURNS
        $true if Docker is available
    #>
    
    try {
        $version = docker version 2>$null
        return $null -ne $version
    }
    catch {
        return $false
    }
}

function Test-KubectlAvailable {
    <#
    .SYNOPSIS
        Check if kubectl is installed
    .RETURNS
        $true if kubectl is available
    #>
    
    return $null -ne (Get-Command kubectl -ErrorAction SilentlyContinue)
}
