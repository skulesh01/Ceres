# CERES Platform - Full Deployment Plan

## 🎯 Цель
Развернуть все сервисы платформы CERES и настроить VPN доступ

## ✅ Уже развернуто (Core Infrastructure)

1. **PostgreSQL** - 10.43.1.196:5432 ✅
2. **Redis** - 10.43.89.168:6379 ✅
3. **WireGuard VPN** - работает на Proxmox (10.8.0.0/24) ✅

## 📋 Требуется развернуть (Applications)

### Phase 1: Identity & Access
- [ ] **Keycloak** - OIDC Provider (SSO для всех сервисов)
  - Подключается к PostgreSQL
  - keycloak.ceres.local

### Phase 2: DevOps Platform
- [ ] **GitLab** - Git repository + CI/CD
  - Подключается к PostgreSQL, Redis
  - gitlab.ceres.local

### Phase 3: Collaboration
- [ ] **Nextcloud** - File sharing
  - nextcloud.ceres.local
  
- [ ] **Mattermost** - Team chat
  - mattermost.ceres.local
  
- [ ] **Wiki.js** - Documentation
  - wiki.ceres.local

### Phase 4: Project Management
- [ ] **Redmine** - Issue tracker
  - redmine.ceres.local

### Phase 5: Monitoring & Observability
- [ ] **Prometheus** - Metrics
  - prometheus.ceres.local
  
- [ ] **Grafana** - Dashboards
  - grafana.ceres.local
  
- [ ] **Loki** - Logs
  - loki.ceres.local
  
- [ ] **Jaeger** - Distributed tracing
  - jaeger.ceres.local

### Phase 6: Networking
- [ ] **Ingress NGINX** - Reverse proxy (для доступа через домены)
- [ ] **Cert-Manager** - TLS сертификаты (для HTTPS)

## 🌐 VPN Access Setup

### Сервер (Proxmox)
```
WireGuard Server: 10.8.0.1
External IP: 192.168.1.3
Port: 51820
Network: 10.8.0.0/24
```

### Клиент (Ваш компьютер)
Нужно:
1. Установить WireGuard на Windows
2. Создать конфигурацию клиента
3. Подключиться к VPN
4. Получить доступ к сервисам через ClusterIP

### После подключения к VPN

Вместо `kubectl port-forward` вы сможете напрямую:
```
PostgreSQL: 10.43.1.196:5432
Redis: 10.43.89.168:6379
Keycloak: keycloak.ceres.local
GitLab: gitlab.ceres.local
...
```

## 🔧 Методы доступа к сервисам

### Метод 1: NodePort (простой, но небезопасный)
```yaml
service:
  type: NodePort
```
Доступ: `http://192.168.1.3:<NodePort>`

### Метод 2: Ingress + DNS (рекомендуемый)
```yaml
ingress:
  enabled: true
  host: keycloak.ceres.local
```
Доступ: `https://keycloak.ceres.local` (через VPN)

### Метод 3: VPN + ClusterIP (максимально безопасный)
```
VPN → K3s CNI → ClusterIP
```
Доступ: прямой к ClusterIP через туннель

## 📝 Следующие шаги

1. **Создать манифесты для приложений** (Keycloak, GitLab, etc.)
2. **Развернуть Ingress NGINX**
3. **Настроить DNS** (keycloak.ceres.local → ClusterIP)
4. **Создать конфигурацию WireGuard для клиента**
5. **Задокументировать подключение**

## 🎯 Приоритет развертывания

**Сегодня развернуть:**
1. Ingress NGINX (для маршрутизации)
2. Keycloak (для SSO)
3. Prometheus + Grafana (для мониторинга)
4. Настроить VPN клиент для доступа

**Позже развернуть:**
- GitLab (большой, требует ресурсов)
- Nextcloud, Mattermost, Wiki.js
- Loki, Jaeger

Какие сервисы развернуть в первую очередь?
