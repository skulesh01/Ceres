# CERES — Лучшие практики реализации системы ресурсов

## 🎯 BEST PRACTICES ПО КАТЕГОРИЯМ

---

## 1️⃣ АРХИТЕКТУРА И ДИЗАЙН

### ✅ Разделение ответственности
**Принцип:** Каждый скрипт должен делать одно и делать хорошо

```
❌ ПЛОХО: Один mega-скрипт делает всё
configure-everything.ps1
├─ Анализ ресурсов
├─ Интерактивный wizard
├─ Генерация configs
├─ Валидация
├─ Деплой
└─ Мониторинг

✅ ХОРОШО: Модульная архитектура
analyze-resources.ps1           ← Только анализ
configure-ceres.ps1             ← Только wizard UI
generate-terraform-config.ps1   ← Только Terraform
generate-docker-resources.ps1   ← Только Docker
generate-env-config.ps1         ← Только .env
_lib/Resource-Profiles.ps1      ← Shared data
_lib/Config-Validation.ps1      ← Shared logic
```

**Выигрыш:**
- Легче тестировать каждый компонент
- Легче переиспользовать (например, анализ в разных скриптах)
- Легче обновлять и дебагить
- Легче добавлять новые профили

### ✅ Single Source of Truth
**Проблема:** Если одна информация хранится в нескольких местах, она легко рассинхронизируется

```
❌ ПЛОХО: Одна инфа в разных местах
README.md:
  "Small: 8 CPU, 16 GB RAM"
config/profiles/small.json:
  { "cpu": 4, "ram": 8 }  ← Конфликт!
terraform/variables.tf:
  default = "2 cpu"  ← Ещё конфликт!

✅ ХОРОШО: Одна инфа в одном месте
config/profiles/small.json
├─ Используется в configure-ceres.ps1
├─ Используется в generate-terraform-config.ps1
├─ Документируется в docs/
└─ Тестируется в tests/
```

**Реализация:**
```powershell
# _lib/Resource-Profiles.ps1

$PROFILES = @{
    small = @{
        name = "Small"
        description = "Development/PoC, 1-2 VMs"
        vmCount = 1
        totalCPU = 8
        totalRAM = 16
        totalStorage = 100
        vms = @(
            @{ name = "core"; cpu = 8; ram = 16; storage = 100 }
        )
        services = @("core", "apps", "monitoring")
    }
    medium = @{
        name = "Medium"
        description = "Standard team, 3 VMs"
        vmCount = 3
        totalCPU = 10
        totalRAM = 20
        totalStorage = 170
        # ... остальное
    }
}

# Использование везде:
$config = $PROFILES.small
Write-Host "Deploying $($config.name): $($config.description)"
```

---

## 2️⃣ ВАЛИДАЦИЯ И ERROR HANDLING

### ✅ Ранняя валидация (Fail Fast)
**Принцип:** Проверить все перед началом работы, а не в конце

```powershell
❌ ПЛОХО: Ошибка выявляется в конце
function Deploy-CERES {
    # 30 минут работы...
    # В конце:
    if ($RAM -lt 16) {
        throw "Not enough RAM!"  # Слишком поздно!
    }
}

✅ ХОРОШО: Ошибка выявляется в начале
function Invoke-CeresPreflight {
    # Проверка 1: Proxmox доступен?
    Test-ProxmoxConnection
    
    # Проверка 2: Ресурсов достаточно?
    Assert-SufficientResources
    
    # Проверка 3: Порты свободны?
    Assert-PortsAvailable
    
    # Проверка 4: Сеть настроена?
    Assert-NetworkSetup
    
    # ✓ Если сюда дошли - всё OK
}
```

