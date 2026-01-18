#!/usr/bin/env powershell
<#
.SYNOPSIS
    Phase 1 MVP Verification Script
.DESCRIPTION
    Demonstrates complete resource planning workflow
#>

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "CERES Resource Planning - Phase 1 Verify" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Analyze Resources
Write-Host "[Test 1] System Resource Analysis" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Gray
.\scripts\analyze-resources.ps1
Write-Host ""

# Test 2: Test Profiles Library
Write-Host "[Test 2] Profile Library Functions" -ForegroundColor Yellow
Write-Host "===================================" -ForegroundColor Gray

. .\scripts\_lib\Resource-Profiles.ps1

$profiles = Get-AvailableProfiles
Write-Host "Available profiles: $($profiles -join ', ')"

Write-Host ""
Write-Host "Profile totals:"
$profiles | ForEach-Object {
    $profile = Get-ResourceProfile -ProfileName $_
    $totals = Get-ProfileTotals -Profile $profile
    Write-Host "  $($_): $($totals.cpu) CPU, $($totals.ram_gb) GB RAM, $($totals.disk_gb) GB disk"
}
Write-Host ""

# Test 3: Run Configuration Wizard
Write-Host "[Test 3] Configuration Wizard (Non-Interactive)" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Gray

.\scripts\configure-ceres.ps1 -PresetProfile small -NonInteractive
Write-Host ""

# Test 4: Verify Deployment Plan
Write-Host "[Test 4] Deployment Plan Verification" -ForegroundColor Yellow
Write-Host "=====================================" -ForegroundColor Gray

if (Test-Path DEPLOYMENT_PLAN.json) {
    $plan = Get-Content DEPLOYMENT_PLAN.json | ConvertFrom-Json
    Write-Host "Deployment Plan Summary:"
    Write-Host "  Profile: $($plan.profile)"
    Write-Host "  Timestamp: $($plan.timestamp)"
    Write-Host "  Total CPU: $($plan.details.details.virtual_machines | Measure-Object -Property cpu -Sum | Select-Object -ExpandProperty Sum)"
    Write-Host "  Total RAM: $($plan.details.details.virtual_machines | Measure-Object -Property ram_gb -Sum | Select-Object -ExpandProperty Sum) GB"
    Write-Host "  Total Disk: $($plan.details.details.virtual_machines | Measure-Object -Property disk_gb -Sum | Select-Object -ExpandProperty Sum) GB"
    Write-Host "  VMs: $($plan.details.details.virtual_machines.Count)"
    Write-Host ""
    Write-Host "File: DEPLOYMENT_PLAN.json" -ForegroundColor Green
}
else {
    Write-Host "DEPLOYMENT_PLAN.json not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Phase 1 Verification Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Review PHASE_1_COMPLETE.md for documentation"
Write-Host "2. Review DEPLOYMENT_PLAN.json for configuration"
Write-Host "3. Proceed to Phase 2 implementation"
Write-Host ""
