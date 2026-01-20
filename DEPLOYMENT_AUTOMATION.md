# CERES Deployment Automation

## Автоматизация развертывания

Все настройки и развертывание CERES теперь полностью автоматизированы через несколько слоев:

### 🔧 Уровень 1: Локальное развертывание

**Makefile** - основные команды для управления:
```bash
make deploy                 # Локальный деплой с auto-setup
make deploy-prod            # Деплой на удаленный сервер
make setup-integration      # Настройка OIDC интеграции
make verify-integration     # Проверка интеграции
```

**setup-services.sh** - автоматическая настройка:
- ✅ Генерация OIDC secrets
- ✅ Создание Docker сетей
- ✅ Инициализация баз данных
- ✅ Деплой всех сервисов с интеграцией
- ✅ Проверка prerequisites

### 🚀 Уровень 2: CI/CD Pipeline

**.gitlab-ci.yml** - автоматический CI/CD с 5 стадиями:

#### Stage 1: Validate
- Проверка Docker Compose конфигурации
- Валидация environment переменных
- Проверка наличия обязательных параметров

#### Stage 2: Test
- Syntax check всех shell скриптов через shellcheck
- Интеграционные тесты (если доступны)
- Проверка Python скриптов

#### Stage 3: Build
- Генерация OIDC secrets для всех сервисов
- Подготовка .env файла
- Создание artifacts для деплоя

#### Stage 4: Deploy
**Staging** (develop branch):
```yaml
deploy:staging:
  - Подключение по SSH к staging серверу
  - Git pull последних изменений
  - Запуск setup-services.sh
  - Проверка статуса сервисов
```

**Production** (main branch):
```yaml
deploy:production:
  - Создание backup перед деплоем
  - Git pull последних изменений (main)
  - Запуск setup-services.sh
  - Health check критических сервисов (PostgreSQL, Redis)
```

#### Stage 5: Verify
- HTTP проверка всех 6 сервисов (8080-8085)
- Проверка Keycloak OIDC discovery endpoint
- Интеграционные тесты OIDC flow

**Rollback** (manual trigger):
- Восстановление из последнего backup
- Перезапуск сервисов
- Проверка статуса

### 🌐 Уровень 3: Remote Deployment

**scripts/remote-deploy.sh** - удаленное развертывание:

```bash
# Использование:
make deploy-prod SSH_HOST=192.168.1.3 SSH_USER=root

# Или напрямую:
bash scripts/remote-deploy.sh 192.168.1.3 root --backup
```

**Процесс:**
1. ✅ Проверка SSH подключения
2. ✅ Проверка prerequisites на сервере (Docker, Git)
3. ✅ Sync файлов через Git pull/clone
4. ✅ Опциональный backup перед деплоем (--backup flag)
5. ✅ Запуск setup-services.sh на сервере
6. ✅ Проверка health сервисов
7. ✅ Вывод URLs для доступа

### 📋 Workflow примеры

#### Пример 1: Локальное развертывание
```bash
cd /opt/Ceres
make deploy
```
Автоматически:
- Генерирует secrets
- Создает Docker сети
- Разворачивает 7 сервисов
- Настраивает OIDC интеграцию

#### Пример 2: Деплой на production сервер
```bash
# Из локальной машины
cd ~/projects/Ceres
make deploy-prod SSH_HOST=192.168.1.3 SSH_USER=root
```
Автоматически:
- Подключается по SSH
- Синхронизирует код через Git
- Создает backup
- Запускает полный деплой
- Проверяет health

#### Пример 3: GitLab CI/CD автодеплой
```bash
# Просто push в ветку
git add .
git commit -m "Feat: Update configuration"
git push origin develop      # → auto-deploy to staging

git push origin main         # → manual approval → production
```

Pipeline автоматически:
1. Валидирует конфигурацию
2. Запускает тесты
3. Генерирует secrets
4. Деплоит на staging/production
5. Проверяет интеграцию

### 🔐 GitLab CI/CD Variables

Необходимо настроить в GitLab → Settings → CI/CD → Variables:

```yaml
SSH_PRIVATE_KEY      # SSH ключ для подключения к серверу
DEPLOY_HOST          # IP/hostname сервера (192.168.1.3)
DEPLOY_USER          # SSH пользователь (root)
DOMAIN               # Домен для сервисов (example.com)
```

