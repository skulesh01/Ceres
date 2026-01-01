<#
Setup CERES internal hostnames on Windows via hosts file.

Use-case: VPN (Tailscale/WireGuard) access without public DNS.

Examples:
  # Add mappings to hosts (run as Administrator)
    .\setup-ceres-hosts.ps1 -TargetIp 100.64.0.10 -Domain ceres

  # Remove CERES block
  .\setup-ceres-hosts.ps1 -Remove
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Interactive script output with colors.'
)]
param(
    [string]$Domain = 'ceres',
    [string]$TargetIp,
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$systemRoot = [System.Environment]::GetEnvironmentVariable('SystemRoot')
if (-not $systemRoot) {
    throw 'SystemRoot environment variable is not set.'
}
$hostsPath = Join-Path $systemRoot 'System32\drivers\etc\hosts'

$begin = '# CERES HOSTS BEGIN'
$end = '# CERES HOSTS END'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$names = @(
    "auth.$Domain",
    "nextcloud.$Domain",
    "wiki.$Domain",
    "gitea.$Domain",
    "mattermost.$Domain",
    "redmine.$Domain",
    "grafana.$Domain",
    "portainer.$Domain",
    "uptime.$Domain"
)

if (-not (Test-Path $hostsPath)) {
    throw "Hosts file not found: $hostsPath"
}

$content = [System.IO.File]::ReadAllText($hostsPath, [System.Text.Encoding]::UTF8)

# If the hosts file is empty (can happen if it was previously truncated), restore a minimal baseline.
if ([string]::IsNullOrWhiteSpace($content)) {
    $content = @(
        '# Copyright (c) Microsoft Corp.'
        '#'
        '# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.'
        '#'
        '# This file contains the mappings of IP addresses to host names. Each'
        '# entry should be kept on an individual line. The IP address should'
        '# be placed in the first column followed by the corresponding host name.'
        '# The IP address and the host name should be separated by at least one'
        '# space.'
        '#'
        '# For example:'
        '#'
        '#      102.54.94.97     rhino.acme.com          # source server'
        '#       38.25.63.10     x.acme.com              # x client host'
        '#'
        '# localhost name resolution is handled within DNS itself.'
        '#'
        '127.0.0.1	localhost'
        '::1	localhost'
        ''
    ) -join "`r`n"
}

# Remove existing CERES block if present
$pattern = "(?s)\r?\n?" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end) + "\r?\n?"
$content = [regex]::Replace($content, $pattern, "`r`n")

if ($Remove) {
    [System.IO.File]::WriteAllText($hostsPath, $content.TrimEnd() + "`r`n", $utf8NoBom)
    Write-Host "[OK] Removed CERES hosts block from $hostsPath" -ForegroundColor Green
    return
}

if (-not $TargetIp) {
    throw "TargetIp is required unless -Remove is used. Example: -TargetIp 100.64.0.10"
}

if ($TargetIp -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
    throw "TargetIp must be an IPv4 address. Got: $TargetIp"
}

$blockLines = New-Object System.Collections.Generic.List[string]
$blockLines.Add($begin)
$blockLines.Add("# Added by CERES scripts. Domain=$Domain IP=$TargetIp")
foreach ($n in $names) {
    $blockLines.Add("$TargetIp`t$n")
}
$blockLines.Add($end)

$block = "`r`n" + ($blockLines -join "`r`n") + "`r`n"

$content = $content.TrimEnd() + $block
[System.IO.File]::WriteAllText($hostsPath, $content, $utf8NoBom)

Write-Host ("[OK] Updated hosts file: {0}" -f $hostsPath) -ForegroundColor Green
Write-Host ("Mapped to {0}:" -f $TargetIp) -ForegroundColor Cyan
foreach ($n in $names) {
    Write-Host "- $n"
}
