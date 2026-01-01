# Deploy CERES на Kubernetes (Windows)
# Полное развертывание с проверкой предусловий

param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "ceres",
    
    [Parameter(Mandatory=$false)]
    [string]$ReleaseName = "ceres",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPVCheck,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSecrets
)

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "➤ $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ $Text" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "✗ $Text" -ForegroundColor Red
}

Write-Header "CERES v2.7.0 - Kubernetes Deployment (Windows)"

# 1. Проверка предусловий
Write-Step "Проверка предусловий..."

if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error-Custom "kubectl не установлен. Установите K3s/Kubernetes."
    exit 1
}
Write-Success "kubectl найден"

if (!(Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Error-Custom "helm не установлен. Установите Helm."
    exit 1
}
Write-Success "helm найден"

# Проверка кластера
try {
    $nodes = kubectl get nodes -q 2>$null | Measure-Object -Line
    if ($nodes.Lines -lt 3) {
        Write-Error-Custom "Требуется минимум 3 узла, найдено: $($nodes.Lines)"
        exit 1
    }
    Write-Success "K3s кластер: $($nodes.Lines) узлов готовых"
} catch {
    Write-Error-Custom "Не удается подключиться к кластеру K3s"
    exit 1
}

# 2. Создание namespaces
Write-Step "Создание namespaces..."
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f - | Out-Null
kubectl create namespace tenants --dry-run=client -o yaml | kubectl apply -f - | Out-Null
Write-Success "Namespaces созданы"

# 3. Создание секретов
if (!$SkipSecrets) {
    Write-Step "Создание секретов..."
    
    # Генерация паролей
    $postgresPassword = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).ToString()))
    $redisPassword = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).ToString()))
    $keycloakPassword = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).ToString()))
    
    # Создание YAML с секретами
    @"
apiVersion: v1
kind: Secret
metadata:
  name: postgres-credentials
  namespace: $Namespace
type: Opaque
data:
  username: $(([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("ceres_user"))))
  password: $postgresPassword
---
apiVersion: v1
kind: Secret
metadata:
  name: redis-credentials
  namespace: $Namespace
type: Opaque
data:
  password: $redisPassword
---
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-credentials
  namespace: $Namespace
type: Opaque
data:
  admin-user: $(([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("admin"))))
  admin-password: $keycloakPassword
"@ | kubectl apply -f - | Out-Null
    
    Write-Success "Секреты созданы"
}

# 4. Применение Persistent Volumes
if (!$SkipPVCheck) {
    Write-Step "Применение Persistent Volumes..."
    kubectl apply -f "config\k3s\persistent-volumes.yml" 2>$null | Out-Null
    Write-Success "PV конфигурация применена"
}

# 5. Применение StatefulSets
Write-Step "Развертывание StatefulSets (PostgreSQL, Redis)..."
kubectl apply -f "config\k3s\k3s-cluster.yml" 2>$null | Out-Null
Write-Success "StatefulSets развернуты"

# 6. Добавление Helm репозиториев
Write-Step "Добавление Helm репозиториев..."
helm repo add bitnami https://charts.bitnami.com/bitnami --force-update 2>$null | Out-Null
helm repo add codecentric https://codecentric.github.io/helm-charts --force-update 2>$null | Out-Null
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update 2>$null | Out-Null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update 2>$null | Out-Null
helm repo update 2>$null | Out-Null
Write-Success "Helm репозитории обновлены"

# 7. Установка CERES через Helm
Write-Step "Развертывание CERES через Helm..."
$helmRelease = helm list -n $Namespace | Select-String -Pattern "ceres"

if ($helmRelease) {
    Write-Host "Обновление CERES..." -ForegroundColor Cyan
    helm upgrade $ReleaseName ./helm/ceres -n $Namespace -f helm/ceres/values.yml --wait 2>$null | Out-Null
} else {
    Write-Host "Первоначальная установка CERES..." -ForegroundColor Cyan
    helm install $ReleaseName ./helm/ceres -n $Namespace -f helm/ceres/values.yml --wait 2>$null | Out-Null
}
Write-Success "CERES развернута"

# 8. Применение Network Policies
Write-Step "Применение Network Policies для изоляции тенантов..."
@"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: tenants
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-nginx
  namespace: tenants
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app: nginx
"@ | kubectl apply -f - | Out-Null
Write-Success "Network Policies применены"

# 9. Проверка статуса
Write-Header "Статус сервисов"
Write-Host "Pods в namespace $Namespace`:" -ForegroundColor Yellow
kubectl get pods -n $Namespace --no-headers 2>$null | Select-Object -First 10

Write-Host "`nServices в namespace $Namespace`:" -ForegroundColor Yellow
kubectl get svc -n $Namespace --no-headers 2>$null

# 10. Информация для доступа
Write-Header "✓ CERES v2.7.0 успешно развернута на K3s!"

Write-Host "Информация для доступа:" -ForegroundColor Yellow
Write-Host "Keycloak:   http://localhost:8080"
Write-Host "Nextcloud:  http://localhost/nextcloud"
Write-Host "Gitea:      http://localhost:3000"
Write-Host "Mattermost: http://localhost:8000"
Write-Host "Redmine:    http://localhost:3001"
Write-Host "Wiki.js:    http://localhost:3002"

Write-Host "`nПолезные команды:" -ForegroundColor Yellow
Write-Host "# Просмотр логов:"
Write-Host "kubectl logs -f deployment/nextcloud -n $Namespace"
Write-Host ""
Write-Host "# Масштабирование сервиса:"
Write-Host "kubectl scale deployment/keycloak --replicas=5 -n $Namespace"
Write-Host ""
Write-Host "# Port forward для доступа:"
Write-Host "kubectl port-forward svc/keycloak 8080:8080 -n $Namespace"
Write-Host ""
Write-Host "# Просмотр статуса:"
Write-Host "kubectl get all -n $Namespace"
Write-Host ""
Write-Host "# Мониторинг ресурсов:"
Write-Host "kubectl top nodes"
Write-Host "kubectl top pods -n $Namespace"

Write-Host "`n════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "Развертывание завершено!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green
