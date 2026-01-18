# PHASE 2 - Детальный план реализации

**Статус**: Подробный план для правильной реализации  
**Срок**: 3-4 недели (при 8-10 часов в день)  
**Цель**: Полная автоматизация без конфликтов, работает везде  

---

## 📋 Week 1: Фундамент (Валидация + Генерация)

### День 1-2: scripts/validate/environment.ps1

**Что проверяем:**
```powershell
✓ ОС (Windows/Linux/MacOS)
✓ PowerShell версия (5.1+)
✓ Docker установлен и работает
✓ Docker Compose версия (2.0+)
✓ Terraform установлен (если нужен)
✓ Kubernetes (kubectl, если k3s)
✓ Интернет соединение
✓ Права доступа (нужны ли sudo?)
```

**Пример функции:**
```powershell
function Test-DockerInstalled {
    try {
        $version = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) { return $false }
        return $true
    }
    catch { return $false }
}

function Test-DockerRunning {
    try {
        docker ps >$null 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch { return $false }
}

# Использование:
if (-not (Test-DockerInstalled)) {
    Write-Host "❌ Docker не установлен" -ForegroundColor Red
    Write-Host "Установи: https://www.docker.com/products/docker-desktop"
    exit 1
}

if (-not (Test-DockerRunning)) {
    Write-Host "⚠️  Docker не запущен" -ForegroundColor Yellow
    Write-Host "Запусти Docker Desktop"
    exit 1
}
```

### День 2-3: scripts/validate/conflicts.ps1

**Что проверяем:**
```powershell
✓ Занятые порты (80, 443, 8080, 5432, 6379)
✓ Переменные окружения (конфликты)
✓ Папки (права на /data, /etc)
✓ Сетевые интерфейсы (может ли Docker создать сеть?)
✓ Хранилище (свободное место на диске)
✓ Совместимость профиля с ресурсами
```

**Пример:**
```powershell
function Test-PortAvailable {
    param([int]$Port, [string]$Service)
    
    # Windows
    if ($PSVersionTable.OS -like "*Windows*") {
        $netstat = netstat -ano | Select-String ":$Port "
        if ($netstat) {
            Write-Host "❌ Порт $Port занят (используется $Service)" -ForegroundColor Red
            return $false
        }
    }
    # Linux
    else {
        $lsof = sudo lsof -i :$Port 2>/dev/null
        if ($lsof) {
            return $false
        }
    }
    return $true
}

# Проверяем только публичные порты
$publicPorts = @{
    80   = "Caddy HTTP"
    443  = "Caddy HTTPS"
    8080 = "Caddy альт"
}

foreach ($port in $publicPorts.Keys) {
    if (-not (Test-PortAvailable -Port $port -Service $publicPorts[$port])) {
        Write-Host "Решение: Измени CADDY_HTTP_PORT в config/.env" -ForegroundColor Yellow
    }
}
```

### День 3-4: scripts/validate/health.ps1

**Что проверяем после развёртывания:**
```powershell
✓ Docker контейнеры запущены
✓ Kubernetes pods в Running состоянии
✓ Все сервисы отвечают (curl к endpoints)
✓ БД доступна (тест подключения)
✓ Loggen работает правильно
```

### День 4-5: scripts/generate/from-profile.ps1

**Вход**: DEPLOYMENT_PLAN.json (из Phase 1)  
**Выход**: Все конфиги (terraform.tfvars, .env, docker-compose.yml)

```powershell
function Generate-ConfigsFromProfile {
    param([string]$DeploymentPlanPath)
    
    $plan = Get-Content $DeploymentPlanPath | ConvertFrom-Json
    $profile = $plan.details
    
    # 1. Генерируем terraform.tfvars
    Generate-TerraformVars -Profile $profile
    
    # 2. Генерируем .env
    Generate-EnvFile -Profile $profile
    
    # 3. Генерируем docker-compose.yml (если Docker режим)
    if ($profile.deployment.type -eq "docker-compose") {
        Generate-DockerCompose -Profile $profile
    }
    
    # 4. Генерируем flux-values.yaml (если K8s режим)
    if ($profile.deployment.type -like "*kubernetes*") {
        Generate-FluxValues -Profile $profile
    }
    
    Write-Host "✅ Все конфиги сгенерированы" -ForegroundColor Green
}
```

---

## 📋 Week 2: Генерация конфигов

### День 5-7: scripts/generate/terraform-config.ps1

**Генерирует**: terraform.tfvars из профиля

