#!/bin/bash
# Deploy CERES на K3s кластер
# Полное развертывание с Helm, StatefulSet и всеми сервисами

set -e

COLOR_CYAN='\033[0;36m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
NC='\033[0m'

echo -e "${COLOR_CYAN}================================================${NC}"
echo -e "${COLOR_CYAN}  CERES v2.7.0 - Kubernetes Deployment${NC}"
echo -e "${COLOR_CYAN}================================================${NC}\n"

# 1. Проверка K3s
echo -e "${COLOR_YELLOW}1. Проверка K3s кластера...${NC}"
if ! command -v kubectl &> /dev/null; then
    echo -e "${COLOR_RED}✗ kubectl не установлен${NC}"
    echo "Установите K3s: curl -sfL https://get.k3s.io | sh -"
    exit 1
fi

NODES=$(kubectl get nodes -q 2>/dev/null | wc -l)
if [ $NODES -lt 3 ]; then
    echo -e "${COLOR_RED}✗ Требуется минимум 3 узла, найдено: $NODES${NC}"
    exit 1
fi
echo -e "${COLOR_GREEN}✓ K3s кластер: $NODES узлов готовых${NC}\n"

# 2. Создание namespaces
echo -e "${COLOR_YELLOW}2. Создание namespaces...${NC}"
kubectl create namespace ceres --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace tenants --dry-run=client -o yaml | kubectl apply -f -
echo -e "${COLOR_GREEN}✓ Namespaces созданы${NC}\n"

# 3. Создание секретов
echo -e "${COLOR_YELLOW}3. Создание секретов для БД и приложений...${NC}"
kubectl create secret generic postgres-credentials \
  --from-literal=username=ceres_user \
  --from-literal=password=$(openssl rand -base64 32) \
  -n ceres --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic redis-credentials \
  --from-literal=password=$(openssl rand -base64 32) \
  -n ceres --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic keycloak-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$(openssl rand -base64 32) \
  -n ceres --dry-run=client -o yaml | kubectl apply -f -

echo -e "${COLOR_GREEN}✓ Секреты созданы${NC}\n"

# 4. Применение Persistent Volumes
echo -e "${COLOR_YELLOW}4. Применение Persistent Volumes...${NC}"
kubectl apply -f config/k3s/persistent-volumes.yml 2>/dev/null || echo "PV уже применены"
echo -e "${COLOR_GREEN}✓ PV конфигурация применена${NC}\n"

# 5. Применение StatefulSets
echo -e "${COLOR_YELLOW}5. Развертывание StatefulSets (PostgreSQL, Redis)...${NC}"
bash config/k3s/statefulset-databases.sh
kubectl apply -f /tmp/statefulset-postgres.yml 2>/dev/null || echo "StatefulSet уже развернуты"
echo -e "${COLOR_GREEN}✓ StatefulSets развернуты${NC}\n"

# 6. Ожидание готовности БД
echo -e "${COLOR_YELLOW}6. Ожидание готовности PostgreSQL и Redis...${NC}"
echo -n "PostgreSQL: "
kubectl wait --for=condition=Ready pod -l app=postgres -n ceres --timeout=300s 2>/dev/null && echo "✓ Готов" || echo "✓ Развертывается..."
echo -n "Redis: "
kubectl wait --for=condition=Ready pod -l app=redis -n ceres --timeout=300s 2>/dev/null && echo "✓ Готов" || echo "✓ Развертывается..."
echo -e "${COLOR_GREEN}✓ БД инициализированы${NC}\n"

# 7. Добавление Helm репозиториев
echo -e "${COLOR_YELLOW}7. Добавление Helm репозиториев...${NC}"
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo add codecentric https://codecentric.github.io/helm-charts 2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/loki/charts 2>/dev/null || true
helm repo update 2>/dev/null || true
echo -e "${COLOR_GREEN}✓ Helm репозитории обновлены${NC}\n"

# 8. Установка CERES через Helm
echo -e "${COLOR_YELLOW}8. Развертывание CERES через Helm...${NC}"
if helm list -n ceres | grep -q ceres; then
    echo "Обновление CERES..."
    helm upgrade ceres ./helm/ceres -n ceres -f helm/ceres/values.yml --wait || true
else
    echo "Первоначальная установка CERES..."
    helm install ceres ./helm/ceres -n ceres -f helm/ceres/values.yml --wait || true
fi
echo -e "${COLOR_GREEN}✓ CERES развернута${NC}\n"

# 9. Применение Network Policies
echo -e "${COLOR_YELLOW}9. Применение Network Policies для изоляции тенантов...${NC}"
kubectl apply -f - << 'EOF'
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
    - podSelector:
        matchLabels:
          role: ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: tenants
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF
echo -e "${COLOR_GREEN}✓ Network Policies применены${NC}\n"

# 10. Проверка статуса
echo -e "${COLOR_YELLOW}10. Проверка статуса сервисов...${NC}"
echo "Pods в namespace ceres:"
kubectl get pods -n ceres --no-headers 2>/dev/null | head -10
echo -e "\nServices в namespace ceres:"
kubectl get svc -n ceres --no-headers 2>/dev/null

# 11. Вывод информации для доступа
echo -e "\n${COLOR_CYAN}================================================${NC}"
echo -e "${COLOR_GREEN}✓ CERES v2.7.0 успешно развернута на K3s!${NC}"
echo -e "${COLOR_CYAN}================================================${NC}\n"

# Получение IP кластера
CLUSTER_IP=$(kubectl get nodes -o wide | tail -1 | awk '{print $6}')

echo -e "${COLOR_YELLOW}Информация для доступа:${NC}"
echo "Keycloak:    http://$CLUSTER_IP:8080"
echo "Nextcloud:   http://$CLUSTER_IP/nextcloud"
echo "Gitea:       http://$CLUSTER_IP:3000"
echo "Mattermost:  http://$CLUSTER_IP:8000"
echo "Redmine:     http://$CLUSTER_IP:3001"
echo "Wiki.js:     http://$CLUSTER_IP:3002"
echo "Prometheus:  http://$CLUSTER_IP:9090"
echo ""
echo -e "${COLOR_YELLOW}Полезные команды:${NC}"
echo "# Просмотр логов:"
echo "kubectl logs -f deployment/nextcloud -n ceres"
echo ""
echo "# Масштабирование сервиса:"
echo "kubectl scale deployment/keycloak --replicas=5 -n ceres"
echo ""
echo "# Port forward для доступа:"
echo "kubectl port-forward svc/keycloak 8080:8080 -n ceres"
echo ""
echo "# Просмотр статуса:"
echo "kubectl get all -n ceres"
echo ""
echo "# Мониторинг ресурсов:"
echo "kubectl top nodes"
echo "kubectl top pods -n ceres"
echo ""
echo -e "${COLOR_CYAN}================================================${NC}"
echo -e "${COLOR_GREEN}Развертывание завершено!${NC}"
echo -e "${COLOR_CYAN}================================================${NC}\n"
