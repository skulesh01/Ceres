# 🔄 CERES GitOps Guide

Полное руководство по GitOps автоматизации CERES платформы.

## 📋 Содержание

- [Что такое GitOps?](#что-такое-gitops)
- [Архитектура](#архитектура)
- [Компоненты](#компоненты)
- [Быстрый старт](#быстрый-старт)
- [CI/CD Pipeline](#cicd-pipeline)
- [Управление секретами](#управление-секретами)
- [Multi-Environment](#multi-environment)
- [Best Practices](#best-practices)

## 🎯 Что такое GitOps?

**GitOps** — методология управления инфраструктурой и приложениями, где Git является единственным источником истины (Single Source of Truth).

### Принципы GitOps:

1. **Декларативность** — вся инфраструктура описана декларативно
2. **Версионирование** — вся конфигурация в Git с историей изменений
3. **Автоматизация** — автоматическое применение изменений из Git
4. **Непрерывная синхронизация** — состояние системы = состоянию в Git

### Преимущества для CERES:

✅ **Автоматическое развертывание** — push в Git → автодеплой  
✅ **Audit trail** — полная история изменений в Git  
✅ **Easy rollback** — откат = git revert  
✅ **Disaster recovery** — восстановление из Git  
✅ **Multi-environment** — dev/staging/prod из одного репозитория  

## 🏗️ Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                     Developer Workflow                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ git push
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        GitHub Repository                     │
│  ├── config/compose/       (Docker Compose files)           │
│  ├── terraform/            (Infrastructure as Code)         │
│  ├── ansible/              (Configuration Management)       │
│  ├── flux/                 (GitOps manifests)               │
│  └── .github/workflows/    (CI/CD pipelines)                │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┼─────────────┐
                │             │             │
                ▼             ▼             ▼
         ┌──────────┐  ┌──────────┐  ┌──────────┐
         │   Dev    │  │ Staging  │  │   Prod   │
         │ Environment│ Environment│ Environment│
         └──────────┘  └──────────┘  └──────────┘
                │             │             │
                ▼             ▼             ▼
         GitHub Actions   GitHub Actions   GitHub Actions
                │             │             │
                ▼             ▼             ▼
            Terraform     Terraform     Terraform
         (creates VMs) (creates VMs) (creates VMs)
                │             │             │
                ▼             ▼             ▼
            Ansible       Ansible       Ansible
         (configures)  (configures)  (configures)
                │             │             │
                ▼             ▼             ▼
           Docker Compose Docker Compose Docker Compose
         (runs CERES)  (runs CERES)  (runs CERES)
```

## 🔧 Компоненты

### 1. **Terraform** — Infrastructure as Code

Автоматическое создание 3 VM в Proxmox:

```bash
cd terraform/
terraform init
terraform plan
terraform apply
```

**Файлы:**
- `main.tf` — определение VM
- `variables.tf` — переменные (CPU, RAM, IP)
- `terraform.tfvars` — значения для production

### 2. **Ansible** — Configuration Management

Настройка и развертывание CERES на VM:

```bash
cd ansible/
ansible-playbook -i inventory/production.yml deploy.yml
```

**Роли:**
- `common` — базовая настройка системы
- `docker` — установка Docker
- `ceres-core` — PostgreSQL, Redis, Keycloak
- `ceres-apps` — Nextcloud, Gitea, Mattermost
- `ceres-edge` — Caddy, Prometheus, Grafana

### 3. **FluxCD** — GitOps Operator (опционально для K8s)

Автоматическая синхронизация кластера Kubernetes с Git:

```bash
cd flux/
./bootstrap.sh yourusername ceres production
```

### 4. **GitHub Actions** — CI/CD Automation

Автоматические пайплайны при push/PR:

- **Validate** — проверка синтаксиса
- **Security Scan** — Trivy, TruffleHog
- **Deploy Dev** — автодеплой в dev на push в develop
- **Deploy Staging** — автодеплой staging при PR
- **Deploy Production** — деплой prod при merge в main
- **Rollback** — автоматический откат при ошибках

## 🚀 Быстрый старт

### Шаг 1: Подготовка репозитория

```bash
# Клонируйте репозиторий
git clone https://github.com/yourusername/ceres.git
cd ceres

# Создайте ветки для окружений
git checkout -b develop
git checkout -b staging
git checkout main
```

### Шаг 2: Настройка секретов в GitHub

В Settings → Secrets and Variables → Actions добавьте:

- `PROXMOX_API_URL` — https://192.168.1.3:8006/api2/json
- `PROXMOX_API_TOKEN` — токен доступа к Proxmox
- `DEV_SSH_KEY` — приватный SSH ключ для dev
- `STAGING_SSH_KEY` — приватный SSH ключ для staging
- `PROD_SSH_KEY` — приватный SSH ключ для production
- `MATTERMOST_WEBHOOK` — webhook для уведомлений

### Шаг 3: Создание инфраструктуры

```bash
# Локально: создайте VM через Terraform
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Отредактируйте terraform.tfvars

terraform init
terraform apply

# Запишите IP адреса VM
terraform output
```

### Шаг 4: Обновление инвентаря Ansible

```bash
# Обновите IP адреса в ansible/inventory/production.yml
nano ansible/inventory/production.yml
```

### Шаг 5: Первое развертывание

```bash
# Локально: разверните через Ansible
cd ansible/
ansible-playbook -i inventory/production.yml deploy.yml

# Или через GitHub Actions:
git add .
git commit -m "feat: initial production deployment"
git push origin main
# GitHub Actions автоматически задеплоит
```

### Шаг 6: Автоматизация дальнейших обновлений

Теперь любой push в main автоматически деплоится:

```bash
# Внесите изменения
nano config/compose/apps.yml

# Закоммитьте и запушьте
git add .
git commit -m "feat: add new service"
git push origin main

# GitHub Actions автоматически:
# 1. Проверит изменения
# 2. Запустит security scan
# 3. Сделает backup
# 4. Задеплоит обновление
# 5. Проверит health
# 6. Уведомит в Mattermost
```

## 🔄 CI/CD Pipeline

### Development (develop branch)

```yaml
On: push to develop
→ Validate configs
→ Security scan
→ Deploy to dev VMs (192.168.1.20-22)
→ Health check
```

### Staging (PR to main)

```yaml
On: Pull Request to main
→ Validate configs
→ Security scan
→ Deploy to staging VMs (192.168.1.30-32)
→ Run smoke tests
→ Wait for approval
```

### Production (merge to main)

```yaml
On: merge to main
→ Validate configs
→ Security scan
→ Backup current state
→ Deploy to prod VMs (192.168.1.10-12)
→ Health check
→ Notify team
→ [If fails] → Auto-rollback
```

## 🔐 Управление секретами

### Sealed Secrets (Kubernetes)

```bash
# Создайте sealed secrets
cd flux/
./setup-sealed-secrets.sh

# Создайте секреты для CERES
cd ../config
./create-sealed-secrets.sh ceres-system

# Sealed secrets можно коммитить в Git!
git add sealed-secrets/
git commit -m "Add sealed secrets"
git push
```

### Ansible Vault (Docker Compose)

```bash
# Зашифруйте чувствительные файлы
ansible-vault encrypt ansible/group_vars/all/secrets.yml

# Используйте при деплое
ansible-playbook -i inventory/production.yml deploy.yml --ask-vault-pass

# Или с файлом пароля
ansible-playbook -i inventory/production.yml deploy.yml --vault-password-file ~/.vault_pass
```

### GitHub Secrets

Храните в GitHub Secrets:
- SSH ключи
- API токены
- Пароли баз данных
- Webhook URLs

**НЕ коммитьте в Git:**
- `terraform.tfvars` (содержит пароли)
- `config/.env` (содержит секреты)
- SSH приватные ключи

## 🌍 Multi-Environment

### Development

```bash
Branch: develop
VMs: 192.168.1.20-22
Domain: dev.ceres.local
Auto-deploy: on every push
```

### Staging

```bash
Branch: staging
VMs: 192.168.1.30-32
Domain: staging.ceres.local
Auto-deploy: on PR to main
```

### Production

```bash
Branch: main
VMs: 192.168.1.10-12
Domain: ceres.company.com
Auto-deploy: on merge to main (with approval)
```

## 📊 Мониторинг GitOps

### GitHub Actions

```bash
# Смотрите статус в GitHub UI
https://github.com/yourusername/ceres/actions

# Или через CLI
gh run list
gh run view <run-id>
gh run watch
```

### FluxCD (если используете)

```bash
# Статус всех ресурсов
flux get all

# Логи
flux logs --follow

# Принудительная синхронизация
flux reconcile kustomization ceres-core --with-source
```

### Ansible

```bash
# Проверка без применения изменений
ansible-playbook -i inventory/production.yml deploy.yml --check

# С показом diff
ansible-playbook -i inventory/production.yml deploy.yml --check --diff
```

## 📝 Best Practices

### 1. Используйте ветки

```bash
main → production (только merges)
staging → staging environment
develop → development (активная разработка)
feature/* → feature branches
```

### 2. Code Review обязателен

- Все изменения через Pull Requests
- Требуйте approval перед merge в main
- Запускайте CI/CD на PR

### 3. Тестируйте изменения

```bash
# Локально перед push
docker compose -f config/compose/*.yml config
terraform validate
ansible-playbook --syntax-check deploy.yml

# В dev окружении перед staging
# В staging перед production
```

### 4. Храните версии

```bash
# Используйте семантическое версионирование
git tag v2.1.0
git push origin v2.1.0

# Автоматические releases через GitHub Actions
```

### 5. Документируйте изменения

```bash
# Conventional Commits
git commit -m "feat: add new service"
git commit -m "fix: resolve database connection issue"
git commit -m "docs: update deployment guide"

# Автоматический CHANGELOG из коммитов
```

### 6. Мониторьте деплои

- Подключите Mattermost/Slack webhooks
- Настройте алерты на failed deployments
- Регулярно проверяйте health checks

### 7. Backup перед продакшен деплоем

```yaml
# В GitHub Actions workflow
- name: Backup before deploy
  run: |
    ssh prod "cd /opt/ceres && ./scripts/backup.sh"
```

## 🔍 Troubleshooting

### GitHub Actions не запускается

```bash
# Проверьте triggers в .github/workflows/gitops.yml
# Проверьте секреты в Settings → Secrets
# Проверьте логи в Actions tab
```

### Ansible не может подключиться

```bash
# Проверьте SSH доступ
ssh ceres@192.168.1.10

# Проверьте inventory
ansible all -i inventory/production.yml -m ping

# Используйте verbose режим
ansible-playbook -vvv ...
```

### Terraform ошибки

```bash
# Проверьте state
terraform show

# Refresh state
terraform refresh

# Пересоздайте ресурс
terraform taint proxmox_vm_qemu.core
terraform apply
```

## 📚 Дополнительные ресурсы

- [GitOps Principles](https://www.gitops.tech/)
- [FluxCD Documentation](https://fluxcd.io/)
- [Terraform Proxmox Provider](https://github.com/Telmate/terraform-provider-proxmox)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Вопросы?** Создайте issue в [GitHub Issues](https://github.com/yourusername/ceres/issues)