```hcl
# Генерируемый terraform.tfvars
proxmox_node = "proxmox-1"
vm_count = 3

vms = [
  {
    name   = "ceres-core"
    cpu    = 4
    memory = 8192
    disk   = 50
  },
  {
    name   = "ceres-apps"
    cpu    = 6
    memory = 12288
    disk   = 80
  },
  {
    name   = "ceres-edge"
    cpu    = 4
    memory = 8192
    disk   = 40
  }
]

# ← ВАЖНО: Все из profile JSON, БЕЗ ручного редактирования
```

### День 7-9: scripts/generate/docker-compose.ps1

**Генерирует**: docker-compose.yml с правильными ресурсами

```yaml
# Из profile:
version: '3.9'

services:
  postgresql:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    deploy:
      resources:
        limits:
          cpus: '${POSTGRESQL_CPU}'      # Из profile
          memory: ${POSTGRESQL_MEMORY}   # Из profile
        reservations:
          memory: ${POSTGRESQL_MEMORY_RESERVE}
    networks:
      - ceres-internal
    # ← НЕ публикуем порт!

  nextcloud:
    image: nextcloud:28
    deploy:
      resources:
        limits:
          cpus: '${NEXTCLOUD_CPU}'
          memory: ${NEXTCLOUD_MEMORY}
    networks:
      - ceres-public
      - ceres-internal

networks:
  ceres-public:
    driver: bridge
  ceres-internal:
    driver: bridge
```

### День 9-10: scripts/generate/secrets.ps1

**Генерирует**: Безопасные секреты в .env

```powershell
function Generate-SecurePassword {
    param([int]$Length = 32)
    
    $charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = [byte[]]::new($Length)
    $rng.GetBytes($bytes)
    
    $result = ""
    foreach ($byte in $bytes) {
        $result += $charset[$byte % $charset.Length]
    }
    return $result
}

# Генерируем .env с секретами
@"
# Пароли (ГЕНЕРИРУЮТСЯ АВТОМАТИЧЕСКИ)
POSTGRES_PASSWORD=$(Generate-SecurePassword)
KEYCLOAK_ADMIN_PASSWORD=$(Generate-SecurePassword)
GRAFANA_ADMIN_PASSWORD=$(Generate-SecurePassword)
MATTERMOST_SQL_PASSWORD=$(Generate-SecurePassword)

# Ключи (ГЕНЕРИРУЮТСЯ АВТОМАТИЧЕСКИ)
NEXTCLOUD_SECRET_KEY=$(Generate-SecurePassword 64)
GRAFANA_SECRET_KEY=$(Generate-SecurePassword 32)

# Из профиля
DEPLOYMENT_MODE=$(if ($profile.deployment.type -eq 'docker-compose') { 'compose' } else { 'kubernetes' })
PROFILE_NAME=$($profile.name)
PROFILE_VERSION=$($profile.version)
"@ | Out-File config/.env -Encoding UTF8

Write-Host "✅ Секреты сгенерированы (config/.env)" -ForegroundColor Green
Write-Host "⚠️  ВНИМАНИЕ: .env в .gitignore! Не коммитить!" -ForegroundColor Yellow
```

---

## 📋 Week 3: Развёртывание инфраструктуры

### День 10-12: scripts/deploy/infrastructure.ps1

**Что делает:**
```powershell
1. Проверяет конфликты (validate/conflicts.ps1)
2. Проверяет окружение (validate/environment.ps1)
3. Генерирует конфиги (generate/from-profile.ps1)
4. Запускает Terraform (terraform apply)
5. Сохраняет состояние (terraform.tfstate)
6. Экспортирует информацию о ВМ (IP адреса, etc)
```

```powershell
function Deploy-Infrastructure {
    Write-Host "=== Развёртывание инфраструктуры ===" -ForegroundColor Cyan
    
    # 1. Валидация
    Write-Host "Проверка конфликтов..." -ForegroundColor Yellow
    & .\scripts\validate\conflicts.ps1
    if ($LASTEXITCODE -ne 0) { exit 1 }
    
    # 2. Генерация
    Write-Host "Генерация конфигов..." -ForegroundColor Yellow
    & .\scripts\generate\from-profile.ps1 -DeploymentPlan DEPLOYMENT_PLAN.json
    if ($LASTEXITCODE -ne 0) { exit 1 }
    
    # 3. Terraform
    Write-Host "Создание ВМ на Proxmox..." -ForegroundColor Yellow
    terraform -chdir=config/terraform init
    terraform -chdir=config/terraform apply -auto-approve
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform failed" -ForegroundColor Red
        Write-Host "Откат: terraform destroy -auto-approve" -ForegroundColor Yellow
        exit 1
    }
    
    # 4. Сохраняем информацию
    $tfOutput = terraform -chdir=config/terraform output -json | ConvertFrom-Json
    $tfOutput | ConvertTo-Json | Out-File deployment-info.json
    
    Write-Host "✅ Инфраструктура создана" -ForegroundColor Green
    Write-Host "IP адреса сохранены в deployment-info.json"
}
```

