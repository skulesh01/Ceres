# 🚀 CERES Deployment Checklist

Полный чек-лист для развёртывания CERES на Kubernetes.

## ✅ Подготовка

- [ ] Репозиторий на GitHub: https://github.com/skulesh01/Ceres
- [ ] Сервер Proxmox доступен: 192.168.1.3 (root, SSH)
- [ ] Установлен Git, Docker, k3s/k8s на сервере

## 📝 Шаг 1: Инициализация сервера

На сервере Proxmox:

```bash
# Скачайте и запустите скрипт установки
curl -fsSL https://raw.githubusercontent.com/skulesh01/Ceres/main/scripts/install.sh | bash

# Или вручную установите зависимости
sudo apt-get update && sudo apt-get install -y git curl wget docker.io
curl -sfL https://get.k3s.io | sh -
```

## 🔐 Шаг 2: Подготовка SSH-ключей

На вашей машине (Windows PowerShell):

```powershell
# 1. Генерируем ключ (если нет)
ssh-keygen -t ed25519 -f $HOME\.ssh\ceres -N ""

# 2. Отправляем публичный ключ на сервер
$pubKey = Get-Content $HOME\.ssh\ceres.pub
ssh $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# 3. Проверяем подключение
ssh $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "uname -a"
```

## 📋 Шаг 3: Получаем kubeconfig

На сервере (k3s):

```bash
cat /etc/rancher/k3s/k3s.yaml
# Скопируйте содержимое

# Или через PowerShell:
scp $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP:/etc/rancher/k3s/k3s.yaml $HOME\k3s.yaml
```

## 🔑 Шаг 4: Добавляем секреты в GitHub

Откройте https://github.com/skulesh01/Ceres/settings/secrets/actions

Или через CLI:

```powershell
gh auth login
gh secret set DEPLOY_HOST --body "192.168.1.3"
gh secret set DEPLOY_USER --body "root"
gh secret set SSH_PRIVATE_KEY --body (Get-Content $HOME\.ssh\ceres -Raw)
```

## 🚀 Шаг 5: Запускаем деплой

Через GitHub Actions:

1. Откройте https://github.com/skulesh01/Ceres/actions
2. Выберите "Ceres Deploy"
3. Нажмите "Run workflow"
4. Заполните параметры и нажмите "Run workflow"

Или через CLI:

```powershell
gh workflow run ceres-deploy.yml -f branch=main -f app_dir=/srv/ceres -R skulesh01/Ceres
gh run watch -R skulesh01/Ceres
```

## ✅ Проверка после деплоя

На сервере:

```bash
# Проверяем подсистемы
systemctl status k3s
kubectl get pods -A
kubectl get svc -A

# Проверяем логи
tail -f /srv/ceres/logs/*.log
```

## 🛠️ Инструменты управления

После деплоя используйте готовые скрипты:

```bash
# SSH-команды
./scripts/remote-ops/remote.sh cmd "uname -a"
./scripts/remote-ops/remote.sh kubectl-apply /srv/ceres/k8s

# GitHub Actions
GH_REPO=skulesh01/Ceres ./scripts/gh-ops/gh-actions.sh run .github/workflows/ceres-deploy.yml

# Деплой
./scripts/deploy-ops/deploy-k8s.sh /srv/ceres/k8s
./scripts/deploy-ops/smoke.sh
```

## 📚 Дальнейшее чтение

- [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) — подробная настройка секретов
- [scripts/DEPLOYMENT_GUIDE.md](scripts/DEPLOYMENT_GUIDE.md) — полное руководство деплоя
- [ARCHITECTURE.md](ARCHITECTURE.md) — архитектура проекта
- [docs/MULTI_TENANCY_GUIDE.md](docs/MULTI_TENANCY_GUIDE.md) — мульти-тенантность

## 🆘 Проблемы?

- Логи workflow → Actions → выберите run
- Логи на сервере → `/srv/ceres/logs/`
- Чек зависимостей → `bash /srv/ceres/scripts/check-dependencies.sh`
- SSH тест → `ssh $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "echo OK"`

---

**Дата обновления:** 2026-01-01  
**Версия CERES:** 2.6.0  
**Статус:** ✅ Production Ready
