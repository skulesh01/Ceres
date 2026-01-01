<#
Idempotent Keycloak bootstrap for CERES (clients + secrets).

Creates/updates OIDC clients using secrets from config/.env, so SSO stays consistent
even if .env is regenerated.

Clients handled:
- grafana
- wikijs

Safe to run multiple times.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script output with colors.'
)]
param(
    [string]$EnvFile = "..\\config\\.env",
    [string]$ProjectName = "ceres",
    [string]$KeycloakBaseUrl = "http://localhost:8081",
    [string]$Realm = "master",
    [switch]$InsecureTls
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

function Get-AdminToken {
    param(
        [string]$BaseUrl,
        [string]$RealmName,
        [hashtable]$Body
    )

    $tokenUrl = "$BaseUrl/realms/$RealmName/protocol/openid-connect/token"

    $resp = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $Body -ContentType 'application/x-www-form-urlencoded'
    if (-not $resp.access_token) {
        throw 'Keycloak token response missing access_token'
    }
    return $resp.access_token
}

function Invoke-Kc {
    param(
        [string]$Method,
        [string]$Url,
        [string]$Token,
        $Body = $null
    )

    $headers = @{ Authorization = "Bearer $Token" }
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
    }

    $json = ($Body | ConvertTo-Json -Depth 20)
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType 'application/json' -Body $json
}

function Convert-ToBoolString {
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
        default {
            return ($(if ($Default) { 'true' } else { 'false' }))
        }
    }
}

function Set-KeycloakRealmSmtp {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$BaseUrl,
        [string]$RealmName,
        [string]$Token,
        [hashtable]$SmtpServer
    )

    if (-not $SmtpServer -or -not $SmtpServer.ContainsKey('host')) {
        return
    }

    if (-not $PSCmdlet.ShouldProcess("Keycloak realm '$RealmName'", 'Configure SMTP')) {
        return
    }

    $realmUrl = "$BaseUrl/admin/realms/$RealmName"
    $rep = Invoke-Kc -Method Get -Url $realmUrl -Token $Token
    $rep.smtpServer = $SmtpServer
    Invoke-Kc -Method Put -Url $realmUrl -Token $Token -Body $rep | Out-Null
}

function Set-KeycloakOidcClient {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$BaseUrl,
        [string]$RealmName,
        [string]$Token,
        [string]$ClientId,
        [string]$Secret,
        [string[]]$RedirectUris,
        [string[]]$WebOrigins
    )

    if (-not $PSCmdlet.ShouldProcess("Keycloak client '$ClientId'", 'Create/Update')) {
        return
    }

    $clientsUrl = "$BaseUrl/admin/realms/$RealmName/clients"
    $found = Invoke-Kc -Method Get -Url ("${clientsUrl}?clientId=$ClientId") -Token $Token
    $client = $null
    if ($found -and $found.Count -gt 0) {
        $client = $found[0]
    }

    if (-not $client) {
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
        Invoke-Kc -Method Post -Url $clientsUrl -Token $Token -Body $createBody | Out-Null
        $client = (Invoke-Kc -Method Get -Url ("${clientsUrl}?clientId=$ClientId") -Token $Token)[0]
    } else {
        $rep = Invoke-Kc -Method Get -Url ("$clientsUrl/$($client.id)") -Token $Token
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
        Invoke-Kc -Method Put -Url ("$clientsUrl/$($client.id)") -Token $Token -Body $rep | Out-Null
    }
}

$envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) { Resolve-Path $EnvFile } else { Resolve-Path (Join-Path $PSScriptRoot $EnvFile) }
$envMap = Read-DotEnvFile -Path $envPath

$domain = $envMap['DOMAIN']
if (-not $domain) { $domain = 'ceres' }

if (-not $PSBoundParameters.ContainsKey('KeycloakBaseUrl')) {
    $KeycloakBaseUrl = "https://auth.$domain"
}

if ($InsecureTls) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $script:__oldCertCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}

$grafanaPublic = "https://grafana.$domain"
$wikiPublic = "https://wiki.$domain"

$adminUser = $envMap['KEYCLOAK_ADMIN']
if (-not $adminUser) { $adminUser = 'admin' }
$adminPass = $envMap['KEYCLOAK_ADMIN_PASSWORD']
if (-not $adminPass) { throw 'KEYCLOAK_ADMIN_PASSWORD is missing' }

$tokenBody = @{ 
    grant_type = 'password'
    client_id  = 'admin-cli'
    username   = $adminUser
    password   = $adminPass
}
$token = Get-AdminToken -BaseUrl $KeycloakBaseUrl -RealmName $Realm -Body $tokenBody

