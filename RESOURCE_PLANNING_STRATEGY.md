# CERES — Стратегия анализа ресурсов и конфигурации

## 📋 ПЛАН ИЗМЕНЕНИЙ ПРОЕКТА

### Задача
Добавить в CERES систему, которая:
1. **Анализирует** имеющиеся ресурсы (CPU, RAM, Storage)
2. **Рекомендует** конфигурацию на основе ресурсов
3. **Позволяет выбирать** сколько машин, какие ресурсы, какие сервисы
4. **Автоматически генерирует** конфиги (Terraform, Docker Compose, .env)

---

## 🏗️ АРХИТЕКТУРА РЕШЕНИЯ

### Уровень 1: Анализ ресурсов
```
┌─────────────────────────────────┐
│   System Resource Analyzer      │
├─────────────────────────────────┤
│ 1. Проверить целевую машину:    │
│    - Proxmox: узнать CPU/RAM    │
│    - Windows/Linux: узнать      │
│      CPU/RAM для Docker         │
│ 2. Рассчитать требования        │
│ 3. Вывести рекомендации         │
└─────────────────────────────────┘
```

### Уровень 2: Выбор конфигурации
```
┌──────────────────────────────────┐
│  Interactive Configuration Wizard │
├──────────────────────────────────┤
│ 1. Preset profiles:              │
│    • Small (1-3 машины)          │
│    • Medium (3 машины)           │
│    • Large (3+ машины + HA)      │
│                                  │
│ 2. Customization:                │
│    • Кол-во машин                │
│    • CPU на машину               │
│    • RAM на машину               │
│    • Storage                     │
│    • Какие модули               │
│    • Какие опции (VPN, mail)    │
│                                  │
│ 3. Отобразить plan:              │
│    • Total resources             │
│    • VM distribution             │
│    • Services placement          │
│    • Estimated costs             │
└──────────────────────────────────┘
```

### Уровень 3: Генерация конфигов
```
┌────────────────────────────────┐
│  Configuration Generator        │
├────────────────────────────────┤
│ На основе выбора генерирует:    │
│                                │
│ 1. terraform/environments/      │
│    • {profile}.tfvars          │
│    • terraform.auto.tfvars     │
│                                │
│ 2. config/compose/             │
│    • Пересчитанные resources   │
│    • Updated .env              │
│                                │
│ 3. Documentation:              │
│    • deployment-plan.md        │
│    • resource-allocation.json  │
└────────────────────────────────┘
```

---

## 📊 СТРУКТУРА ПРОФИЛЕЙ

### Small Profile (Разработка/Тестирование)
```
环境: Docker Compose на одной машине / Proxmox (одна VM)

┌─────────────────────┐
│  Single VM / Docker │ 
├─────────────────────┤
│ Total: 8-16 CPU,    │
│        16-32 GB RAM │
│        100+ GB SSD  │
│                     │
│ Services:           │
│ • core (Postgres,   │
│   Redis, Keycloak)  │
│ • apps (basic)      │
│ • monitoring        │
└─────────────────────┘
```

**Когда использовать:** Локальная разработка, PoC, небольшая команда (5-10 чел)

### Medium Profile (Стандартная команда)
```
Окружение: Proxmox, 3 VM

┌───────────┐  ┌────────────┐  ┌──────────┐
│  Core VM  │  │  Apps VM   │  │ Edge VM  │
├───────────┤  ├────────────┤  ├──────────┤
│ 4 CPU     │  │ 4 CPU      │  │ 2 CPU    │
│ 8 GB RAM  │  │ 8 GB RAM   │  │ 4 GB RAM │
│ 50 GB     │  │ 80 GB      │  │ 40 GB    │
│           │  │            │  │          │
│ Postgres  │  │ Nextcloud  │  │ Caddy    │
│ Redis     │  │ Gitea      │  │ Grafana  │
│ Keycloak  │  │ Mattermost │  │ Prometh. │
│           │  │ Redmine    │  │ Uptime K │
│           │  │ Wiki.js    │  │          │
└───────────┘  └────────────┘  └──────────┘
```

**Когда использовать:** Команда 10-50 человек, production-like окружение

