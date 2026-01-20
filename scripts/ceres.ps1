<#
.SYNOPSIS
    CERES CLI - Unified application deployment platform for Docker and Kubernetes

.DESCRIPTION
    Single-entry point for all CERES operations: analyze, configure, generate, validate, deploy

.EXAMPLE
    # Analyze resources and get recommendations
    .\ceres.ps1 analyze resources

    # Interactive configuration wizard
    .\ceres.ps1 configure

    # Generate all configurations from profile
    .\ceres.ps1 generate from-profile

    # Validate environment before deployment
    .\ceres.ps1 validate environment

    # Deploy everything
    .\ceres.ps1 deploy all --profile medium --yes

.NOTES
    Version: 1.0.0
    Author: CERES Team
    License: MIT
#>

param(
    [Parameter(Position = 0, HelpMessage = "Main command (analyze, configure, generate, validate, deploy, status, help, init)")]
    [string]$Command = "help",

    [Parameter(Position = 1, HelpMessage = "Subcommand")]
    [string]$Subcommand = "",

    [Parameter(HelpMessage = "Preset profile name (small, medium, large)")]
    [string]$Profile = "",

    [Parameter(HelpMessage = "Non-interactive mode (skip prompts)")]
    [switch]$Yes,

    [Parameter(HelpMessage = "Output format (text, json)")]
    [string]$Format = "text",

    [Parameter(HelpMessage = "Show version")]
    [switch]$Version,

    [Parameter(HelpMessage = "Service name for logs command")]
    [string]$Service = "",

    [Parameter(HelpMessage = "Step number for rollback")]
    [int]$Step = 0
)

# ============================================================================
# INITIALIZATION
# ============================================================================

$ErrorActionPreference = "Stop"
$script:CeresVersion = "1.0.0"
$script:CeresRoot = Split-Path -Parent $PSScriptRoot  # Up from scripts/ -> root
$script:ScriptsPath = Join-Path $CeresRoot "scripts"
$script:ConfigPath = Join-Path $CeresRoot "config"
$script:DocsPath = Join-Path $CeresRoot "docs"
$script:LogPath = Join-Path $CeresRoot "logs"

# Ensure logs directory exists
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

$script:LogFile = Join-Path $LogPath "ceres-$(Get-Date -Format 'yyyy-MM-dd').log"
$script:Colors = @{
    Success = "Green"
    Error   = "Red"
    Warning = "Yellow"
    Info    = "Cyan"
    Debug   = "Gray"
}

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-CeresLog {
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet("INFO", "OK", "WARN", "ERROR", "DEBUG", "CHECK")]
        [string]$Level = "INFO",

        [switch]$NoNewline
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Write to file
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue

    # Write to console with colors
    $colorMap = @{
        "INFO"  = $Colors.Info
        "OK"    = $Colors.Success
        "WARN"  = $Colors.Warning
        "ERROR" = $Colors.Error
        "DEBUG" = $Colors.Debug
        "CHECK" = $Colors.Info
    }

    $color = $colorMap[$Level]
    Write-Host "[$Level] $Message" -ForegroundColor $color -NoNewline:$NoNewline
}

function Write-CeresError {
    param([string]$Message, [int]$ExitCode = 1)
    Write-CeresLog $Message "ERROR"
    exit $ExitCode
}

# ============================================================================
# MODULE LOADING
# ============================================================================

function Import-CeresModules {
    param([string[]]$ModuleNames = @())

    try {
        $libPath = Join-Path $ScriptsPath "_lib"

        if (-not (Test-Path $libPath)) {
            Write-CeresLog "WARNING: _lib directory not found at $libPath" "WARN"
            return
        }

        # Always load Common.ps1 first
        $commonPath = Join-Path $libPath "Common.ps1"
        if (Test-Path $commonPath) {
            . $commonPath
            Write-CeresLog "Loaded module: Common" "DEBUG"
        }

        # Load requested modules
        foreach ($module in $ModuleNames) {
            $modulePath = Join-Path $libPath "$module.ps1"
            if (Test-Path $modulePath) {
                . $modulePath
                Write-CeresLog "Loaded module: $module" "DEBUG"
            }
        }
    }
    catch {
        Write-CeresLog "Error loading modules: $_" "ERROR"
        exit 1
    }
}

# ============================================================================
# COMMAND HANDLERS
# ============================================================================

function Invoke-HelpCommand {
    param([string]$Topic = "")

    if ([string]::IsNullOrEmpty($Topic) -or $Topic -eq "help") {
        Show-MainHelp
    }
    else {
        Show-CommandHelp $Topic
    }
}

function Show-MainHelp {
    $help = @"
╔════════════════════════════════════════════════════════════════════════════╗
║                        CERES CLI v$script:CeresVersion - Help                           ║
╚════════════════════════════════════════════════════════════════════════════╝

COMMANDS:

  interactive           Interactive deployment wizard (RECOMMENDED)
                        Usage: ceres interactive

  init                  Initialize CERES environment
                        Usage: ceres init

  analyze               Analyze system resources
                        Usage: ceres analyze resources

  configure             Interactive configuration wizard
                        Usage: ceres configure [--preset small|medium|large]

  generate              Generate configurations from profile
                        Usage: ceres generate [from-profile|terraform|docker-compose|secrets]

  validate              Validate environment and configurations
                        Usage: ceres validate [environment|conflicts|profile|preflight|deployment]

  start                 Start Docker Compose services
                        Usage: ceres start [modules...]

  stop                  Stop Docker Compose services
                        Usage: ceres stop [modules...]

  status                Show services status
                        Usage: ceres status [--detailed]

  backup                Backup databases and volumes
                        Usage: ceres backup

  restore               Restore from backup
                        Usage: ceres restore <timestamp>

  setup                 Setup/configure components
                        Usage: ceres setup keycloak|smtp

  user                  User management
                        Usage: ceres user create <username>

  vpn                   VPN management
                        Usage: ceres vpn add <username>

  k8s                   Kubernetes operations
                        Usage: ceres k8s deploy|flux-status|flux-bootstrap

    deploy                Guided deploy (compose|k8s)
                                                Usage: ceres deploy compose|k8s [--profile preset] [--yes]

  logs                  Show service logs
                        Usage: ceres logs [<service>]

  rollback              Rollback deployment
                        Usage: ceres rollback [last|to-step <num>|full]

  help                  Show this help message
                        Usage: ceres help [command]

OPTIONS:

  --profile <name>      Use preset profile (small, medium, large)
  --format <type>       Output format: text (default), json
  --yes, -y             Non-interactive mode (skip prompts)
  --version             Show version
  --help, -h            Show this help

EXAMPLES:

  # Analyze resources
  ceres analyze resources

  # Interactive setup
  ceres configure

  # Deploy with preset
  ceres deploy all --profile medium --yes

  # Get help about specific command
  ceres help validate

For more information, see: docs/CERES_CLI_USAGE.md

"@
    Write-Host $help
}

