# FluxCD Configuration for CERES

Автоматическое управление развертыванием через GitOps с FluxCD.

## 📋 Что такое FluxCD?

FluxCD — это GitOps оператор для Kubernetes, который автоматически синхронизирует состояние кластера с Git репозиторием.

**Преимущества:**
- ✅ Автоматическое развертывание при push в Git
- ✅ Декларативное управление инфраструктурой
- ✅ Rollback через Git revert
- ✅ Multi-cluster support
- ✅ Automated image updates

## 🚀 Быстрый старт

### 1. Установка FluxCD CLI

**Linux/macOS:**
```bash
curl -s https://fluxcd.io/install.sh | sudo bash
```

**Windows (Chocolatey):**
```powershell
choco install flux
```

**Windows (Scoop):**
```powershell
scoop install flux
```

### 2. Проверка требований

```bash
# Проверьте подключение к Kubernetes
kubectl cluster-info

# Проверьте установку Flux
flux check --pre
```

### 3. Bootstrap FluxCD

**Bash:**
```bash
./flux/bootstrap.sh yourusername ceres production
```

**PowerShell:**
```powershell
.\flux\bootstrap.ps1 -GitHubUser yourusername -GitHubRepo ceres -ClusterName production
```

## 📦 Структура

```
flux/
├── bootstrap.sh              # Bootstrap script (Bash)
├── bootstrap.ps1             # Bootstrap script (PowerShell)
├── clusters/
│   ├── production/           # Production cluster config
│   │   └── flux-system.yaml
│   ├── staging/              # Staging cluster config
│   └── development/          # Dev cluster config
├── infrastructure/           # Core infrastructure
│   ├── namespaces/
│   ├── rbac/
│   └── sealed-secrets/
└── apps/
    ├── core/                 # PostgreSQL, Redis, Keycloak
    ├── applications/         # Nextcloud, Gitea, etc.
    └── monitoring/           # Prometheus, Grafana
```

## 🔄 Workflow

```
Developer Push → GitHub → FluxCD detects change
                             ↓
                        Syncs to K8s
                             ↓
                    CERES services updated
```

## 📊 Мониторинг

### Проверка статуса

```bash
# Все ресурсы Flux
flux get all

# Git источники
flux get sources git

# Kustomizations
flux get kustomizations

# Helm releases (если используются)
flux get helmreleases -A
```

### Логи

```bash
# Follow Flux logs
flux logs --follow

# Конкретный компонент
flux logs --kind=Kustomization --name=ceres-core
```

### События

```bash
# События в namespace flux-system
kubectl -n flux-system get events --sort-by='.lastTimestamp'

# Описание Kustomization
kubectl -n flux-system describe kustomization ceres-core
```

## 🔧 Управление

### Ручная синхронизация

```bash
# Синхронизировать конкретную Kustomization
flux reconcile kustomization ceres-core

# Синхронизировать Git источник
flux reconcile source git ceres

# Синхронизировать всё
flux reconcile kustomization flux-system --with-source
```

### Приостановка автосинхронизации

```bash
# Приостановить
flux suspend kustomization ceres-apps

# Возобновить
flux resume kustomization ceres-apps
```

### Откат изменений

```bash
# Git revert коммита
git revert <commit-hash>
git push

# Flux автоматически применит rollback
```

## 🔐 Управление секретами

Flux интегрируется с **Sealed Secrets** для безопасного хранения секретов в Git.

### Создание Sealed Secret

```bash
# Установите kubeseal
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo mv kubeseal /usr/local/bin/

# Создайте обычный секрет
kubectl create secret generic postgres-password \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml > secret.yaml

# Зашифруйте его
kubeseal -f secret.yaml -w sealed-secret.yaml

# Закоммитьте sealed-secret.yaml в Git (безопасно!)
git add sealed-secret.yaml
git commit -m "Add sealed postgres password"
git push
```

## 🎯 Multi-Environment

### Development

```bash
flux bootstrap github \
  --owner=yourusername \
  --repository=ceres \
  --branch=develop \
  --path=./flux/clusters/development
```

### Staging

```bash
flux bootstrap github \
  --owner=yourusername \
  --repository=ceres \
  --branch=staging \
  --path=./flux/clusters/staging
```

### Production

```bash
flux bootstrap github \
  --owner=yourusername \
  --repository=ceres \
  --branch=main \
  --path=./flux/clusters/production
```

## 🔄 Image Auto-Update

FluxCD может автоматически обновлять образы контейнеров:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageRepository
metadata:
  name: nextcloud
  namespace: flux-system
spec:
  image: nextcloud
  interval: 5m
---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImagePolicy
metadata:
  name: nextcloud
  namespace: flux-system
spec:
  imageRepositoryRef:
    name: nextcloud
  policy:
    semver:
      range: '>=28.0.0'
---
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: ceres-apps
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: ceres
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        email: flux@ceres.local
        name: FluxCD
      messageTemplate: 'Update {{range .Updated.Images}}{{println .}}{{end}}'
  update:
    path: ./config/compose
    strategy: Setters
```

## 🔍 Troubleshooting

### Flux не синхронизируется

```bash
# Проверьте статус
flux get all

# Проверьте логи
flux logs --all-namespaces --level=error

# Reconcile вручную
flux reconcile kustomization flux-system --with-source
```

### Ошибки аутентификации Git

```bash
# Проверьте секрет
kubectl -n flux-system get secret flux-system -o yaml

# Пересоздайте секрет
flux create secret git ceres \
  --url=https://github.com/yourusername/ceres \
  --username=git \
  --password=<github-token>
```

### Health check failures

```bash
# Проверьте health checks
kubectl -n ceres-system get all

# Проверьте события
kubectl -n ceres-system get events --sort-by='.lastTimestamp'
```

## 📚 Дополнительные ресурсы

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [CERES GitOps Guide](../docs/GITOPS_GUIDE.md)

## 🔗 Интеграция с CI/CD

FluxCD интегрируется с:
- GitHub Actions (`.github/workflows/gitops.yml`)
- Terraform для создания инфраструктуры
- Ansible для настройки хостов
