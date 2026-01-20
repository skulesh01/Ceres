# CERES Deployment - Quick Reference

## 🚀 Автоматическое развертывание (рекомендуется)

### Вариант 1: Make команды (проще всего)

```bash
# Локальное развертывание
make deploy

# Развертывание на production сервер
make deploy-prod SSH_HOST=192.168.1.3 SSH_USER=root

# Проверка интеграции
make verify-integration
```

### Вариант 2: GitLab CI/CD (production-ready)

```bash
# Push в develop → автоматический деплой на staging
git push origin develop

# Push в main → manual approval → production
git push origin main
# Затем: GitLab → CI/CD → Pipelines → "Deploy to Production"
```

### Вариант 3: Прямой запуск скриптов

```bash
# Локально
bash setup-services.sh

# На удаленном сервере
bash scripts/remote-deploy.sh 192.168.1.3 root --backup
```

---

## 📋 Что происходит автоматически

### setup-services.sh делает:
1. ✅ Генерирует OIDC secrets (GitLab, Mattermost, Redmine, Wiki.js)
2. ✅ Создает Docker network (compose_internal)
3. ✅ Создает .env из .env.example (если нет)
4. ✅ Проверяет Docker, Docker Compose
5. ✅ Запускает все сервисы с интеграцией
6. ✅ Показывает URLs для доступа

### GitLab CI/CD pipeline делает:
1. ✅ **Validate** - проверяет YAML конфигурацию
2. ✅ **Test** - shellcheck + integration tests
3. ✅ **Build** - генерирует secrets
4. ✅ **Deploy** - SSH на сервер + git pull + setup-services.sh
5. ✅ **Verify** - HTTP checks + OIDC discovery test

### remote-deploy.sh делает:
1. ✅ Проверяет SSH подключение
2. ✅ Проверяет prerequisites на сервере
3. ✅ Git clone/pull на сервер (/opt/Ceres)
4. ✅ Создает backup (если флаг --backup)
5. ✅ Запускает setup-services.sh
6. ✅ Проверяет health сервисов

---

## 🎯 Рекомендуемый workflow

### Первоначальное развертывание:

```bash
# 1. Клонируем репозиторий на локальную машину
git clone <repo-url> ~/projects/Ceres
cd ~/projects/Ceres

# 2. Тестируем локально (опционально)
make deploy

# 3. Деплоим на production сервер
make deploy-prod SSH_HOST=192.168.1.3 SSH_USER=root
```

### Обновления в будущем:

**Вариант A: Через GitLab CI/CD** (production-ready)
```bash
# Делаем изменения
git add .
git commit -m "Feat: Update config"
git push origin main

# Открываем GitLab → CI/CD → Pipelines
# Жмем "Deploy to Production"
# Pipeline автоматически:
#   - Создаст backup
#   - Sync изменений на сервер
#   - Перезапустит сервисы
#   - Проверит health
```

**Вариант B: Через Make** (быстрее для срочных изменений)
```bash
git add .
git commit -m "Fix: Urgent config update"
git push origin main

make deploy-prod SSH_HOST=192.168.1.3 SSH_USER=root
```

**Вариант C: Прямо на сервере** (НЕ рекомендуется, только для emergency)
```bash
ssh root@192.168.1.3
cd /opt/Ceres
git pull origin main
bash setup-services.sh <<< "yes"
```

---

## ⚙️ GitLab CI/CD переменные

Настроить в GitLab → Settings → CI/CD → Variables:

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `SSH_PRIVATE_KEY` | (содержимое ~/.ssh/id_rsa) | ✅ | ✅ |
| `DEPLOY_HOST` | 192.168.1.3 | ✅ | ❌ |
| `DEPLOY_USER` | root | ✅ | ❌ |
| `DOMAIN` | ceres.local | ❌ | ❌ |

---

## 🔍 Проверка статуса

### После деплоя:

```bash
# Вариант 1: Make команда
make status

# Вариант 2: SSH на сервер
ssh root@192.168.1.3 'cd /opt/Ceres && docker compose ps'

# Вариант 3: Через GitLab CI/CD
# GitLab → CI/CD → Pipelines → последний успешный → verify:services
```

### Проверка интеграции:

```bash
# Локально
make verify-integration

# На сервере
ssh root@192.168.1.3 << 'EOF'
curl -sf http://localhost:8080/auth/realms/master/.well-known/openid-configuration
EOF
```

---

## 📊 Service URLs после деплоя

| Service | Direct Port | Production URL |
|---------|-------------|----------------|
| **Keycloak** | http://192.168.1.3:8080 | https://auth.ceres.local |
| **GitLab** | http://192.168.1.3:8081 | https://gitlab.ceres.local |
| **Nextcloud** | http://192.168.1.3:8082 | https://nextcloud.ceres.local |
| **Redmine** | http://192.168.1.3:8083 | https://redmine.ceres.local |
| **Wiki.js** | http://192.168.1.3:8084 | https://wiki.ceres.local |
| **Mattermost** | http://192.168.1.3:8085 | https://chat.ceres.local |

---

## 🔄 Rollback при проблемах

### Автоматический (GitLab CI/CD):
```
GitLab → CI/CD → Pipelines → Rollback (manual job)
```

### Ручной:
```bash
ssh root@192.168.1.3
cd /opt/Ceres
LATEST_BACKUP=$(ls -t backups/*.tar.gz | head -n1)
bash scripts/restore.sh $LATEST_BACKUP
docker compose down && docker compose up -d
```

---

## 📖 Детальная документация

- [DEPLOYMENT_AUTOMATION.md](DEPLOYMENT_AUTOMATION.md) - Полное описание автоматизации
- [SERVICES_INTEGRATION_GUIDE.md](SERVICES_INTEGRATION_GUIDE.md) - OIDC интеграция
- [QUICKSTART_WITH_INTEGRATION.md](QUICKSTART_WITH_INTEGRATION.md) - Пошаговый гайд
- [.gitlab-ci.yml](.gitlab-ci.yml) - CI/CD pipeline конфигурация

---

## ❓ FAQ

**Q: Нужно ли настраивать что-то вручную на сервере?**  
A: Нет! Все настройки автоматические через Git + CI/CD.

**Q: Как обновить конфигурацию сервисов?**  
A: Отредактировать `config/compose/*.yml` → `git push` → CI/CD автоматически задеплоит.

**Q: Что делать если сервис не запускается?**  
A: `make logs service=<имя_сервиса>` или `ssh root@... 'cd /opt/Ceres && docker compose logs <сервис>'`

**Q: Можно ли откатить деплой?**  
A: Да, либо через GitLab CI/CD (Rollback job), либо вручную через `scripts/restore.sh`

**Q: Нужно ли вручную создавать OIDC clients в Keycloak?**  
A: Да, это пока единственный ручной шаг. Запланировано автоматизировать через Keycloak API.

---

**Весь деплой теперь автоматизирован - просто `make deploy-prod` или GitLab CI/CD!** 🚀
