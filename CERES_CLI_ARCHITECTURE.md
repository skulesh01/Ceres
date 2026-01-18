# CERES CLI — Архитектура единого приложения

## Концепция
Вместо десятков скриптов в разных папках — **одно приложение** `ceres.ps1` с подкомандами:

```bash
ceres validate environment
ceres validate conflicts
ceres analyze resources
ceres configure --preset medium
ceres generate from-profile
ceres generate terraform
ceres generate docker-compose
ceres generate secrets
ceres deploy infrastructure
ceres deploy applications
ceres deploy post-deploy
ceres status
ceres help
```

---

## Структура

### Главный файл: `scripts/ceres.ps1`
**Точка входа** (200 строк). Отвечает за:
- Парсинг аргументов и подкоманд
- Загрузку модулей
- Маршрутизацию к нужной команде
- Error handling и логирование
- Exit codes

### Модули в `scripts/_lib/`

#### 1. **Common.ps1** (250 строк)
Общие функции для всех:
```powershell
Initialize-CeresEnv        # Инициализация переменных, проверка .env
Get-CeresConfig            # Загрузить конфиг
Write-CeresLog             # Логирование с таймстампом
Write-CeresError           # Логирование ошибок
Test-Command               # Проверить наличие команды (docker, terraform, etc)
Get-ProfilePath            # Путь до профила
Get-TemplatePath           # Путь до шаблона
ConvertTo-CeresObject      # Парсинг JSON в объект
```

#### 2. **Validate.ps1** (300 строк)
Валидация окружения:
```powershell
Test-Environment           # Docker, PowerShell версия, зависимости
Test-Conflicts            # Проверка портов, переменных, сетей
Test-ResourceProfile      # Валидация выбранного профила
Get-ValidationReport      # Полный отчет о готовности
```

#### 3. **Analyze.ps1** (200 строк)
Анализ ресурсов (переработанный analyze-resources.ps1):
```powershell
Get-SystemResources       # CPU, RAM, Disk, Networks
Get-ProfileRecommendations # Какие профили подходят
Format-AnalysisReport     # Красивый вывод
```

#### 4. **Configure.ps1** (250 строк)
Конфигурирование (переработанный configure-ceres.ps1):
```powershell
Show-ConfigWizard         # Интерактивный мастер
Select-Profile            # Меню выбора профила
Create-DeploymentPlan     # Генерация плана
Export-DeploymentPlan     # Сохранить как JSON
```

#### 5. **Generate.ps1** (400 строк)
Генерация конфигов из профила:
```powershell
New-TerraformConfig       # terraform.tfvars из профила
New-DockerComposeConfig   # docker-compose.yml с лимитами
New-EnvironmentFile       # .env с генерацией паролей
New-SecretsFile           # Sealed Secrets для K8s
New-AnsibleInventory      # inventory.yml для VM
```

#### 6. **Deploy.ps1** (350 строк)
Развёртывание:
```powershell
Deploy-Infrastructure     # Terraform apply
Deploy-OsConfiguration    # Ansible playbook
Deploy-Applications       # Docker Compose или kubectl
Deploy-PostDeploy         # Keycloak bootstrap, SSL, etc
Get-DeploymentStatus      # Статус текущего развёртывания
Rollback-Deployment       # Откат по шагам
```

#### 7. **Utils.ps1** (150 строк)
Утилиты:
```powershell
Invoke-Command-Safe       # Выполнить с error handling
Wait-ForService           # Ждать пока сервис запустится
Test-Port                 # Проверить открыт ли порт
Get-AvailablePort         # Найти свободный порт
New-SecurePassword        # Генерировать пароль
ConvertFrom-EnvFile       # Парсинг .env
```

---

## Регламент использования

### Инициализация
```bash
# Первый запуск — полная инициализация
ceres init

# Это сделает:
# 1. Проверит зависимости (Docker, PowerShell 5.1+, etc)
# 2. Создаст структуру папок
# 3. Скопирует .env.example → .env
# 4. Запустит analyze + configure
```

