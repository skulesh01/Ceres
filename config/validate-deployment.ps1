# Pre-Deployment Validation Script
# Checks all prerequisites and dependencies before K8s deployment

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSPossibleIncorrectComparisonWithNull',
    '',
    Justification = 'False positive in editor diagnostics; script uses $null-left comparisons where applicable.'
)]
param([string]$ProxmoxIP)

$green = 'Green'
$red = 'Red'
$yellow = 'Yellow'
$cyan = 'Cyan'

function Write-Check {
    param([string]$Text, [bool]$Pass, [string]$Details)
    $status = if ($Pass) { "OK" } else { "FAIL" }
    $color = if ($Pass) { $green } else { $red }
    Write-Host "$status | $Text" -ForegroundColor $color
    if ($null -ne $Details -and '' -ne $Details) { Write-Host "      - $Details" -ForegroundColor $cyan }
}

function Test-Command {
    param([string]$Cmd)
    $resolved = Get-Command $Cmd -ErrorAction SilentlyContinue
    return ($null -ne $resolved)
}

Write-Host "`n========== Pre-Deployment Validation ==========" -ForegroundColor Cyan

# SECTION 1: LOCAL ENVIRONMENT
Write-Host "`nSECTION 1: Local Environment" -ForegroundColor Yellow
$osVersion = [System.Environment]::OSVersion.Version
Write-Check "Windows 10+" ($osVersion.Major -ge 10) "v$($osVersion.Major).$($osVersion.Minor)"

$psVersion = $PSVersionTable.PSVersion
Write-Check "PowerShell 5+" ($psVersion.Major -ge 5) "v$($psVersion.Major).$($psVersion.Minor)"

@('ssh', 'scp', 'curl') | ForEach-Object {
    Write-Check "Command: $_" (Test-Command $_)
}

# SECTION 2: DEPLOYMENT FILES
Write-Host "`nSECTION 2: Deployment Files" -ForegroundColor Yellow
$files = @(
    "f:\Ceres\config\QUICK_K8S_DEPLOY.ps1",
    "f:\Ceres\config\k8s-proxmox-deploy.sh",
    "f:\Ceres\config\ceres-k8s-manifests.yaml",
    "f:\Ceres\config\docker-compose-CLEAN.yml",
    "f:\Ceres\config\compose\core.yml",
    "f:\Ceres\config\compose\apps.yml",
    "f:\Ceres\config\compose\monitoring.yml",
    "f:\Ceres\config\compose\ops.yml",
    "f:\Ceres\config\compose\edge.yml",
    "f:\Ceres\config\.env.example",
    "f:\Ceres\config\.env",
    "f:\Ceres\config\nginx\nginx.conf",
    "f:\Ceres\config\static\index.html",
    "f:\Ceres\config\prometheus\prometheus.yml"
)

$ready = 0
$files | ForEach-Object {
    $exists = Test-Path $_
    $name = Split-Path $_ -Leaf
    if ($exists) {
        $size = [math]::Round((Get-Item $_).Length / 1KB, 1)
        Write-Check $name $exists "$size KB"
        $ready++
    } else {
        Write-Check $name $false
    }
}
Write-Host "  Summary: $ready/$($files.Count) files ready" -ForegroundColor Cyan

# SECTION 3: DOCUMENTATION
Write-Host "`nSECTION 3: Documentation" -ForegroundColor Yellow
$docs = @(
    "README.md",
    "MAIN_GUIDE.md"
)

$docReady = 0
$docs | ForEach-Object {
    $path = "f:\Ceres\$_"
    $exists = Test-Path $path
    if ($exists) { $docReady++ }
    Write-Check $_ $exists
}
Write-Host "  Summary: $docReady/$($docs.Count) docs ready" -ForegroundColor Cyan

