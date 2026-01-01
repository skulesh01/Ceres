<#
Idempotent Wiki.js <-> Keycloak SSO fixer for CERES.

What it does:
- Ensures Wiki.js Keycloak auth provider uses key='keycloak' (not a random UUID)
- Ensures required config fields exist (host/realm/clientId/clientSecret + URLs)
- Restarts Wiki.js container and prints a quick HTTP check

Safe to run multiple times.
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
  'PSAvoidUsingWriteHost',
  '',
  Justification = 'Interactive script output with colors.'
)]
param(
    [string]$ProjectName = "ceres",
    [string]$EnvFile = "..\\config\\.env",
    [string]$WikiJsUrl = "http://localhost:8083",
    [string]$KeycloakInternal = "http://keycloak:8080",
    [string]$KeycloakPublic = "http://localhost:8081"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot "_lib\\Ceres.ps1")

$envPath = Resolve-Path (Join-Path $PSScriptRoot $EnvFile)
$envMap = Read-DotEnvFile -Path $envPath

$domain = $envMap['DOMAIN']
if (-not $domain) { $domain = 'ceres' }

if (-not $PSBoundParameters.ContainsKey('WikiJsUrl')) {
  $WikiJsUrl = "https://wiki.$domain"
}
if (-not $PSBoundParameters.ContainsKey('KeycloakPublic')) {
  $KeycloakPublic = "https://auth.$domain"
}

$realm = $envMap['WIKIJS_OIDC_REALM']
$clientId = $envMap['WIKIJS_OIDC_CLIENT_ID']
$clientSecret = $envMap['WIKIJS_OIDC_CLIENT_SECRET']

if (-not $realm) { $realm = 'master' }
if (-not $clientId) { $clientId = 'wikijs' }
if (-not $clientSecret) { throw 'WIKIJS_OIDC_CLIENT_SECRET is empty; cannot configure Wiki.js provider.' }

$tokenUrl = "$KeycloakInternal/realms/$realm/protocol/openid-connect/token"
$userInfoUrl = "$KeycloakInternal/realms/$realm/protocol/openid-connect/userinfo"
$authUrl = "$KeycloakPublic/realms/$realm/protocol/openid-connect/auth"
$logoutUrl = "$KeycloakPublic/realms/$realm/protocol/openid-connect/logout"
$callbackUrl = "$WikiJsUrl/login/keycloak/callback"

$postgres = (docker ps --filter "name=${ProjectName}-postgres-" --format "{{.Names}}" | Select-Object -First 1)
if (-not $postgres) { $postgres = (docker ps --filter "name=${ProjectName}_postgres" --format "{{.Names}}" | Select-Object -First 1) }
if (-not $postgres) { $postgres = 'ceres-postgres-1' }

$wikijs = (docker ps --filter "name=${ProjectName}-wikijs-" --format "{{.Names}}" | Select-Object -First 1)
if (-not $wikijs) { $wikijs = (docker ps --filter "name=${ProjectName}_wikijs" --format "{{.Names}}" | Select-Object -First 1) }
if (-not $wikijs) { $wikijs = 'ceres-wikijs-1' }

$sql = @"
BEGIN;

-- If the Keycloak provider exists under a random UUID key, normalize it to key='keycloak'
UPDATE authentication
SET key='keycloak'
WHERE "strategyKey"='keycloak' AND key <> 'keycloak';

-- If no Keycloak provider exists at all, create it
INSERT INTO authentication (key, "isEnabled", config, "selfRegistration", "domainWhitelist", "autoEnrollGroups", "order", "strategyKey", "displayName")
SELECT 'keycloak', true, '{}'::json, false, '[]'::json, '[]'::json, 0, 'keycloak', 'Keycloak'
WHERE NOT EXISTS (SELECT 1 FROM authentication WHERE "strategyKey"='keycloak');

-- Enforce required config values
UPDATE authentication
SET config = jsonb_strip_nulls(
  (config::jsonb)
  || jsonb_build_object(
    'host', '$KeycloakInternal',
    'realm', '$realm',
    'clientId', '$clientId',
    'clientSecret', '$clientSecret',
    'tokenURL', '$tokenUrl',
    'userInfoURL', '$userInfoUrl',
    'authorizationURL', '$authUrl',
    'logoutURL', '$logoutUrl',
    'callbackURL', '$callbackUrl',
    'logoutUpstream', false
  )
)
WHERE key='keycloak';

COMMIT;

SELECT key, "isEnabled", "strategyKey", config->>'host', config->>'realm', config->>'clientId', config->>'callbackURL'
FROM authentication
WHERE key='keycloak';
"@

$sql | docker exec -i $postgres psql -U postgres -d wikijs_db -v ON_ERROR_STOP=1 -At
if ($LASTEXITCODE -ne 0) {
    throw "psql failed with exit code $LASTEXITCODE"
}

docker restart $wikijs | Out-Null
Start-Sleep -Seconds 4

Write-Host "HTTP check: $WikiJsUrl/login/keycloak" -ForegroundColor Cyan
curl.exe -k -I "$WikiJsUrl/login/keycloak"