### Large Profile (Enterprise)
```
Окружение: Proxmox, 4-5 VM + HA + Failover

┌───────────────┐  ┌─────────────┐  ┌──────────────┐  ┌──────────┐
│ Core Primary  │  │ Core Backup │  │  Apps VM 1   │  │ Edge VM  │
├───────────────┤  ├─────────────┤  ├──────────────┤  ├──────────┤
│ 6 CPU         │  │ 6 CPU       │  │ 4 CPU        │  │ 4 CPU    │
│ 16 GB RAM     │  │ 16 GB RAM   │  │ 8 GB RAM     │  │ 8 GB RAM │
│ 100 GB        │  │ 100 GB      │  │ 100 GB       │  │ 50 GB    │
│               │  │             │  │              │  │          │
│ Postgres (M)  │  │ Postgres (R)│  │ Nextcloud    │  │ Caddy    │
│ Redis (M)     │  │ Redis (R)   │  │ Gitea (HA)   │  │ Prometheus
│ Keycloak (HA) │  │ Keycloak(R) │  │ Mattermost   │  │ Grafana  │
│ Patroni       │  │ Patroni     │  │ Redmine      │  │ Loki     │
│ etcd          │  │ etcd        │  │ Wiki.js      │  │ Portainer
└───────────────┘  └─────────────┘  └──────────────┘  └──────────┘
                    
Optional:           Optional:       Optional:         
└───────────────┐   └─────────────┐ └──────────────┐
│  Apps VM 2    │   │  Storage    │ │  VPN         │
│  (Read-only)  │   │  (NFS/GlusterFS)
└───────────────┘   └─────────────┘ └──────────────┘
```

**Когда использовать:** 50+ человек, high-availability requirement, SLA 99.9%

---

## 🔧 ТЕХНИЧЕСКИЕ КОМПОНЕНТЫ

### 1. Resource Analyzer Script
**Файл:** `scripts/analyze-resources.ps1`

```powershell
# Что должен делать:
- Get-SystemResources       # Анализ локальной машины
- Get-ProxmoxResources      # Подключиться к Proxmox, узнать ресурсы
- Calculate-Requirements    # Рассчитать требования для каждого профиля
- Generate-Report          # Вывести понятный отчёт
```

**Выходные данные:**
```json
{
  "system": {
    "type": "proxmox",
    "total_cpu": 16,
    "total_ram_gb": 64,
    "total_storage_gb": 500,
    "available_cpu": 12,
    "available_ram_gb": 48
  },
  "recommendations": {
    "small": { "feasible": true, "reason": "sufficient resources" },
    "medium": { "feasible": true, "reason": "recommended profile" },
    "large": { "feasible": true, "reason": "can run with HA" }
  },
  "warnings": [
    "Storage < 500GB recommended",
    "CPU might be tight for high load"
  ]
}
```

### 2. Configuration Wizard Script
**Файл:** `scripts/configure-ceres.ps1`

```powershell
# Что должен делать:
- Show-Profile-Options      # Предложить Preset или Custom
- Show-VM-Config            # Выбрать сколько VM, ресурсы
- Show-Service-Selection    # Выбрать модули (core/apps/monitoring/vpn)
- Show-Resource-Preview     # Показать plan перед генерацией
- Validate-Configuration    # Проверить что выбор валидный
- Generate-All-Configs      # Запустить генераторы
```

**Интерактивное меню:**
```
╔════════════════════════════════════════╗
║  CERES Configuration Wizard            ║
╚════════════════════════════════════════╝

1. Deployment Type:
   ○ Docker Compose (local)
   ○ Kubernetes on Proxmox
   → [Kubernetes]

2. Resource Profile:
   ○ Small (1-3 VM, basic)
   ○ Medium (3 VM, standard) ← RECOMMENDED
   ○ Large (4-5 VM, HA)
   ○ Custom
   → [Medium]

3. Virtual Machines:
   VM Count: [3]
   
   VM1 (Core):
     CPU:  [4] cores
     RAM:  [8] GB
     Storage: [50] GB
   
   VM2 (Apps):
     CPU:  [4] cores
     RAM:  [8] GB
     Storage: [80] GB
   
   VM3 (Edge):
     CPU:  [2] cores
     RAM:  [4] GB
     Storage: [40] GB

4. Services to Deploy:
   [✓] core (Postgres, Redis, Keycloak)
   [✓] apps (Nextcloud, Gitea, Mattermost)
   [✓] monitoring (Prometheus, Grafana)
   [✓] ops (Portainer, Uptime Kuma)
   [ ] vpn (WireGuard)
   [ ] mail (Mailu + SMTP)
   [ ] edms (Mayan EDMS)

5. Options:
   [ ] Enable HA mode
   [ ] Enable monitoring alerts
   [ ] Enable backup automation
   [ ] Enable Cloudflare Tunnel

6. Summary:
   ┌─────────────────────────────────┐
   │ DEPLOYMENT PLAN                 │
   │                                 │
   │ Deployment: Kubernetes/Proxmox  │
   │ Profile: Medium                 │
   │ Total Resources:                │
   │   CPU: 10 cores                 │
   │   RAM: 20 GB                    │
   │   Storage: 170 GB               │
   │                                 │
   │ Services:                       │
   │   • PostgreSQL (8GB)            │
   │   • Redis (2GB)                 │
   │   • Keycloak (1.5GB)            │
   │   • Nextcloud (2GB)             │
   │   • Gitea (1.5GB)               │
   │   • Mattermost (2GB)            │
   │   • Grafana (1GB)               │
   │   • Prometheus (1GB)            │
   │   • Caddy (0.5GB)               │
   │                                 │
   │ Estimated monthly cost: $120    │
   │ (on Hetzner/DigitalOcean)       │
   └─────────────────────────────────┘

   Proceed? [Yes/No] → 
```

