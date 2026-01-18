# CERES CLI Reference

Полное руководство по командам `ceres` CLI.

## 📋 Содержание

- [Общая структура команд](#общая-структура-команд)
- [Docker Compose Operations](#docker-compose-operations)
- [Configuration & Setup](#configuration--setup)
- [User Management](#user-management)
- [Kubernetes Operations](#kubernetes-operations)
- [Analysis & Validation](#analysis--validation)
- [Help System](#help-system)

## Общая структура команд

```
ceres <command> [subcommand] [options] [arguments]
```

**Основные правила:**
- Все команды работают кроссплатформенно (Windows, Linux, macOS)
- Опции начинаются с `-` (short) или `--` (long): `-f`, `--force`
- Логи в цвете с emoji-префиксами: `✅`, `⚠️`, `❌`
- Интерактивные промпты можно пропустить с `--yes`

## Docker Compose Operations

Команды для управления сервисами через Docker Compose (локальная разработка).

### `ceres start`

Запускает сервисы через Docker Compose.

**Синтаксис:**
```powershell
ceres start [modules...]
```

**Аргументы:**
- `[modules...]` — список модулей для запуска (необязательно)
  - `core` — PostgreSQL, Redis, Keycloak
  - `apps` — Nextcloud, Gitea, Mattermost, Redmine, Wiki.js
  - `monitoring` — Prometheus, Grafana
  - `ops` — Portainer, Uptime Kuma
  - `edge` — Caddy (требует свободные порты 80/443)
  - `vpn` — WireGuard (wg-easy)

**Примеры:**
```powershell
# Запустить все сервисы (core + apps + monitoring + ops)
ceres start

# Только core и apps (без monitoring/ops)
ceres start core apps

# Core + apps + VPN
ceres start core apps vpn
```

**Что происходит:**
1. Проверка зависимостей (Docker, Docker Compose)
2. Генерация `config/.env` из `config/.env.example` (если нужно)
3. Запуск выбранных модулей через `docker compose up -d`
4. Health checks для сервисов (30-60s timeout)
5. Keycloak bootstrap (OIDC clients для Grafana, Wiki.js)
6. Вывод URLs для доступа

**Health checks:**
- PostgreSQL (5432)
- Redis (6379)
- Keycloak (8080)
- Nextcloud (80)
- Gitea (3000)
- Mattermost (8065)

**Требования:**
- Docker Engine 24.0+
- Docker Compose v2.20+
- Порты 80, 443 свободны (для `edge`)
- Порты 8080, 5432, 6379 свободны (для `core`)

---

### `ceres stop`

Останавливает запущенные сервисы.

**Синтаксис:**
```powershell
ceres stop [modules...] [--clean]
```

**Опции:**
- `--clean` — удалить volumes (данные будут потеряны!)

**Примеры:**
```powershell
# Остановить все сервисы (volumes сохраняются)
ceres stop

# Остановить только core
ceres stop core

# Остановить и удалить все volumes
ceres stop --clean
```

**Что происходит:**
1. `docker compose down` для выбранных модулей
2. Опционально: `docker volume rm` (если `--clean`)

---

### `ceres status`

Показывает статус контейнеров.

**Синтаксис:**
```powershell
ceres status [--detailed]
```

**Опции:**
- `--detailed` — показать CPU/Memory/Networks

**Примеры:**
```powershell
# Краткий статус
ceres status

# Детальный статус с ресурсами
ceres status --detailed
```

**Вывод:**
```
CONTAINER            STATUS    PORTS
postgres             Up        5432
redis                Up        6379
keycloak             Up        8080
nextcloud            Up        80
gitea                Up        3000, 2222
```

---

### `ceres backup`

Создаёт бэкап баз данных и volumes.

**Синтаксис:**
```powershell
ceres backup
```

**Что бэкапится:**
- PostgreSQL (все базы)
- Redis (dump.rdb)
- Docker volumes (gitea_data, nextcloud_data, grafana_data)

**Формат:**
```
backups/
└── 20260118_120000/
    ├── postgres_backup.sql
    ├── redis_backup.rdb
    ├── gitea_data.tar.gz
    ├── nextcloud_data.tar.gz
    └── grafana_data.tar.gz
```

**Примеры:**
```powershell
# Создать бэкап
ceres backup
# → backups/20260118_120000/
```

---

### `ceres restore`

Восстанавливает из бэкапа.

**Синтаксис:**
```powershell
ceres restore <timestamp>
```

**Аргументы:**
- `<timestamp>` — директория в `backups/`, например `20260118_120000`

**Примеры:**
```powershell
# Восстановить из последнего бэкапа
ceres restore 20260118_120000
```

**Что восстанавливается:**
- PostgreSQL (все базы)
- Redis (dump.rdb)
- Docker volumes

---

### `ceres logs`

Показывает логи контейнера (алиас для `docker logs`).

**Синтаксис:**
```powershell
ceres logs <service> [--follow]
```

**Опции:**
- `--follow` (или `-f`) — следить за логами в реальном времени

**Примеры:**
```powershell
# Последние логи Gitea
ceres logs gitea

# Следить за логами Keycloak
ceres logs keycloak --follow
```

---

## Configuration & Setup

Команды для конфигурации и настройки сервисов.

### `ceres configure`

Интерактивный конфигуратор (мастер настройки).

**Синтаксис:**
```powershell
ceres configure
```

**Что происходит:**
1. Выбор профиля (small/medium/large)
2. Настройка доменов (`DOMAIN=ceres.local`)
3. Генерация паролей (автоматически для `CHANGE_ME`)
4. Настройка SMTP (опционально)
5. Настройка VPN (опционально)
6. Сохранение в `config/.env`

**Примеры:**
```powershell
# Запустить мастер конфигурации
ceres configure
```

---

### `ceres setup keycloak`

Настройка Keycloak SSO (bootstrap OIDC clients).

**Синтаксис:**
```powershell
ceres setup keycloak
```

**Что настраивается:**
- OIDC клиент для Grafana
- OIDC клиент для Wiki.js
- OIDC клиент для Redmine (опционально)

**Примеры:**
```powershell
# Bootstrap Keycloak SSO
ceres setup keycloak
```

**Требования:**
- Keycloak должен быть запущен
- Переменные в `.env`: `KEYCLOAK_ADMIN_PASSWORD`, `GRAFANA_OIDC_CLIENT_SECRET`

---

### `ceres setup smtp`

Настройка SMTP для Keycloak (отправка email).

**Синтаксис:**
```powershell
ceres setup smtp
```

**Примеры:**
```powershell
# Настроить SMTP
ceres setup smtp
```

**Требования:**
- Переменные в `.env`: `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`

---

## User Management

Команды для управления пользователями.

### `ceres user create`

Создаёт сотрудника (employee onboarding).

**Синтаксис:**
```powershell
ceres user create <username>
```

**Что создаётся:**
1. Email ящик в Mailu (если настроен)
2. VPN конфигурация (wg-easy)
3. Пользователь в Keycloak (если `--keycloak`)

**Примеры:**
```powershell
# Создать сотрудника john.doe
ceres user create john.doe

# Интерактивный режим
ceres user create
```

**Вывод:**
```
✅ Email создан: john.doe@ceres.local
✅ VPN конфиг: vpn-configs/john.doe.conf
⚠️  Отправьте файл сотруднику
```

---

### `ceres vpn add`

Добавляет VPN пользователя (только VPN, без email).

**Синтаксис:**
```powershell
ceres vpn add <username>
```

**Примеры:**
```powershell
# Добавить VPN для john.doe
ceres vpn add john.doe
```

**Вывод:**
```
✅ VPN конфиг создан: vpn-configs/john.doe.conf
```

---

## Kubernetes Operations

Команды для работы с Kubernetes/k3s на Proxmox.

### `ceres k8s deploy`

Деплой k3s кластера на Proxmox (wrapper для DEPLOY.ps1).

**Синтаксис:**
```powershell
ceres k8s deploy
```

**Что происходит:**
1. Terraform создаёт 3 VM на Proxmox
2. Ansible настраивает ОС и зависимости
3. k3s устанавливается и формирует кластер
4. kubeconfig копируется локально
5. GitHub Secrets обновляются (KUBECONFIG)

**Примеры:**
```powershell
# Деплой кластера
ceres k8s deploy
```

**Требования:**
- Proxmox сервер доступен
- `terraform.tfvars` настроен
- SSH ключи настроены

---

### `ceres k8s flux-status`

Показывает статус FluxCD (GitOps).

**Синтаксис:**
```powershell
ceres k8s flux-status
```

**Примеры:**
```powershell
# Статус Flux
ceres k8s flux-status
```

**Вывод:**
```
NAME                          READY   STATUS
flux-system                   True    Applied
ceres-core                    True    Applied
ceres-apps                    True    Applied
```

---

### `ceres k8s flux-bootstrap`

Bootstrap FluxCD GitOps.

**Синтаксис:**
```powershell
ceres k8s flux-bootstrap
```

**Примеры:**
```powershell
# Bootstrap Flux
ceres k8s flux-bootstrap
```

---

## Analysis & Validation

Команды для анализа и валидации.

### `ceres analyze resources`

Анализ системных ресурсов (CPU, RAM, Disk).

**Синтаксис:**
```powershell
ceres analyze resources
```

**Примеры:**
```powershell
ceres analyze resources
```

**Вывод:**
```
SYSTEM RESOURCES:
  CPU: 8 cores
  RAM: 16 GB (12 GB available)
  Disk: 250 GB (180 GB free)

RECOMMENDED PROFILE: medium
```

---

### `ceres analyze profiles`

Показывает доступные профили (small/medium/large).

**Синтаксис:**
```powershell
ceres analyze profiles
```

**Примеры:**
```powershell
ceres analyze profiles
```

---

### `ceres validate environment`

Валидация окружения перед деплоем.

**Синтаксис:**
```powershell
ceres validate environment
```

**Что проверяется:**
- Docker установлен и запущен
- Docker Compose v2.20+
- Свободные порты (80, 443, 5432, 6379)
- Достаточно места на диске

**Примеры:**
```powershell
ceres validate environment
```

---

### `ceres validate conflicts`

Проверка конфликтующих контейнеров/процессов.

**Синтаксис:**
```powershell
ceres validate conflicts
```

**Примеры:**
```powershell
ceres validate conflicts
```

---

## Help System

### `ceres help`

Показывает помощь по всем командам.

**Синтаксис:**
```powershell
ceres help [command]
```

**Примеры:**
```powershell
# Общая помощь
ceres help

# Помощь по команде start
ceres help start
```

---

## Переменные окружения

Основные переменные в `config/.env`:

```bash
# Домен
DOMAIN=ceres.local

# PostgreSQL
POSTGRES_PASSWORD=your_secure_password

# Keycloak
KEYCLOAK_ADMIN_PASSWORD=your_secure_password
GRAFANA_OIDC_CLIENT_SECRET=your_secure_secret
WIKIJS_OIDC_CLIENT_SECRET=your_secure_secret

# SMTP (опционально)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password

# VPN (опционально)
WG_HOST=vpn.ceres.local
WG_EASY_PASSWORD=your_secure_password
```

---

## Troubleshooting

### Проблема: `ceres start` падает с ошибкой "port already allocated"

**Решение:**
```powershell
# Проверить занятые порты
ceres validate conflicts

# Остановить конфликтующие контейнеры
docker stop $(docker ps -q --filter "publish=80")
```

---

### Проблема: Keycloak не запускается (ждёт PostgreSQL)

**Решение:**
```powershell
# Проверить логи PostgreSQL
ceres logs postgres

# Убедиться, что порт 5432 свободен
netstat -an | Select-String "5432"
```

---

### Проблема: `ceres backup` падает с ошибкой "permission denied"

**Решение:**
```powershell
# Запустить PowerShell с правами администратора
# Или проверить права на директорию backups/
```

---

## Advanced Usage

### Модульная архитектура

Команды `ceres` используют модули из `scripts/_lib/`:

| Модуль | Функции |
|--------|---------|
| `Docker.ps1` | Invoke-CeresStart, Invoke-CeresStop, Invoke-CeresBackup |
| `Configure.ps1` | Invoke-CeresConfiguration, Invoke-CeresPreflight |
| `Keycloak.ps1` | Invoke-CeresKeycloakBootstrap, Set-KeycloakSmtp |
| `User.ps1` | New-CeresEmployee, New-CeresVpnUser |
| `Kubernetes.ps1` | Invoke-CeresK8sDeploy, Get-CeresFluxStatus |

### Вызов напрямую

Можно импортировать модули напрямую:

```powershell
# Импорт модуля Docker
. "$PSScriptRoot/_lib/Docker.ps1"

# Вызов функции
Invoke-CeresStart -Modules @("core", "apps")
```

---

## См. также

- [00-QUICKSTART.md](00-QUICKSTART.md) — быстрый старт
- [01-ARCHITECTURE.md](01-ARCHITECTURE.md) — архитектура
- [../scripts/advanced/README.md](../scripts/advanced/README.md) — продвинутые скрипты
- [../SCRIPT_AUDIT_REPORT.md](../SCRIPT_AUDIT_REPORT.md) — аудит скриптов
