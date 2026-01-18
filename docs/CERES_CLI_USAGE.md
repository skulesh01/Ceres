# CERES CLI — Руководство пользователя

## Быстрый старт

### 1️⃣ Инициализация (первый раз)
```powershell
cd Ceres
.\scripts\ceres.ps1 init
```

Это проверит зависимости, создаст структуру папок и .env файл.

---

## Основные команды

### 📊 Анализ ресурсов
```powershell
# Узнать, какой профил подходит для вашей машины
.\scripts\ceres.ps1 analyze resources

# Вывод в JSON (для скриптов)
.\scripts\ceres.ps1 analyze resources --format json
```

**Вывод:**
```
[INFO] Analyzing system resources...

System Resources:
  CPU Cores: 12
  RAM: 15 GB
  Disk: 500 GB

Recommendations:
  ✓ Small (4 CPU, 8 GB RAM) - FEASIBLE
  ✓ Medium (10 CPU, 20 GB RAM) - FEASIBLE (NOT ENOUGH RAM)
  ✗ Large (24 CPU, 56 GB RAM) - NOT FEASIBLE
```

---

### ⚙️ Конфигурирование

#### Интерактивный мастер
```powershell
.\scripts\ceres.ps1 configure
```

**Процесс:**
1. Анализирует вашу машину
2. Показывает доступные профили
3. Предлагает выбрать один
4. Сохраняет выбор в DEPLOYMENT_PLAN.json

#### С предустановленным профилем
```powershell
.\scripts\ceres.ps1 configure --preset medium
```

#### Без вопросов (CI/CD режим)
```powershell
.\scripts\ceres.ps1 configure --preset medium --yes
```

---

### 🔨 Генерация конфигураций

#### Всё сразу
```powershell
.\scripts\ceres.ps1 generate from-profile
```

Создаст все файлы из вашего профила:
- terraform.tfvars
- docker-compose.yml
- .env с автогенерированными паролями
- inventory.yml для Ansible

#### По отдельности
```powershell
# Только Terraform конфиг
.\scripts\ceres.ps1 generate terraform

# Только Docker Compose
.\scripts\ceres.ps1 generate docker-compose

# Секреты (.env с паролями)
.\scripts\ceres.ps1 generate secrets
```

---

### ✅ Валидация перед развёртыванием

#### Проверить окружение
```powershell
.\scripts\ceres.ps1 validate environment
```

**Проверяет:**
- Docker версия >= 20.10
- PowerShell версия >= 5.1
- Terraform >= 1.0 (если нужен)
- Kubernetes kubectl (если нужен)

#### Проверить конфликты
```powershell
.\scripts\ceres.ps1 validate conflicts
```

**Проверяет:**
- Занятые порты (80, 443, 5432, 6379, 8080, etc)
- Переменные окружения (.env)
- Сетевые конфликты
- Конфликты хранилища

#### Валидировать профил
```powershell
.\scripts\ceres.ps1 validate profile
```

Проверит DEPLOYMENT_PLAN.json на корректность.

---

### 🚀 Развёртывание

#### Полное развёртывание (рекомендуется)
```powershell
# С подтверждением
.\scripts\ceres.ps1 deploy all

# Без подтверждения (для автоматизации)
.\scripts\ceres.ps1 deploy all --yes
```

**Фазы:**
1. Инфраструктура (создание VM)
2. ОС конфигурация (Ansible)
3. Приложения (Docker/Kubernetes)
4. Post-deploy (Keycloak, SSL, пользователи)

#### По фазам (для контроля)
```powershell
# Фаза 1: Создать виртуальные машины
.\scripts\ceres.ps1 deploy infrastructure

# Фаза 2: Настроить ОС
.\scripts\ceres.ps1 deploy os-config

# Фаза 3: Развернуть приложения
.\scripts\ceres.ps1 deploy applications

# Фаза 4: Финальные настройки
.\scripts\ceres.ps1 deploy post-deploy
```

