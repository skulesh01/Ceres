<#
Configure Keycloak SMTP (realm-level) for CERES.

Why this exists:
- In hardened setups Keycloak is not exposed on localhost ports.
- Access via https://auth.<DOMAIN> may require local DNS/hosts entries.
- This script configures SMTP by executing kcadm.sh inside the Keycloak container.

Reads SMTP_* variables from config/.env.

Required:
- SMTP_HOST
- SMTP_FROM
Optional:
- SMTP_PORT (default 587)
- SMTP_USER / SMTP_PASSWORD
- SMTP_FROM_NAME
- SMTP_REPLY_TO / SMTP_REPLY_TO_NAME
- SMTP_STARTTLS (default true)
- SMTP_SSL (default false)
- SMTP_AUTH (default auto: true if SMTP_USER+SMTP_PASSWORD present)

Example:
  cd f:\Ceres\scripts
  .\keycloak-smtp.ps1 -EnvFile ..\config\.env -ProjectName ceres -Realm master
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script output with colors.'
)]
param(
    [string]$EnvFile = "..\\config\\.env",
    [string]$ProjectName = "ceres",
    [string]$Realm = "master",
    [string]$KeycloakContainer = "",
    [bool]$Interactive = $true,
    [bool]$WriteEnv = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

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

function Set-DotEnvValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][AllowNull()][string]$Value
    )

    $content = Get-Content -Path $Path -Raw
    $escapedKey = [regex]::Escape($Key)
    $line = if ($null -eq $Value) { "$Key=" } else { "$Key=$Value" }

    if ([regex]::IsMatch($content, "(?m)^${escapedKey}=")) {
        $content = [regex]::Replace(
            $content,
            "(?m)^${escapedKey}=.*$",
            { param($m) $line }
        )
    } else {
        $content = $content.TrimEnd() + "`r`n" + $line + "`r`n"
    }

    Set-Content -Path $Path -Value $content -NoNewline
}

function Read-HostPlainTextSecret {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt
    )

    $sec = Read-Host -Prompt $Prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

$envPath = if ([System.IO.Path]::IsPathRooted($EnvFile)) { Resolve-Path $EnvFile } else { Resolve-Path (Join-Path $PSScriptRoot $EnvFile) }
$envMap = Read-DotEnvFile -Path $envPath

$adminUser = $envMap['KEYCLOAK_ADMIN']
if (-not $adminUser) { $adminUser = 'admin' }
$adminPass = $envMap['KEYCLOAK_ADMIN_PASSWORD']
if (-not $adminPass) { throw 'KEYCLOAK_ADMIN_PASSWORD is missing' }

$smtpHost = $envMap['SMTP_HOST']
$smtpFrom = $envMap['SMTP_FROM']

$smtpPort = $null

if ($Interactive) {
    if (-not $smtpHost -or $smtpHost -eq 'CHANGE_ME') {
        Write-Host 'SMTP: please enter your SMTP server host (your mail provider/relay).' -ForegroundColor Cyan
        $smtpHost = Read-Host -Prompt 'SMTP_HOST (e.g. smtp.company.ru)'
    }

    $smtpPort = $envMap['SMTP_PORT']
    if (-not $smtpPort -or $smtpPort -eq 'CHANGE_ME') { $smtpPort = '' }

    $mode = ''
    if (-not $smtpPort) {
        Write-Host 'SMTP: choose connection type (if unsure, pick 1).' -ForegroundColor Cyan
        Write-Host '  1) STARTTLS (port 587) - most common' -ForegroundColor Gray
        Write-Host '  2) SSL/TLS (port 465)' -ForegroundColor Gray
        Write-Host '  3) Plain (port 25/587) - not recommended' -ForegroundColor Gray
        $mode = Read-Host -Prompt 'Choice (1/2/3)'
        if (-not $mode) { $mode = '1' }
        switch ($mode.Trim()) {
            '2' { $smtpPort = '465' }
            '3' { $smtpPort = '25' }
            default { $smtpPort = '587' }
        }
    }
}

if (-not $smtpHost -or $smtpHost -eq 'CHANGE_ME') { throw 'SMTP_HOST is missing in config/.env' }

$smtpPortFromEnv = $envMap['SMTP_PORT']
if (-not $smtpPort -or $smtpPort -eq 'CHANGE_ME') {
    $smtpPort = $smtpPortFromEnv
}
if (-not $smtpPort -or $smtpPort -eq 'CHANGE_ME') { $smtpPort = '587' }

$smtpUser = $envMap['SMTP_USER']
$smtpPass = $envMap['SMTP_PASSWORD']

$smtpStartTls = Convert-ToBoolString -Value $envMap['SMTP_STARTTLS'] -Default:$true
$smtpSsl = Convert-ToBoolString -Value $envMap['SMTP_SSL'] -Default:$false

