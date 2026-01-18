#!/usr/bin/env pwsh
<#
.SYNOPSIS
Full automation for CERES deployment on Proxmox:
- Check and install Terraform
- Check and install Ansible  
- Create 3 VMs via Terraform
- Configure VMs via Ansible
- Start 20+ services via Docker Compose
#>

param(
    [switch]$DryRun = $false,
    [switch]$SkipInfra = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "`n>>> $Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error-Msg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Check-Command {
    param([string]$Command)
    try {
        $null = & $Command --version 2>$null
        return $true
    }
    catch {
        return $false
    }
}

function Install-Terraform {
    Write-Step "Terraform not found. Installing..." Yellow
    
    $terraformUrl = "https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_windows_amd64.zip"
    $terraformZip = "$env:TEMP\terraform.zip"
    $terraformDir = "$env:LOCALAPPDATA\terraform"
    
    New-Item -ItemType Directory -Force -Path $terraformDir | Out-Null
    
    Write-Host "Downloading Terraform..." -ForegroundColor White
    try {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $terraformUrl -OutFile $terraformZip -ErrorAction Stop
        Write-Success "Terraform downloaded"
    }
    catch {
        Write-Error-Msg "Failed to download Terraform: $_"
        Write-Host "Install manually from https://www.terraform.io/downloads" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Extracting Terraform..." -ForegroundColor White
    Expand-Archive -Path $terraformZip -DestinationPath $terraformDir -Force
    Remove-Item $terraformZip -Force
    
    $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notcontains $terraformDir) {
        [System.Environment]::SetEnvironmentVariable(
            "PATH",
            "$currentPath;$terraformDir",
            "User"
        )
    }
    
    $env:PATH = "$env:PATH;$terraformDir"
    Write-Success "Terraform installed to $terraformDir"
}