### День 12-14: scripts/deploy/os-configuration.ps1

**Что делает:**
```powershell
1. Получает IP адреса из deployment-info.json
2. Запускает Ansible playbooks
3. Ждёт пока ВМ загрузятся
4. Устанавливает Docker на все ВМ
5. Устанавливает k3s на ВМ
6. Настраивает firewall
7. Проверяет доступность
```

```powershell
function Configure-OS {
    Write-Host "=== Конфигурация операционных систем ===" -ForegroundColor Cyan
    
    # Получаем IP адреса из Terraform
    $deployment = Get-Content deployment-info.json | ConvertFrom-Json
    $vmIPs = $deployment.vm_ips.value
    
    # Ждём пока ВМ загрузятся
    Write-Host "Ожидание загрузки ВМ..." -ForegroundColor Yellow
    foreach ($ip in $vmIPs) {
        Wait-ForVMBoot -IP $ip -Timeout 600
    }
    
    # Запускаем Ansible
    Write-Host "Конфигурирование ОС..." -ForegroundColor Yellow
    
    $inventory = @"
[all]
ceres_core   ansible_host=$($vmIPs[0])
ceres_apps   ansible_host=$($vmIPs[1])
ceres_edge   ansible_host=$($vmIPs[2])

[all:vars]
ansible_user=root
ansible_password=$env:VM_PASSWORD
ansible_connection=ssh
"@
    
    $inventory | Out-File config/ansible/inventory.ini
    
    # Запускаем playbook
    ansible-playbook `
        -i config/ansible/inventory.ini `
        config/ansible/site.yml
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Ansible failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ ОС сконфигурирована" -ForegroundColor Green
}
```

---

## 📋 Week 4: Развёртывание приложений

### День 14-17: scripts/deploy/applications.ps1