### ✅ Валидация конфигурации
```powershell
# config/Validation.ps1

function Test-ResourceConfiguration {
    param($Config)
    
    $errors = @()
    
    # Rule 1: Хотя бы одна VM
    if ($Config.vmCount -lt 1) {
        $errors += "VM count must be >= 1"
    }
    
    # Rule 2: Core VM должна иметь Postgres + Redis
    if (-not $Config.vms[0].services.Contains("postgres")) {
        $errors += "First VM must contain PostgreSQL"
    }
    
    # Rule 3: Total resources не должны превышать доступные
    if ($Config.totalCPU -gt $env:AvailableCPU) {
        $errors += "Requested CPU ($($Config.totalCPU)) > Available ($env:AvailableCPU)"
    }
    
    # Rule 4: Memory не менее 512MB на контейнер
    $containerCount = $Config.vms | Measure-Object -Property "containers" -Sum
    if ($Config.totalRAM / $containerCount.Sum -lt 0.5) {
        $errors += "Not enough RAM per container"
    }
    
    if ($errors.Count -gt 0) {
        Write-Host "❌ Configuration validation failed:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  - $_" }
        throw "Invalid configuration"
    }
    
    Write-Host "✅ Configuration is valid" -ForegroundColor Green
}
```

---

## 3️⃣ КОНФИГУРАЦИЯ И ПАРАМЕТРИЗАЦИЯ

### ✅ Используй JSON для конфиг-профилей
**Почему:**
- Лёгкий парсинг в PowerShell, Python, etc.
- Легко редактировать и версионировать в Git
- Легко валидировать JSON schema
- Легко экспортировать/импортировать

```json
// config/profiles/medium.json

{
  "version": "1.0",
  "name": "Medium",
  "description": "Standard team deployment (10-50 users)",
  
  "deployment": {
    "type": "kubernetes-proxmox",
    "ha": false,
    "monitoring": true
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
      "services": ["nextcloud", "gitea", "mattermost", "redmine", "wikijs"]
    },
    {
      "id": 3,
      "name": "edge",
      "ip": "192.168.1.12",
      "cpu": 2,
      "ram_gb": 4,
      "disk_gb": 40,
      "services": ["caddy", "prometheus", "grafana", "portainer"]
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
  },
  
  "estimated_cost": {
    "provider": "hetzner",
    "monthly_usd": 120,
    "notes": "3 VM * $40/mo"
  }
}
```

**Использование:**
```powershell
$profile = Get-Content "config/profiles/medium.json" | ConvertFrom-Json

foreach ($vm in $profile.virtual_machines) {
    Write-Host "VM: $($vm.name)"
    Write-Host "  CPU: $($vm.cpu)"
    Write-Host "  RAM: $($vm.ram_gb) GB"
    Write-Host "  Services: $($vm.services -join ', ')"
}
```

### ✅ Параметризуй Terraform variables
**Проблема:** Хардкод в terraform/main.tf

```hcl
❌ ПЛОХО: Хардкод
resource "proxmox_vm_qemu" "core" {
  cores   = 4          # Хардкод!
  memory  = 8192       # Хардкод!
  vmid    = 100        # Хардкод!
}

✅ ХОРОШО: Переменные
variable "core_vm_cores" {
  default = 4
}

variable "core_vm_memory" {
  default = 8192
}

resource "proxmox_vm_qemu" "core" {
  cores   = var.core_vm_cores
  memory  = var.core_vm_memory
}
```

**terraform/variables.tf:**
```hcl
variable "environment" {
  description = "Deployment environment"
  default     = "production"
}

variable "deployment_profile" {
  description = "Resource profile: small, medium, large"
  default     = "medium"
}

variable "core_vm_cores" {
  description = "CPU cores for core VM"
  type        = number
  default     = 4
}

variable "core_vm_memory" {
  description = "RAM in MB for core VM"
  type        = number
  default     = 8192
}

# ... и т.д.
```

**terraform/environments/medium.tfvars:**
```hcl
environment         = "production"
deployment_profile  = "medium"
core_vm_cores       = 4
core_vm_memory      = 8192
apps_vm_cores       = 4
apps_vm_memory      = 8192
edge_vm_cores       = 2
edge_vm_memory      = 4096
```

---

## 4️⃣ ГЕНЕРАЦИЯ КОНФИГОВ

### ✅ Генерируй, не изменяй
**Принцип:** Лучше пересгенерировать конфиг, чем вручную его менять

