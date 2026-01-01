# CERES v2.8.0 - GitOps для Kubernetes

## 📌 Обзор

CERES v2.8.0 добавляет полную поддержку **GitOps** для управления Kubernetes развертываниями. Система автоматически синхронизирует состояние кластера с Git репозиторием, обеспечивая декларативный, версионируемый и надежный deployment процесс.

### Ключевые возможности

- **ArgoCD**: Declarative deployment с автоматической синхронизацией
- **Flux CD**: Alternative GitOps инструмент с image auto-updates
- **Sealed Secrets**: Безопасное управление secrets в Git
- **Multi-Cluster**: Управление несколькими K3s кластерами
- **GitHub Actions**: Automated CI/CD pipeline для building и deployment
- **Image Auto-Updates**: Автоматическое обновление image tags
- **Notifications**: Slack/Teams интеграция для deployment статуса
- **RBAC**: Role-based access control с tenant isolation
- **Disaster Recovery**: Backup/restore across clusters

---

## 🏗️ Архитектура GitOps

```
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Repository                          │
│  (Helm charts, Kustomizations, ApplicationSets, Secrets)        │
└─────────────────────────────────────────────────────────────────┘
                    ▲              ▲              ▲
                    │              │              │
         ┌──────────┴──────┬───────┴──┬───────────┴──┐
         │                 │          │              │
         │                 ▼          ▼              ▼
    ┌────────┐      ┌──────────┐  ┌─────────┐  ┌──────────┐
    │ArgoCD  │      │Flux CD   │  │Sealed   │  │GitHub    │
    │Server  │      │HelmRel   │  │Secrets  │  │Actions   │
    │        │      │          │  │         │  │Pipeline  │
    └────┬───┘      └──────┬───┘  └────┬────┘  └──────┬───┘
         │                 │           │             │
         └─────────────────┼───────────┼─────────────┘
                           ▼           ▼
                  ┌──────────────────────────┐
                  │  Kubernetes Cluster      │
                  │  (K3s - Primary)         │
                  │ ┌────────────────────┐   │
                  │ │ CERES Services     │   │
                  │ │ PostgreSQL         │   │
                  │ │ Redis              │   │
                  │ │ Keycloak           │   │
                  │ │ Monitoring         │   │
                  │ └────────────────────┘   │
                  └──────────────────────────┘
                            ▲ ▲ ▲
         ┌──────────────────┼─┼─┼────────────────┐
         │                  │ │ │                │
    ┌────▼────┐      ┌──────▼─▼─▼──────┐  ┌──────▼──────┐
    │Secondary│      │  Disaster       │  │ Monitoring  │
    │Cluster  │      │  Recovery       │  │ & Alerts    │
    │(K3s)    │      │  Cluster (K3s)  │  │ (Prometheus)│
    └─────────┘      └─────────────────┘  └─────────────┘
```

---

## 🚀 Установка ArgoCD

### Требования

- K3s v1.29.0+
- kubectl v1.29.0+
- Helm 3.0+
- Domain (например: argocd.ceres.local)

### Быстрый старт

```bash
# 1. Добавить Helm репозиторий
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 2. Установить ArgoCD
./scripts/deploy-argocd.sh argocd argocd ceres.local

# 3. Получить пароль админа
kubectl get secret -n argocd argocd-secret -o jsonpath='{.data.admin\.password}' | base64 -d

# 4. Войти в ArgoCD UI
argocd login argocd.ceres.local --username admin --password <пароль>

# 5. Подключить кластер к ArgoCD
argocd cluster add k3s-cluster
```

### Конфигурация ArgoCD

**Основные компоненты** (`config/argocd/argocd-install.yml`):

1. **Server**: WebUI и API для управления deployments
2. **Repository Server**: Обработка Git репозиториев и Helm charts
3. **Application Controller**: Мониторинг и синхронизация приложений
4. **Redis**: Кеширование и сессии
5. **Notifications Controller**: Slack/Teams интеграция

**Настройки безопасности**:

```yaml
rbac:
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:developer, applications, get, ceres/*, allow
    p, role:viewer, applications, get, */*, allow
```

---

## 📊 ApplicationSet для автоматизации

**ApplicationSet** автоматически создает Applications на основе:
- Структуры Git репозитория
- Списка кластеров (для multi-cluster)
- Pull Request (для preview environments)
- ConfigMap с tenant-списком

### Пример ApplicationSet для tenants

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: ceres-tenants
spec:
  generators:
    - configMap:
        name: ceres-tenants-list
        keys: [tenants]
  template:
    metadata:
      name: 'tenant-{{tenant-id}}'
    spec:
      destination:
        namespace: 'ceres-{{tenant-id}}'
      source:
        path: helm/ceres-tenant
```

### Использование

```bash
# Просмотр всех ApplicationSet
argocd appset list

# Создать автоматически
argocd appset create <name> --git-repo <url> --git-revision main