function Show-CommandHelp {
    param([string]$Command)

    $helps = @{
        "analyze" = @"
COMMAND: analyze

DESCRIPTION:
  Analyze system resources and get CERES configuration recommendations

SUBCOMMANDS:
  resources         Analyze CPU, RAM, disk and recommend profiles

OPTIONS:
  --format json     Output as JSON

EXAMPLES:
  ceres analyze resources
  ceres analyze resources --format json
"@

        "configure" = @"
COMMAND: configure

DESCRIPTION:
  Interactive configuration wizard for CERES deployment

OPTIONS:
  --preset small|medium|large    Skip wizard and use preset
  --yes, -y                       Non-interactive mode

EXAMPLES:
  ceres configure
  ceres configure --preset medium
"@

        "generate" = @"
COMMAND: generate

DESCRIPTION:
  Generate configuration files from DEPLOYMENT_PLAN.json

SUBCOMMANDS:
  from-profile      Generate all configurations
  terraform         Generate terraform.tfvars
  docker-compose    Generate docker-compose.yml
  secrets           Generate .env with secure passwords

EXAMPLES:
  ceres generate from-profile
  ceres generate terraform
"@

        "validate" = @"
COMMAND: validate

DESCRIPTION:
  Validate environment and configurations

SUBCOMMANDS:
  environment       Check Docker, PowerShell, Terraform versions
  conflicts         Check for port and variable conflicts
  profile           Validate DEPLOYMENT_PLAN.json structure

EXAMPLES:
  ceres validate environment
  ceres validate conflicts
"@

                "deploy" = @"
COMMAND: deploy

DESCRIPTION:
    Guided deployment with preflight, config, run, post-checks.

SUBCOMMANDS:
    compose    Run Docker Compose path (core/apps/monitoring/ops)
    k8s        Run k3s/Flux path (Terraform+Ansible wrapper)

OPTIONS:
    --profile <name>   Preset profile: small|medium|large
    --yes, -y          Non-interactive (auto-accept prompts)

EXAMPLES:
    ceres deploy compose --profile small
    ceres deploy k8s --profile medium --yes
"@
    }

    if ($helps.ContainsKey($Command)) {
        Write-Host $helps[$Command]
    }
    else {
        Write-CeresLog "Unknown command: $Command" "WARN"
        Show-MainHelp
    }
}

function Invoke-InitCommand {
    Import-CeresModules @("Validate", "Configure")

    Write-CeresLog "Initializing CERES environment..." "INFO"
    Write-Host ""

    # Check environment
    if (Test-CeresEnvironment) {
        Write-CeresLog "Environment validation: PASSED" "OK"
    }
    else {
        Write-CeresError "Environment validation failed" 3
    }

    Write-Host ""

    # Copy .env if not exists
    $envPath = Join-Path $ConfigPath ".env"
    $envExamplePath = Join-Path $ConfigPath ".env.example"

    if (-not (Test-Path $envPath) -and (Test-Path $envExamplePath)) {
        Copy-Item $envExamplePath $envPath
        Write-CeresLog "Created .env from template" "OK"
    }

    Write-Host ""

    # Create directory structure
    @(
        (Join-Path $LogPath ""),
        (Join-Path $ConfigPath "profiles"),
        (Join-Path $ConfigPath "templates"),
        (Join-Path $ConfigPath "validation")
    ) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }

    Write-CeresLog "Directory structure created" "OK"
    Write-Host ""
    Write-CeresLog "Initialization completed successfully!" "OK"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Edit config/.env with your settings"
    Write-Host "  2. Run: ceres analyze resources"
    Write-Host "  3. Run: ceres configure"
    Write-Host ""
}

function Invoke-AnalyzeCommand {
    param([string]$Format = "text", [string]$Subcommand = "")
    
    $libPath = Join-Path $ScriptsPath "_lib"
    
    # Load modules directly
    $commonPath = Join-Path $libPath "Common.ps1"
    $analyzePath = Join-Path $libPath "Analyze.ps1"
    
    if ((Test-Path $commonPath) -and (Test-Path $analyzePath)) {
        . $commonPath
        . $analyzePath
        
        if ($Subcommand -eq "resources" -or [string]::IsNullOrEmpty($Subcommand)) {
            Write-CeresLog "Analyzing system resources..." "INFO"
            $exportFlag = if ($Format -eq "json") { $false } else { $true }
            Invoke-ResourceAnalysis -Format $Format -Export:$exportFlag
        }
        else {
            Write-CeresError "Unknown analyze subcommand: $Subcommand" 2
        }
    }
    else {
        Write-CeresError "Failed to load modules" 3
    }
}