### Основной workflow
```bash
# 1. Анализ
ceres analyze resources          # Показать рекомендации

# 2. Конфигурирование
ceres configure --preset medium  # Или интерактивно без флага

# 3. Генерация
ceres generate from-profile      # Все конфиги сразу
# или по отдельности:
ceres generate terraform
ceres generate docker-compose
ceres generate secrets

# 4. Валидация перед деплоем
ceres validate environment
ceres validate conflicts
ceres validate profile

# 5. Развёртывание
ceres deploy infrastructure      # Создать VM (Terraform)
ceres deploy os-config          # Настроить ОС (Ansible)
ceres deploy applications       # Запустить приложения
ceres deploy post-deploy        # Настройки после деплоя

# 6. Мониторинг
ceres status                     # Статус всех сервисов
ceres logs [service]            # Логи сервиса
```

### Полное развёртывание одной командой
```bash
# Режим non-interactive (для CI/CD)
ceres deploy all --profile medium --yes
```

### Откат
```bash
ceres rollback last              # Откат последнего шага
ceres rollback to-step 3         # Откат на шаг 3
ceres rollback full              # Полный откат
```

---

## Структура папок (НОВАЯ)

```
Ceres/
├── scripts/
│   ├── ceres.ps1                 ← ГЛАВНОЕ ПРИЛОЖЕНИЕ
│   ├── _lib/
│   │   ├── Common.ps1            ← Общие функции
│   │   ├── Validate.ps1          ← Модуль валидации
│   │   ├── Analyze.ps1           ← Модуль анализа
│   │   ├── Configure.ps1         ← Модуль конфигурации
│   │   ├── Generate.ps1          ← Модуль генерации
│   │   ├── Deploy.ps1            ← Модуль развёртывания
│   │   └── Utils.ps1             ← Утилиты
│   └── tests/
│       ├── validate.tests.ps1
│       ├── generate.tests.ps1
│       └── deploy.tests.ps1
│
├── config/
│   ├── profiles/
│   │   ├── small.json
│   │   ├── medium.json
│   │   └── large.json
│   ├── templates/
│   │   ├── terraform.tfvars.tpl
│   │   ├── docker-compose.yml.tpl
│   │   ├── .env.tpl
│   │   ├── inventory.yml.tpl
│   │   └── README.md
│   ├── validation/
│   │   ├── requirements.json      ← требования к окружению
│   │   ├── port-conflicts.json    ← конфликты портов
│   │   └── environment-vars.json  ← переменные
│   └── .env.example              ← шаблон переменных
│
└── docs/
    └── CLI_USAGE.md              ← справка пользователя
```

---

## Примеры использования

### Сценарий 1: Разработчик на локальной машине
```bash
# Клонировал проект
git clone https://github.com/...

# Чтобы начать:
cd Ceres
powershell -File scripts/ceres.ps1 init
# → проверит Docker, создаст .env, запустит wizard

powershell -File scripts/ceres.ps1 configure
# → интерактивный мастер, выберет Small профил

powershell -File scripts/ceres.ps1 generate docker-compose
# → создаст config/compose/docker-compose.yml с лимитами

powershell -File scripts/ceres.ps1 deploy applications
# → запустит docker compose up
```

### Сценарий 2: DevOps на Proxmox (GitHub Actions)
```bash
# В GitHub Actions runner:
powershell -File scripts/ceres.ps1 analyze resources
# → выведет JSON с рекомендациями

powershell -File scripts/ceres.ps1 deploy all \
  --profile medium \
  --target proxmox \
  --yes

# → создаст 3 VM, настроит ОС, развернёт приложения, бутстрапит Keycloak
```

