# CERES Quick Start Guide

Быстрый старт развертывания платформы CERES

## 5 минут для первого запуска

### 1️⃣ Клонируем репозиторий

```bash
git clone https://github.com/yourorg/Ceres.git
cd Ceres
```

### 2️⃣ Запускаем CLI (единая команда `ceres`)

- Windows: `ceres.cmd <command>` (из корня)
- Linux/macOS: `chmod +x ceres` один раз, затем `./ceres <command>`
- Альтернатива: `pwsh -File scripts/ceres.ps1 <command>`

### 3️⃣ Анализируем ресурсы

```powershell
ceres analyze resources
```

**Ожидаемый результат:**
```
System Resources: CPU=12 RAM=15GB Disk=100GB

Recommendation: SMALL profile (Docker, 1 VM, 4 CPU, 8GB RAM)
```

### 4️⃣ Выбираем профиль

| Профиль | Использование | Требования |
|---------|-------------|-----------|
| **SMALL** | Локальное тестирование | 4 CPU, 8GB RAM, 80GB Disk |
| **MEDIUM** | Production на Kubernetes (рекомендуется) | 10 CPU, 20GB RAM, 170GB Disk |
| **LARGE** | HA Kubernetes кластер | 24 CPU, 56GB RAM, 450GB Disk |

### 5️⃣ Конфигурируем

```powershell
ceres configure --preset medium
```

Мастер спросит:
- DOMAIN (по умолчанию: ceres.local)
- PostgreSQL пароль
- Keycloak админ пароль
- Grafana админ пароль

### 6️⃣ Проверяем конфигурацию

```powershell
ceres validate environment
```

## Основные команды

### Happy path (локально, 4 шага)

```powershell
ceres configure --preset small
ceres start core apps
ceres status --detailed
# открыть http://localhost (Nextcloud/Gitea)
```

### Статус и логи

```powershell
ceres status
ceres logs postgres
ceres logs keycloak --follow
```

### Backup/restore

```powershell
ceres backup
ceres restore 20260118_120000
```

## Структура проекта (ключевое)

```
Ceres/
├── ceres            ← Unix shim (./ceres <command>)
├── ceres.cmd        ← Windows shim (ceres.cmd <command>)
├── scripts/
│   ├── ceres.ps1    ← ЕДИНАЯ ТОЧКА ВХОДА (CLI ядро)
│   ├── _lib/        ← Модули: Docker, Configure, Keycloak, User, Kubernetes
│   └── advanced/    ← Опциональные скрипты (mTLS/HA/Cost) — НЕ для базового запуска
├── config/          ← .env.example, compose, profiles
├── docs/            ← Документация
└── flux/            ← GitOps (K8s)
```

## Где какие сервисы?

| Сервис | Docker | K8s | UI |
|--------|--------|-----|-----|
| PostgreSQL | ✅ | ✅ | pgAdmin |
| Redis | ✅ | ✅ | Redis Insight |
| Keycloak (SSO) | ✅ | ✅ | `https://auth.{domain}` |
| Nextcloud (Файлы) | ✅ | ✅ | `https://nextcloud.{domain}` |
| Gitea (Git) | ✅ | ✅ | `https://gitea.{domain}` |
| Mattermost (Чат) | ✅ | ✅ | `https://mattermost.{domain}` |
| Wiki.js (Документация) | ✅ | ✅ | `https://wiki.{domain}` |
| Redmine (Проекты) | ✅ | ✅ | `https://redmine.{domain}` |
| Grafana (Мониторинг) | ✅ | ✅ | `https://grafana.{domain}` |
| Prometheus | ✅ | ✅ | `https://prometheus.{domain}` |

## Часто задаваемые вопросы

### 1. Какой профиль выбрать?

- **SMALL**: Для тестирования на локальной машине или VM с малыми ресурсами
- **MEDIUM**: Стандартный выбор для production (K8s на Proxmox)
- **LARGE**: Если нужна HA и высокая доступность

### 2. Как включить SSL?

SSL включается автоматически через Caddy. Для производства:

1. Отредактируйте `config/caddy/Caddyfile`
2. Раскомментируйте `acme_ca https://acme-v02.api.letsencrypt.org/directory`
3. Установите `ACME_EMAIL` в `.env`

### 3. Как интегрировать VPN?

```powershell
powershell -File scripts/ceres.ps1 deploy vpn
```

WireGuard будет доступен на `https://vpn.{domain}`

### 4. Как смотреть логи?

```powershell
# Все логи в реал-тайме
docker-compose -f config/compose/core.yml logs -f

# Конкретного сервиса
docker-compose -f config/compose/core.yml logs postgres

# Последние 100 строк
docker-compose -f config/compose/apps.yml logs --tail=100 keycloak
```

### 5. Как перезагрузить сервис?

```powershell
# Через Docker
docker-compose restart postgres

# Или через CERES CLI
powershell -File scripts/ceres.ps1 deploy applications --profile medium
```

## Трабблшутинг

### ❌ "Port 80 already in use"

Решение: Освободите порт или используйте другой в `config/.env`

```powershell
# Посмотреть что слушает порт 80
netstat -ano | findstr :80

# Kill процесс (замените PID)
taskkill /PID 1234 /F
```

### ❌ "Failed to connect to Keycloak"

Решение:
1. Проверьте что контейнер запущен: `docker-compose ps keycloak`
2. Посмотрите логи: `docker-compose logs keycloak`
3. Проверьте пароль: `grep KEYCLOAK_ADMIN_PASSWORD config/.env`

### ❌ "Database connection error"

Решение:
1. Проверьте PostgreSQL: `docker-compose ps postgres`
2. Посмотрите логи: `docker-compose logs postgres`
3. Убедитесь что `POSTGRES_PASSWORD` совпадает в `.env`

## Что дальше?

1. **Документация:**
   - [Архитектура системы](ARCHITECTURE.md)
   - [Полное руководство](docs/CERES_v3.0_COMPLETE_GUIDE.md)
   - [Индекс документации](docs/INDEX.md)

2. **Развертывание:**
   - [На Proxmox с Kubernetes](docs/DEPLOY_TO_PROXMOX.md)
   - [GitOps с Flux](docs/GITOPS_GUIDE.md)
   - [Облачное развертывание](docs/DEPLOYMENT_GUIDE.md)

3. **Интеграция:**
   - [SSO с Keycloak](docs/WIKIJS_KEYCLOAK_SSO.md)
   - [SMTP и почта](docs/MAIL_SMTP_DAY1.md)
   - [VPN](docs/PROXMOX_VPN_SETUP.md)

## Поддержка

- 📖 [Читайте документацию](README.md)
- 🐛 [Создавайте issues](https://github.com/yourorg/Ceres/issues)
- 💬 [Обсуждения в Discussions](https://github.com/yourorg/Ceres/discussions)

---

**Готовы начать?** Запустите:

```powershell
powershell -File scripts/ceres.ps1 analyze resources
```