function Invoke-ConfigureCommand {
    Import-CeresModules @("Configure", "Analyze")

    Write-CeresLog "Starting configuration wizard..." "INFO"

    if (-not [string]::IsNullOrEmpty($Profile)) {
        Start-ConfigurationWizard -PresetProfile $Profile -Interactive (-not $Yes)
    }
    else {
        Start-ConfigurationWizard -Interactive (-not $Yes)
    }
}

function Invoke-GenerateCommand {
    Import-CeresModules @("Generate")

    if ([string]::IsNullOrEmpty($Subcommand)) {
        $Subcommand = "from-profile"
    }

    Write-CeresLog "Generating configurations ($Subcommand)..." "INFO"

    switch ($Subcommand) {
        "from-profile" {
            Generate-AllConfigurations
        }
        "terraform" {
            Generate-TerraformConfig
        }
        "docker-compose" {
            Generate-DockerComposeConfig
        }
        "secrets" {
            Generate-SecretsFile
        }
        default {
            Write-CeresError "Unknown generate subcommand: $Subcommand" 2
        }
    }
}

function Invoke-ValidateCommand {
    Import-CeresModules @("Validate")

    if ([string]::IsNullOrEmpty($Subcommand)) {
        $Subcommand = "environment"
    }

    Write-CeresLog "Validating ($Subcommand)..." "INFO"

    switch ($Subcommand) {
        "environment" {
            if (Test-CeresEnvironment) {
                Write-CeresLog "Environment validation: PASSED" "OK"
            }
            else {
                Write-CeresError "Environment validation failed" 3
            }
        }
        "conflicts" {
            if (Test-ConfigurationConflicts) {
                Write-CeresLog "Conflict validation: PASSED" "OK"
            }
            else {
                Write-CeresError "Conflicts detected" 3
            }
        }
        "profile" {
            if (Test-DeploymentPlan) {
                Write-CeresLog "Profile validation: PASSED" "OK"
            }
            else {
                Write-CeresError "Profile validation failed" 3
            }
        }
        default {
            Write-CeresError "Unknown validate subcommand: $Subcommand" 2
        }
    }
}

function Invoke-DeployCommand {
    if ([string]::IsNullOrEmpty($Subcommand)) {
        $Subcommand = "compose"
    }

    switch ($Subcommand.ToLower()) {
        "compose" {
            Import-CeresModules @("Configure", "Docker", "Keycloak")

            Write-CeresLog "[compose] Preflight checks..." "INFO"
            $preflightOk = Invoke-CeresPreflight
            if (-not $preflightOk) { Write-CeresError "Preflight failed" 3 }

            Write-CeresLog "[compose] Configuration..." "INFO"
            $configOk = Invoke-CeresConfiguration -PresetProfile $Profile -NonInteractive:$Yes
            if (-not $configOk) { Write-CeresError "Configuration failed" 3 }

            Write-CeresLog "[compose] Starting services..." "INFO"
            Invoke-CeresStart -Modules @()  # all modules by default

            Write-CeresLog "[compose] Post-deploy checks..." "INFO"
            $postOk = Invoke-CeresValidateDeployment
            if (-not $postOk) { Write-CeresError "Post-deploy validation failed" 3 }

            Write-CeresLog "[compose] (optional) Keycloak bootstrap" "INFO"
            try { Invoke-CeresKeycloakBootstrap -ConfigureSmtp } catch { Write-CeresLog "Keycloak bootstrap warning: $_" "WARN" }

            Write-Host "`n✅ Compose deploy completed" -ForegroundColor Green
        }

        "k8s" {
            Import-CeresModules @("Configure", "Kubernetes", "Keycloak")

            Write-CeresLog "[k8s] Preflight checks (no Docker)..." "INFO"
            $preflightOk = Invoke-CeresPreflight -SkipDocker
            if (-not $preflightOk) { Write-CeresError "Preflight failed" 3 }

            Write-CeresLog "[k8s] Configuration..." "INFO"
            $configOk = Invoke-CeresConfiguration -PresetProfile $Profile -NonInteractive:$Yes
            if (-not $configOk) { Write-CeresError "Configuration failed" 3 }

            Write-CeresLog "[k8s] Deploying k3s/Flux..." "INFO"
            Invoke-CeresK8sDeploy

            Write-CeresLog "[k8s] Flux status..." "INFO"
            try { Get-CeresFluxStatus } catch { Write-CeresLog "Flux status warning: $_" "WARN" }

            Write-CeresLog "[k8s] (optional) Flux bootstrap..." "INFO"
            try { Invoke-CeresFluxBootstrap } catch { Write-CeresLog "Flux bootstrap warning: $_" "WARN" }

            Write-CeresLog "[k8s] (optional) Keycloak bootstrap" "INFO"
            try { Invoke-CeresKeycloakBootstrap -ConfigureSmtp } catch { Write-CeresLog "Keycloak bootstrap warning: $_" "WARN" }

            Write-Host "`n✅ Kubernetes deploy completed" -ForegroundColor Green
        }

        default {
            Write-CeresError "Unknown deploy subcommand: $Subcommand" 2
        }
    }
}

function Invoke-StatusCommand {
    Import-CeresModules @("Deploy")

    Write-CeresLog "Getting deployment status..." "INFO"
    Get-DeploymentStatus -Service $Service -Format $Format
}