if ($Interactive) {
    # Derive defaults from selected port if user didn't set explicit flags.
    if ($smtpPort -eq '465') {
        $smtpSsl = 'true'
        $smtpStartTls = 'false'
    } elseif ($smtpPort -eq '587') {
        $smtpSsl = 'false'
        $smtpStartTls = 'true'
    }

    if (-not $smtpUser -or $smtpUser -eq 'CHANGE_ME') {
        $smtpUser = Read-Host -Prompt 'SMTP_USER (often an email; leave empty if no auth)'
    }

    if ($smtpUser) {
        if (-not $smtpPass -or $smtpPass -eq 'CHANGE_ME') {
            $smtpPass = Read-HostPlainTextSecret -Prompt 'SMTP_PASSWORD (will be saved into config/.env)'
        }
    } else {
        $smtpPass = ''
    }

    if (-not $smtpFrom -or $smtpFrom -eq 'CHANGE_ME') {
        $suggestFrom = if ($smtpUser -and $smtpUser -match '@') { $smtpUser } else { '' }
        if ($suggestFrom) {
            $smtpFrom = Read-Host -Prompt "SMTP_FROM (leave empty to use $suggestFrom)"
            if (-not $smtpFrom) { $smtpFrom = $suggestFrom }
        } else {
            $smtpFrom = Read-Host -Prompt 'SMTP_FROM (sender email, e.g. no-reply@company.ru)'
        }
    }
}

if (-not $smtpFrom -or $smtpFrom -eq 'CHANGE_ME') { throw 'SMTP_FROM is missing in config/.env' }

$smtpAuth = Convert-ToBoolString -Value $envMap['SMTP_AUTH'] -Default:([bool]($smtpUser -and $smtpPass -and $smtpUser -ne 'CHANGE_ME' -and $smtpPass -ne 'CHANGE_ME'))

$fromName = $envMap['SMTP_FROM_NAME']
$replyTo = $envMap['SMTP_REPLY_TO']
$replyToName = $envMap['SMTP_REPLY_TO_NAME']

$containerName = if ($KeycloakContainer) { $KeycloakContainer } else { "$ProjectName-keycloak-1" }

Write-Host "Configuring Keycloak SMTP via container '$containerName' (realm '$Realm')..." -ForegroundColor Cyan

if ($WriteEnv) {
    Write-Host "Writing SMTP settings to $envPath ..." -ForegroundColor Gray
    Set-DotEnvValue -Path $envPath -Key 'SMTP_HOST' -Value $smtpHost
    Set-DotEnvValue -Path $envPath -Key 'SMTP_PORT' -Value $smtpPort
    Set-DotEnvValue -Path $envPath -Key 'SMTP_FROM' -Value $smtpFrom
    Set-DotEnvValue -Path $envPath -Key 'SMTP_USER' -Value $smtpUser
    Set-DotEnvValue -Path $envPath -Key 'SMTP_PASSWORD' -Value $smtpPass
    Set-DotEnvValue -Path $envPath -Key 'SMTP_STARTTLS' -Value $smtpStartTls
    Set-DotEnvValue -Path $envPath -Key 'SMTP_SSL' -Value $smtpSsl
    # Only write SMTP_AUTH if not present; otherwise keep user's explicit value.
    if (-not $envMap.ContainsKey('SMTP_AUTH') -or -not $envMap['SMTP_AUTH']) {
        Set-DotEnvValue -Path $envPath -Key 'SMTP_AUTH' -Value $smtpAuth
    }
}

try {
    $tnc = Test-NetConnection -ComputerName $smtpHost -Port ([int]$smtpPort) -WarningAction SilentlyContinue
    if (-not $tnc.TcpTestSucceeded) {
        Write-Host "Warning: TCP connect to ${smtpHost}:$smtpPort failed from this host. This may still work from inside Keycloak container or after firewall changes." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Warning: connectivity test skipped/failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Ensure the container exists/runs
$names = @(& docker ps --format '{{.Names}}')
$exists = $names -contains $containerName
if (-not $exists) {
    throw "Keycloak container not running: $containerName (check 'docker ps')"
}

# Login
& docker exec $containerName /opt/keycloak/bin/kcadm.sh config credentials `
    --server http://localhost:8080 `
    --realm $Realm `
    --user $adminUser `
    --password $adminPass | Out-Null

# Build update args
$setArgs = @(
    'update',
    "realms/$Realm",
    '-s', "smtpServer.host=$smtpHost",
    '-s', "smtpServer.port=$smtpPort",
    '-s', "smtpServer.from=$smtpFrom",
    '-s', "smtpServer.auth=$smtpAuth",
    '-s', "smtpServer.starttls=$smtpStartTls",
    '-s', "smtpServer.ssl=$smtpSsl"
)

if ($fromName -and $fromName -ne 'CHANGE_ME') { $setArgs += @('-s', "smtpServer.fromDisplayName=$fromName") }
if ($replyTo -and $replyTo -ne 'CHANGE_ME') { $setArgs += @('-s', "smtpServer.replyTo=$replyTo") }
if ($replyToName -and $replyToName -ne 'CHANGE_ME') { $setArgs += @('-s', "smtpServer.replyToDisplayName=$replyToName") }
if ($smtpUser -and $smtpUser -ne 'CHANGE_ME') { $setArgs += @('-s', "smtpServer.user=$smtpUser") }
if ($smtpPass -and $smtpPass -ne 'CHANGE_ME') { $setArgs += @('-s', "smtpServer.password=$smtpPass") }

& docker exec $containerName /opt/keycloak/bin/kcadm.sh @setArgs | Out-Null

Write-Host 'Keycloak SMTP configured.' -ForegroundColor Green
Write-Host 'Next: in Keycloak Admin Console you can use "Test connection" (Realm Settings -> Email).' -ForegroundColor Gray
