# CERES - Архитектура без конфликтов

**Версия**: 2.0  
**Цель**: Полная автоматизация + воспроизводимость + кроссплатформность  

---

## ⚠️ Все возможные конфликты и как их решить

### 1. ПОРТОВЫЕ КОНФЛИКТЫ

#### Проблема
```
Caddy хочет порт 80/443
Nginx тоже хочет порт 80/443
Mattermost хочет 8065
PostgreSQL хочет 5432
Redis хочет 6379

На машине пользователя может быть что-то уже на этих портах!
```

#### Решение (ПРАВИЛЬНО)
```
# config/.env.example
CADDY_HTTP_PORT=80                # user может изменить на 8080
CADDY_HTTPS_PORT=443              # user может изменить на 8443
MATTERMOST_PORT=8065              # изолировано
POSTGRESQL_PORT=5432              # только внутри Docker сети
REDIS_PORT=6379                   # только внутри Docker сети

# config/compose/base.yml
services:
  caddy:
    ports:
      - "${CADDY_HTTP_PORT}:80"    # ← Использует переменную из .env
      - "${CADDY_HTTPS_PORT}:443"

  mattermost:
    ports:
      - "${MATTERMOST_PORT}:8065"  # ← Использует переменную

  postgresql:
    # ❌ НЕ публикуем порт!
    # Только внутренняя сеть:
    networks:
      - ceres-internal

  redis:
    # ❌ НЕ публикуем порт!
    networks:
      - ceres-internal
```

#### Проверка перед запуском
```powershell
# scripts/validate-ports.ps1
function Test-PortAvailable {
    param([int]$Port)
    
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
        $listener.Start()
        $listener.Stop()
        return $true
    }
    catch {
        return $false
    }
}

# Проверяем только публичные порты
$requiredPorts = @{
    80  = "Caddy HTTP"
    443 = "Caddy HTTPS"
}

foreach ($port in $requiredPorts.Keys) {
    if (-not (Test-PortAvailable -Port $port)) {
        Write-Host "ОШИБКА: Порт $port занят! ($($requiredPorts[$port]))" -ForegroundColor Red
        Write-Host "Решение: Измени CADDY_HTTP_PORT в config/.env"
        exit 1
    }
}
```

---

### 2. КОНФЛИКТЫ ПЕРЕМЕННЫХ ОКРУЖЕНИЯ

#### Проблема
```
Профиль small.json ожидает 1 ВМ
Профиль medium.json ожидает 3 ВМ
Но .env всегда один и тот же!

Если Terraform создал 3 ВМ,
а ты запустил Docker Compose для 1 ВМ
= КОНФЛИКТ
```

#### Решение (ПРАВИЛЬНО)
```
config/
├── .env                    # ❌ НИКОГДА НЕ КОММИТИМ
├── .env.example            # ✅ Шаблон (в Git)
│
├── profiles/
│   ├── small.json          # Профиль для Docker Compose (1 машина)
│   ├── medium.json         # Профиль для Kubernetes (3 машины)
│   └── large.json          # Профиль для HA (5 машин)
│
├── terraform/
│   └── terraform.tfvars    # ❌ НИКОГДА НЕ КОММИТИМ
│       (генерируется из профиля)
│
├── flux/
│   └── flux-values.yaml    # ✅ В Git (генерируется один раз)
│
└── compose/
    └── .env                # ← ДА, для Compose нужен .env
```

#### Как избежать конфликта
```powershell
# scripts/validate-deployment-mode.ps1

function Get-DeploymentMode {
    param([string]$TerraformState)
    
    if (Test-Path "terraform.tfstate") {
        $tfstate = Get-Content terraform.tfstate | ConvertFrom-Json
        $vmCount = ($tfstate.outputs.vm_count.value)
        
        if ($vmCount -eq 1) { return "docker-compose" }
        if ($vmCount -eq 3) { return "kubernetes" }
        if ($vmCount -eq 5) { return "kubernetes-ha" }
    }
    
    return "none"
}

$mode = Get-DeploymentMode

if ($mode -eq "none") {
    Write-Host "Ты выбрал профиль, но не развернул инфраструктуру" -ForegroundColor Yellow
    Write-Host "Запусти: .\DEPLOY.ps1"
}
```

