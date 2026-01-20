# CERES Interactive Wizard - Quick Start

## 🎯 Единая точка входа для развертывания CERES

Теперь весь проект разворачивается через интерактивный CLI инструмент!

## 🚀 Запуск

### Windows:
```cmd
cd e:\Новая папка\All_project\Ceres
.\ceres.cmd
```

### Linux/Mac:
```bash
cd /opt/Ceres
./ceres
```

### PowerShell напрямую:
```powershell
pwsh scripts/ceres.ps1 interactive
```

## 📋 Главное меню

```
╔═══════════════════════════════════════════════════════╗
║              MAIN MENU - Choose Action            ║
╚═══════════════════════════════════════════════════════╝

  [1] Quick Deploy (Recommended) - Auto-deploy with defaults
  [2] Custom Deploy - Choose services and configuration
  [3] Remote Deploy - Deploy to remote server via SSH
  [4] Check Status - View deployed services
  [5] Service Management - Start/Stop/Restart services
  [6] Backup & Restore - Manage backups
  [7] System Info - Analyze resources and check prerequisites
  [0] Exit

Enter your choice [0-7]:
```

## ✨ Возможности каждого пункта меню

### 1️⃣ Quick Deploy (Рекомендуется)
**Что делает:**
- Автоматически разворачивает все сервисы с настройками по умолчанию
- Генерирует OIDC secrets
- Настраивает Docker сети
- Запускает все 7 сервисов (PostgreSQL, Redis, Keycloak, GitLab, Nextcloud, Mattermost, Redmine, Wiki.js)
- Показывает URLs для доступа

**Как использовать:**
```
1. Выбрать [1]
2. Подтвердить "yes"
3. Дождаться завершения (30-60 секунд)
4. Перейти на http://localhost:8080-8085
```

**Когда использовать:**
- Первое развертывание
- Быстрое тестирование
- У вас есть все prerequisites (Docker, Docker Compose)

---

### 2️⃣ Custom Deploy
**Что делает:**
- Позволяет выбрать **target** (Docker Compose или Kubernetes)
- Выбрать **конкретные сервисы** для деплоя
- Выбрать **resource profile** (small/medium/large)
- Развернуть только выбранные компоненты

**Пример выбора:**
```
Where do you want to deploy?
  [1] Local machine (Docker Compose)
  [2] Kubernetes cluster (k3s + Flux)

Enter choice [1-2]: 1

Select services (or 'all'):
  core, keycloak, gitlab

Select resource profile:
  [1] Small  - 2 CPU, 4GB RAM
  [2] Medium - 4 CPU, 8GB RAM (recommended)
  [3] Large  - 8 CPU, 16GB RAM

Enter choice [1-3]: 2
```

**Когда использовать:**
- Нужны только определенные сервисы
- Ограниченные ресурсы
- Тестирование отдельных компонентов

---

### 3️⃣ Remote Deploy
**Что делает:**
- Спрашивает SSH данные (host, user)
- Опционально создает backup перед деплоем
- Подключается к серверу по SSH
- Синхронизирует код через Git
- Запускает полный деплой на удаленном сервере

**Пример:**
```
Server IP or hostname: 192.168.1.3
SSH username: root
Create backup before deployment? yes

Continue with remote deployment? yes

[Автоматически выполняется на сервере]
```

**Когда использовать:**
- Деплой на production сервер
- Централизованное управление
- Обновление уже работающей системы

---

### 4️⃣ Check Status
**Что делает:**
- Показывает статус всех Docker Compose сервисов
- Отображает health статус каждого контейнера
- Выводит список URLs для доступа

**Вывод:**
```
NAME                STATUS       PORTS
postgres            Up (healthy) 5432/tcp
redis               Up (healthy) 6379/tcp
keycloak            Up           8080:8080/tcp
gitlab              Up           8081:80/tcp
...

Service URLs:
  Keycloak:   http://localhost:8080
  GitLab:     http://localhost:8081
  ...
```

**Когда использовать:**
- Проверка что все работает
- Диагностика проблем
- Получение URLs после деплоя

---

### 5️⃣ Service Management
**Что делает:**
- **Start all services** - запуск всех сервисов
- **Stop all services** - остановка всех сервисов
- **Restart all services** - перезапуск всех сервисов
- **View service logs** - просмотр логов (всех или конкретного)

**Меню:**
```
  [1] Start all services
  [2] Stop all services
  [3] Restart all services
  [4] View service logs

Enter choice [0-4]:
```

**Когда использовать:**
- Перезапуск после изменения конфигурации
- Остановка сервисов для обслуживания
- Просмотр логов для отладки

---

### 6️⃣ Backup & Restore
**Что делает:**
- **Create backup** - создает резервную копию данных
- **Restore from backup** - восстанавливает из бэкапа
- **List backups** - показывает список всех бэкапов

**Пример:**
```
  [1] Create backup
  [2] Restore from backup
  [3] List backups

Enter choice [0-3]: 1

Backup name (or empty for timestamp): before-update

[Создается backup-before-update-20260120.tar.gz]
```

**Когда использовать:**
- Перед обновлениями
- Перед изменением конфигурации
- Для disaster recovery

---