---

### 📋 Статус

```powershell
# Полный статус всех сервисов
.\scripts\ceres.ps1 status

# Статус конкретного сервиса
.\scripts\ceres.ps1 status --service postgresql

# Вывод в JSON
.\scripts\ceres.ps1 status --format json
```

**Вывод:**
```
Deployment Status:
  Infrastructure: ✓ Running (Proxmox VM)
  PostgreSQL: ✓ Running
  Redis: ✓ Running
  Keycloak: ✓ Running
  Nextcloud: ✓ Running
  Gitea: ✓ Running
  Mattermost: ⧖ Starting
  Grafana: ✗ Failed
  
Last Updated: 2026-01-17 14:23:45
```

---

### 📜 Логи

```powershell
# Логи всех сервисов
.\scripts\ceres.ps1 logs

# Логи конкретного сервиса
.\scripts\ceres.ps1 logs postgresql

# Следить за логами в реальном времени
.\scripts\ceres.ps1 logs postgresql --follow
```

---

### 🔄 Откат

```powershell
# Откат последнего шага
.\scripts\ceres.ps1 rollback last

# Откат на конкретный шаг
.\scripts\ceres.ps1 rollback to-step 2

# Полный откат всего развёртывания
.\scripts\ceres.ps1 rollback full
```

⚠️ **ВНИМАНИЕ:** Запросит подтверждение перед откатом!

---

### 📖 Справка

```powershell
# Главная справка
.\scripts\ceres.ps1 help

# Справка по команде
.\scripts\ceres.ps1 help validate

# Версия
.\scripts\ceres.ps1 --version
```

---

## Типичные сценарии

### 🔧 Сценарий 1: Локальная разработка (Small профил)

```powershell
# Инициализация
.\scripts\ceres.ps1 init

# Анализ
.\scripts\ceres.ps1 analyze resources

# Конфигурация (выберет Small)
.\scripts\ceres.ps1 configure

# Генерация
.\scripts\ceres.ps1 generate from-profile

# Валидация
.\scripts\ceres.ps1 validate environment
.\scripts\ceres.ps1 validate conflicts

# Развёртывание
.\scripts\ceres.ps1 deploy applications
```

**Результат:** Docker Compose с 9 сервисами на локальной машине

---

### 🏢 Сценарий 2: Production на Proxmox (Medium профил)

```powershell
# На машине с Proxmox и Terraform:
.\scripts\ceres.ps1 init

# Выбрать Medium (3 VM)
.\scripts\ceres.ps1 configure --preset medium

# Сгенерировать все конфиги
.\scripts\ceres.ps1 generate from-profile

# Полная валидация
.\scripts\ceres.ps1 validate environment
.\scripts\ceres.ps1 validate conflicts
.\scripts\ceres.ps1 validate profile

# Развернуть всё
.\scripts\ceres.ps1 deploy all --yes
```

**Результат:** 
- 3 VM на Proxmox (core, apps, edge)
- Kubernetes k3s кластер
- Все сервисы в production режиме

---

### ⚡ Сценарий 3: CI/CD автоматизация (GitHub Actions)

```powershell
# Non-interactive режим для автоматизации
.\scripts\ceres.ps1 init --yes
.\scripts\ceres.ps1 configure --preset large --yes
.\scripts\ceres.ps1 validate environment --format json > validation.json
.\scripts\ceres.ps1 generate from-profile
.\scripts\ceres.ps1 deploy all --profile large --yes
```

---

### 🔧 Сценарий 4: Отладка проблемы

```powershell
# 1. Посмотреть статус
.\scripts\ceres.ps1 status

# 2. Посмотреть логи проблемного сервиса
.\scripts\ceres.ps1 logs postgresql

# 3. Если нужно, откатить последний шаг
.\scripts\ceres.ps1 rollback last

# 4. Исправить конфиг
# ... редактируете файл ...

# 5. Повторить развёртывание
.\scripts\ceres.ps1 deploy applications
```

