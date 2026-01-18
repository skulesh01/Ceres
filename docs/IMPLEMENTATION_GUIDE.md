# CERES Внедрение системы анализа ресурсов — Инструкция

**Дата создания:** 17 января 2026  
**Статус:** 🎯 Ready for Implementation  
**Доп. информация:** Полный план с примерами кода в `RESOURCE_PLANNING_BEST_PRACTICES.md`

---

## 📌 БЫСТРЫЙ СТАРТ

Для реализации этого плана:

1. **Прочитайте документы** (в порядке):
   - [RESOURCE_PLANNING_SUMMARY.md](../RESOURCE_PLANNING_SUMMARY.md) — Краткое резюме
   - [RESOURCE_PLANNING_STRATEGY.md](../RESOURCE_PLANNING_STRATEGY.md) — Полная стратегия
   - [RESOURCE_PLANNING_BEST_PRACTICES.md](../RESOURCE_PLANNING_BEST_PRACTICES.md) — Лучшие практики с кодом
   - [RESOURCE_PLANNING_VISUALS.md](./RESOURCE_PLANNING_VISUALS.md) — Диаграммы

2. **Начните с Phase 1 (MVP):** неделю 1-2
   - Создавайте файлы в указанном порядке
   - Тестируйте каждый компонент отдельно
   - Интегрируйте в конце

3. **Переходите на Phase 2:** неделя 3-4
   - Добавьте custom profiles
   - Расширьте валидацию
   - Добавьте integration тесты

---

## 🎯 PHASE 1: MVP (1-2 недели) — НАЧНИТЕ ЗДЕСЬ

### Задача 1: Создать профили (Data Layer)

**Файл:** `config/profiles/small.json`

```json
{
  "version": "1.0",
  "name": "Small",
  "description": "Development/PoC, 1-2 VMs, 8-12 CPU, 16-24 GB RAM",
  "deployment": {
    "type": "docker-compose",
    "ha": false,
    "environment": "development"
  },
  "virtual_machines": [
    {
      "id": 1,
      "name": "all-in-one",
      "cpu": 8,
      "ram_gb": 16,
      "disk_gb": 100,
      "services": [
        "postgresql",
        "redis",
        "keycloak",
        "nextcloud",
        "gitea",
        "prometheus",
        "grafana",
        "caddy",
        "portainer"
      ]
    }
  ],
  "optional_modules": {
    "vpn": false,
    "mail": false,
    "edms": false,
    "loki": false
  }
}
```

**Файл:** `config/profiles/medium.json`

```json
{
  "version": "1.0",
  "name": "Medium",
  "description": "Standard team, 3 VMs, 10 CPU, 20 GB RAM (RECOMMENDED)",
  "deployment": {
    "type": "kubernetes-proxmox",
    "ha": false,
    "environment": "production"
  },
  "virtual_machines": [
    {
      "id": 1,
      "name": "core",
      "ip": "192.168.1.10",
      "cpu": 4,
      "ram_gb": 8,
      "disk_gb": 50,
      "services": ["postgresql", "redis", "keycloak"]
    },
    {
      "id": 2,
      "name": "apps",
      "ip": "192.168.1.11",
      "cpu": 4,
      "ram_gb": 8,
      "disk_gb": 80,
      "services": [
        "nextcloud",
        "gitea",
        "mattermost",
        "redmine",
        "wikijs"
      ]
    },
    {
      "id": 3,
      "name": "edge",
      "ip": "192.168.1.12",
      "cpu": 2,
      "ram_gb": 4,
      "disk_gb": 40,
      "services": [
        "caddy",
        "prometheus",
        "grafana",
        "portainer",
        "uptime-kuma"
      ]
    }
  ],
  "resource_allocation": {
    "postgresql": {
      "cpu_limit": "1.5",
      "memory_limit": "2G",
      "memory_reservation": "1G"
    },
    "redis": {
      "cpu_limit": "1.0",
      "memory_limit": "1G",
      "memory_reservation": "512M"
    },
    "keycloak": {
      "cpu_limit": "1.5",
      "memory_limit": "1.5G",
      "memory_reservation": "1G"
    }
  },
  "optional_modules": {
    "vpn": false,
    "mail": false,
    "edms": false,
    "loki": true
  }
}
```