### 7️⃣ System Info
**Что делает:**
- Показывает системные ресурсы (CPU, RAM)
- Проверяет наличие prerequisites (Docker, Git, etc.)
- Рекомендует подходящий profile

**Вывод:**
```
System Resources:
  CPU:     Intel Core i7-12700K (12 cores)
  RAM:     16.00 GB

Prerequisites:
  ✓ Docker:  Docker version 24.0.7
  ✓ Compose: Docker Compose version v2.23.0
  ✓ Git:     git version 2.43.0

Recommended Profile:
  → LARGE profile (8 CPU, 16GB RAM)
```

**Когда использовать:**
- Перед первым деплоем
- Проверка совместимости
- Выбор оптимального profile

---

## 🎬 Полный workflow примера

### Сценарий: Первое развертывание на локальной машине

```powershell
# 1. Запускаем интерактивный wizard
.\ceres.cmd

# 2. Выбираем [7] - проверяем систему
[7]
# Видим: 16GB RAM, Docker установлен, рекомендуется MEDIUM profile
[Enter]

# 3. Выбираем [1] - Quick Deploy
[1]
yes
# Ждем 30-60 секунд...
# ✓ PostgreSQL, Redis, Keycloak, GitLab, Nextcloud, Mattermost, Redmine, Wiki.js
[Enter]

# 4. Проверяем статус
[4]
# Все сервисы Up (healthy)
[Enter]

# 5. Открываем браузер
# http://localhost:8080 - Keycloak
# http://localhost:8081 - GitLab
# и т.д.

# 6. Завершаем
[0]
```

---

### Сценарий: Деплой на production сервер

```powershell
# 1. Запускаем wizard
.\ceres.cmd

# 2. Выбираем Remote Deploy
[3]

# 3. Вводим данные сервера
Server IP: 192.168.1.3
SSH username: root
Create backup? yes
Continue? yes

# Wizard автоматически:
# - Подключается по SSH
# - Создает backup
# - Синхронизирует код
# - Запускает setup-services.sh
# - Проверяет health

[Enter] # Возврат в меню

# 4. Проверяем статус (опционально)
[4]

# 5. Выход
[0]
```

---

## 🔧 Технические детали

### Что происходит под капотом

**Quick Deploy [1]:**
```powershell
# Вызывает:
bash setup-services.sh  # (Linux/Mac)
# или
.\setup-services.ps1    # (Windows)
```

**Custom Deploy [2]:**
```powershell
# Docker Compose:
docker compose `
  -f config/compose/base.yml `
  -f config/compose/core.yml `
  -f config/compose/apps.yml `
  up -d

# Kubernetes:
bash scripts/deploy-kubernetes.sh
```

**Remote Deploy [3]:**
```powershell
# Вызывает:
bash scripts/remote-deploy.sh <host> <user> [--backup]
```

**Service Management [5]:**
```powershell
# Start:
docker compose -f ... up -d

# Stop:
docker compose -f ... down

# Logs:
docker compose -f ... logs -f [service]
```

**Backup & Restore [6]:**
```bash
# Create:
bash scripts/backup.sh [--name <name>]

# Restore:
bash scripts/restore.sh <backup-file>
```

---

## 📖 Связь с другой документацией

| Wizard опция | Детальная документация |
|--------------|------------------------|
| Quick Deploy | [QUICKSTART_WITH_INTEGRATION.md](QUICKSTART_WITH_INTEGRATION.md) |
| Custom Deploy | [DEPLOYMENT_AUTOMATION.md](DEPLOYMENT_AUTOMATION.md) |
| Remote Deploy | [DEPLOYMENT_QUICKREF.md](DEPLOYMENT_QUICKREF.md) |
| OIDC Integration | [SERVICES_INTEGRATION_GUIDE.md](SERVICES_INTEGRATION_GUIDE.md) |
| Troubleshooting | [RECOVERY_RUNBOOK.md](RECOVERY_RUNBOOK.md) |

---

## ❓ FAQ

**Q: Какую опцию выбрать для первого раза?**  
A: [1] Quick Deploy - самый простой способ развернуть все сразу.

**Q: Можно ли развернуть только GitLab без остальных?**  
A: Да, используйте [2] Custom Deploy и выберите только "core,gitlab".

**Q: Как обновить уже развернутую систему?**  
A: [3] Remote Deploy с флагом backup, или [5] Service Management → Restart.

**Q: Что делать если сервис не запускается?**  
A: [5] Service Management → [4] View service logs → введите имя сервиса.

**Q: Нужно ли что-то настраивать вручную после деплоя?**  
A: Только OIDC clients в Keycloak - остальное автоматическое.

**Q: Работает ли wizard на Windows?**  
A: Да! Используйте `.\ceres.cmd` или `pwsh scripts/ceres.ps1 interactive`.

---

## 🚀 Быстрый старт (TL;DR)

```powershell
# Запустить wizard
.\ceres.cmd

# Выбрать [1] Quick Deploy
# Подтвердить "yes"
# Ждать 60 секунд
# Открыть http://localhost:8080-8085

# Готово! 🎉
```

---

**Теперь весь CERES разворачивается через один интерактивный wizard!** 🎯