**Для Docker Compose режима:**
```powershell
function Deploy-Applications-Docker {
    Write-Host "=== Развёртывание приложений (Docker Compose) ===" -ForegroundColor Cyan
    
    # 1. Проверяем здоровье Docker
    & .\scripts\validate\environment.ps1
    
    # 2. Создаём тома
    Create-DataVolumes
    
    # 3. Запускаем compose
    Write-Host "Запуск контейнеров..." -ForegroundColor Yellow
    docker-compose `
        -f config/compose/base.yml `
        -f config/compose/core.yml `
        -f config/compose/apps.yml `
        --env-file config/.env `
        up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker Compose failed" -ForegroundColor Red
        exit 1
    }
    
    # 4. Проверяем здоровье
    Write-Host "Проверка здоровья сервисов..." -ForegroundColor Yellow
    & .\scripts\validate\health.ps1
}
```

**Для Kubernetes режима:**
```powershell
function Deploy-Applications-Kubernetes {
    Write-Host "=== Развёртывание приложений (Kubernetes) ===" -ForegroundColor Cyan
    
    # 1. Инициализируем Flux
    Write-Host "Инициализация FluxCD..." -ForegroundColor Yellow
    flux bootstrap github `
        --owner=$env:GITHUB_USER `
        --repository=Ceres `
        --branch=main `
        --path=./flux/clusters/production `
        --personal
    
    # 2. Создаём namespace
    kubectl create namespace ceres
    
    # 3. Создаём sealed secrets
    kubectl apply -f config/sealed-secrets/db-secret.yaml
    kubectl apply -f config/sealed-secrets/app-secret.yaml
    
    # 4. Flux синхронизирует все остальное
    Write-Host "FluxCD синхронизирует приложения..." -ForegroundColor Yellow
    flux reconcile kustomization flux-system --with-source
    
    # 5. Ждём развёртывания
    Write-Host "Ожидание развёртывания всех подов..." -ForegroundColor Yellow
    kubectl -n ceres wait --for=condition=ready pod --all --timeout=600s
    
    # 6. Проверяем здоровье
    & .\scripts\validate\health.ps1
}
```

### День 17-18: scripts/deploy/post-deploy.ps1

**Что делает после развёртывания:**
```powershell
function Post-Deploy {
    Write-Host "=== Post-Deployment Setup ===" -ForegroundColor Cyan
    
    # 1. Инициализируем Keycloak
    Write-Host "Инициализация Keycloak..." -ForegroundColor Yellow
    & .\scripts\keycloak-bootstrap.ps1
    
    # 2. Создаём первого пользователя
    Write-Host "Создание администратора..." -ForegroundColor Yellow
    
    # 3. Настраиваем SSL сертификаты
    Write-Host "Настройка SSL..." -ForegroundColor Yellow
    
    # 4. Проверяем все компоненты
    Write-Host "Финальная проверка..." -ForegroundColor Yellow
    & .\scripts\validate\health.ps1
    
    # 5. Выводим информацию доступа
    Write-Host ""
    Write-Host "✅ РАЗВЁРТЫВАНИЕ ЗАВЕРШЕНО!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Адреса доступа:" -ForegroundColor Cyan
    Write-Host "  Auth:     https://auth.$($env:DOMAIN)"
    Write-Host "  Nextcloud: https://nextcloud.$($env:DOMAIN)"
    Write-Host "  Gitea:    https://gitea.$($env:DOMAIN)"
    Write-Host "  Grafana:  https://grafana.$($env:DOMAIN)"
    Write-Host ""
}
```

---

## 🔧 Интеграционный скрипт: DEPLOY.ps1

```powershell
#!/usr/bin/env powershell

# Главный скрипт развёртывания CERES

param(
    [ValidateSet("validate", "generate", "deploy", "all")]
    [string]$Step = "all",
    
    [switch]$DryRun,
    [switch]$Rollback
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Импортируем функции
. .\scripts\_lib\Logging.ps1
. .\scripts\_lib\Platform.ps1
. .\scripts\_lib\Validation.ps1

function Main {
    Write-Header "CERES Deployment"
    
    if ($Rollback) {
        Invoke-Rollback
        return
    }
    
    if ($Step -in @("validate", "all")) {
        Write-Step "Validation"
        & .\scripts\validate\environment.ps1
        & .\scripts\validate\conflicts.ps1
    }
    
    if ($Step -in @("generate", "all")) {
        Write-Step "Configuration Generation"
        & .\scripts\generate\from-profile.ps1
    }
    
    if ($Step -in @("deploy", "all")) {
        Write-Step "Infrastructure Deployment"
        & .\scripts\deploy\infrastructure.ps1
        
        Write-Step "OS Configuration"
        & .\scripts\deploy\os-configuration.ps1
        
        Write-Step "Application Deployment"
        & .\scripts\deploy\applications.ps1
        
        Write-Step "Post-Deploy Setup"
        & .\scripts\deploy\post-deploy.ps1
    }
    
    Write-Success "All steps completed!"
}

try {
    Main
}
catch {
    Write-Error "Deployment failed: $_"
    Write-Host ""
    Write-Host "Для отката запусти:" -ForegroundColor Yellow
    Write-Host "  .\DEPLOY.ps1 -Rollback" -ForegroundColor Yellow
    exit 1
}
```

---

## 📊 График реализации

```
Week 1: Валидация (10 часов)
  День 1-2: Проверка окружения (4ч)
  День 3-4: Проверка конфликтов (3ч)
  День 4-5: Health checks (3ч)

Week 2: Генерация (12 часов)
  День 5-7: Terraform конфиги (4ч)
  День 7-9: Docker Compose (4ч)
  День 9-10: Секреты (4ч)

Week 3: Инфраструктура (10 часов)
  День 10-12: Terraform deploy (5ч)
  День 12-14: Ansible config (5ч)

Week 4: Приложения (10 часов)
  День 14-17: App deploy (6ч)
  День 17-18: Post-deploy (4ч)

ИТОГО: ~42 часа (при 10-12 часов в день = 4-5 дней интенсивной работы)
```

---

## ✅ Финальный чеклист

```
[ ] Week 1: Все валидации работают
[ ] Week 2: Конфиги генерируются правильно
[ ] Week 3: Terraform создаёт ВМ, Ansible конфигурирует
[ ] Week 4: Приложения развёртываются
[ ] Тестирование на разных ОС (Windows, Linux, MacOS)
[ ] Документация полна
[ ] Откат работает (--rollback)
[ ] Вторая развёртка с нуля работает идеально
[ ] PRODUCTION READY 🚀
```

---

**РЕЗУЛЬТАТ**: Полная автоматизация, работает на любой машине, БЕЗ конфликтов! ✅