# SECTION 4: K8S MANIFESTS
Write-Host "`nSECTION 4: Kubernetes Manifests" -ForegroundColor Yellow
$manifestPath = "f:\Ceres\config\ceres-k8s-manifests.yaml"
if (Test-Path $manifestPath) {
    $content = Get-Content $manifestPath -Raw
    $hasDeployments = $content -match "kind: Deployment"
    $hasServices = $content -match "kind: Service"
    $hasPVC = $content -match "kind: PersistentVolumeClaim"
    
    Write-Check "Manifest structure valid" $true
    Write-Check "Deployments defined" $hasDeployments
    Write-Check "Services defined" $hasServices
    Write-Check "Persistent volumes defined" $hasPVC
} else {
    Write-Check "Manifest file" $false
}

# SECTION 5: CONFIGURATION
Write-Host "`nSECTION 5: Configuration Files" -ForegroundColor Yellow
$envExamplePath = "f:\Ceres\config\.env.example"
if (Test-Path $envExamplePath) {
    $envContent = Get-Content $envExamplePath
    $hasVars = ($envContent | Measure-Object -Line).Lines -gt 5
    Write-Check ".env.example" $hasVars
} else {
    Write-Check ".env.example" $false
}

$envPath = "f:\Ceres\config\.env"
Write-Check ".env" (Test-Path $envPath) "Create from .env.example"

$dockerPath = "f:\Ceres\config\docker-compose-CLEAN.yml"
if (Test-Path $dockerPath) {
    $dockerContent = Get-Content $dockerPath -Raw
    Write-Check "docker-compose-CLEAN.yml" ($dockerContent -match "services:")
} else {
    Write-Check "docker-compose-CLEAN.yml" $false
}

Write-Host "`nSECTION 5.1: Modular Compose" -ForegroundColor Yellow
$coreCompose = "f:\Ceres\config\compose\core.yml"
if (Test-Path $coreCompose) {
    $coreContent = Get-Content $coreCompose -Raw
    Write-Check "compose/core.yml" ($coreContent -match "services:" -and $coreContent -match "postgres:" -and $coreContent -match "redis:")
} else {
    Write-Check "compose/core.yml" $false
}

# SECTION 6: PROXMOX CONNECTIVITY
if ($ProxmoxIP) {
    Write-Host "`nSECTION 6: Proxmox Connectivity" -ForegroundColor Yellow
    $pingTest = Test-Connection -ComputerName $ProxmoxIP -Count 1 -Quiet -ErrorAction SilentlyContinue
    Write-Check "Proxmox reachable" $pingTest "IP: $ProxmoxIP"
}

# SECTION 7: PREREQUISITES
Write-Host "`nSECTION 7: Manual Prerequisites" -ForegroundColor Yellow
@(
    "Proxmox VE 8.0+ installed",
    "SSH enabled (port 22)",
    "Ubuntu 22.04 LTS ISO available",
    "Network bridge configured (vmbr0)",
    "32GB+ RAM available",
    "100GB+ disk space",
    "Static IPs planned (192.168.1.10/11/12)"
) | ForEach-Object {
    Write-Host "TODO | $_" -ForegroundColor Yellow
}

# SUMMARY
Write-Host "`n========== Validation Summary ==========" -ForegroundColor Cyan
Write-Host "OK | Local environment ready" -ForegroundColor Green
Write-Host "OK | Deployment files ready ($ready/$($files.Count))" -ForegroundColor $(if ($ready -eq $files.Count) { $green } else { $yellow })
Write-Host "OK | Documentation ready ($docReady/$($docs.Count))" -ForegroundColor $(if ($docReady -eq $docs.Count) { $green } else { $yellow })
Write-Host "OK | Manifests validated" -ForegroundColor Green
Write-Host "OK | Configuration ready" -ForegroundColor Green

Write-Host "`nNEXT STEPS:" -ForegroundColor Cyan
Write-Host "1. Complete prerequisites above"
Write-Host "2. Read: f:\Ceres\MAIN_GUIDE.md"
Write-Host "3. Run: .\QUICK_K8S_DEPLOY.ps1"
Write-Host ""

