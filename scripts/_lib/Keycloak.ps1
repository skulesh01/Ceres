<#
.SYNOPSIS
    CERES Keycloak Management Module
    
.DESCRIPTION
    Provides Keycloak configuration and management for CERES platform:
    - OIDC client bootstrap (Grafana, Wiki.js, Redmine)
    - SMTP configuration for email functionality
    - User management integration
    
    Consolidates functionality from:
    - keycloak-bootstrap.ps1
    - keycloak-smtp.ps1
    
.NOTES
    Version: 3.0
    Part of CERES unified CLI
    Requires: Common.ps1
    Cross-platform: Windows, Linux, macOS
#>

# ============================================================================
# KEYCLOAK BOOTSTRAP
# ============================================================================

<#
.SYNOPSIS
    Bootstraps Keycloak OIDC clients and configuration
.PARAMETER KeycloakBaseUrl
    Base URL for Keycloak (default: https://auth.${DOMAIN})
.PARAMETER Realm
    Keycloak realm to configure (default: master)
.PARAMETER ConfigureSmtp
    Also configure SMTP settings
#>
function Invoke-CeresKeycloakBootstrap {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$KeycloakBaseUrl,
        
        [Parameter()]
        [string]$Realm = "master",
        
        [Parameter()]
        [switch]$ConfigureSmtp,
        
        [Parameter()]
        [switch]$InsecureTls
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Keycloak Bootstrap                                     ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Load environment
    $configDir = Get-CeresConfigDir
    $envPath = Join-Path $configDir ".env"
    
    if (-not (Test-Path $envPath)) {
        Write-Host "❌ .env file not found: $envPath" -ForegroundColor Red
        return $false
    }
    
    $envMap = Read-DotEnvFile -Path $envPath
    
    # Get configuration
    $domain = $envMap['DOMAIN']
    if (-not $domain) { $domain = 'ceres' }
    
    if (-not $KeycloakBaseUrl) {
        $KeycloakBaseUrl = "https://auth.$domain"
    }
    
    $adminUser = $envMap['KEYCLOAK_ADMIN']
    if (-not $adminUser) { $adminUser = 'admin' }
    
    $adminPass = $envMap['KEYCLOAK_ADMIN_PASSWORD']
    if (-not $adminPass) {
        Write-Host "❌ KEYCLOAK_ADMIN_PASSWORD is missing from .env" -ForegroundColor Red
        return $false
    }
    
    # Disable TLS validation if requested
    if ($InsecureTls) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $script:__oldCertCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    }
    
    try {
        Write-Host "🔑 Authenticating to Keycloak..." -ForegroundColor Cyan
        $token = Get-KeycloakAdminToken -BaseUrl $KeycloakBaseUrl -Realm $Realm -Username $adminUser -Password $adminPass
        
        if (-not $token) {
            Write-Host "❌ Failed to authenticate" -ForegroundColor Red
            return $false
        }
        
        Write-Host "✅ Authenticated successfully" -ForegroundColor Green
        
        # Configure SMTP if requested
        if ($ConfigureSmtp) {
            Write-Host "`n📧 Configuring SMTP..." -ForegroundColor Cyan
            $smtpConfigured = Set-KeycloakSmtp -BaseUrl $KeycloakBaseUrl -Realm $Realm -Token $token -EnvMap $envMap
            
            if ($smtpConfigured) {
                Write-Host "✅ SMTP configured" -ForegroundColor Green
            }
            else {
                Write-Host "⚠️  SMTP not configured (missing SMTP_HOST or SMTP_FROM)" -ForegroundColor Yellow
            }
        }
        
        # Bootstrap OIDC clients
        Write-Host "`n🔧 Creating OIDC clients..." -ForegroundColor Cyan
        
        # Grafana
        $grafanaSecret = $envMap['GRAFANA_OIDC_CLIENT_SECRET']
        if ($grafanaSecret) {
            Write-Host "  • Grafana..." -NoNewline
            $grafanaPublic = "https://grafana.$domain"
            
            $result = Set-KeycloakOidcClient `
                -BaseUrl $KeycloakBaseUrl `
                -Realm $Realm `
                -Token $token `
                -ClientId 'grafana' `
                -Secret $grafanaSecret `
                -RedirectUris @(
                    "http://localhost:3001/login/generic_oauth",
                    "http://localhost:3001/*",
                    "$grafanaPublic/login/generic_oauth",
                    "$grafanaPublic/*"
                ) `
                -WebOrigins @("http://localhost:3001", $grafanaPublic)
            
            if ($result) {
                Write-Host " ✅" -ForegroundColor Green
            }
            else {
                Write-Host " ❌" -ForegroundColor Red
            }
        }
        
        # Wiki.js
        $wikiSecret = $envMap['WIKIJS_OIDC_CLIENT_SECRET']
        $wikiClientId = $envMap['WIKIJS_OIDC_CLIENT_ID']
        if (-not $wikiClientId) { $wikiClientId = 'wikijs' }
        
        if ($wikiSecret) {
            Write-Host "  • Wiki.js..." -NoNewline
            $wikiPublic = "https://wiki.$domain"
            
            $result = Set-KeycloakOidcClient `
                -BaseUrl $KeycloakBaseUrl `
                -Realm $Realm `
                -Token $token `
                -ClientId $wikiClientId `
                -Secret $wikiSecret `
                -RedirectUris @(
                    "http://localhost:8083/*",
                    "http://localhost:8083/login/keycloak/callback",
                    "$wikiPublic/*",
                    "$wikiPublic/login/keycloak/callback"
                ) `
                -WebOrigins @("http://localhost:8083", $wikiPublic)
            
            if ($result) {
                Write-Host " ✅" -ForegroundColor Green
            }
            else {
                Write-Host " ❌" -ForegroundColor Red
            }
        }
        
        Write-Host "`n✅ Keycloak bootstrap completed!" -ForegroundColor Green
        Write-Host ""
        
        return $true
    }
    catch {
        Write-Host "`n❌ Bootstrap failed: $_" -ForegroundColor Red
        return $false
    }
    finally {
        if ($InsecureTls) {
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $script:__oldCertCallback
            Remove-Variable -Name __oldCertCallback -Scope Script -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Gets admin token from Keycloak
#>
function Get-KeycloakAdminToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory)]
        [string]$Realm,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$Password
    )
    
    $tokenUrl = "$BaseUrl/realms/$Realm/protocol/openid-connect/token"
    
    $body = @{
        grant_type = 'password'
        client_id  = 'admin-cli'
        username   = $Username
        password   = $Password
    }
    
    try {
        $response = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType 'application/x-www-form-urlencoded'
        return $response.access_token
    }
    catch {
        return $null
    }
}