```powershell
❌ ПЛОХО: Ручное редактирование
# Пользователь открывает .env и ручно меняет:
POSTGRES_PASSWORD=old_value  # Может ошибиться
KEYCLOAK_MEMORY=1G           # Может забыть других параметров

✅ ХОРОШО: Автогенерация
.\scripts\generate-env-config.ps1 -Profile medium
# Скрипт генерирует весь .env консистентно
```

**Реализация:**
```powershell
# scripts/generate-env-config.ps1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('small', 'medium', 'large')]
    [string]$Profile,
    
    [Parameter()]
    [string]$OutputPath = "config/.env"
)

# 1. Загрузить профиль
$profileData = Get-Content "config/profiles/$Profile.json" | ConvertFrom-Json

# 2. Создать базовый .env с defaults
$envContent = @(
    "# Auto-generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "# Profile: $Profile"
    "# DO NOT EDIT MANUALLY - regenerate with generate-env-config.ps1"
    ""
    "DOMAIN=ceres"
    "DEPLOYMENT_PROFILE=$Profile"
    "DEPLOYMENT_DATE=$(Get-Date -Format 'yyyy-MM-dd')"
    ""
) -join "`n"

# 3. Добавить profile-specific параметры
foreach ($service in $profileData.resource_allocation.PSObject.Properties) {
    $name = $service.Name
    $limits = $service.Value
    
    # Например, для PostgreSQL:
    # POSTGRES_CPU_LIMIT=1.5
    # POSTGRES_MEMORY_LIMIT=2G
    $envContent += "`n$($name.ToUpper())_CPU_LIMIT=$($limits.cpu_limit)`n"
    $envContent += "$($name.ToUpper())_MEMORY_LIMIT=$($limits.memory_limit)`n"
}

# 4. Добавить секреты (с генерацией если надо)
$envContent += "`n# Secrets (generated automatically)`n"
$envContent += "POSTGRES_PASSWORD=$(Generate-SecurePassword)`n"
$envContent += "KEYCLOAK_ADMIN_PASSWORD=$(Generate-SecurePassword)`n"
$envContent += "NEXTCLOUD_ADMIN_PASSWORD=$(Generate-SecurePassword)`n"

# 5. Сохранить
$envContent | Set-Content $OutputPath -Encoding UTF8

Write-Host "✅ Generated $OutputPath for profile: $Profile" -ForegroundColor Green
```

### ✅ Создавай бэкапы перед изменением
```powershell
function Invoke-SafeConfigUpdate {
    param(
        [string]$ConfigPath,
        [scriptblock]$UpdateAction
    )
    
    # Шаг 1: Сделать бэкап
    $timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
    $backupPath = "$ConfigPath.backup.$timestamp"
    Copy-Item $ConfigPath $backupPath -Force
    
    Write-Host "📦 Backup created: $backupPath"
    
    try {
        # Шаг 2: Выполнить обновление
        & $UpdateAction
        
        Write-Host "✅ Config updated successfully"
        
        # Шаг 3: Валидировать новый конфиг
        if (Test-ConfigValidity -Path $ConfigPath) {
            Write-Host "✅ Validation passed"
            return $true
        }
        else {
            throw "Validation failed"
        }
    }
    catch {
        # Шаг 4: Откатить если ошибка
        Write-Host "⚠️ Rolling back to backup..." -ForegroundColor Yellow
        Copy-Item $backupPath $ConfigPath -Force
        throw "Config update failed: $_"
    }
}

