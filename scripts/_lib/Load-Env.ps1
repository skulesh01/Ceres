<#
.SYNOPSIS
    Load environment variables from .env file
.DESCRIPTION
    Sources .env file and sets environment variables for the current session
.EXAMPLE
    . .\scripts\_lib\Load-Env.ps1
#>

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$envFile = Join-Path $repoRoot ".env"

if (-not (Test-Path $envFile)) {
    Write-Warning ".env file not found at: $envFile"
    Write-Host "Copy .env.example to .env and fill in your values:" -ForegroundColor Yellow
    Write-Host "  Copy-Item .env.example .env" -ForegroundColor Cyan
    return
}

Write-Host "Loading environment variables from .env..." -ForegroundColor Cyan

Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    
    # Skip comments and empty lines
    if ($line -match '^#' -or [string]::IsNullOrWhiteSpace($line)) {
        return
    }
    
    # Parse KEY=VALUE
    if ($line -match '^([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        
        # Remove quotes if present (PowerShell 5.1 safe)
        if ($value.Length -ge 2) {
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }
        
        [System.Environment]::SetEnvironmentVariable($key, $value, 'Process')
        Write-Verbose "Set $key"
    }
}

# Validate required variables
$required = @(
    'DEPLOY_SERVER_IP',
    'DEPLOY_SERVER_USER',
    'DEPLOY_SERVER_PASSWORD'
)

$missing = $required | Where-Object { -not [Environment]::GetEnvironmentVariable($_) }

if ($missing) {
    Write-Warning "Missing required environment variables:"
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nPlease update your .env file" -ForegroundColor Yellow
} else {
    Write-Host "Environment loaded successfully" -ForegroundColor Green
}