<#
.SYNOPSIS
    Invokes Keycloak API
#>
function Invoke-KeycloakApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Method,
        
        [Parameter(Mandatory)]
        [string]$Url,
        
        [Parameter(Mandatory)]
        [string]$Token,
        
        [Parameter()]
        $Body = $null
    )
    
    $headers = @{ Authorization = "Bearer $Token" }
    
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
    }
    
    $json = ($Body | ConvertTo-Json -Depth 20)
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType 'application/json' -Body $json
}

<#
.SYNOPSIS
    Configures SMTP for Keycloak realm
#>
function Set-KeycloakSmtp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory)]
        [string]$Realm,
        
        [Parameter(Mandatory)]
        [string]$Token,
        
        [Parameter(Mandatory)]
        [hashtable]$EnvMap
    )
    
    $smtpHost = $EnvMap['SMTP_HOST']
    $smtpFrom = $EnvMap['SMTP_FROM']
    
    if (-not $smtpHost -or $smtpHost -eq 'CHANGE_ME' -or -not $smtpFrom -or $smtpFrom -eq 'CHANGE_ME') {
        return $false
    }
    
    $smtpPort = $EnvMap['SMTP_PORT']
    if (-not $smtpPort -or $smtpPort -eq 'CHANGE_ME') { $smtpPort = '587' }
    
    $smtpUser = $EnvMap['SMTP_USER']
    $smtpPass = $EnvMap['SMTP_PASSWORD']
    $smtpAuth = Convert-ToBoolString -Value $EnvMap['SMTP_AUTH'] -Default:([bool]($smtpUser -and $smtpPass))
    $smtpStartTls = Convert-ToBoolString -Value $EnvMap['SMTP_STARTTLS'] -Default:$true
    $smtpSsl = Convert-ToBoolString -Value $EnvMap['SMTP_SSL'] -Default:$false
    
    $smtp = @{
        host     = $smtpHost
        port     = "$smtpPort"
        from     = $smtpFrom
        auth     = $smtpAuth
        starttls = $smtpStartTls
        ssl      = $smtpSsl
    }
    
    if ($smtpUser -and $smtpUser -ne 'CHANGE_ME') { $smtp.user = $smtpUser }
    if ($smtpPass -and $smtpPass -ne 'CHANGE_ME') { $smtp.password = $smtpPass }
    
    $fromName = $EnvMap['SMTP_FROM_NAME']
    if ($fromName -and $fromName -ne 'CHANGE_ME') { $smtp.fromDisplayName = $fromName }
    
    $replyTo = $EnvMap['SMTP_REPLY_TO']
    if ($replyTo -and $replyTo -ne 'CHANGE_ME') { $smtp.replyTo = $replyTo }
    
    $realmUrl = "$BaseUrl/admin/realms/$Realm"
    $realmData = Invoke-KeycloakApi -Method Get -Url $realmUrl -Token $Token
    $realmData.smtpServer = $smtp
    
    Invoke-KeycloakApi -Method Put -Url $realmUrl -Token $Token -Body $realmData | Out-Null
    
    return $true
}