# Использование:
Invoke-SafeConfigUpdate "config/.env" {
    .\scripts\generate-env-config.ps1 -Profile medium
}
```

---

## 5️⃣ ДОКУМЕНТИРОВАНИЕ И ОТЧЁТЫ

### ✅ Создавай DEPLOYMENT_PLAN.json
**Назначение:** Сохранить историю выбранной конфигурации

```json
{
  "generated_at": "2026-01-17T14:30:00Z",
  "profile_version": "1.0",
  "selected_profile": "medium",
  
  "user_selections": {
    "deployment_type": "kubernetes-proxmox",
    "vm_count": 3,
    "enable_vpn": false,
    "enable_mail": false,
    "enable_ha": false
  },
  
  "resource_summary": {
    "total_cpu": 10,
    "total_ram_gb": 20,
    "total_storage_gb": 170,
    "vm_breakdown": [
      {
        "name": "core",
        "cpu": 4,
        "ram_gb": 8,
        "storage_gb": 50,
        "services": ["postgresql", "redis", "keycloak"]
      },
      {
        "name": "apps",
        "cpu": 4,
        "ram_gb": 8,
        "storage_gb": 80,
        "services": ["nextcloud", "gitea", "mattermost", "redmine", "wikijs"]
      },
      {
        "name": "edge",
        "cpu": 2,
        "ram_gb": 4,
        "storage_gb": 40,
        "services": ["caddy", "prometheus", "grafana", "portainer"]
      }
    ]
  },
  
  "generated_artifacts": {
    "terraform_vars": "terraform/environments/medium.tfvars",
    "env_file": "config/.env",
    "compose_files": [
      "config/compose/base.yml",
      "config/compose/core.yml",
      "config/compose/apps.yml",
      "config/compose/monitoring.yml"
    ]
  },
  
  "next_steps": [
    "1. Review generated configs",
    "2. Optionally modify terraform/environments/medium.tfvars",
    "3. Run: .\\DEPLOY.ps1",
    "4. Follow on-screen prompts",
    "5. Verify deployment with: kubectl get pods -A"
  ],
  
  "estimated_times": {
    "terraform_apply": "5-10 minutes",
    "ansible_provisioning": "10-15 minutes",
    "k3s_installation": "2-3 minutes",
    "services_startup": "5-10 minutes",
    "total": "20-40 minutes"
  },
  
  "estimated_costs": {
    "provider": "hetzner",
    "monthly_usd": 120,
    "breakdown": {
      "core_vm": 40,
      "apps_vm": 40,
      "edge_vm": 40
    }
  }
}
```

### ✅ Создавай readable summary в Markdown
```powershell
function Export-DeploymentPlan {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Config,
        
        [Parameter()]
        [string]$OutputPath = "DEPLOYMENT_PLAN.md"
    )
    
    $summary = @"
# CERES Deployment Plan

**Generated:** $(Get-Date)
**Profile:** $($Config.name)

## Overview
$($Config.description)

## Resource Allocation

| VM | CPU | RAM | Storage | Services |
|----|----|-----|---------|----------|
$(@($Config.virtual_machines | ForEach-Object {
    "| $($_.name) | $($_.cpu) | $($_.ram_gb) GB | $($_.disk_gb) GB | $($_.services -join ', ') |"
}) -join "`n")

## Total Resources
- **CPU:** $($Config.virtual_machines | Measure-Object -Property cpu -Sum).Sum cores
- **RAM:** $($Config.virtual_machines | Measure-Object -Property ram_gb -Sum).Sum GB
- **Storage:** $($Config.virtual_machines | Measure-Object -Property disk_gb -Sum).Sum GB

## Next Steps
1. Review this plan
2. Run `.\DEPLOY.ps1`
3. Monitor progress

## Support
See README.md for troubleshooting
"@
    
    $summary | Set-Content $OutputPath -Encoding UTF8
    Write-Host "✅ Deployment plan saved to $OutputPath"
}
```

---

## 6️⃣ ТЕСТИРОВАНИЕ И ВАЛИДАЦИЯ

### ✅ Создавай unit-тесты для скриптов
```powershell
# tests/unit/Test-ResourceAnalyzer.ps1