### 3. Terraform Generator
**Файл:** `scripts/generate-terraform-config.ps1`

Генерирует `terraform/environments/{profile}.tfvars`:

```hcl
# terraform/environments/medium.tfvars

# Proxmox Connection
proxmox_api_url  = "https://192.168.1.5:8006/api2/json"
proxmox_node     = "proxmox-01"
proxmox_storage  = "local"
template_name    = "debian-12-cloudinit"

# Environment
environment  = "production"
domain       = "ceres"

# Core VM
core_vm_ip       = "192.168.1.10"
core_vm_cores    = 4
core_vm_sockets  = 1
core_vm_memory   = 8192
core_vm_disk     = 50

# Apps VM
apps_vm_ip       = "192.168.1.11"
apps_vm_cores    = 4
apps_vm_sockets  = 1
apps_vm_memory   = 8192
apps_vm_disk     = 80

# Edge VM
edge_vm_ip       = "192.168.1.12"
edge_vm_cores    = 2
edge_vm_sockets  = 1
edge_vm_memory   = 4096
edge_vm_disk     = 40

# Network
network_gateway  = "192.168.1.1"
network_dns      = ["8.8.8.8", "8.8.4.4"]

# Optional features
enable_ha        = false
enable_vpn       = false
```

### 4. Docker Compose Resource Adjuster
**Файл:** `scripts/generate-docker-resources.ps1`

Обновляет `config/compose/*.yml` с реальными лимитами:

```yaml
# config/compose/apps.yml (после обработки)

postgres:
  deploy:
    resources:
      limits:
        cpus: '1.5'         # ← Рассчитано из total
        memory: 2G          # ← Рассчитано из total
      reservations:
        cpus: '1.0'
        memory: 1G

keycloak:
  deploy:
    resources:
      limits:
        cpus: '1.5'
        memory: 1.5G
      reservations:
        cpus: '0.75'
        memory: 1G
```

### 5. Environment Generator
**Файл:** `scripts/generate-env-config.ps1`

Генерирует/обновляет `config/.env`:

```dotenv
# Автоматически сгенерировано на основе выбранной конфигурации

DOMAIN=ceres
DEPLOYMENT_TYPE=kubernetes
DEPLOYMENT_PROFILE=medium
TOTAL_VMS=3

# Postgres (рассчитано)
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_SHARED_BUFFERS=2GB
POSTGRES_WORK_MEM=10MB

# Keycloak (рассчитано)
KEYCLOAK_JVM_OPTS=-Xms512m -Xmx1g
KEYCLOAK_INITIAL_ADMIN_PASSWORD=<generated>

# Resource limits
NEXTCLOUD_MAX_UPLOAD=512M
GITEA_MAX_BODY_SIZE=512M
```

---

## 📈 MATRIX: Профиль → Ресурсы → Сервисы

### Mapping: Profile → VM Configuration