<#
.SYNOPSIS
    Creates or updates OIDC client in Keycloak
#>
function Set-KeycloakOidcClient {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUrl,
        
        [Parameter(Mandatory)]
        [string]$Realm,
        
        [Parameter(Mandatory)]
        [string]$Token,
        
        [Parameter(Mandatory)]
        [string]$ClientId,
        
        [Parameter(Mandatory)]
        [string]$Secret,
        
        [Parameter(Mandatory)]
        [string[]]$RedirectUris,
        
        [Parameter(Mandatory)]
        [string[]]$WebOrigins
    )
    
    try {
        $clientsUrl = "$BaseUrl/admin/realms/$Realm/clients"
        $found = Invoke-KeycloakApi -Method Get -Url ("${clientsUrl}?clientId=$ClientId") -Token $Token
        
        $client = $null
        if ($found -and $found.Count -gt 0) {
            $client = $found[0]
        }
        
        if (-not $client) {
            # Create new client
            $createBody = @{
                clientId = $ClientId
                enabled = $true
                protocol = 'openid-connect'
                publicClient = $false
                standardFlowEnabled = $true
                implicitFlowEnabled = $false
                directAccessGrantsEnabled = $false
                serviceAccountsEnabled = $false
                redirectUris = $RedirectUris
                webOrigins = $WebOrigins
                secret = $Secret
            }
            
            Invoke-KeycloakApi -Method Post -Url $clientsUrl -Token $Token -Body $createBody | Out-Null
        }
        else {
            # Update existing client
            $rep = Invoke-KeycloakApi -Method Get -Url ("$clientsUrl/$($client.id)") -Token $Token
            $rep.enabled = $true
            $rep.protocol = 'openid-connect'
            $rep.publicClient = $false
            $rep.standardFlowEnabled = $true
            $rep.implicitFlowEnabled = $false
            $rep.directAccessGrantsEnabled = $false
            $rep.serviceAccountsEnabled = $false
            $rep.redirectUris = $RedirectUris
            $rep.webOrigins = $WebOrigins
            $rep.secret = $Secret
            
            Invoke-KeycloakApi -Method Put -Url ("$clientsUrl/$($client.id)") -Token $Token -Body $rep | Out-Null
        }
        
        return $true
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Converts string to boolean
#>
function Convert-ToBoolString {
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyString()][string]$Value,
        [bool]$Default
    )
    
    if ($null -eq $Value -or $Value.Trim() -eq '') {
        return ($(if ($Default) { 'true' } else { 'false' }))
    }
    
    switch ($Value.Trim().ToLowerInvariant()) {
        '1' { return 'true' }
        'true' { return 'true' }
        'yes' { return 'true' }
        'y' { return 'true' }
        'on' { return 'true' }
        '0' { return 'false' }
        'false' { return 'false' }
        'no' { return 'false' }
        'n' { return 'false' }
        'off' { return 'false' }
        default { return ($(if ($Default) { 'true' } else { 'false' })) }
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-CeresKeycloakBootstrap'
)
