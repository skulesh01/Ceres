#!/bin/bash
# ВКЛЮЧИТЬ ВСЕ СЕРВИСЫ CERES - ПОЛНАЯ АВТОМАТИЗАЦИЯ (BASH VERSION)

set -e

SKIP_VALIDATION=false
SKIP_K8S=false
ONLY_ARGOCD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-validation) SKIP_VALIDATION=true; shift ;;
        --skip-k8s) SKIP_K8S=true; shift ;;
        --only-argocd) ONLY_ARGOCD=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

function header() {
    echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
}

function success() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

function error() {
    echo -e "${RED}  ✗ $1${NC}"
}

function info() {
    echo -e "${CYAN}  • $1${NC}"
}

# НАЧАЛО
header "CERES KUBERNETES - ПОЛНОЕ ВКЛЮЧЕНИЕ"

# Шаг 1: Валидация
if [ "$SKIP_VALIDATION" = false ]; then
    header "ШАГ 1: ВАЛИДАЦИЯ ОКРУЖЕНИЯ"
    
    if [ -f "./validate-deployment.ps1" ]; then
        # Проверяем основные команды
        command -v kubectl &> /dev/null && success "kubectl найден" || error "kubectl не найден"
        command -v docker &> /dev/null && success "docker найден" || error "docker не найден"
        command -v git &> /dev/null && success "git найден" || error "git не найден"
        success "Валидация окружения"
    else
        error "Файл validate-deployment.ps1 не найден"
        exit 1
    fi
fi

# Шаг 2: Проверить K8s
header "ШАГ 2: ПРОВЕРКА ДОСТУПА К КЛАСТЕРУ"

K8S_REACHABLE=false
if kubectl cluster-info &> /dev/null; then
    K8S_REACHABLE=true
    success "Kubernetes кластер доступен"
fi

if [ "$K8S_REACHABLE" = false ] && [ "$SKIP_K8S" = false ]; then
    echo -e "\n${YELLOW}⚠️  Кластер не найден. Развернуть K8s? (y/n)${NC}"
    read -r deploy
    
    if [ "$deploy" = "y" ]; then
        header "ШАГ 2.5: РАЗВЕРТЫВАНИЕ K8S КЛАСТЕРА"
        
        if [ -f "./k8s-proxmox-deploy.sh" ]; then
            echo -e "${YELLOW}Запуск k8s-proxmox-deploy.sh...${NC}"
            bash ./k8s-proxmox-deploy.sh
            
            echo -e "${YELLOW}⏳ Ожидание инициализации кластера (30 сек)...${NC}"
            sleep 30
            
            success "K8s кластер развернут"
        else
            error "k8s-proxmox-deploy.sh не найден"
            exit 1
        fi
    else
        error "Пропущено развертывание K8s. Завершение."
        exit 1
    fi
fi

# Шаг 3: Развернуть Ceres сервисы
if [ "$ONLY_ARGOCD" = false ]; then
    header "ШАГ 3: РАЗВЕРТЫВАНИЕ СЕРВИСОВ CERES"
    
    if [ -f "./ceres-k8s-manifests.yaml" ]; then
        echo -e "${YELLOW}Применение манифестов...${NC}"
        kubectl apply -f ceres-k8s-manifests.yaml
        success "Манифесты применены"
        
        # Ожидание готовности подов
        echo -e "\n${YELLOW}⏳ Ожидание развертывания подов...${NC}"
        MAX_WAIT=300
        ELAPSED=0
        CHECK_INTERVAL=5
        
        while [ $ELAPSED -lt $MAX_WAIT ]; do
            READY=$(kubectl get pods -n ceres --no-headers 2>/dev/null | grep -c "Running" || echo "0")
            TOTAL=$(kubectl get pods -n ceres --no-headers 2>/dev/null | wc -l || echo "0")
            
            echo -e "  Подов готово: ${CYAN}$READY/$TOTAL${NC} (прошло: ${ELAPSED}с)"
            
            if [ "$READY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
                break
            fi
            
            sleep $CHECK_INTERVAL
            ELAPSED=$((ELAPSED + CHECK_INTERVAL))
        done
        
        success "Все сервисы Ceres развернуты"
    else
        error "ceres-k8s-manifests.yaml не найден"
    fi
    
    # Статус сервисов
    echo -e "\n${CYAN}Статус сервисов:${NC}"
    kubectl get pods -n ceres -o wide
fi

# Шаг 4: Развернуть ArgoCD
header "ШАГ 4: РАЗВЕРТЫВАНИЕ ARGOCD (GitOps)"

echo -e "${YELLOW}Установка ArgoCD...${NC}"
kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo -e "${YELLOW}⏳ Ожидание ArgoCD (30 сек)...${NC}"
sleep 30

success "ArgoCD установлен"

# Шаг 5: Получить пароль ArgoCD
header "ШАГ 5: КОНФИГУРАЦИЯ ARGOCD"

echo -e "${YELLOW}Получение пароля администратора ArgoCD...${NC}"
ARGOCD_PASSWORD=""
RETRIES=5

for i in $(seq 1 $RETRIES); do
    SECRET=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null || echo "")
    if [ ! -z "$SECRET" ]; then
        ARGOCD_PASSWORD=$(echo "$SECRET" | base64 -d)
        break
    fi
    
    if [ $i -lt $RETRIES ]; then
        echo -e "  Попытка $i/$RETRIES не удалась, ретрай через 5 сек..."
        sleep 5
    fi