### Сценарий 3: Откат после ошибки
```bash
powershell -File scripts/ceres.ps1 status
# → FAIL: Docker PostgreSQL не стартует

powershell -File scripts/ceres.ps1 logs postgresql
# → показывает ошибку

powershell -File scripts/ceres.ps1 rollback last
# → откатывает развёртывание

powershell -File scripts/ceres.ps1 deploy applications
# → повторный деплой
```

---

## Exit codes

```
0   = успех
1   = ошибка инициализации
2   = ошибка парсинга команды
3   = ошибка валидации окружения
4   = ошибка генерации конфигов
5   = ошибка развёртывания
99  = неизвестная ошибка
```

---

## Help система

```bash
ceres help                        # Список команд
ceres help validate              # Справка по validate
ceres help validate environment  # Справка по конкретной команде
ceres --version                  # Версия
ceres --list-profiles            # Список профилов
```

---

## Logging

Все логи пишутся в `logs/ceres-{date}.log`:
```
[2026-01-17 14:23:45] [INFO]  Starting CERES CLI v1.0
[2026-01-17 14:23:46] [CHECK] Docker version: 24.0.6 ✓
[2026-01-17 14:23:47] [CHECK] PowerShell version: 7.2 ✓
[2026-01-17 14:23:48] [WARN]  Port 80 already in use
[2026-01-17 14:23:49] [INFO]  Recommending profile: Medium (3 VMs)
[2026-01-17 14:23:50] [OK]    Configuration saved to DEPLOYMENT_PLAN.json
```

---

## Интеграция с Windows

### Создание ярлыка на рабочий стол
```powershell
# scripts/ceres-shortcut.ps1
$shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:USERPROFILE\Desktop\CERES.lnk")
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-NoExit -File '$pwd\scripts\ceres.ps1'"
$shortcut.Save()
```

### Добавление в PATH (опционально)
```powershell
# Создать ceres.bat в папке из PATH
@echo off
powershell -File C:\path\to\Ceres\scripts\ceres.ps1 %*
```

Тогда можно просто писать:
```bash
ceres analyze resources
ceres configure
```

---

## Roadmap (Фазы реализации)

### Фаза 1 (эта неделя): CLI каркас + базовые команды
- [ ] Создать `ceres.ps1` с парсингом аргументов
- [ ] Реализовать `Common.ps1` (логирование, инициализация)
- [ ] Реализовать `ceres init`
- [ ] Реализовать `ceres help`
- [ ] Интегрировать существующие скрипты (analyze, configure)

### Фаза 2 (следующая неделя): Валидация и генерация
- [ ] Реализовать `Validate.ps1`
- [ ] Реализовать `Generate.ps1`
- [ ] Все команды `ceres validate *`
- [ ] Все команды `ceres generate *`

### Фаза 3: Развёртывание
- [ ] Реализовать `Deploy.ps1`
- [ ] Все команды `ceres deploy *`
- [ ] Откат функциональность
- [ ] GitHub Actions интеграция

### Фаза 4: Polish & Tests
- [ ] Unit тесты для модулей
- [ ] Integration тесты
- [ ] Документация
- [ ] Windows/Linux тестирование

---

## Преимущества CLI подхода

✅ **Один файл для запуска** (scripts/ceres.ps1)  
✅ **Логичная организация** (команды, подкоманды)  
✅ **Легко расширяемо** (добавить новую команду = новая функция)  
✅ **Профессиональный вид** (как Docker CLI, Terraform CLI)  
✅ **Easy CI/CD** (non-interactive режим)  
✅ **Встроенная справка** (ceres help)  
✅ **Логирование централизовано** (один файл логов)  
✅ **Exit codes** (для scripts и automation)  

---

## Первый шаг

Начнём с создания:
1. **scripts/ceres.ps1** — главное приложение
2. **scripts/_lib/Common.ps1** — общие функции
3. **CERES_CLI_USAGE.md** — справка для пользователей

Поехали! 🚀