---

### 3. КОНФЛИКТЫ ВЕРСИЙ

#### Проблема
```
Docker образ Nextcloud 28.0 был хорош
Kubernetes обновился до 30.0
Конфиги несовместимы!
```

#### Решение (ПРАВИЛЬНО)
```yaml
# config/flux/flux-releases.yml (версионируется в Git)
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: nextcloud
  namespace: ceres
spec:
  interval: 10m
  
  chart:
    spec:
      chart: nextcloud
      version: "4.5.x"        # ← Pin версию Helm чарта
      
  values:
    image:
      tag: "28.0"             # ← Pin версию приложения
      
    persistence:
      size: 50Gi              # ← Фиксируем размер
      
  # ← ВАЖНО: Никогда не автообновляем!
  postRenderers:
    - kustomize:
        patchesStrategicMerge:
          - apiVersion: v1
            kind: ConfigMap
            metadata:
              name: nextcloud-config
```

#### Как обновлять безопасно
```powershell
# scripts/safe-update.ps1

function Update-Service {
    param(
        [string]$Service,
        [string]$NewVersion,
        [string]$Branch = "update/$Service-$NewVersion"
    )
    
    # 1. Создаём ветку
    git checkout -b $Branch
    
    # 2. Меняем только версию
    $releasesFile = "config/flux/flux-releases.yml"
    (Get-Content $releasesFile) -replace "version: `".*`"", "version: `"$NewVersion`"" | 
        Set-Content $releasesFile
    
    # 3. Коммитим
    git commit -m "Update $Service to $NewVersion"
    git push origin $Branch
    
    # 4. Создаём PR (ручное тестирование!)
    Write-Host "PR создан! Проверь в stage окружении перед мержем"
}
```

---

### 4. КОНФЛИКТЫ СЕТЕВЫХ ИНТЕРФЕЙСОВ

#### Проблема
```
Docker Compose создаёт сеть ceres-network
Kubernetes создаёт сеть calico/flannel
DNS не работает между ними!
```

#### Решение (ПРАВИЛЬНО)
```yaml
# config/compose/base.yml
networks:
  ceres-public:          # Для публичного доступа
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
        
  ceres-internal:        # Для приватных сервисов
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/16

# Каждый сервис указывает свою сеть
services:
  caddy:
    networks:
      - ceres-public       # Это публичный, нужен доступ

  postgresql:
    networks:
      - ceres-internal     # Это приватный, скрыт

  nextcloud:
    networks:
      - ceres-public       # Клиенты подключаются
      - ceres-internal     # БД подключается
```

---

### 5. КОНФЛИКТЫ ХРАНИЛИЩА

#### Проблема
```
Volume pg_data находится где?
В разных местах на разных машинах?
Данные потеряны при миграции!
```

#### Решение (ПРАВИЛЬНО)
```yaml
# config/compose/core.yml
volumes:
  pg_data:
    driver: local
    driver_opts:
      # ← СТАНДАРТНАЯ ПАПКА, одна на всех машинах
      o: bind
      type: none
      device: /data/volumes/postgresql  # Linux/Mac
      # или: C:\ceres-data\postgresql    # Windows
  
  redis_data:
    driver: local
    driver_opts:
      device: /data/volumes/redis

# Автоматическое создание папок
$volumePaths = @(
    "/data/volumes/postgresql",
    "/data/volumes/redis",
    "/data/volumes/nextcloud"
)

foreach ($path in $volumePaths) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force
        Write-Host "✓ Создана папка: $path"
    }
}
```

#### Для Kubernetes
```yaml
# config/flux/pvc.yaml (постоянные тома)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pg-pvc
  namespace: ceres
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: local-path  # ← Используем локальное хранилище
```

---

### 6. КОНФЛИКТЫ СЕКРЕТОВ

#### Проблема
```
POSTGRES_PASSWORD хранится в .env (открыто!)
Кто-то коммитнул в Git!
Взломали базу!
```

#### Решение (ПРАВИЛЬНО)
```powershell
# scripts/generate-secrets.ps1

function Generate-SecureSecret {
    param([int]$Length = 32)
    
    $chars = [char[]]"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $bytes = [byte[]]::new($Length)
    $rng.GetBytes($bytes)
    
    $secret = ""
    foreach ($byte in $bytes) {
        $secret += $chars[$byte % $chars.Count]
    }
    return $secret
}

