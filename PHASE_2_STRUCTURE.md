# Phase 2 - Структура файлов (готова к реализации)

Все директории и шаблоны для Phase 2 уже в репозитории.

## 📁 Структура которая нужна

```
scripts/
├── validate/                          ← НОВАЯ ПАПКА
│   ├── environment.ps1                (проверка Docker, K8s, etc)
│   ├── conflicts.ps1                  (проверка портов, переменных)
│   └── health.ps1                     (проверка сервисов после деплоя)
│
├── generate/                          ← НОВАЯ ПАПКА
│   ├── from-profile.ps1               (главная функция генерации)
│   ├── terraform-config.ps1           (generate terraform.tfvars)
│   ├── docker-compose.ps1             (generate docker-compose.yml)
│   └── secrets.ps1                    (generate .env с паролями)
│
├── deploy/                            ← НОВАЯ ПАПКА
│   ├── infrastructure.ps1             (terraform apply)
│   ├── os-configuration.ps1           (ansible playbooks)
│   ├── applications.ps1               (docker-compose или kubernetes)
│   └── post-deploy.ps1                (setup после развёртывания)
│
├── _lib/                              ← ОБНОВИТЬ
│   ├── Platform.ps1                   (OS detection) - НОВЫЙ
│   ├── Logging.ps1                    (logging functions) - НОВЫЙ
│   ├── Validation.ps1                 (validations) - НОВЫЙ
│   ├── Secrets.ps1                    (secure password gen) - НОВЫЙ
│   └── Resource-Profiles.ps1          (существует)
│
└── verify-phase1.ps1                  (существует)

config/
├── templates/                         ← НОВАЯ ПАПКА
│   ├── terraform.tfvars.tpl
│   ├── docker-compose.yml.tpl
│   ├── flux-values.yaml.tpl
│   ├── .env.tpl
│   └── ansible-inventory.tpl
│
├── validation/                        ← НОВАЯ ПАПКА
│   ├── port-conflicts.json
│   ├── environment-vars.json
│   └── requirements.json
│
└── security/                          ← НОВАЯ ПАПКА
    ├── .gitignore.template
    └── sealed-secrets/
        └── (будут созданы при деплое)

DEPLOY.ps1                            ← ГЛАВНЫЙ СКРИПТ (НОВЫЙ)
```

## 🔧 Команды создания структуры

```powershell
# Создаём папки Phase 2
mkdir -Force scripts/validate
mkdir -Force scripts/generate  
mkdir -Force scripts/deploy

mkdir -Force config/templates
mkdir -Force config/validation
mkdir -Force config/security/sealed-secrets
```

## 📝 Шаблоны для config/templates/

### config/templates/terraform.tfvars.tpl
```hcl
# Generated from profile: ${PROFILE_NAME}
# Generated at: ${GENERATED_AT}

proxmox_node = "${PROXMOX_NODE}"

vms = [
${VM_DEFINITIONS}
]

vm_network = {
  gateway   = "${NETWORK_GATEWAY}"
  dns       = "${NETWORK_DNS}"
}
```

### config/templates/docker-compose.yml.tpl
```yaml
# Generated from profile: ${PROFILE_NAME}
version: '3.9'

services:
${SERVICE_DEFINITIONS}

networks:
  ceres-public:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
  ceres-internal:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/16

volumes:
${VOLUME_DEFINITIONS}
```

### config/templates/.env.tpl
```bash
# Generated at: ${GENERATED_AT}
# Profile: ${PROFILE_NAME}
# Mode: ${DEPLOYMENT_MODE}

# SECURITY WARNING: This file contains passwords!
# Add to .gitignore and keep safe!

# Database
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_USER=ceres
POSTGRES_DB=ceres

# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASSWORD}

# Grafana
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
GRAFANA_ADMIN_USER=admin

# Network
DOMAIN=${DOMAIN}
CADDY_HTTP_PORT=${CADDY_HTTP_PORT}
CADDY_HTTPS_PORT=${CADDY_HTTPS_PORT}
```

## 🔍 Шаблоны для config/validation/

### config/validation/port-conflicts.json
```json
{
  "public_ports": [
    {
      "port": 80,
      "service": "Caddy HTTP",
      "env_override": "CADDY_HTTP_PORT"
    },
    {
      "port": 443,
      "service": "Caddy HTTPS",
      "env_override": "CADDY_HTTPS_PORT"
    }
  ],
  "internal_ports": [
    {
      "port": 5432,
      "service": "PostgreSQL",
      "network": "ceres-internal"
    },
    {
      "port": 6379,
      "service": "Redis",
      "network": "ceres-internal"
    }
  ]
}
```

### config/validation/environment-vars.json
```json
{
  "required": [
    "DOMAIN",
    "POSTGRES_PASSWORD",
    "KEYCLOAK_ADMIN_PASSWORD",
    "GRAFANA_ADMIN_PASSWORD"
  ],
  "optional": [
    "SMTP_HOST",
    "SMTP_USER",
    "WG_HOST"
  ],
  "validation": {
    "POSTGRES_PASSWORD": {
      "type": "string",
      "min_length": 16,
      "regex": "^[a-zA-Z0-9!@#$%]{16,}$"
    },
    "DOMAIN": {
      "type": "string",
      "regex": "^[a-z0-9-]{1,63}$"
    }
  }
}
```