try {
    Write-Host "Bootstrapping Keycloak OIDC clients for project '$ProjectName'..." -ForegroundColor Cyan

    # Optional: configure Keycloak SMTP (realm-level) for password resets / emails.
    # Enable by setting SMTP_HOST and SMTP_FROM in config/.env.
    $smtpHost = $envMap['SMTP_HOST']
    $smtpFrom = $envMap['SMTP_FROM']
    if ($smtpHost -and $smtpHost -ne 'CHANGE_ME') {
        if (-not $smtpFrom -or $smtpFrom -eq 'CHANGE_ME') {
            Write-Host 'SMTP_HOST is set but SMTP_FROM is missing; skipping Keycloak SMTP setup.' -ForegroundColor Yellow
        } else {
            $smtpPort = $envMap['SMTP_PORT']
            if (-not $smtpPort -or $smtpPort -eq 'CHANGE_ME') { $smtpPort = '587' }

            $smtpUser = $envMap['SMTP_USER']
            $smtpPass = $envMap['SMTP_PASSWORD']
            $smtpAuth = Convert-ToBoolString -Value $envMap['SMTP_AUTH'] -Default:([bool]($smtpUser -and $smtpPass))
            $smtpStartTls = Convert-ToBoolString -Value $envMap['SMTP_STARTTLS'] -Default:$true
            $smtpSsl = Convert-ToBoolString -Value $envMap['SMTP_SSL'] -Default:$false

            $smtp = @{
                host     = $smtpHost
                port     = "$smtpPort"
                from     = $smtpFrom
                auth     = $smtpAuth
                starttls = $smtpStartTls
                ssl      = $smtpSsl
            }

            $fromName = $envMap['SMTP_FROM_NAME']
            if ($fromName -and $fromName -ne 'CHANGE_ME') { $smtp.fromDisplayName = $fromName }

            $replyTo = $envMap['SMTP_REPLY_TO']
            if ($replyTo -and $replyTo -ne 'CHANGE_ME') { $smtp.replyTo = $replyTo }

            $replyToName = $envMap['SMTP_REPLY_TO_NAME']
            if ($replyToName -and $replyToName -ne 'CHANGE_ME') { $smtp.replyToDisplayName = $replyToName }

            if ($smtpUser -and $smtpUser -ne 'CHANGE_ME') { $smtp.user = $smtpUser }
            if ($smtpPass -and $smtpPass -ne 'CHANGE_ME') { $smtp.password = $smtpPass }

            Write-Host 'Configuring Keycloak SMTP (realm-level)...' -ForegroundColor Cyan
            Set-KeycloakRealmSmtp -BaseUrl $KeycloakBaseUrl -RealmName $Realm -Token $token -SmtpServer $smtp
        }
    }

    # grafana
    $grafanaSecret = $envMap['GRAFANA_OIDC_CLIENT_SECRET']
    if ($grafanaSecret) {
        Set-KeycloakOidcClient -BaseUrl $KeycloakBaseUrl -RealmName $Realm -Token $token -ClientId 'grafana' -Secret $grafanaSecret `
            -RedirectUris @(
                'http://localhost:3001/login/generic_oauth',
                'http://localhost:3001/*',
                "$grafanaPublic/login/generic_oauth",
                "$grafanaPublic/*"
            ) `
            -WebOrigins @(
                'http://localhost:3001',
                $grafanaPublic
            )
    }

    # wikijs
    $wikiSecret = $envMap['WIKIJS_OIDC_CLIENT_SECRET']
    $wikiClientId = $envMap['WIKIJS_OIDC_CLIENT_ID']
    if (-not $wikiClientId) { $wikiClientId = 'wikijs' }
    if ($wikiSecret) {
        Set-KeycloakOidcClient -BaseUrl $KeycloakBaseUrl -RealmName $Realm -Token $token -ClientId $wikiClientId -Secret $wikiSecret `
            -RedirectUris @(
                'http://localhost:8083/*',
                'http://localhost:8083/login/keycloak/callback',
                "$wikiPublic/*",
                "$wikiPublic/login/keycloak/callback"
            ) `
            -WebOrigins @(
                'http://localhost:8083',
                $wikiPublic
            )
    }

    Write-Host 'Keycloak bootstrap completed.' -ForegroundColor Green
}
finally {
    if ($InsecureTls) {
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $script:__oldCertCallback
        Remove-Variable -Name __oldCertCallback -Scope Script -ErrorAction SilentlyContinue
    }
}