**Файл:** `config/profiles/large.json` — Аналогично, но с 4-5 VMs

**Проверка:**
```powershell
# Убедитесь, что JSON валидный
$profiles = Get-Content "config/profiles/medium.json" | ConvertFrom-Json
Write-Host "Loaded profile: $($profiles.name)"
Write-Host "VMs: $($profiles.virtual_machines.Count)"
```

---

### Задача 2: Создать _lib/Resource-Profiles.ps1

**Файл:** `scripts/_lib/Resource-Profiles.ps1`

```powershell
<#
.SYNOPSIS
    Resource profile definitions for CERES
#>

# Load all profiles from JSON
function Get-ResourceProfiles {
    param(
        [string]$ProfilesDir = "$PSScriptRoot\..\..\config\profiles"
    )
    
    $profiles = @{}
    
    Get-ChildItem "$ProfilesDir\*.json" | ForEach-Object {
        $name = $_.BaseName
        $content = Get-Content $_.FullName | ConvertFrom-Json
        $profiles[$name] = $content
    }
    
    return $profiles
}

# Get specific profile
function Get-ResourceProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileName,
        
        [string]$ProfilesDir = "$PSScriptRoot\..\..\config\profiles"
    )
    
    $path = Join-Path $ProfilesDir "$ProfileName.json"
    
    if (-not (Test-Path $path)) {
        throw "Profile not found: $ProfileName"
    }
    
    return Get-Content $path | ConvertFrom-Json
}

# List available profiles
function Get-AvailableProfiles {
    param(
        [string]$ProfilesDir = "$PSScriptRoot\..\..\config\profiles"
    )
    
    $profiles = Get-ResourceProfiles -ProfilesDir $ProfilesDir
    return $profiles.Keys | Sort-Object
}

# Validate profile
function Test-ResourceProfile {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Profile
    )
    
    $errors = @()
    
    # Check required fields
    if (-not $Profile.version) { $errors += "Missing: version" }
    if (-not $Profile.name) { $errors += "Missing: name" }
    if (-not $Profile.virtual_machines) { $errors += "Missing: virtual_machines" }
    
    # Check VM count
    if ($Profile.virtual_machines.Count -lt 1) {
        $errors += "At least 1 VM required"
    }
    
    # Check each VM
    $Profile.virtual_machines | ForEach-Object {
        if (-not $_.cpu -or $_.cpu -lt 1) { 
            $errors += "VM $($_.name): invalid CPU" 
        }
        if (-not $_.ram_gb -or $_.ram_gb -lt 512MB) { 
            $errors += "VM $($_.name): invalid RAM" 
        }
        if (-not $_.disk_gb -or $_.disk_gb -lt 10) { 
            $errors += "VM $($_.name): invalid disk" 
        }
        if (-not $_.services -or $_.services.Count -eq 0) { 
            $errors += "VM $($_.name): no services defined" 
        }
    }
    
    if ($errors.Count -gt 0) {
        return $false, $errors
    }
    
    return $true, @()
}

Export-ModuleMember -Function @(
    'Get-ResourceProfiles',
    'Get-ResourceProfile',
    'Get-AvailableProfiles',
    'Test-ResourceProfile'
)
```

**Проверка:**
```powershell
. scripts/_lib/Resource-Profiles.ps1

$profiles = Get-AvailableProfiles
Write-Host "Available profiles: $profiles"

$medium = Get-ResourceProfile "medium"
Write-Host "Medium profile: $($medium.name)"
Write-Host "VMs: $($medium.virtual_machines | Select-Object -ExpandProperty name)"
```

---

### Задача 3: Создать analyze-resources.ps1

**Файл:** `scripts/analyze-resources.ps1`