Describe "Analyze-Resources" {
    Context "When called with default parameters" {
        It "Should return system information" {
            $result = & .\scripts\analyze-resources.ps1
            
            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain "total_cpu"
            $result.PSObject.Properties.Name | Should -Contain "total_ram"
        }
    }
    
    Context "When system has insufficient resources" {
        It "Should warn for Small profile" {
            Mock Get-SystemResources { return @{ cpu = 2; ram = 4 } }
            
            { & .\scripts\analyze-resources.ps1 } | Should -Throw
        }
    }
}
```

### ✅ Валидируй генерированные конфиги
```powershell
function Test-GeneratedConfigs {
    param(
        [string]$ConfigDir = "config"
    )
    
    $tests = @(
        # .env должен быть валидным
        @{
            name = ".env syntax"
            test = { Test-EnvFileSyntax "$ConfigDir\.env" }
        },
        
        # Terraform vars должны быть валидными
        @{
            name = "terraform validation"
            test = { terraform -chdir=$ConfigDir\.. validate }
        },
        
        # Docker Compose файлы должны быть валидными
        @{
            name = "docker-compose syntax"
            test = { docker-compose -f "$ConfigDir\compose\docker-compose.yml" config }
        },
        
        # Нет CHANGE_ME плейсхолдеров
        @{
            name = "no CHANGE_ME placeholders"
            test = { 
                $content = Get-Content "$ConfigDir\.env" -Raw
                $content | Should -Not -Match "CHANGE_ME"
            }
        }
    )
    
    foreach ($test in $tests) {
        Write-Host "Testing: $($test.name)..." -ForegroundColor Cyan
        try {
            & $test.test
            Write-Host "✅ $($test.name)" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ $($test.name): $_" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}
```

---

## 7️⃣ ИНТЕГРАЦИЯ С СУЩЕСТВУЮЩИМИ СКРИПТАМИ

### ✅ Обнови start.ps1
```powershell
# В начале start.ps1 добавить:

if (-not (Test-Path "config/.env")) {
    Write-Host "⚠️ No .env found. Running configuration wizard..." -ForegroundColor Yellow
    & .\scripts\configure-ceres.ps1
}

# Валидировать перед началом
if (-not (Test-ConfigValidity)) {
    throw "Configuration invalid. Run .\scripts\configure-ceres.ps1"
}

# Дальше как было...
```

### ✅ Обнови DEPLOY.ps1
```powershell
# В начале DEPLOY.ps1 добавить:

# Если не указан профиль, спросить
if (-not $env:DEPLOYMENT_PROFILE) {
    Write-Host "Select deployment profile:" -ForegroundColor Cyan
    $profile = Read-Host "  (small|medium|large)"
    
    & .\scripts\configure-ceres.ps1 -Profile $profile
}

# Использовать сгенерированный terraform vars
$terraformVars = "terraform/environments/$env:DEPLOYMENT_PROFILE.tfvars"
if (Test-Path $terraformVars) {
    Write-Host "Using Terraform vars: $terraformVars"
    terraform apply -var-file=$terraformVars
}
```

---

## 8️⃣ ОБРАБОТКА ОШИБОК И RECOVERY

### ✅ Создавай log файлы
```powershell
function Write-CeresLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # В консоль
    switch ($Level) {
        'INFO'    { Write-Host $logEntry -ForegroundColor Cyan }
        'WARN'    { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # В файл
    $logEntry | Add-Content "logs/ceres-$(Get-Date -Format 'yyyy-MM-dd').log"
}
```

### ✅ Предоставь способ отката
```powershell
# scripts/rollback-config.ps1

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateScript({ Test-Path $_ })]
    [string]$BackupFile
)

Write-CeresLog "Rolling back configuration..." INFO

# Восстановить из backup
Copy-Item $BackupFile "config/.env" -Force
Copy-Item "$BackupFile.tfvars" "terraform/terraform.tfvars" -Force

Write-CeresLog "Configuration rolled back successfully" SUCCESS
Write-Host "Previous configuration restored from: $BackupFile"
```

---

## ✅ SUMMARY: Контрольный список

- [ ] Профили в отдельном JSON файле (не в коде)
- [ ] Каждый скрипт — одна ответственность
- [ ] Валидация конфига перед деплоем
- [ ] Бэкапы перед изменением конфигов
- [ ] Генерируй конфиги, не редактируй вручную
- [ ] Создавай DEPLOYMENT_PLAN.json для отчёта
- [ ] Логируй все действия в файл
- [ ] Тестируй сгенерированные конфиги
- [ ] Обнови интеграцию с start.ps1 и DEPLOY.ps1
- [ ] Документируй лучшие практики в README