function Invoke-RollbackCommand {
    Import-CeresModules @("Deploy")

    if ([string]::IsNullOrEmpty($Subcommand)) {
        $Subcommand = "last"
    }

    Write-Host ""
    Write-Host "WARNING: This will undo deployment changes" -ForegroundColor Red
    $response = Read-Host "Continue rollback? (yes/no)"

    if ($response -ne "yes") {
        Write-CeresLog "Rollback cancelled" "INFO"
        exit 0
    }

    Write-CeresLog "Starting rollback ($Subcommand)..." "WARN"

    switch ($Subcommand) {
        "last" {
            Undo-LastDeploymentStep
        }
        "to-step" {
            Undo-ToStep -StepNumber $Step
        }
        "full" {
            Undo-FullDeployment
        }
        default {
            Write-CeresError "Unknown rollback subcommand: $Subcommand" 2
        }
    }
}

function Invoke-LogsCommand {
    Import-CeresModules @("Deploy")

    Write-CeresLog "Getting logs..." "INFO"
    Get-ServiceLogs -Service $Service
}

# ============================================================================
# MAIN DISPATCHER
# ============================================================================

function Main {
    if ($Version) {
        Write-Host "CERES CLI version $script:CeresVersion"
        exit 0
    }

    Write-CeresLog "CERES CLI started - Command: $Command $Subcommand" "DEBUG"

    try {
        switch ($Command.ToLower()) {
            "init" { Invoke-InitCommand }
            "help" { Invoke-HelpCommand $Subcommand }
            "analyze" { Invoke-AnalyzeCommand }
            "configure" { Invoke-ConfigureCommand }
            "generate" { Invoke-GenerateCommand }
            "validate" { Invoke-ValidateCommand }
            
            # Docker operations
            "start" { Invoke-StartCommand }
            "stop" { Invoke-StopCommand }
            "status" { Invoke-StatusCommand }
            "backup" { Invoke-BackupCommand }
            "restore" { Invoke-RestoreCommand }
            
            # Setup operations
            "setup" { Invoke-SetupCommand }
            
            # User management
            "user" { Invoke-UserCommand }
            "vpn" { Invoke-VpnCommand }
            
            # Kubernetes operations
            "k8s" { Invoke-K8sCommand }
            
            # Legacy deployment
            "deploy" { Invoke-DeployCommand }
            "logs" { Invoke-LogsCommand }
            "rollback" { Invoke-RollbackCommand }
            
            # Help variants
            "-h" { Show-MainHelp }
            "--help" { Show-MainHelp }
            "" { Show-MainHelp }
            
            default {
                Write-CeresError "Unknown command: $Command" 2
            }
        }
    }
    catch {
        Write-CeresLog "Error: $_" "ERROR"
        Write-CeresLog $_.ScriptStackTrace "DEBUG"
        exit 99
    }

    Write-CeresLog "CERES CLI completed successfully" "DEBUG"
}

# ============================================================================
# NEW DOCKER/KEYCLOAK/USER COMMANDS
# ============================================================================

function Invoke-StartCommand {
    Import-CeresModules @("Docker")
    
    $modules = @()
    if ($Subcommand) {
        $modules += $Subcommand
    }
    
    Invoke-CeresStart -Modules $modules
}

function Invoke-StopCommand {
    Import-CeresModules @("Docker")
    
    $modules = @()
    if ($Subcommand) {
        $modules += $Subcommand
    }
    
    Invoke-CeresStop -Modules $modules
}

function Invoke-BackupCommand {
    Import-CeresModules @("Docker")
    Invoke-CeresBackup
}

function Invoke-RestoreCommand {
    Import-CeresModules @("Docker")
    
    if ([string]::IsNullOrEmpty($Subcommand)) {
        Write-CeresError "Restore requires timestamp. Usage: ceres restore <timestamp>" 2
    }
    
    Invoke-CeresRestore -Timestamp $Subcommand
}

function Invoke-SetupCommand {
    if ([string]::IsNullOrEmpty($Subcommand)) {
        Write-CeresError "Setup requires subcommand. Usage: ceres setup keycloak|smtp" 2
    }
    
    switch ($Subcommand.ToLower()) {
        "keycloak" {
            Import-CeresModules @("Keycloak")
            Invoke-CeresKeycloakBootstrap -ConfigureSmtp
        }
        "smtp" {
            Import-CeresModules @("Keycloak")
            Invoke-CeresKeycloakBootstrap -ConfigureSmtp
        }
        default {
            Write-CeresError "Unknown setup subcommand: $Subcommand" 2
        }
    }
}

function Invoke-UserCommand {
    if ([string]::IsNullOrEmpty($Subcommand)) {
        Write-CeresError "User command requires subcommand. Usage: ceres user create <username>" 2
    }
    
    Import-CeresModules @("User")
    
    switch ($Subcommand.ToLower()) {
        "create" {
            if ([string]::IsNullOrEmpty($Service)) {
                Write-CeresError "Username required. Usage: ceres user create <username> --service <username>" 2
            }
            
            Write-Host "Full Name: " -NoNewline
            $fullName = Read-Host
            
            Write-Host "Password (min 8 chars): " -NoNewline
            $password = Read-Host -AsSecureString
            $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
            
            New-CeresEmployee -Username $Service -FullName $fullName -Password $passwordPlain
        }
        default {
            Write-CeresError "Unknown user subcommand: $Subcommand" 2
        }
    }
}

function Invoke-VpnCommand {
    if ([string]::IsNullOrEmpty($Subcommand)) {
        Write-CeresError "VPN command requires subcommand. Usage: ceres vpn add <username>" 2
    }
    
    Import-CeresModules @("User")
    
    switch ($Subcommand.ToLower()) {
        "add" {
            if ([string]::IsNullOrEmpty($Service)) {
                Write-CeresError "Username required. Usage: ceres vpn add <username> --service <username>" 2
            }
            
            New-CeresVpnUser -Username $Service
        }
        default {
            Write-CeresError "Unknown vpn subcommand: $Subcommand" 2
        }
    }
}