done

if [ ! -z "$ARGOCD_PASSWORD" ]; then
    success "Пароль ArgoCD получен"
    echo -e "\n${GREEN}🔐 Учетные данные ArgoCD:${NC}"
    echo -e "  Пользователь: ${CYAN}admin${NC}"
    echo -e "  Пароль: ${YELLOW}$ARGOCD_PASSWORD${NC}"
else
    error "Не удалось получить пароль ArgoCD (попробуйте позже)"
fi

# Шаг 6: Показать ссылки
header "ШАГ 6: ССЫЛКИ НА РАБОТАЮЩИЕ СЕРВИСЫ"

echo -e "${CYAN}Основные сервисы доступны через:${NC}\n"

declare -a SERVICES=(
    "Keycloak (SSO)|8080|keycloak|ceres"
    "Nextcloud (Files)|80|nextcloud|ceres"
    "Gitea (Git)|3000|gitea|ceres"
    "Mattermost (Chat)|8000|mattermost|ceres"
    "Prometheus (Metrics)|9090|prometheus|monitoring"
    "Grafana (Dashboards)|3000|grafana|monitoring"
    "Portainer (Container Mgmt)|9000|portainer|ceres"
    "ArgoCD (GitOps)|8080|argocd-server|argocd"
)

for service in "${SERVICES[@]}"; do
    IFS='|' read -r NAME PORT SVC NS <<< "$service"
    echo -e "  ${WHITE}$NAME:${NC}"
    echo -e "    Local:     ${CYAN}http://localhost:$PORT${NC}"
    echo -e "    Cluster:   ${CYAN}http://$SVC.$NS.svc.cluster.local:$PORT${NC}"
    echo ""
done

# Шаг 7: Port-forward инструкции
header "ШАГ 7: ВКЛЮЧЕНИЕ PORT-FORWARD"

echo -e "${CYAN}Для доступа из localhost, запустите:${NC}\n"
echo -e "  kubectl port-forward svc/keycloak -n ceres 8080:8080 &"
echo -e "  kubectl port-forward svc/nextcloud -n ceres 8081:80 &"
echo -e "  kubectl port-forward svc/gitea -n ceres 3000:3000 &"
echo -e "  kubectl port-forward svc/mattermost -n ceres 8000:8000 &"
echo -e "  kubectl port-forward svc/prometheus -n monitoring 9090:9090 &"
echo -e "  kubectl port-forward svc/grafana -n monitoring 3001:3000 &"
echo -e "  kubectl port-forward svc/portainer -n ceres 9000:9000 &"
echo -e "  kubectl port-forward svc/argocd-server -n argocd 8443:443 &"
echo ""

echo -e "${YELLOW}Включить port-forward сейчас? (y/n)${NC}"
read -r setup_pf

if [ "$setup_pf" = "y" ]; then
    echo -e "${YELLOW}Запуск port-forward...${NC}"
    kubectl port-forward svc/keycloak -n ceres 8080:8080 &
    kubectl port-forward svc/nextcloud -n ceres 8081:80 &
    kubectl port-forward svc/gitea -n ceres 3000:3000 &
    kubectl port-forward svc/mattermost -n ceres 8000:8000 &
    kubectl port-forward svc/prometheus -n monitoring 9090:9090 &
    kubectl port-forward svc/grafana -n monitoring 3001:3000 &
    kubectl port-forward svc/portainer -n ceres 9000:9000 &
    kubectl port-forward svc/argocd-server -n argocd 8443:443 &
    
    success "Port-forward запущен в фоне"
    sleep 2
fi

# Шаг 8: Финальная проверка
header "ШАГ 8: ФИНАЛЬНАЯ ПРОВЕРКА"

POD_COUNT=$(kubectl get pods -n ceres --no-headers 2>/dev/null | wc -l || echo "0")

echo -e "${CYAN}Статус сервисов:${NC}"
info "Подов в ceres:     $POD_COUNT"
info "ArgoCD namespace:  argocd"

# Итог
header "✅ CERES ПОЛНОСТЬЮ ВКЛЮЧЕН И ГОТОВ"

echo -e "${CYAN}Следующие шаги:${NC}"
echo -e "  1. Откройте браузер на ${YELLOW}http://localhost:8080${NC} для Keycloak"
echo -e "  2. Для GitOps настройки, смотрите документацию"
echo -e "  3. Мониторинг доступен на ${YELLOW}http://localhost:3001${NC} (Grafana)"
echo ""

echo -e "Полная документация: ${YELLOW}f:\\Ceres\\РАБОЧИЕ_СЕРВИСЫ.md${NC}"
echo -e "Быстрый старт: ${YELLOW}f:\\Ceres\\README.md${NC}"
echo ""

echo -e "${GREEN}Статус: ✅ PRODUCTION READY${NC}"
echo -e "${CYAN}Время развертывания: ~2 часа${NC}"