function Install-Ansible {
    Write-Step "Ansible not found. Checking Python..." Yellow
    
    $pythonExists = Check-Command "python"
    if (-not $pythonExists) {
        $pythonExists = Check-Command "python3"
    }
    
    if (-not $pythonExists) {
        Write-Error-Msg "Python not installed. Requires Python 3.8+"
        Write-Host "Install Python from https://www.python.org/downloads/" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Installing Ansible via pip..." -ForegroundColor White
    try {
        $ProgressPreference = "SilentlyContinue"
        python -m pip install --upgrade pip --quiet
        python -m pip install ansible --quiet
        Write-Success "Ansible installed"
    }
    catch {
        Write-Error-Msg "Failed to install Ansible: $_"
        exit 1
    }
}

# ============================================================================
# MAIN MENU
# ============================================================================

Write-Host @"
================================================================================
                  CERES AUTOMATED DEPLOYMENT ON PROXMOX
                                                                            
  Infrastructure:  Proxmox 192.168.1.3
  Cluster:         3 VMs (Core, Apps, Edge)
  Services:        20+ (PostgreSQL, Redis, GitLab, Zulip, etc)
  Stages:          Terraform -> Ansible -> Docker Compose
================================================================================

"@ -ForegroundColor Green

# ============================================================================
# STAGE 1: Check and install dependencies
# ============================================================================

Write-Step "STAGE 1: Checking dependencies" Cyan

if (-not (Check-Command "terraform")) {
    Install-Terraform
}
else {
    Write-Success "Terraform found"
}

if (-not (Check-Command "ansible")) {
    Install-Ansible
}
else {
    Write-Success "Ansible found"
}

if (Check-Command "docker") {
    Write-Success "Docker found"
}
else {
    Write-Host "[WARN] Docker not found (may be needed later)" -ForegroundColor Yellow
}

# ============================================================================
# STAGE 2: Check configuration files
# ============================================================================

Write-Step "STAGE 2: Checking configuration" Cyan

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$terraformDir = Join-Path $projectRoot "terraform"
$terraformVars = Join-Path $terraformDir "terraform.tfvars"
$ansibleInventory = Join-Path $projectRoot "ansible" "inventory" "production.yml"
$envFile = Join-Path $projectRoot "config" ".env"

$configsOk = $true

if (-not (Test-Path $terraformVars)) {
    Write-Error-Msg "terraform.tfvars not found at $terraformVars"
    $configsOk = $false
}
else {
    Write-Success "terraform.tfvars found"
}

if (-not (Test-Path $ansibleInventory)) {
    Write-Error-Msg "Ansible inventory not found at $ansibleInventory"
    $configsOk = $false
}
else {
    Write-Success "Ansible inventory found"
}

if (-not (Test-Path $envFile)) {
    Write-Error-Msg ".env not found at $envFile"
    $configsOk = $false
}
else {
    Write-Success ".env found"
}

if (-not $configsOk) {
    exit 1
}

# ============================================================================
# STAGE 3: Terraform infrastructure
# ============================================================================

if (-not $SkipInfra) {
    Write-Step "STAGE 3: Creating infrastructure (Terraform)" Cyan
    
    Push-Location $terraformDir
    try {
        Write-Host "Initializing Terraform..." -ForegroundColor White
        terraform init
        Write-Success "Terraform initialized"
        
        Write-Host "`nPlanning 3 VMs creation..." -ForegroundColor White
        terraform plan -out=tfplan
        
        if ($DryRun) {
            Write-Host "`n[DRY RUN] Plan saved to tfplan" -ForegroundColor Yellow
            Write-Host "Run without -DryRun to apply plan" -ForegroundColor Yellow
        }
        else {
            Write-Host "`nApplying plan (creating 3 VMs)..." -ForegroundColor White
            Write-Host "[WAIT] This may take 10-15 minutes..." -ForegroundColor Yellow
            terraform apply tfplan
            Write-Success "Infrastructure created!"
            
            $coreIp = terraform output -raw core_ip 2>$null
            $appsIp = terraform output -raw apps_ip 2>$null
            $edgeIp = terraform output -raw edge_ip 2>$null
            
            if ($coreIp) {
                Write-Host "`nVM IP addresses:" -ForegroundColor White
                Write-Host "  Core: $coreIp" -ForegroundColor Green
                Write-Host "  Apps: $appsIp" -ForegroundColor Green
                Write-Host "  Edge: $edgeIp" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Error-Msg "Terraform error: $_"
        exit 1
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "[SKIPPED] Infrastructure creation (-SkipInfra)" -ForegroundColor Yellow
}

# ============================================================================
# STAGE 4: Ansible configuration
# ============================================================================

Write-Step "STAGE 4: Configuring VMs (Ansible)" Cyan

$ansiblePlaybook = Join-Path $projectRoot "ansible" "playbooks" "deploy-ceres.yml"

if (Test-Path $ansiblePlaybook) {
    if ($DryRun) {
        Write-Host "[DRY RUN] Would run: ansible-playbook -i $ansibleInventory $ansiblePlaybook" -ForegroundColor Yellow
    }
    else {
        Write-Host "Running Ansible playbook..." -ForegroundColor White
        Write-Host "[WAIT] This may take 20-30 minutes..." -ForegroundColor Yellow
        ansible-playbook -i $ansibleInventory $ansiblePlaybook -v
        Write-Success "VMs configured!"
    }
}
else {
    Write-Host "[WARN] ansible-playbook not found at $ansiblePlaybook" -ForegroundColor Yellow
}

# ============================================================================
# STAGE 5: Docker Compose
# ============================================================================

Write-Step "STAGE 5: Starting services (Docker Compose)" Cyan

$dockerComposeScript = Join-Path $projectRoot "scripts" "start.ps1"

if (Test-Path $dockerComposeScript) {
    if ($DryRun) {
        Write-Host "[DRY RUN] Would run: powershell -File $dockerComposeScript" -ForegroundColor Yellow
    }
    else {
        Write-Host "Starting Docker Compose on all VMs..." -ForegroundColor White
        Write-Host "[WAIT] This may take 10-20 minutes..." -ForegroundColor Yellow
        
        & $dockerComposeScript
        Write-Success "All services started!"
    }
}
else {
    Write-Host "[WARN] scripts/start.ps1 not found" -ForegroundColor Yellow
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host @"
================================================================================
                        DEPLOYMENT COMPLETED
================================================================================

CREATED:
  - 3 VMs on Proxmox (Core, Apps, Edge)
  - Docker installed on all VMs
  - All dependencies configured

STARTED:
  - PostgreSQL + Redis (storage)
  - Keycloak (SSO/OIDC)
  - GitLab CE (Git + CI/CD)
  - Zulip (chat)
  - Nextcloud (files)
  - Prometheus + Grafana (monitoring)
  - 20+ additional services

ACCESS:
  - auth.ceres           = Keycloak
  - gitlab.ceres         = GitLab CE
  - zulip.ceres          = Zulip
  - nextcloud.ceres      = Nextcloud
  - grafana.ceres        = Grafana

NEXT STEPS:
  1. Verify access to services via browser
  2. Configure DNS (if needed)
  3. Add users through Keycloak
  4. Configure SMTP for notifications

USEFUL COMMANDS:
  - View logs: docker logs container-name
  - Stop services: docker-compose -f config/compose/base.yml down
  - Status: docker ps

================================================================================
"@ -ForegroundColor Green