# Отобразить сгенерированные Applications
argocd appset get <name>
```

---

## 🔄 Flux CD альтернатива

Для окружений, требующих **безопасность по умолчанию** и **decentralized управления**:

```bash
# 1. Установить Flux
curl -s https://fluxcd.io/install.sh | sudo bash

# 2. Bootstrap Flux в кластере
flux bootstrap github \
  --owner=ceres-platform \
  --repo=ceres-helm-charts \
  --path=clusters/production \
  --personal

# 3. Создать HelmRelease
kubectl apply -f config/flux/flux-releases.yml

# 4. Проверить синхронизацию
flux get all -A
```

### Flux CD vs ArgoCD

| Критерий | ArgoCD | Flux CD |
|----------|--------|---------|
| Управление | UI + CLI + API | CLI + Webhooks |
| Complexity | Выше (больше features) | Ниже (более простой) |
| Multi-cluster | ✓ Встроено | ✓ Native |
| Image Updates | ✓ ImagePolicy | ✓ ImageAutomation |
| Policy Enforcement | RBAC | Kyverno + OPA |

---

## 🔐 Sealed Secrets для безопасного Git

**Problem**: Secrets нельзя хранить в plain text в Git

**Solution**: Sealed Secrets шифруют secrets с публичным ключом кластера

### Установка Sealed Secrets

```bash
# 1. Установить контроллер
kubectl apply -f config/sealed-secrets/sealed-secrets.yml

# 2. Получить публичный ключ для team
kubectl get secret -n sealed-secrets sealed-secrets-key -o jsonpath='{.data.tls\.crt}' | base64 -d > public-key.crt

# 3. Зашифровать secret
echo -n "my-secret" | kubectl create secret generic my-secret --dry-run=client --from-file=password=/dev/stdin -o yaml | \
  kubeseal -f - > my-secret-sealed.yaml

# 4. Применить sealed secret в Git
kubectl apply -f my-secret-sealed.yaml
```

### SealedSecret Example

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: postgres-credentials
  namespace: ceres
spec:
  encryptedData:
    password: AgBcD5F...
  template:
    type: Opaque
```

---

## 🔄 GitHub Actions CI/CD Pipeline

Полный pipeline для building, testing, и deployment:

### Pipeline Stages

1. **Analyze**: SAST + dependency scanning (Trivy)
2. **Build**: Docker image build + push
3. **Scan**: Image vulnerability scan
4. **Deploy**: Helm upgrade + verify
5. **Monitor**: Health checks + drift detection

### Рабочие потоки

```bash
# Trigger 1: On push to main
git push origin main
  → Build image → Push to registry
  → Auto-update Helm values
  → ArgoCD syncs changes

# Trigger 2: On release
git tag v2.8.1
  → Build image:v2.8.1
  → Create PR с обновлением values.yml
  → Deploy to production

# Trigger 3: Scheduled (weekly)
0 2 * * 0
  → Rebuild image (security patches)
  → Run full test suite
```

### Настройка GitHub Actions

```bash
# 1. Добавить secrets
gh secret set KUBECONFIG
gh secret set GITHUB_TOKEN
gh secret set SLACK_WEBHOOK

# 2. Enable Actions
Settings → Actions → Allow public workflows

# 3. Setup OIDC для K8s (опционально)
gh secret set KUBE_CLUSTER_URL
gh secret set KUBE_CLUSTER_TOKEN
```

---

## 🌍 Multi-Cluster Setup

Управление **несколькими K3s кластерами** с единой ArgoCD instance:

### Архитектура

```
Primary Cluster (США - Восток)
├── ArgoCD Server
├── Gitea (Git backend)
└── PostgreSQL (primary)
        ↓ Replication
Secondary Cluster (Европа)
├── ArgoCD Agent
├── PostgreSQL (replica)
└── Services (read-only)
        ↓ Failover
DR Cluster (США - Запад)
├── PostgreSQL (replica)
└── Standby services
```

### Настройка Multi-Cluster

```bash
# 1. Зарегистрировать secondary cluster
argocd cluster add secondary-cluster --name secondary

# 2. Создать ApplicationSet для multi-cluster
kubectl apply -f config/argocd/applicationset.yml

# 3. Настроить cross-cluster networking
./scripts/setup-multi-cluster.sh all

# 4. Проверить replication
kubectl exec -n ceres postgres-0 -- pg_basebackup --progress

# 5. Создать failover policy
kubectl apply -f config/k3s/failover-policy.yml
```

### Database Replication

```sql
-- На primary
CREATE ROLE replication WITH REPLICATION LOGIN;
ALTER ROLE replication WITH PASSWORD 'password';

-- На secondary
SELECT * FROM pg_stat_replication;
```

---

## 📊 Мониторинг GitOps

### Drift Detection

```bash
# Автоматически проверяется каждые 15 минут
# Trigger: GitHub Issue + Slack notification

argocd app diff ceres
argocd app refresh ceres --hard-refresh
```

### Notifications