```powershell
<#
.SYNOPSIS
    Analyze system resources and recommend profile
    
.DESCRIPTION
    Checks local or remote (Proxmox) resources
    Compares with profile requirements
    Returns recommendations
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('local', 'proxmox')]
    [string]$Environment = 'local',
    
    [Parameter()]
    [string]$ProxmoxHost,
    
    [Parameter()]
    [string]$ProxmoxUser = 'root',
    
    [Parameter()]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib\Resource-Profiles.ps1")

# ============================================================================
# ANALYZE LOCAL SYSTEM
# ============================================================================

function Get-LocalResources {
    Write-Verbose "Analyzing local system..."
    
    $computerInfo = Get-ComputerInfo
    $cpu = $computerInfo.CsProcessors | Measure-Object -Property NumberOfCores -Sum
    $ram = [Math]::Round($computerInfo.CsTotalPhysicalMemory / 1GB)
    
    # Storage: get C: drive
    $disk = Get-Volume -DriveLetter C | Select-Object -ExpandProperty Size
    $disk = [Math]::Round($disk / 1GB)
    
    return @{
        type = "local"
        total_cpu = $cpu.Sum
        total_ram_gb = $ram
        total_storage_gb = $disk
        available_cpu = $cpu.Sum  # Assume all available
        available_ram_gb = $ram
        available_storage_gb = $disk
    }
}

# ============================================================================
# ANALYZE PROXMOX
# ============================================================================

function Get-ProxmoxResources {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [Parameter()]
        [string]$User
    )
    
    Write-Verbose "Analyzing Proxmox host: $Host..."
    
    # TODO: Implement Proxmox API call
    # For now, return placeholder
    Write-Warning "Proxmox analysis not yet implemented"
    
    return @{
        type = "proxmox"
        total_cpu = 0
        total_ram_gb = 0
        total_storage_gb = 0
    }
}

# ============================================================================
# RECOMMEND PROFILE
# ============================================================================

function Get-ProfileRecommendation {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Resources
    )
    
    $profiles = Get-ResourceProfiles
    $recommendations = @{
        feasible = @()
        recommended = $null
        warnings = @()
    }
    
    foreach ($profileName in @('small', 'medium', 'large')) {
        $profile = $profiles[$profileName]
        $totalCpuNeeded = 0
        $totalRamNeeded = 0
        $totalDiskNeeded = 0
        
        # Calculate requirements
        $profile.virtual_machines | ForEach-Object {
            $totalCpuNeeded += $_.cpu
            $totalRamNeeded += $_.ram_gb
            $totalDiskNeeded += $_.disk_gb
        }
        
        # Check if feasible
        $cpuOk = $totalCpuNeeded -le $Resources.available_cpu
        $ramOk = $totalRamNeeded -le $Resources.available_ram_gb
        $diskOk = $totalDiskNeeded -le $Resources.available_storage_gb
        
        if ($cpuOk -and $ramOk -and $diskOk) {
            $recommendations.feasible += $profileName
            
            # Select as recommended if Medium
            if ($profileName -eq 'medium') {
                $recommendations.recommended = $profileName
            }
        }
    }
    
    # If no Medium, recommend highest available
    if (-not $recommendations.recommended -and $recommendations.feasible.Count -gt 0) {
        $recommendations.recommended = $recommendations.feasible[-1]
    }
    
    # Generate warnings
    if ($Resources.available_ram_gb -lt 8) {
        $recommendations.warnings += "Low RAM: Consider upgrade for better performance"
    }
    
    if ($Resources.available_storage_gb -lt 150) {
        $recommendations.warnings += "Limited storage: May affect service scaling"
    }
    
    return $recommendations
}

# ============================================================================
# MAIN
# ============================================================================

try {
    # Analyze resources
    Write-Host "Analyzing system resources..." -ForegroundColor Cyan
    
    if ($Environment -eq 'local') {
        $resources = Get-LocalResources
    }
    else {
        if (-not $ProxmoxHost) {
            throw "ProxmoxHost required for proxmox environment"
        }
        $resources = Get-ProxmoxResources -Host $ProxmoxHost -User $ProxmoxUser
    }
    
    # Get recommendations
    $recommendations = Get-ProfileRecommendation -Resources $resources
    
    # Output
    if ($Json) {
        @{
            resources = $resources
            recommendations = $recommendations
        } | ConvertTo-Json | Write-Output
    }
    else {
        Write-Host "`n📊 System Resources:" -ForegroundColor Green
        Write-Host "  CPU:     $($resources.total_cpu) cores"
        Write-Host "  RAM:     $($resources.total_ram_gb) GB"
        Write-Host "  Storage: $($resources.total_storage_gb) GB"
        
        Write-Host "`n🎯 Profile Recommendations:" -ForegroundColor Green
        Write-Host "  Feasible:    $($recommendations.feasible -join ', ')"
        Write-Host "  Recommended: $($recommendations.recommended) ⭐"
        
        if ($recommendations.warnings.Count -gt 0) {
            Write-Host "`n⚠️  Warnings:" -ForegroundColor Yellow
            $recommendations.warnings | ForEach-Object { Write-Host "  • $_" }
        }
    }
    
    return @{
        success = $true
        resources = $resources
        recommendations = $recommendations
    }
}
catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    return @{
        success = $false
        error = $_
    }
}
```

**Проверка:**
```powershell
.\scripts\analyze-resources.ps1
# Должно вывести текущие ресурсы и рекомендации профилей
```

---

### Задача 4: Создать базовый configure-ceres.ps1

**Файл:** `scripts/configure-ceres.ps1`

```powershell
<#
.SYNOPSIS
    Interactive CERES configuration wizard
    