# config/.env
POSTGRES_PASSWORD=$(Generate-SecureSecret)          # ← Генерируем
KEYCLOAK_ADMIN_PASSWORD=$(Generate-SecureSecret)
GRAFANA_ADMIN_PASSWORD=$(Generate-SecureSecret)

# .gitignore
config/.env              # ← НИКОГДА НЕ КОММИТИМ
secrets/                 # ← Все секреты здесь
*.tfvars                 # ← Terraform секреты

# Для Kubernetes (Sealed Secrets)
kubectl create secret generic db-secret \
  --from-literal=password=$POSTGRES_PASSWORD \
  --dry-run=client -o yaml | \
  kubeseal -f - > config/sealed-secrets/db-secret.yaml
```

---

### 7. КОНФЛИКТЫ КРОССПЛАТФОРМНОСТИ

#### Проблема
```
#!/bin/bash работает на Linux
powershell работает на Windows
На Mac - проблемы с обоими!
```

#### Решение (ПРАВИЛЬНО)
```powershell
# scripts/_lib/Platform.ps1 (единый интерфейс)

function Get-OSType {
    if ($PSVersionTable.OS -like "*Windows*") { return "windows" }
    if ($PSVersionTable.OS -like "*Linux*") { return "linux" }
    if ($PSVersionTable.OS -like "*Darwin*") { return "macos" }
}

function Test-CommandExists {
    param([string]$Command)
    
    try {
        if (Get-Command $Command -ErrorAction Stop) { return $true }
    }
    catch { return $false }
}

function Invoke-OSSpecific {
    param(
        [scriptblock]$Windows,
        [scriptblock]$Linux,
        [scriptblock]$Mac
    )
    
    $os = Get-OSType
    
    if ($os -eq "windows" -and $Windows) { & $Windows }
    elseif ($os -eq "linux" -and $Linux) { & $Linux }
    elseif ($os -eq "macos" -and $Mac) { & $Mac }
}

# Использование:
Invoke-OSSpecific `
    -Windows { Start-Process "C:\Program Files\Docker\Docker\Docker.exe" } `
    -Linux { Invoke-Expression "systemctl start docker" } `
    -Mac { Invoke-Expression "open /Applications/Docker.app" }
```

---

## ✅ АРХИТЕКТУРА БЕЗ КОНФЛИКТОВ

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  PHASE 1 MVP: Анализ ресурсов + выбор профиля        │
│  ├─ analyze-resources.ps1                             │
│  ├─ configure-ceres.ps1                               │
│  └─ DEPLOYMENT_PLAN.json                              │
│                                                         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ PHASE 2: Валидация + конфигурация без конфликтов       │
│                                                         │
│ 1. Проверяем окружение (OS, Docker, K8s, Terraform)   │
│    └─ validate-environment.ps1                         │
│                                                         │
│ 2. Проверяем потенциальные конфликты                  │
│    └─ validate-conflicts.ps1                           │
│       ├─ Порты                                         │
│       ├─ Переменные окружения                          │
│       ├─ Сеть                                          │
│       ├─ Хранилище                                     │
│       └─ Секреты                                       │
│                                                         │
│ 3. Генерируем конфиги из профиля                      │
│    └─ generate-from-profile.ps1                        │
│       ├─ terraform.tfvars (из small/medium/large)     │
│       ├─ .env (с безопасными секретами)               │
│       ├─ compose/.env                                  │
│       └─ flux-values.yaml                              │
│                                                         │
│ 4. Готовим инфраструктуру (Terraform)                │
│    └─ infrastructure/setup.ps1                         │
│       ├─ Создаёт ВМ на Proxmox                        │
│       ├─ Настраивает сеть                              │
│       └─ Выполняет health check                        │
│                                                         │
│ 5. Конфигурируем ОС (Ansible)                         │
│    └─ os-setup.ps1                                     │
│       ├─ Устанавливает Docker                          │
│       ├─ Устанавливает k3s                             │
│       └─ Настраивает firewall                          │
│                                                         │
│ 6. Развёртываем приложения (Kubernetes/Docker)        │
│    └─ deploy-applications.ps1                          │
│       ├─ Для Docker Compose: docker-compose up        │
│       ├─ Для Kubernetes: FluxCD синхронизирует        │
│       └─ Проверяем health всех подов                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Чеклист - ЧТО ДОЛЖНО БЫТЬ