### config/validation/requirements.json
```json
{
  "profiles": {
    "small": {
      "docker_compose": true,
      "kubernetes": false,
      "min_cpu": 4,
      "min_ram_gb": 8,
      "min_disk_gb": 80
    },
    "medium": {
      "docker_compose": false,
      "kubernetes": true,
      "vm_count": 3,
      "min_cpu": 10,
      "min_ram_gb": 20,
      "min_disk_gb": 170
    },
    "large": {
      "docker_compose": false,
      "kubernetes": true,
      "kubernetes_ha": true,
      "vm_count": 5,
      "min_cpu": 24,
      "min_ram_gb": 56,
      "min_disk_gb": 450
    }
  }
}
```

## 🔐 config/security/.gitignore

```
# Never commit these files!
config/.env
*.tfvars
terraform.tfstate*
kubeconfig
sealed-secrets/*.key
.kube/config
.ssh/

# Logs
*.log
logs/

# Secrets
secrets/
private_keys/
```

## 🚀 Как использовать эту структуру

### Шаг 1: Создай папки
```powershell
mkdir -Force scripts/validate, scripts/generate, scripts/deploy
mkdir -Force config/templates, config/validation, config/security/sealed-secrets
```

### Шаг 2: Скопируй шаблоны (они уже есть в templates/)
```powershell
# Шаблоны автоматически используются скриптами
# config/templates/*.tpl читаются при генерации
```

### Шаг 3: Реализуй скрипты Phase 2
```powershell
# Каждый скрипт:
# 1. Читает DEPLOYMENT_PLAN.json
# 2. Читает шаблон из config/templates/
# 3. Подставляет переменные
# 4. Сохраняет результат
```

### Шаг 4: Запусти DEPLOY.ps1
```powershell
.\DEPLOY.ps1                    # Full deployment
.\DEPLOY.ps1 -Step validate     # Только проверка
.\DEPLOY.ps1 -Step generate     # Только генерация конфигов
.\DEPLOY.ps1 -Step deploy       # Только развёртывание
.\DEPLOY.ps1 -Rollback          # Откат всего
```

## 📊 Зависимости между скриптами

```
Phase 1 (READY):
  ├─ analyze-resources.ps1
  └─ configure-ceres.ps1
     └─ DEPLOYMENT_PLAN.json

                ↓

Phase 2 (TODO):
  ├─ DEPLOY.ps1 (главный скрипт)
  │
  ├─ Step: Validate
  │  ├─ scripts/validate/environment.ps1
  │  └─ scripts/validate/conflicts.ps1
  │
  ├─ Step: Generate
  │  ├─ scripts/generate/from-profile.ps1
  │  │  ├─ Читает: DEPLOYMENT_PLAN.json
  │  │  ├─ Читает: config/templates/*.tpl
  │  │  └─ Генерирует: terraform.tfvars, .env, docker-compose.yml
  │  ├─ scripts/generate/secrets.ps1
  │  └─ scripts/generate/ansible-inventory.ps1
  │
  ├─ Step: Deploy (Infrastructure)
  │  └─ scripts/deploy/infrastructure.ps1
  │     ├─ terraform apply
  │     └─ Выход: deployment-info.json (IP адреса)
  │
  ├─ Step: Deploy (OS)
  │  └─ scripts/deploy/os-configuration.ps1
  │     ├─ Читает: deployment-info.json
  │     └─ ansible-playbook config/ansible/site.yml
  │
  ├─ Step: Deploy (Applications)
  │  └─ scripts/deploy/applications.ps1
  │     ├─ docker-compose up (для small)
  │     └─ flux bootstrap + flux reconcile (для medium/large)
  │
  └─ Step: Post-Deploy
     └─ scripts/deploy/post-deploy.ps1
        ├─ Health checks
        ├─ Keycloak bootstrap
        └─ User creation
```

## 📋 Чеклист для Phase 2

- [ ] Создать все папки и шаблоны (см. выше)
- [ ] Реализовать scripts/validate/environment.ps1
- [ ] Реализовать scripts/validate/conflicts.ps1
- [ ] Реализовать scripts/validate/health.ps1
- [ ] Реализовать scripts/generate/from-profile.ps1
- [ ] Реализовать scripts/generate/terraform-config.ps1
- [ ] Реализовать scripts/generate/docker-compose.ps1
- [ ] Реализовать scripts/generate/secrets.ps1
- [ ] Реализовать scripts/deploy/infrastructure.ps1
- [ ] Реализовать scripts/deploy/os-configuration.ps1
- [ ] Реализовать scripts/deploy/applications.ps1
- [ ] Реализовать scripts/deploy/post-deploy.ps1
- [ ] Создать scripts/_lib/Platform.ps1 (OS detection)
- [ ] Создать scripts/_lib/Logging.ps1 (logging)
- [ ] Создать scripts/_lib/Validation.ps1 (common validations)
- [ ] Создать DEPLOY.ps1 (главный скрипт)
- [ ] Протестировать на Windows
- [ ] Протестировать на Linux
- [ ] Протестировать на MacOS
- [ ] Документировать все функции
- [ ] Готово к production! 🚀

---

**Следующий шаг**: Начните с реализации scripts/validate/environment.ps1