.DESCRIPTION
    Guides user through profile selection and customization
    Generates all necessary configuration files
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('small', 'medium', 'large', 'custom')]
    [string]$PresetProfile = $null,
    
    [Parameter()]
    [switch]$NonInteractive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib\Resource-Profiles.ps1")
. (Join-Path $PSScriptRoot "analyze-resources.ps1")

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

function Show-ProfileMenu {
    param(
        [psobject[]]$AvailableProfiles
    )
    
    Write-Host "`n🎯 Select Profile:" -ForegroundColor Cyan
    Write-Host ""
    
    $profiles = Get-ResourceProfiles
    
    $index = 1
    foreach ($name in ('small', 'medium', 'large')) {
        $profile = $profiles[$name]
        $available = $AvailableProfiles -contains $name
        $mark = if ($available) { "✓" } else { "✗" }
        $recommended = if ($name -eq 'medium') { " ⭐ RECOMMENDED" } else { "" }
        
        Write-Host "  $index) $($profile.name) - $($profile.description)$recommended [$mark]"
        $index++
    }
    
    Write-Host ""
    $choice = Read-Host "Select (1-3)"
    
    switch ($choice) {
        "1" { return "small" }
        "2" { return "medium" }
        "3" { return "large" }
        default { 
            Write-Host "Invalid choice" -ForegroundColor Red
            return Show-ProfileMenu -AvailableProfiles $AvailableProfiles
        }
    }
}

# ============================================================================
# MAIN
# ============================================================================