function Invoke-K8sCommand {
    if ([string]::IsNullOrEmpty($Subcommand)) {
        Write-CeresError "K8s command requires subcommand. Usage: ceres k8s deploy|flux-status|flux-bootstrap" 2
    }
    
    Import-CeresModules @("Kubernetes")
    
    switch ($Subcommand.ToLower()) {
        "deploy" {
            Invoke-CeresK8sDeploy
        }
        "flux-status" {
            Get-CeresFluxStatus
        }
        "flux-bootstrap" {
            Invoke-CeresFluxBootstrap
        }
        default {
            Write-CeresError "Unknown k8s subcommand: $Subcommand" 2
        }
    }
}

# ============================================================================
# INTERACTIVE WIZARD
# ============================================================================

function Invoke-InteractiveWizard {
    Clear-Host
    
    # ASCII Banner
    Write-Host @"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   ██████╗███████╗██████╗ ███████╗███████╗                                   ║
║  ██╔════╝██╔════╝██╔══██╗██╔════╝██╔════╝                                   ║
║  ██║     █████╗  ██████╔╝█████╗  ███████╗                                   ║
║  ██║     ██╔══╝  ██╔══██╗██╔══╝  ╚════██║                                   ║
║  ╚██████╗███████╗██║  ██║███████╗███████║                                   ║
║   ╚═════╝╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝                                   ║
║                                                                              ║
║                  Interactive Deployment Wizard v$script:CeresVersion                   ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    Write-Host "Welcome to CERES! This wizard will help you deploy the platform." -ForegroundColor Green
    Write-Host ""
    
    # Main Menu
    while ($true) {
        Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║              MAIN MENU - Choose Action            ║" -ForegroundColor Cyan
        Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] " -ForegroundColor Yellow -NoNewline
        Write-Host "Quick Deploy (Recommended) - Auto-deploy with defaults"
        Write-Host "  [2] " -ForegroundColor Yellow -NoNewline
        Write-Host "Custom Deploy - Choose services and configuration"
        Write-Host "  [3] " -ForegroundColor Yellow -NoNewline
        Write-Host "Remote Deploy - Deploy to remote server via SSH"
        Write-Host "  [4] " -ForegroundColor Yellow -NoNewline
        Write-Host "Check Status - View deployed services"
        Write-Host "  [5] " -ForegroundColor Yellow -NoNewline
        Write-Host "Service Management - Start/Stop/Restart services"
        Write-Host "  [6] " -ForegroundColor Yellow -NoNewline
        Write-Host "Backup & Restore - Manage backups"
        Write-Host "  [7] " -ForegroundColor Yellow -NoNewline
        Write-Host "System Info - Analyze resources and check prerequisites"
        Write-Host "  [0] " -ForegroundColor Red -NoNewline
        Write-Host "Exit"
        Write-Host ""
        
        $choice = Read-Host "Enter your choice [0-7]"
        
        switch ($choice) {
            "1" { Invoke-QuickDeploy; break }
            "2" { Invoke-CustomDeploy; break }
            "3" { Invoke-RemoteDeploy; break }
            "4" { Invoke-StatusCheck; break }
            "5" { Invoke-ServiceManagement; break }
            "6" { Invoke-BackupRestore; break }
            "7" { Invoke-SystemInfo; break }
            "0" { 
                Write-Host ""
                Write-Host "Thank you for using CERES! 🚀" -ForegroundColor Green
                exit 0
            }
            default {
                Write-Host ""
                Write-Host "Invalid choice. Please enter a number between 0 and 7." -ForegroundColor Red
                Write-Host ""
                Start-Sleep -Seconds 2
            }
        }
    }
}