| Profile | VMs | Core CPU | Core RAM | Apps CPU | Apps RAM | Edge CPU | Edge RAM | Total | Use Case |
|---------|-----|----------|----------|----------|----------|----------|----------|-------|----------|
| Small | 1 | 8 | 16 | - | - | - | - | 8C/16GB | Dev/PoC |
| Small | 2 | 4 | 8 | 4 | 8 | - | - | 8C/16GB | Small team |
| Medium | 3 | 4 | 8 | 4 | 8 | 2 | 4 | 10C/20GB | Standard |
| Large | 4 | 6 | 16 | 4 | 8 | 4 | 8 | 14C/32GB | Enterprise |
| Large HA | 5 | 6 | 16 | 6 | 16 | 4 | 8 | 16C/40GB | HA/SLA99.9 |

### Mapping: Profile → Services

| Service | Small (1VM) | Small (2VM) | Medium (3VM) | Large (4VM) | Large HA (5VM) |
|---------|:-----------:|:-----------:|:------------:|:----------:|:-----:|
| Postgres | Core | Core | Core | Core Primary | Core Primary |
| Redis | Core | Core | Core | Core | Core |
| Keycloak | Apps | Apps | Core | Core (HA) | Core (HA) |
| Nextcloud | Apps | Apps | Apps | Apps | Apps |
| Gitea | Apps | Apps | Apps | Apps | Apps |
| Mattermost | Apps | Apps | Apps | Apps | Apps |
| Redmine | Apps | Apps | Apps | Apps | Apps |
| Wiki.js | Apps | Apps | Apps | Apps | Apps |
| Prometheus | Ops | Edge | Edge | Edge | Edge |
| Grafana | Ops | Edge | Edge | Edge | Edge |
| Caddy | Apps | Edge | Edge | Edge | Edge |
| Loki | - | - | Edge (opt) | Edge | Edge |
| WireGuard | - | - | Edge (opt) | Edge (opt) | Edge |
| Mayan EDMS | - | - | - | Separate VM (opt) | Separate VM (opt) |

---

## 🔄 WORKFLOW: От анализа к деплою

```
User Action                    System Response
─────────────────────────────────────────────────
1. Run configure-ceres.ps1 ──→ Analyze system resources
                              │
                              ├─ Show recommendations
                              │
2. Choose profile ────────────→ Calculate requirements
                              │
3. Customize (opt.) ─────────→ Validate configuration
                              │
4. Confirm deployment plan ──→ Generate all configs:
                              │
                              ├─ terraform/environments/{profile}.tfvars
                              ├─ terraform.auto.tfvars (symlink)
                              ├─ config/.env
                              ├─ config/compose/*.yml (adjusted)
                              └─ DEPLOYMENT_PLAN.json (for reference)
                              │
5. Run DEPLOY.ps1 ───────────→ Execute Terraform + Ansible
                              │
                              └─ Platform ready ✓
```

---

## 📁 НОВАЯ СТРУКТУРА ФАЙЛОВ

```
scripts/
├── analyze-resources.ps1              ← NEW: Analyze system
├── configure-ceres.ps1                ← NEW: Interactive wizard
├── generate-terraform-config.ps1      ← NEW: Generate tfvars
├── generate-docker-resources.ps1      ← NEW: Adjust compose limits
├── generate-env-config.ps1            ← NEW: Generate .env
├── _lib/
│   ├── Ceres.ps1
│   ├── Resource-Profiles.ps1          ← NEW: Profile definitions
│   ├── Config-Validation.ps1          ← NEW: Validation logic
│   └── Config-Generation.ps1          ← NEW: Generation helpers
│
├── start.ps1                          ← UPDATED: Call generator first
└── ...

config/
├── .env.example
├── .env                               ← Auto-generated
├── profiles/                          ← NEW: Profile definitions
│   ├── small.json
│   ├── medium.json
│   └── large.json
│
├── compose/
│   ├── *.yml                          ← Auto-adjusted with resources
│   └── ...

terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── environments/                      ← NEW: Profile-specific
│   ├── small.tfvars
│   ├── medium.tfvars
│   ├── large.tfvars
│   └── custom.tfvars
├── terraform.auto.tfvars              ← NEW: Symlink to selected profile
└── ...

docs/
├── RESOURCE_ALLOCATION_GUIDE.md       ← NEW: User guide
├── PROFILE_SELECTION.md               ← NEW: How to choose
└── ...
```

---

## 🎯 BEST PRACTICES

### 1. Profile Definitions
✅ **Store in JSON** for easy parsing
✅ **Version profiles** (v1.0, v2.0) as requirements change
✅ **Include cost estimates** (for cloud)
✅ **Validate against real Proxmox** resources