---

### 🔄 Сценарий 5: Обновление конфигурации

```powershell
# 1. Посмотреть текущий план
cat config/DEPLOYMENT_PLAN.json

# 2. Изменить профил (если нужно)
.\scripts\ceres.ps1 configure --preset large

# 3. Сгенерировать новые конфиги
.\scripts\ceres.ps1 generate from-profile

# 4. Валидировать
.\scripts\ceres.ps1 validate conflicts

# 5. Развернуть обновления
.\scripts\ceres.ps1 deploy applications
```

---

## Структура файлов, которые создаются

```
Ceres/
├── config/
│   ├── .env                      # ← Переменные окружения (секреты!)
│   ├── DEPLOYMENT_PLAN.json      # ← Ваш выбранный план (не коммитить!)
│   ├── docker-compose.yml        # ← Для Docker Compose режима
│   ├── terraform.tfvars          # ← Для Terraform режима
│   ├── inventory.yml             # ← Для Ansible
│   └── profiles/
│       ├── small.json
│       ├── medium.json
│       └── large.json
│
├── logs/
│   └── ceres-2026-01-17.log      # ← Все операции логируются сюда
│
└── scripts/
    ├── ceres.ps1                 # ← ГЛАВНОЕ ПРИЛОЖЕНИЕ
    └── _lib/
        ├── Common.ps1
        ├── Validate.ps1          # (будет)
        ├── Generate.ps1          # (будет)
        ├── Deploy.ps1            # (будет)
        └── ...
```

---

## 🚨 Важные файлы (НЕ КОММИТИТЬ!)

```gitignore
config/.env                      # Содержит пароли!
config/DEPLOYMENT_PLAN.json      # Содержит IP и секреты!
config/docker-compose.yml        # Может быть персональным
config/terraform.tfvars          # Может быть персональным
logs/                            # Логи окружения
```

---

## 📝 Логирование

Все команды пишут логи в `logs/ceres-YYYY-MM-DD.log`:

```
[2026-01-17 14:23:45] [INFO] Starting CERES CLI
[2026-01-17 14:23:46] [CHECK] Docker version: 24.0.6 ✓
[2026-01-17 14:23:47] [CHECK] PowerShell version: 7.2 ✓
[2026-01-17 14:23:48] [WARN] Port 80 already in use
[2026-01-17 14:23:49] [OK] Configuration saved
```

Просмотреть логи:
```powershell
Get-Content logs/ceres-*.log | Select-Object -Last 50
```

---

## Exit codes

| Код | Значение |
|-----|----------|
| 0 | Успех ✓ |
| 1 | Ошибка инициализации |
| 2 | Неверная команда/аргумент |
| 3 | Ошибка валидации окружения |
| 4 | Ошибка конфигурации |
| 5 | Ошибка развёртывания |
| 99 | Неизвестная ошибка |

Использование в скриптах:
```powershell
.\scripts\ceres.ps1 validate environment
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK, можно развёртывать"
} else {
    Write-Host "Ошибка валидации"
    exit 1
}
```

---

## 💡 Полезные флаги

```powershell
# Неинтерактивный режим (для скриптов)
.\scripts\ceres.ps1 configure --yes

# JSON вывод (для парсинга)
.\scripts\ceres.ps1 analyze resources --format json

# С предустановкой профила
.\scripts\ceres.ps1 deploy all --profile medium --yes

# Помощь по команде
.\scripts\ceres.ps1 help <команда>
```

---

## 🔗 Дополнительно

Полная архитектура: [CERES_CLI_ARCHITECTURE.md](CERES_CLI_ARCHITECTURE.md)  
Примеры использования: [examples/](examples/)  
Документация по профилам: [config/profiles/README.md](config/profiles/README.md)

---

**Готов начать?**
```powershell
.\scripts\ceres.ps1 init
```