### Phase 2 - Обязательные скрипты

```
scripts/
├── validate/
│   ├── environment.ps1           # Проверяем: OS, Docker, K8s
│   ├── conflicts.ps1             # Проверяем: порты, переменные, сеть
│   └── health.ps1                # Проверяем: all services running
│
├── generate/
│   ├── from-profile.ps1          # Generate terraform.tfvars, .env
│   ├── terraform-config.ps1      # Generate Terraform конфиг
│   ├── docker-compose.ps1        # Generate docker-compose.yml
│   └── secrets.ps1               # Generate безопасные секреты
│
├── deploy/
│   ├── infrastructure.ps1        # Terraform apply
│   ├── os-configuration.ps1      # Ansible playbooks
│   ├── applications.ps1          # Docker или Kubernetes
│   └── post-deploy.ps1           # Setup, health check
│
└── _lib/
    ├── Platform.ps1              # OS detection
    ├── Validation.ps1            # Common validations
    ├── Logging.ps1               # Logging functions
    ├── Secrets.ps1               # Secure secret handling
    └── Docker.ps1                # Docker helpers
```

### Конфиги которые должны быть

```
config/
├── .env.example                  # Template (в Git) ✅
├── templates/
│   ├── terraform.tfvars.tpl      # Template для Terraform
│   ├── docker-compose.yml.tpl    # Template для Compose
│   ├── flux-values.yaml.tpl      # Template для Kubernetes
│   └── .env.tpl                  # Template для .env
│
├── validation/
│   ├── port-conflicts.json       # Какие порты проверять
│   ├── environment-vars.json     # Какие переменные нужны
│   └── requirements.json         # CPU, RAM, disk требования
│
└── security/
    ├── .gitignore                # Что не коммитить
    └── sealed-secrets/           # Kubernetes sealed secrets
```

---

## 🚀 Порядок выполнения Phase 2

```
1. Создать scripts/validate/ (проверка конфликтов)
   ├─ Работает на любой машине
   ├─ Не требует интернета
   └─ Быстро находит проблемы

2. Создать scripts/generate/ (генерация конфигов)
   ├─ Использует DEPLOYMENT_PLAN.json из Phase 1
   ├─ Генерирует все конфиги
   └─ Сохраняет их в правильные места

3. Создать scripts/deploy/ (развёртывание)
   ├─ Terraform
   ├─ Ansible
   └─ Kubernetes/Docker

4. Создать интеграционный скрипт DEPLOY.ps1
   ├─ Вызывает все скрипты в правильном порядке
   ├─ Откатывает на ошибку
   └─ Показывает прогресс
```

---

## 🔒 Безопасность - ПРАВИЛЬНО

```powershell
# ✅ ПРАВИЛЬНО:
.env                        # Локально (не в Git)
secrets/                    # Локально (не в Git)
.gitignore:
  config/.env
  secrets/
  *.tfvars

# Для Git:
config/.env.example         # Template (публичный)
config/sealed-secrets/      # Kubernetes secrets (шифрованные)
config/flux/                # Конфиги (публичные)

# ❌ НЕПРАВИЛЬНО:
git commit config/.env      # Секреты в истории!
git commit terraform.tfvars # Пароли БД открыто!
echo password123 | base64   # base64 это не шифрование!
```

---

## 📊 Как избежать конфликтов - ИТОГ

| Конфликт | Решение |
|----------|---------|
| Порты | Переменные в .env (CADDY_HTTP_PORT) |
| Переменные окружения | Разные .env для разных режимов |
| Версии | Pin версии в flux-releases.yml (Git) |
| Сеть | Несколько Docker сетей (public/internal) |
| Хранилище | Одна папка /data/volumes/ везде |
| Секреты | Не коммитим .env, используем sealed-secrets |
| Кроссплатформность | Platform.ps1 (OS detection) |

---

**ИТОГО**: Правильная архитектура = NO CONFLICTS на любой машине ✅