try {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  CERES Configuration Wizard            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Step 1: Analyze
    Write-Host "📊 Step 1: Analyzing system resources..." -ForegroundColor Yellow
    $analysis = & (Join-Path $PSScriptRoot "analyze-resources.ps1") -Json | ConvertFrom-Json
    
    if (-not $analysis.success) {
        throw "Failed to analyze resources: $($analysis.error)"
    }
    
    $feasibleProfiles = $analysis.recommendations.feasible
    Write-Host "✓ Analysis complete`n" -ForegroundColor Green
    
    # Step 2: Profile selection
    Write-Host "🎯 Step 2: Profile Selection" -ForegroundColor Yellow
    
    if ($PresetProfile) {
        $selectedProfile = $PresetProfile
        Write-Host "Using preset profile: $selectedProfile`n" -ForegroundColor Green
    }
    else {
        $selectedProfile = Show-ProfileMenu -AvailableProfiles $feasibleProfiles
    }
    
    # Validate selection
    if ($feasibleProfiles -notcontains $selectedProfile) {
        throw "Profile $selectedProfile not feasible for your system"
    }
    
    # Step 3: Load profile
    Write-Host "📦 Step 3: Loading profile configuration..." -ForegroundColor Yellow
    $profile = Get-ResourceProfile -ProfileName $selectedProfile
    Write-Host "✓ Loaded: $($profile.name)`n" -ForegroundColor Green
    
    # Step 4: Review
    Write-Host "📋 Step 4: Deployment Plan:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Profile:   $($profile.name)"
    Write-Host "  VMs:       $($profile.virtual_machines.Count)"
    Write-Host "  Total CPU: $(($profile.virtual_machines | Measure-Object -Property cpu -Sum).Sum) cores"
    Write-Host "  Total RAM: $(($profile.virtual_machines | Measure-Object -Property ram_gb -Sum).Sum) GB"
    Write-Host "  Total Disk: $(($profile.virtual_machines | Measure-Object -Property disk_gb -Sum).Sum) GB"
    Write-Host ""
    
    $confirm = Read-Host "Proceed? (yes/no)"
    if ($confirm -ne 'yes') {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
    
    # Step 5: Generate configs (will implement in next tasks)
    Write-Host "`n✨ Generating configuration files..." -ForegroundColor Green
    Write-Host "✓ Configuration wizard complete!" -ForegroundColor Green
    Write-Host "`nNext steps:"
    Write-Host "  1. Review configuration"
    Write-Host "  2. Run .\DEPLOY.ps1"
    Write-Host ""
}
catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    exit 1
}
```

**Проверка:**
```powershell
.\scripts\configure-ceres.ps1
# Должно запустить интерактивный wizard
```

---

## 📋 PHASE 1 CHECKLIST

```powershell
# 1. Create profile JSON files
Test-Path config/profiles/small.json    # ✓
Test-Path config/profiles/medium.json   # ✓
Test-Path config/profiles/large.json    # ✓

# 2. Create library script
Test-Path scripts/_lib/Resource-Profiles.ps1  # ✓

# 3. Create analysis script
.\scripts\analyze-resources.ps1         # ✓ Should run successfully

# 4. Create wizard script  
.\scripts\configure-ceres.ps1           # ✓ Should show interactive menu

# 5. Test end-to-end
.\scripts\configure-ceres.ps1 -PresetProfile medium -NonInteractive  # ✓
```

---

## ✅ NEXT STEPS (После Phase 1)

1. **Создать generate-*.ps1 скрипты** (Phase 2)
   - `generate-terraform-config.ps1`
   - `generate-docker-resources.ps1`
   - `generate-env-config.ps1`

2. **Интегрировать в start.ps1 и DEPLOY.ps1**
   - Вызывать configure-ceres.ps1 если нет .env
   - Использовать сгенерированные конфиги

3. **Добавить тесты**
   - Unit-тесты для каждого скрипта
   - Integration-тесты для whole pipeline

4. **Документировать**
   - Обновить README
   - Добавить примеры
   - Создать видео-тутореал (опционально)

---

## 💬 ВАЖНЫЕ ЗАМЕЧАНИЯ

### Что делать, если...

**Q: Пользователь хочет custom конфиг?**
A: На Phase 2 добавим опцию в wizard для кастомизации

**Q: Нужна поддержка AWS/Azure/GCP?**
A: Добавим отдельные `environments/` в terraform и template для cloud провайдеров

**Q: Как валидировать Terraform vars?**
A: Используйте `terraform validate` перед apply (добавим в DEPLOY.ps1)

**Q: Нужны ли миграции из старых версий?**
A: Да, создадим `scripts/migrate-config.ps1` для существующих deployments

---

## 📞 ВОПРОСЫ?

Смотрите:
- [RESOURCE_PLANNING_STRATEGY.md](../RESOURCE_PLANNING_STRATEGY.md) — Полная архитектура
- [RESOURCE_PLANNING_BEST_PRACTICES.md](../RESOURCE_PLANNING_BEST_PRACTICES.md) — Примеры и best practices
- [RESOURCE_PLANNING_VISUALS.md](./RESOURCE_PLANNING_VISUALS.md) — Диаграммы
