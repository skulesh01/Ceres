#!/usr/bin/env powershell
# Auto SSH with embedded password - fully automatic

$ServerHost = "$env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP"
$Pass = $env:DEPLOY_SERVER_PASSWORD

function SSH-Auto {
    param([string]$Cmd)
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = @{
        FileName = "ssh.exe"
        Arguments = $ServerHost
        RedirectStandardInput = $true
        RedirectStandardOutput = $true
        RedirectStandardError = $false
        UseShellExecute = $false
    }
    $process.Start() | Out-Null
    $process.StandardInput.WriteLine($Pass)
    $process.StandardInput.WriteLine($Cmd)
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    return $output
}

Write-Host "Checking HelmReleases..." -ForegroundColor Cyan
$output = SSH-Auto "kubectl -n ceres get helmrelease -o wide"
Write-Host $output

Write-Host "`nChecking Pods..." -ForegroundColor Cyan
$output = SSH-Auto "kubectl -n ceres get pods -o wide"
Write-Host $output

Write-Host "`nChecking Kustomization..." -ForegroundColor Cyan
$output = SSH-Auto "kubectl -n flux-system get kustomization ceres-releases -o wide"
Write-Host $output