### 📊 Мониторинг деплоя

**Проверка статуса локально:**
```bash
make status              # Общий статус
make verify-integration  # Проверка OIDC интеграции
make logs service=keycloak  # Логи конкретного сервиса
```

**Проверка на удаленном сервере:**
```bash
ssh root@192.168.1.3 'cd /opt/Ceres && docker compose ps'
ssh root@192.168.1.3 'cd /opt/Ceres && docker compose logs -f keycloak'
```

**GitLab CI/CD мониторинг:**
- Открыть GitLab → CI/CD → Pipelines
- Посмотреть статус каждой стадии
- Проверить логи verify:services и verify:integration

### 🔄 Rollback при проблемах

**Автоматический rollback через GitLab:**
1. Открыть GitLab → CI/CD → Pipelines
2. Найти pipeline с успешным деплоем
3. Нажать "Rollback" (manual job)

**Ручной rollback:**
```bash
# На сервере
cd /opt/Ceres
LATEST_BACKUP=$(ls -t backups/*.tar.gz | head -n1)
bash scripts/restore.sh $LATEST_BACKUP
docker compose down && docker compose up -d
```

### 📝 Структура автоматизации

```
Ceres/
├── .gitlab-ci.yml                    # CI/CD pipeline (5 stages)
├── Makefile                          # Make команды для управления
├── setup-services.sh                 # Auto-setup с OIDC secrets
├── setup-services.ps1                # PowerShell версия
├── scripts/
│   ├── remote-deploy.sh              # SSH deployment script
│   ├── backup.sh                     # Backup automation
│   ├── restore.sh                    # Restore automation
│   └── start.sh                      # Service startup
├── config/
│   └── compose/
│       ├── base.yml                  # Базовая конфигурация
│       ├── core.yml                  # PostgreSQL + Redis
│       └── apps.yml                  # 6 сервисов + OIDC
└── .env.example                      # Template с OIDC secrets
```

### ✅ Преимущества автоматизации

1. **Zero Manual Configuration**
   - Нет ручных настроек на сервере
   - Все через Git + CI/CD
   - Воспроизводимые деплои

2. **Automated Secrets Management**
   - OIDC secrets генерируются автоматически
   - Хранятся в .env (не в Git)
   - Ротация через rerun pipeline

3. **Multi-Environment Support**
   - Staging (develop branch) - автоматический деплой
   - Production (main branch) - manual approval
   - Rollback в 1 клик

4. **Health Verification**
   - Автоматическая проверка после деплоя
   - HTTP checks всех сервисов
   - OIDC integration verification

5. **Disaster Recovery**
   - Автоматический backup перед деплоем
   - One-command rollback
   - Git-based восстановление

### 🎯 Следующие шаги

После настройки автоматизации:

1. **Локальный тест:**
   ```bash
   make deploy
   make verify-integration
   ```

2. **Настройка GitLab CI/CD:**
   - Добавить variables (SSH_PRIVATE_KEY, DEPLOY_HOST, etc.)
   - Push в develop → staging auto-deploy
   - Push в main → production manual deploy

3. **Первый production деплой:**
   ```bash
   # Вариант 1: Через make
   make deploy-prod SSH_HOST=192.168.1.3 SSH_USER=root
   
   # Вариант 2: Через GitLab CI/CD
   git push origin main
   # → Open GitLab → Pipelines → Click "Deploy to Production"
   ```

4. **Мониторинг:**
   - Проверить URLs: http://192.168.1.3:8080-8085
   - Настроить Keycloak OIDC clients
   - Протестировать login flow

### 📖 Документация

Детальные гайды:
- [SERVICES_INTEGRATION_GUIDE.md](SERVICES_INTEGRATION_GUIDE.md) - OIDC интеграция
- [QUICKSTART_WITH_INTEGRATION.md](QUICKSTART_WITH_INTEGRATION.md) - Быстрый старт
- [COMPLETE_DOCUMENTATION_INDEX.md](COMPLETE_DOCUMENTATION_INDEX.md) - Общий индекс

---

**Все развертывание теперь автоматизировано - никаких ручных действий на сервере!** 🚀