function Invoke-QuickDeploy {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              QUICK DEPLOY - Auto Setup            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "This will deploy CERES with:" -ForegroundColor Yellow
    Write-Host "  ✓ PostgreSQL database" -ForegroundColor Green
    Write-Host "  ✓ Redis cache" -ForegroundColor Green
    Write-Host "  ✓ Keycloak (OIDC provider)" -ForegroundColor Green
    Write-Host "  ✓ GitLab (with CI/CD)" -ForegroundColor Green
    Write-Host "  ✓ Nextcloud (file storage)" -ForegroundColor Green
    Write-Host "  ✓ Mattermost (team chat)" -ForegroundColor Green
    Write-Host "  ✓ Redmine (project management)" -ForegroundColor Green
    Write-Host "  ✓ Wiki.js (knowledge base)" -ForegroundColor Green
    Write-Host ""
    
    $confirm = Read-Host "Continue with Quick Deploy? (yes/no)"
    
    if ($confirm -ne "yes") {
        Write-Host "Deploy cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host ""
    Write-Host "Starting deployment..." -ForegroundColor Green
    Write-Host ""
    
    # Check if setup-services.sh exists
    $setupScript = Join-Path $CeresRoot "setup-services.sh"
    
    if (Test-Path $setupScript) {
        Write-Host "[1/5] Running setup script..." -ForegroundColor Cyan
        
        if ($IsWindows -or $PSVersionTable.Platform -eq "Win32NT") {
            # Windows - use PowerShell version
            $setupScriptPs1 = Join-Path $CeresRoot "setup-services.ps1"
            if (Test-Path $setupScriptPs1) {
                & $setupScriptPs1
            }
            else {
                Write-Host "ERROR: setup-services.ps1 not found!" -ForegroundColor Red
                Start-Sleep -Seconds 3
                return
            }
        }
        else {
            # Linux/Mac - use bash version
            bash $setupScript
        }
    }
    else {
        Write-Host "ERROR: setup-services.sh not found!" -ForegroundColor Red
        Start-Sleep -Seconds 3
        return
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  DEPLOYMENT COMPLETE! 🚀" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Services are now available at:" -ForegroundColor Yellow
    Write-Host "  Keycloak:   http://localhost:8080" -ForegroundColor Cyan
    Write-Host "  GitLab:     http://localhost:8081" -ForegroundColor Cyan
    Write-Host "  Nextcloud:  http://localhost:8082" -ForegroundColor Cyan
    Write-Host "  Redmine:    http://localhost:8083" -ForegroundColor Cyan
    Write-Host "  Wiki.js:    http://localhost:8084" -ForegroundColor Cyan
    Write-Host "  Mattermost: http://localhost:8085" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Wait 30-60 seconds for all services to start"
    Write-Host "  2. Access Keycloak and configure OIDC clients"
    Write-Host "  3. See SERVICES_INTEGRATION_GUIDE.md for details"
    Write-Host ""
    
    Read-Host "Press Enter to return to main menu"
}

function Invoke-CustomDeploy {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           CUSTOM DEPLOY - Choose Services         ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Deployment target
    Write-Host "Where do you want to deploy?" -ForegroundColor Yellow
    Write-Host "  [1] Local machine (Docker Compose)" -ForegroundColor Green
    Write-Host "  [2] Kubernetes cluster (k3s + Flux)" -ForegroundColor Green
    Write-Host ""
    
    $target = Read-Host "Enter choice [1-2]"
    
    # Service selection
    Write-Host ""
    Write-Host "Select services to deploy (separate with comma, or 'all'):" -ForegroundColor Yellow
    Write-Host "  core       - PostgreSQL + Redis (required)" -ForegroundColor Cyan
    Write-Host "  keycloak   - OIDC/SAML authentication provider" -ForegroundColor Cyan
    Write-Host "  gitlab     - Git repository + CI/CD" -ForegroundColor Cyan
    Write-Host "  nextcloud  - File storage and collaboration" -ForegroundColor Cyan
    Write-Host "  mattermost - Team chat and messaging" -ForegroundColor Cyan
    Write-Host "  redmine    - Project management" -ForegroundColor Cyan
    Write-Host "  wikijs     - Knowledge base and documentation" -ForegroundColor Cyan
    Write-Host ""
    
    $services = Read-Host "Services (e.g., 'core,keycloak,gitlab' or 'all')"
    
    # Configuration profile
    Write-Host ""
    Write-Host "Select resource profile:" -ForegroundColor Yellow
    Write-Host "  [1] Small  - 2 CPU, 4GB RAM" -ForegroundColor Green
    Write-Host "  [2] Medium - 4 CPU, 8GB RAM (recommended)" -ForegroundColor Green
    Write-Host "  [3] Large  - 8 CPU, 16GB RAM" -ForegroundColor Green
    Write-Host ""
    
    $profileChoice = Read-Host "Enter choice [1-3]"
    $profile = switch ($profileChoice) {
        "1" { "small" }
        "2" { "medium" }
        "3" { "large" }
        default { "medium" }
    }
    
    # Confirmation
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Target:   " -NoNewline -ForegroundColor Yellow
    Write-Host $(if ($target -eq "1") { "Docker Compose" } else { "Kubernetes" })
    Write-Host "  Services: " -NoNewline -ForegroundColor Yellow
    Write-Host $services
    Write-Host "  Profile:  " -NoNewline -ForegroundColor Yellow
    Write-Host $profile
    Write-Host ""
    
    $confirm = Read-Host "Continue with deployment? (yes/no)"
    
    if ($confirm -ne "yes") {
        Write-Host "Deploy cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host ""
    Write-Host "Starting custom deployment..." -ForegroundColor Green
    
    if ($target -eq "1") {
        # Docker Compose deployment
        Push-Location $CeresRoot
        
        if ($services -eq "all") {
            docker compose `
                -f config/compose/base.yml `
                -f config/compose/core.yml `
                -f config/compose/apps.yml `
                up -d
        }
        else {
            # Parse service list
            $serviceArray = $services -split ','
            $composeFiles = @("-f", "config/compose/base.yml")
            
            if ($serviceArray -contains "core" -or $serviceArray.Count -gt 1) {
                $composeFiles += @("-f", "config/compose/core.yml")
            }
            
            if ($serviceArray -contains "keycloak" -or $serviceArray -contains "gitlab" -or 
                $serviceArray -contains "nextcloud" -or $serviceArray -contains "mattermost" -or
                $serviceArray -contains "redmine" -or $serviceArray -contains "wikijs") {
                $composeFiles += @("-f", "config/compose/apps.yml")
            }
            
            & docker compose $composeFiles up -d
        }
        
        Pop-Location
    }
    else {
        # Kubernetes deployment
        Write-Host "Deploying to Kubernetes cluster..." -ForegroundColor Cyan
        
        $k8sScript = Join-Path $ScriptsPath "deploy-kubernetes.sh"
        if (Test-Path $k8sScript) {
            bash $k8sScript
        }
        else {
            Write-Host "ERROR: Kubernetes deployment script not found!" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Deployment initiated!" -ForegroundColor Green
    Write-Host ""
    
    Read-Host "Press Enter to return to main menu"
}

function Invoke-RemoteDeploy {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            REMOTE DEPLOY - SSH Deploy             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "This will deploy CERES to a remote server via SSH" -ForegroundColor Yellow
    Write-Host ""
    
    # Get server details
    $sshHost = Read-Host "Server IP or hostname (e.g., 192.168.1.3)"
    $sshUser = Read-Host "SSH username (e.g., root)"
    
    Write-Host ""
    Write-Host "Create backup before deployment? (yes/no)" -ForegroundColor Yellow
    $backup = Read-Host
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  REMOTE DEPLOYMENT SUMMARY" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Server:  " -NoNewline -ForegroundColor Yellow
    Write-Host "$sshUser@$sshHost"
    Write-Host "  Backup:  " -NoNewline -ForegroundColor Yellow
    Write-Host $(if ($backup -eq "yes") { "Yes" } else { "No" })
    Write-Host ""
    
    $confirm = Read-Host "Continue with remote deployment? (yes/no)"
    
    if ($confirm -ne "yes") {
        Write-Host "Deploy cancelled." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        return
    }
    
    Write-Host ""
    Write-Host "Starting remote deployment..." -ForegroundColor Green
    Write-Host ""
    
    # Run remote deploy script
    $remoteScript = Join-Path $ScriptsPath "remote-deploy.sh"
    
    if (Test-Path $remoteScript) {
        $backupFlag = if ($backup -eq "yes") { "--backup" } else { "" }
        bash $remoteScript $sshHost $sshUser $backupFlag
    }
    else {
        Write-Host "ERROR: remote-deploy.sh not found!" -ForegroundColor Red
    }
    
    Write-Host ""
    Read-Host "Press Enter to return to main menu"
}

function Invoke-StatusCheck {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              SERVICE STATUS CHECK                 ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Push-Location $CeresRoot
    
    Write-Host "Checking Docker Compose services..." -ForegroundColor Yellow
    Write-Host ""
    
    docker compose -f config/compose/base.yml -f config/compose/core.yml -f config/compose/apps.yml ps
    
    Write-Host ""
    Write-Host "Service URLs:" -ForegroundColor Yellow
    Write-Host "  Keycloak:   http://localhost:8080" -ForegroundColor Cyan
    Write-Host "  GitLab:     http://localhost:8081" -ForegroundColor Cyan
    Write-Host "  Nextcloud:  http://localhost:8082" -ForegroundColor Cyan
    Write-Host "  Redmine:    http://localhost:8083" -ForegroundColor Cyan
    Write-Host "  Wiki.js:    http://localhost:8084" -ForegroundColor Cyan
    Write-Host "  Mattermost: http://localhost:8085" -ForegroundColor Cyan
    Write-Host ""
    
    Pop-Location
    
    Read-Host "Press Enter to return to main menu"
}

function Invoke-ServiceManagement {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║            SERVICE MANAGEMENT                      ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Choose action:" -ForegroundColor Yellow
    Write-Host "  [1] Start all services" -ForegroundColor Green
    Write-Host "  [2] Stop all services" -ForegroundColor Green
    Write-Host "  [3] Restart all services" -ForegroundColor Green
    Write-Host "  [4] View service logs" -ForegroundColor Green
    Write-Host "  [0] Back to main menu" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Enter choice [0-4]"
    
    Push-Location $CeresRoot
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "Starting services..." -ForegroundColor Green
            docker compose -f config/compose/base.yml -f config/compose/core.yml -f config/compose/apps.yml up -d
            Write-Host "Services started!" -ForegroundColor Green
        }
        "2" {
            Write-Host ""
            Write-Host "Stopping services..." -ForegroundColor Yellow
            docker compose -f config/compose/base.yml -f config/compose/core.yml -f config/compose/apps.yml down
            Write-Host "Services stopped!" -ForegroundColor Green
        }
        "3" {
            Write-Host ""
            Write-Host "Restarting services..." -ForegroundColor Yellow
            docker compose -f config/compose/base.yml -f config/compose/core.yml -f config/compose/apps.yml restart
            Write-Host "Services restarted!" -ForegroundColor Green
        }
        "4" {
            Write-Host ""
            $service = Read-Host "Service name (or leave empty for all)"
            Write-Host ""
            if ([string]::IsNullOrEmpty($service)) {
                docker compose -f config/compose/base.yml -f config/compose/core.yml -f config/compose/apps.yml logs -f
            }
            else {
                docker compose -f config/compose/base.yml -f config/compose/core.yml -f config/compose/apps.yml logs -f $service
            }
        }
        "0" {
            Pop-Location
            return
        }
    }
    
    Pop-Location
    
    Write-Host ""
    Read-Host "Press Enter to return to main menu"
}

function Invoke-BackupRestore {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              BACKUP & RESTORE                      ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Choose action:" -ForegroundColor Yellow
    Write-Host "  [1] Create backup" -ForegroundColor Green
    Write-Host "  [2] Restore from backup" -ForegroundColor Green
    Write-Host "  [3] List backups" -ForegroundColor Green
    Write-Host "  [0] Back to main menu" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host "Enter choice [0-3]"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            $backupName = Read-Host "Backup name (or leave empty for timestamp)"
            
            $backupScript = Join-Path $ScriptsPath "backup.sh"
            if (Test-Path $backupScript) {
                if ([string]::IsNullOrEmpty($backupName)) {
                    bash $backupScript
                }
                else {
                    bash $backupScript --name $backupName
                }
                Write-Host "Backup created!" -ForegroundColor Green
            }
            else {
                Write-Host "ERROR: backup.sh not found!" -ForegroundColor Red
            }
        }
        "2" {
            Write-Host ""
            $backupFile = Read-Host "Backup file path (e.g., backups/backup-20260120.tar.gz)"
            
            $restoreScript = Join-Path $ScriptsPath "restore.sh"
            if (Test-Path $restoreScript) {
                bash $restoreScript $backupFile
                Write-Host "Restore completed!" -ForegroundColor Green
            }
            else {
                Write-Host "ERROR: restore.sh not found!" -ForegroundColor Red
            }
        }
        "3" {
            Write-Host ""
            Write-Host "Available backups:" -ForegroundColor Yellow
            $backupsDir = Join-Path $CeresRoot "backups"
            if (Test-Path $backupsDir) {
                Get-ChildItem $backupsDir -Filter "*.tar.gz" | ForEach-Object {
                    Write-Host "  $($_.Name)" -ForegroundColor Cyan
                }
            }
            else {
                Write-Host "  No backups found" -ForegroundColor Gray
            }
        }
        "0" {
            return
        }
    }
    
    Write-Host ""
    Read-Host "Press Enter to return to main menu"
}

function Invoke-SystemInfo {
    Clear-Host
    Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              SYSTEM INFORMATION                    ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "System Resources:" -ForegroundColor Yellow
    Write-Host ""
    
    # CPU
    if ($IsWindows -or $PSVersionTable.Platform -eq "Win32NT") {
        $cpu = Get-CimInstance -ClassName Win32_Processor
        Write-Host "  CPU:     " -NoNewline -ForegroundColor Cyan
        Write-Host "$($cpu.Name) ($($cpu.NumberOfCores) cores)"
        
        $ram = Get-CimInstance -ClassName Win32_ComputerSystem
        $totalRAM = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
        Write-Host "  RAM:     " -NoNewline -ForegroundColor Cyan
        Write-Host "$totalRAM GB"
    }
    else {
        # Linux/Mac
        $cpuInfo = (lscpu | grep "^CPU(s):" | awk '{print $2}')
        Write-Host "  CPU:     " -NoNewline -ForegroundColor Cyan
        Write-Host "$cpuInfo cores"
        
        $ramInfo = free -g | grep Mem | awk '{print $2}'
        Write-Host "  RAM:     " -NoNewline -ForegroundColor Cyan
        Write-Host "$ramInfo GB"
    }
    
    Write-Host ""
    Write-Host "Prerequisites:" -ForegroundColor Yellow
    Write-Host ""
    
    # Docker
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $dockerVersion = docker --version
        Write-Host "  ✓ Docker:  " -NoNewline -ForegroundColor Green
        Write-Host $dockerVersion
    }
    else {
        Write-Host "  ✗ Docker:  NOT INSTALLED" -ForegroundColor Red
    }
    
    # Docker Compose
    if (docker compose version 2>$null) {
        $composeVersion = docker compose version
        Write-Host "  ✓ Compose: " -NoNewline -ForegroundColor Green
        Write-Host $composeVersion
    }
    else {
        Write-Host "  ✗ Compose: NOT INSTALLED" -ForegroundColor Red
    }
    
    # Git
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitVersion = git --version
        Write-Host "  ✓ Git:     " -NoNewline -ForegroundColor Green
        Write-Host $gitVersion
    }
    else {
        Write-Host "  ✗ Git:     NOT INSTALLED" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Recommended Profile:" -ForegroundColor Yellow
    
    if ($IsWindows -or $PSVersionTable.Platform -eq "Win32NT") {
        $ram = Get-CimInstance -ClassName Win32_ComputerSystem
        $totalRAM = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
    }
    else {
        $totalRAM = [int](free -g | grep Mem | awk '{print $2}')
    }
    
    if ($totalRAM -ge 16) {
        Write-Host "  → LARGE profile (8 CPU, 16GB RAM)" -ForegroundColor Green
    }
    elseif ($totalRAM -ge 8) {
        Write-Host "  → MEDIUM profile (4 CPU, 8GB RAM)" -ForegroundColor Green
    }
    else {
        Write-Host "  → SMALL profile (2 CPU, 4GB RAM)" -ForegroundColor Yellow
        Write-Host "    Note: Limited resources may affect performance" -ForegroundColor Gray
    }
    
    Write-Host ""
    Read-Host "Press Enter to return to main menu"
}