Поддерживаемые провайдеры:
- **Slack**: На deployment success/failure
- **Teams**: Desktop notifications
- **Email**: SMTP-based alerts
- **Webhooks**: Кастомные интеграции

### Настройка уведомлений

```yaml
# Slack
service.slack: |
  token: xoxb-xxx...

trigger.on-sync-failed: |
  - when: app.status.operationState.phase in ['Error', 'Failed']
    send: [app-health-degraded]
```

---

## 🔄 Image Auto-Updates

Автоматическое обновление image tags при релизе:

### ArgoCD Image Updater

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-config
data:
  registries.conf: |
    registries:
      - name: ghcr
        api_url: https://ghcr.io
        kind: github
        credentials: secret:github-creds
```

### Flux Image Automation

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImagePolicy
spec:
  imageRepositoryRef:
    name: ceres-registry
  policy:
    semver:
      range: '>=2.8.0 <2.9'  # Patch updates only
```

---

## 🎯 RBAC и Multi-Tenancy

### Tenant-based RBAC

```yaml
# Админ может manage все
p, role:admin, applications, *, */*, allow

# Developer может sync только свои tenant apps
p, role:developer, applications, sync, ceres/tenant-*, allow

# Viewer только read-only
p, role:viewer, applications, get, */*, allow
```

### Service Accounts per Tenant

```bash
# Создать service account для tenant
kubectl create serviceaccount tenant-acme-sa -n ceres

# Привязать роль
kubectl create rolebinding tenant-acme-admin \
  --clusterrole=ceres-tenant-admin \
  --serviceaccount=ceres:tenant-acme-sa
```

---

## 🆘 Troubleshooting

### ArgoCD не синхронизируется

```bash
# 1. Проверить Application status
argocd app get ceres -o wide

# 2. Просмотреть logs controller
kubectl logs -n argocd deploy/argocd-application-controller -f

# 3. Проверить Git connectivity
argocd repo list
argocd repo get https://github.com/ceres-platform/ceres

# 4. Hard refresh
argocd app refresh ceres --hard-refresh
argocd app sync ceres
```

### Secrets не расшифровываются

```bash
# 1. Проверить sealed-secrets pod
kubectl logs -n sealed-secrets deploy/sealed-secrets-controller

# 2. Verify encryption key
kubectl get secret -n sealed-secrets sealed-secrets-key

# 3. Re-seal secrets
kubeseal < secret.yaml > secret-sealed.yaml
```

### Multi-cluster failover

```bash
# 1. Проверить cluster status
argocd cluster list

# 2. Инициировать failover
kubectl patch application ceres -p '{"spec":{"destination":{"server":"https://secondary-cluster:6443"}}}'

# 3. Verify databases replicated
kubectl exec -n ceres postgres-0 -- pg_stat_replication

# 4. Validate app health
argocd app wait ceres --timeout 5m
```

---

## 📋 Полезные команды

```bash
# ArgoCD
argocd app list                           # Все приложения
argocd app get ceres                      # Детали приложения
argocd app sync ceres                     # Синхронизировать
argocd app history ceres                  # История deployments
argocd app rollback ceres 1               # Откатить версию
argocd cluster add <context>              # Добавить кластер

# Flux
flux get all -A                           # Все ресурсы
flux reconcile source git ceres           # Синхронизировать repo
flux get helmreleases -A                  # Все HelmReleases
flux logs --all-namespaces --follow       # Логи

# Sealed Secrets
kubeseal --fetch-cert > public-key.crt    # Получить ключ
kubeseal -f secret.yaml > secret-sealed.yaml  # Зашифровать

# Debugging
kubectl get events -A                     # События
kubectl describe app ceres -n argocd      # Описание application
argocd app logs ceres --tail 100          # Логи deployment
```

---

## ✅ Чек-лист внедрения v2.8.0

- [ ] Установить ArgoCD
- [ ] Подключить Git репозиторий
- [ ] Создать ApplicationSet для сервисов
- [ ] Создать ApplicationSet для tenants
- [ ] Настроить Sealed Secrets
- [ ] Установить GitHub Actions workflows
- [ ] Тест: Push to main → Auto deploy
- [ ] Настроить notifications (Slack)
- [ ] Установить Flux на secondary кластер
- [ ] Настроить multi-cluster failover
- [ ] Включить image auto-updates
- [ ] Настроить backup sync
- [ ] Документировать runbooks

---

## 📚 Документация

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [Flux CD Documentation](https://fluxcd.io/docs/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Kubernetes GitOps Best Practices](https://www.weave.works/blog/gitops/)

---

## 🎓 Заключение

CERES v2.8.0 полностью преобразует deployment процесс:

✅ **Декларативное управление**: Все в Git  
✅ **Автоматизация**: Push to deploy  
✅ **Безопасность**: Encrypted secrets  
✅ **Масштабируемость**: Multi-cluster support  
✅ **Надежность**: Auto-healing + failover  
✅ **Видимость**: Complete audit trail  

**CERES теперь production-ready GitOps платформа!** 🚀
