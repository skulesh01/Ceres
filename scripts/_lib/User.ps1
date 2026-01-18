<#
.SYNOPSIS
    CERES User Management Module
    
.DESCRIPTION
    Provides user management for CERES platform:
    - Employee onboarding (email + VPN)
    - VPN user creation
    - Integration with Mailu, wg-easy, Keycloak
    
    Consolidates functionality from:
    - create-employee.ps1
    - add-vpn-user.ps1
    
.NOTES
    Version: 3.0
    Part of CERES unified CLI
    Requires: Common.ps1
    Cross-platform: Windows, Linux, macOS
#>

# ============================================================================
# USER CREATION
# ============================================================================

<#
.SYNOPSIS
    Creates a new employee with email and VPN access
.PARAMETER Username
    Username (alphanumeric only, no spaces)
.PARAMETER FullName
    Full name of employee
.PARAMETER Password
    Password for email account (min 8 characters)
.PARAMETER CreateKeycloak
    Also create Keycloak SSO account
#>
function New-CeresEmployee {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9._-]+$')]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$FullName,
        
        [Parameter(Mandatory)]
        [ValidateLength(8, 64)]
        [string]$Password,
        
        [Parameter()]
        [switch]$CreateKeycloak,
        
        [Parameter()]
        [string]$Domain = "ceres.local"
    )
    
    $Email = "${Username}@${Domain}"
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          New Employee Creation                                  ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "Username:    $Username" -ForegroundColor White
    Write-Host "Full Name:   $FullName" -ForegroundColor White
    Write-Host "Email:       $Email" -ForegroundColor White
    Write-Host ""
    
    # Step 1: Create email account
    Write-Host "[1/3] Creating email account..." -NoNewline
    $emailCreated = New-CeresMailbox -Email $Email -Password $Password -FullName $FullName
    
    if ($emailCreated) {
        Write-Host " ✅" -ForegroundColor Green
    }
    else {
        Write-Host " ❌ Failed" -ForegroundColor Red
        return $false
    }
    
    # Step 2: Create VPN account
    Write-Host "[2/3] Creating VPN account..." -NoNewline
    $vpnConfig = New-CeresVpnUser -Username $Username
    
    if ($vpnConfig) {
        Write-Host " ✅" -ForegroundColor Green
    }
    else {
        Write-Host " ⚠️  Failed (optional)" -ForegroundColor Yellow
    }
    
    # Step 3: Keycloak (optional)
    if ($CreateKeycloak) {
        Write-Host "[3/3] Creating Keycloak account..." -NoNewline
        $kcCreated = New-CeresKeycloakUser -Username $Username -Email $Email -FullName $FullName -Password $Password
        
        if ($kcCreated) {
            Write-Host " ✅" -ForegroundColor Green
        }
        else {
            Write-Host " ⚠️  Failed (optional)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n✅ Employee created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Credentials to send to employee:" -ForegroundColor Cyan
    Write-Host "  Email:    $Email" -ForegroundColor White
    Write-Host "  Password: [provided]" -ForegroundColor White
    
    if ($vpnConfig) {
        Write-Host "  VPN Config: $vpnConfig" -ForegroundColor White
    }
    
    Write-Host ""
    return $true
}

# ============================================================================
# VPN MANAGEMENT
# ============================================================================

<#
.SYNOPSIS
    Creates VPN user and returns config file path
.PARAMETER Username
    Username for VPN
.PARAMETER OutputPath
    Directory to save VPN config (default: ./vpn-configs)
#>
function New-CeresVpnUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter()]
        [string]$OutputPath = "./vpn-configs"
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          VPN User Creation                                      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath | Out-Null
    }
    
    $configFile = Join-Path $OutputPath "$Username.conf"
    
    Write-Host "🔒 Creating VPN config for: $Username" -ForegroundColor Cyan
    Write-Host ""
    
    # TODO: Implementation depends on VPN setup (wg-easy API or direct WireGuard commands)
    # For now, return placeholder
    
    Write-Host "⚠️  VPN creation requires wg-easy API or SSH access to server" -ForegroundColor Yellow
    Write-Host "   Use legacy script: scripts/add-vpn-user.ps1" -ForegroundColor Yellow
    Write-Host ""
    
    return $null
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Creates mailbox in Mailu
#>
function New-CeresMailbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Email,
        
        [Parameter(Mandatory)]
        [string]$Password,
        
        [Parameter()]
        [string]$FullName
    )
    
    # TODO: Implementation requires Mailu Admin API
    # For now, return placeholder
    
    Write-Host "`n⚠️  Email creation requires Mailu API access" -ForegroundColor Yellow
    Write-Host "   Use legacy script: scripts/create-employee.ps1" -ForegroundColor Yellow
    Write-Host ""
    
    return $false
}

<#
.SYNOPSIS
    Creates user in Keycloak
#>
function New-CeresKeycloakUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$Email,
        
        [Parameter()]
        [string]$FullName,
        
        [Parameter()]
        [string]$Password
    )
    
    # TODO: Implementation requires Keycloak Admin API
    # For now, return placeholder
    
    return $false
}

# Export public functions
Export-ModuleMember -Function @(
    'New-CeresEmployee',
    'New-CeresVpnUser'
)