# ============================================================================
# PLACEHOLDER FUNCTIONS (Will be implemented in modules)
# ============================================================================

# Temporary implementations - will be replaced by module imports
function Test-CeresEnvironment { return $true }
function Test-ConfigurationConflicts { return $true }
function Test-DeploymentPlan { return $true }
function Get-SystemResourcesAnalysis { param($OutputFormat) }
function Start-ConfigurationWizard { param($PresetProfile, $Interactive) }
function Generate-AllConfigurations { }
function Generate-TerraformConfig { }
function Generate-DockerComposeConfig { }
function Generate-SecretsFile { }
function Deploy-InfrastructurePhase { }
function Deploy-OsConfigPhase { }
function Deploy-ApplicationsPhase { }
function Deploy-PostDeployPhase { }
function Deploy-AllPhases { }
function Get-DeploymentStatus { param($Service, $Format) }
function Undo-LastDeploymentStep { }
function Undo-ToStep { param($StepNumber) }
function Undo-FullDeployment { }
function Get-ServiceLogs { param($Service) }

# ============================================================================
# EXECUTION
# ============================================================================

function Main {
    # Show version if requested
    if ($Version) {
        Write-Host "CERES CLI v$script:CeresVersion"
        exit 0
    }

    # If no command or "interactive", launch wizard
    if ([string]::IsNullOrEmpty($Command) -or $Command -eq "interactive") {
        Invoke-InteractiveWizard
        exit 0
    }

    # Route to command handlers
    switch ($Command.ToLower()) {
        "help" { Invoke-HelpCommand $Subcommand }
        "init" { Invoke-InitCommand }
        "analyze" { Invoke-AnalyzeCommand }
        "configure" { Invoke-ConfigureCommand }
        "generate" { Invoke-GenerateCommand }
        "validate" { Invoke-ValidateCommand }
        "start" { Invoke-StartCommand }
        "stop" { Invoke-StopCommand }
        "status" { Invoke-StatusCommand }
        "backup" { Invoke-BackupCommand }
        "restore" { Invoke-RestoreCommand }
        "deploy" { Invoke-DeployCommand }
        "logs" { Invoke-LogsCommand }
        "rollback" { Invoke-RollbackCommand }
        "setup" { Invoke-SetupCommand }
        "user" { Invoke-UserCommand }
        "vpn" { Invoke-VpnCommand }
        "k8s" { Invoke-K8sCommand }
        default {
            Write-CeresLog "Unknown command: $Command" "ERROR"
            Show-MainHelp
            exit 1
        }
    }
}

Main