### 2. Resource Limits
✅ **Use reservation + limit** pattern (Docker)
✅ **Leave 20% headroom** for system
✅ **Set per-container limits**, not just total
✅ **Monitor and adjust** based on metrics

### 3. Configuration Generation
✅ **Make idempotent** (can run multiple times safely)
✅ **Create backups** of old configs before overwriting
✅ **Validate generated configs** before use
✅ **Log what changed** for troubleshooting

### 4. User Experience
✅ **Sensible defaults** (no required questions)
✅ **Show impact visually** (ASCII art, JSON preview)
✅ **Allow easy undo** (git-like revert)
✅ **Provide estimate** (time, cost, resources)

### 5. Documentation
✅ **Link from QUICKSTART to configure-ceres.ps1**
✅ **Include examples** for each profile
✅ **Show before/after** configs
✅ **Explain trade-offs** (Small vs Medium)

---

## 📊 EXAMPLE: Small Profile Selection

**User runs:**
```powershell
.\scripts\configure-ceres.ps1
```

**Wizard shows:**
```
✓ System Analysis
  └─ 16 CPU, 32 GB RAM, 500 GB Storage detected

1. Select Deployment Type:
   ○ Docker Compose (local dev)
   ○ Proxmox + Kubernetes (production)
   → [Proxmox + Kubernetes]

2. Select Profile (or customize):
   ○ Small (1-2 VMs, basic setup)
   ○ Medium (3 VMs, standard) ← RECOMMENDED ★
   ○ Large (4+ VMs, HA)
   ○ Custom (define own)
   → [Small]

3. Customize Small Profile:
   Keep defaults? [Yes/No] → [Yes]

4. Review Plan:
   ┌──────────────────────────────┐
   │ DEPLOYMENT PLAN              │
   │ Profile: Small               │
   │ VMs: 2                       │
   │                              │
   │ VM1 (Compute):               │
   │   IP: 192.168.1.10           │
   │   CPU: 4 cores               │
   │   RAM: 8 GB                  │
   │   Disk: 50 GB                │
   │   Services: Postgres, Redis, │
   │             Keycloak         │
   │                              │
   │ VM2 (Apps+Edge):             │
   │   IP: 192.168.1.11           │
   │   CPU: 4 cores               │
   │   RAM: 8 GB                  │
   │   Disk: 80 GB                │
   │   Services: Nextcloud, Gitea │
   │             Caddy, Grafana   │
   │                              │
   │ Total: 8 CPU, 16 GB, 130 GB  │
   │ Est. time: 20 minutes        │
   │ Est. monthly cost: $80       │
   └──────────────────────────────┘

   Proceed? [Yes/No] → [Yes]

5. Generating Configs...
   ✓ terraform/environments/small.tfvars
   ✓ config/.env
   ✓ config/compose/apps.yml (adjusted)
   ✓ DEPLOYMENT_PLAN.json
   
   ✓ All configs ready!

6. Next Steps:
   1. Review DEPLOYMENT_PLAN.json
   2. Run: .\DEPLOY.ps1
   3. Follow on-screen prompts
```

---

## 🚀 IMPLEMENTATION TIMELINE

**Phase 1: MVP (Week 1-2)**
- [ ] `analyze-resources.ps1` — basic local + Proxmox detection
- [ ] `Resource-Profiles.ps1` — define Small/Medium/Large
- [ ] `configure-ceres.ps1` — simple wizard (preset only)
- [ ] `generate-terraform-config.ps1` — tfvars generation

**Phase 2: Enhancement (Week 3-4)**
- [ ] `generate-docker-resources.ps1` — resource adjustment
- [ ] `generate-env-config.ps1` — env generation
- [ ] `Config-Validation.ps1` — validation logic
- [ ] Integration with `start.ps1` and `DEPLOY.ps1`

**Phase 3: Polish (Week 5-6)**
- [ ] Custom profile support
- [ ] Cost estimation
- [ ] Web UI (optional, Vue.js)
- [ ] Documentation & examples

---

## ✅ SUCCESS CRITERIA

- [ ] New user can configure CERES in < 5 minutes
- [ ] Generated configs are valid and tested
- [ ] Resource allocation matches actual workload
- [ ] No manual editing of .env/tfvars needed
- [ ] Profiles can be switched easily
- [ ] Backward compatible with existing deployments
