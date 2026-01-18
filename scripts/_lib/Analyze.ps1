# CERES CLI Analyze Module
# Cross-platform resource analysis (Windows, Linux, macOS)

function Get-SystemResources {
    # Get CPU cores (works on all platforms)
    $cpu = [Environment]::ProcessorCount
    
    # Get RAM - platform specific
    $ram = 0
    $os = "Windows"
    
    # Detect OS
    if ($PSVersionTable.OS) {
        # PowerShell Core 6.0+
        if ($PSVersionTable.OS -like "*Linux*") {
            $os = "Linux"
        } elseif ($PSVersionTable.OS -like "*Darwin*") {
            $os = "macOS"
        } else {
            $os = "Windows"
        }
    } else {
        # PowerShell 5.1 (Windows only)
        $os = "Windows"
    }
    
    # Get memory for Windows
    if ($os -eq "Windows") {
        try {
            $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB)
        } catch {
            $ram = 8  # Default fallback
        }
    } else {
        # Linux/macOS - read from /proc/meminfo
        if (Test-Path /proc/meminfo) {
            try {
                $memLine = Select-String "MemTotal" /proc/meminfo | Select-Object -First 1
                if ($memLine) {
                    $memKB = [int]($memLine -split '\s+')[1]
                    $ram = [math]::Round($memKB / 1024 / 1024)
                }
            } catch {
                $ram = 8
            }
        } elseif ($os -eq "macOS") {
            # macOS fallback
            try {
                $sysctl = sysctl hw.memsize 2>/dev/null
                if ($sysctl) {
                    $memBytes = [long]($sysctl -split ':')[1].Trim()
                    $ram = [math]::Round($memBytes / 1GB)
                }
            } catch {
                $ram = 8
            }
        } else {
            $ram = 8
        }
    }
    
    # Get disk space
    $disk = 100
    try {
        if ($os -eq "Windows") {
            $diskInfo = Get-Volume -DriveLetter C -ErrorAction SilentlyContinue
            if ($diskInfo) {
                $disk = [math]::Round($diskInfo.SizeRemaining / 1GB)
            }
        } else {
            # Linux/macOS - use df
            $dfOutput = df -B1 / 2>/dev/null | Select-Object -Last 1
            if ($dfOutput) {
                $parts = $dfOutput -split '\s+' | Where-Object { $_ }
                if ($parts.Count -ge 4) {
                    $disk = [math]::Round([long]$parts[3] / 1GB)
                }
            }
        }
    } catch {
        $disk = 100  # Default fallback
    }
    
    @{
        CPU  = $cpu
        RAM  = $ram
        Disk = $disk
        OS   = $os
    }
}

function Format-AnalysisReport {
    param([hashtable]$Resources)
    
    Write-Host ""
    Write-Host "System Resources" -ForegroundColor Cyan
    Write-Host "  CPU (cores):    $($Resources.CPU)" -ForegroundColor White
    Write-Host "  RAM (GB):       $($Resources.RAM) GB" -ForegroundColor White
    Write-Host "  Disk (GB):      $($Resources.Disk) GB" -ForegroundColor White
    Write-Host "  OS:             $($Resources.OS)" -ForegroundColor Gray
    Write-Host ""
    
    if ($Resources.CPU -ge 10 -and $Resources.RAM -ge 20) {
        Write-Host "Recommendation: LARGE profile (K8s HA, 5 VMs, 24 CPU, 56GB RAM)" -ForegroundColor Green
    }
    elseif ($Resources.CPU -ge 8 -and $Resources.RAM -ge 16) {
        Write-Host "Recommendation: MEDIUM profile (K8s, 3 VMs, 10 CPU, 20GB RAM)" -ForegroundColor Green
    }
    else {
        Write-Host "Recommendation: SMALL profile (Docker, 1 VM, 4 CPU, 8GB RAM)" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Invoke-ResourceAnalysis {
    param([string]$Format = 'console', [switch]$Export)
    
    $resources = Get-SystemResources
    Format-AnalysisReport -Resources $resources
    
    if ($Format -eq 'json') {
        $resources | ConvertTo-Json
    }
}
