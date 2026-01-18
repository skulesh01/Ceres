# 🔍 CERES Services Matrix

Краткая справка для быстрого поиска сервиса и его модуля.

---

## 📋 Алфавитный список всех 45+ сервисов

| Сервис | Модуль | Профили | Назначение |
|--------|--------|---------|-----------|
| **Alertmanager** | monitoring | Large | Управление алертами Prometheus |
| **cAdvisor** | monitoring | Small+ | Метрики контейнеров Docker |
| **Caddy** | edge | Small+ | Reverse proxy, HTTPS, домены |
| **Cert-Manager** | k3s | Large (K8s) | Управление сертификатами |
| **Cloudflare Tunnel** | tunnel | Medium+ | Туннелирование через Cloudflare |
| **Dovecot** | mail | Medium+ | IMAP сервер (в Mailu) |
| **Elasticsearch** | advanced | Large (opt) | Полнотекстовый поиск |
| **etcd** | ha | Large | Consensus для Patroni |
| **Gitea** | apps | Small+ | Git хостинг + SSH |
| **Grafana** | monitoring | Small+ | Дашборды (OIDC) |
| **HAProxy** | ha | Large | Балансировка нагрузки |
| **Hashicorp Vault** | vault | Medium+ | Управление секретами |
| **Jaeger** | observability | Large (opt) | Distributed tracing |
| **Kafka** | advanced | Large (opt) | Потоковая обработка |
| **Keepalived** | ha | Large | Failover для HAProxy |
| **Keycloak** | apps | Small+ | SSO/OIDC аутентификация |
| **Kong** | api-gateway | Large (opt) | API gateway |
| **kube-apiserver** | k3s | Large (K8s) | Kubernetes API сервер |
| **kube-controller-manager** | k3s | Large (K8s) | Kubernetes контроллеры |
| **kube-scheduler** | k3s | Large (K8s) | Kubernetes планировщик |
| **kubelet** | k3s | Large (K8s) | Kubernetes агент на узле |
| **Loki** | observability | Medium+ | TSDB для логов |
| **Mailu Admin** | mail | Medium+ | Управление почтовыми ящиками |
| **Mailu Front** | mail | Medium+ | Reverse proxy для почты |
| **Mailu IMAP** | mail | Medium+ | IMAP сервер (Dovecot) |
| **Mailu SMTP** | mail | Medium+ | SMTP сервер (Postfix) |
| **Mattermost** | apps | Small+ | Корпоративный чат |
| **Mayan EDMS** | edms | Large | Управление документами |
| **Mayan RabbitMQ** | edms | Large | Message queue для Mayan |
| **Mayan Redis** | edms | Large | Кэш для Mayan |
| **Mayan Worker** | edms | Large | Асинхронная обработка Mayan |
| **Metrics Server** | k3s | Large (K8s) | Сбор метрик для HPA |
| **MinIO** | advanced | Large (opt) | S3-совместимое хранилище |
| **Nextcloud** | apps | Small+ | Облачное хранилище файлов |
| **Node Exporter** | monitoring | Medium+ (opt) | Метрики хоста |
| **OPA (Open Policy Agent)** | opa | Large | Политики доступа |
| **PostgreSQL** | core | Small+ | Основная БД для всех |
| **PostgreSQL 1/2/3** | ha | Large | Кластер БД с Patroni |
| **PostgreSQL Exporter** | monitoring | Small+ | Метрики PostgreSQL |
| **Portainer** | ops | Small+ | GUI управление Docker |
| **Postfix** | mail | Medium+ | SMTP сервер (в Mailu) |
| **Prometheus** | monitoring | Small+ | Сбор метрик (TSDB) |
| **Promtail** | observability | Medium+ | Агент сбора логов |
| **RabbitMQ** | advanced | Large (opt) | Message broker |
| **Redis** | core | Small+ | Кэш и очереди |
| **Redis Exporter** | monitoring | Small+ | Метрики Redis |
| **Redis Sentinel 1/2/3** | ha | Large | Высокая доступность Redis |
| **Redmine** | apps | Small+ | Управление проектами |
| **Roundcube** | mail | Medium+ | Веб-интерфейс для почты |
| **Sealed Secrets** | k3s | Large (K8s) | Шифрование секретов |
| **Tempo** | observability | Large | Distributed tracing backend |
| **Uptime Kuma** | ops | Small+ | Мониторинг доступности |
| **Vault Init** | vault | Medium+ | Инициализация Vault |
| **Wiki.js** | apps | Small+ | База знаний |
| **WireGuard** | vpn | Medium+ | VPN сервер |
| **wg-easy** | vpn | Medium+ | UI для управления WireGuard |

---

## 🗂️ По модулям (организация)

### 1. Core (обязательные)
- PostgreSQL
- Redis

### 2. Apps (приложения)
- Keycloak
- Nextcloud
- Gitea
- Mattermost
- Redmine
- Wiki.js

### 3. Monitoring (метрики + дашборды)
- Prometheus
- Grafana
- cAdvisor
- PostgreSQL Exporter
- Redis Exporter
- Node Exporter (опц)
- Alertmanager (опц)

### 4. Ops (управление инфраструктурой)
- Portainer
- Uptime Kuma

### 5. Edge (входной трафик)
- Caddy

### 6. VPN (безопасность)
- WireGuard
- wg-easy

### 7. Mail (почтовая система)
- Mailu Admin
- Mailu Front
- Mailu SMTP
- Mailu IMAP (Dovecot)
- Postfix (входит в Mailu)
- Roundcube

### 8. Observability (логирование + трейсинг)
- Loki
- Promtail
- Tempo (опц)
- Jaeger (опц)

### 9. Vault (управление секретами)
- Hashicorp Vault
- Vault Init

### 10. EDMS (управление документами)
- Mayan Redis
- Mayan RabbitMQ
- Mayan EDMS
- Mayan Worker

### 11. HA (высокая доступность)
- etcd
- PostgreSQL 1
- PostgreSQL 2
- PostgreSQL 3
- Redis Sentinel 1
- Redis Sentinel 2
- Redis Sentinel 3 (опц)
- HAProxy
- Keepalived

### 12. OPA (политики)
- Open Policy Agent

### 13. Tunnel (внешнее туннелирование)
- Cloudflare Tunnel

### 14. Advanced / API Gateway (опц)
- Kong
- RabbitMQ
- Elasticsearch
- MinIO

### 15. K3s / Kubernetes (только в режиме K8s)
- kube-apiserver
- kube-controller-manager
- kube-scheduler
- kubelet
- etcd (system)
- coredns
- kube-proxy
- metrics-server
- Sealed Secrets Operator
- Cert-Manager

### 16. Network Policies (K8s only)
- (Kubernetes network policies config)

---

## 🎯 Таблица профилей

| Компонент | Small | Medium | Large | Описание |
|-----------|:-----:|:------:|:-----:|----------|
| Core | ✅ | ✅ | ✅ | PostgreSQL, Redis |
| Apps (6) | ✅ | ✅ | ✅ | Keycloak, Nextcloud, Gitea, etc |
| Monitoring | ✅ | ✅ | ✅ | Prometheus, Grafana |
| Ops | ✅ | ✅ | ✅ | Portainer, Uptime Kuma |
| Edge | ✅ | ✅ | ✅ | Caddy |
| VPN | ❌ | ✅ | ✅ | WireGuard |
| Mail | ❌ | ✅ | ✅ | Mailu stack |
| Observability | ❌ | ✅ | ✅ | Loki, Promtail, Tempo |
| Vault | ❌ | ❌ | ✅ | Secret management |
| EDMS | ❌ | ❌ | ✅ | Mayan EDMS |
| HA | ❌ | ❌ | ✅ | PostgreSQL/Redis кластеры |
| OPA | ❌ | ❌ | ✅ | Политики (K8s) |
| K8s Operators | ❌ | ❌ | ✅ | Sealed Secrets, Cert-Manager |
| Tunnel | ❌ | ❌ | ✅ (opt) | Cloudflare Tunnel |
| Advanced | ❌ | ❌ | ✅ (opt) | Kong, RabbitMQ, Elasticsearch |
| **ИТОГО** | **20** | **30** | **45+** | |

---

## 🔗 Поиск по назначению

### 🔐 Безопасность
- Keycloak (SSO/OIDC)
- Vault (секреты)
- OPA (политики)
- Sealed Secrets (K8s)
- Cert-Manager (сертификаты)
- WireGuard (VPN)

### 📊 Мониторинг
- Prometheus (метрики)
- Grafana (дашборды)
- cAdvisor (контейнеры)
- Loki (логи)
- Tempo/Jaeger (трейсинг)
- Uptime Kuma (доступность)

### 💾 Данные
- PostgreSQL (БД)
- Redis (кэш)
- MinIO (объекты)
- RabbitMQ (очереди)
- Elasticsearch (поиск)

### 🌍 Сервисы
- Nextcloud (файлы)
- Gitea (Git)
- Mattermost (чат)
- Redmine (проекты)
- Wiki.js (знания)
- Mailu (почта)
- Mayan EDMS (документы)

### 🛠️ Инфраструктура
- Caddy (proxy)
- Portainer (GUI)
- HAProxy (LB)
- Keepalived (failover)
- Patroni (DB HA)
- Sentinel (Redis HA)

---

## 📌 Быстрые команды

```powershell
# Только core + apps
ceres start core apps

# Small профиль (локалка)
ceres deploy compose --profile small

# Medium профиль (production)
ceres deploy compose --profile medium

# Large профиль (HA, K8s)
ceres deploy k8s --profile large

# Проверить какие сервисы запущены
ceres status --detailed

# Логи конкретного сервиса
ceres logs keycloak
ceres logs postgres
ceres logs grafana
```

---

## 🎓 Как выбрать профиль?

### Small ✅ используйте если:
- Локальная разработка
- Личная лаборатория
- Тестирование
- **Ресурсы:** 4 CPU, 8GB RAM, 80GB HDD

### Medium ✅ используйте если:
- Production ready (рекомендуется)
- Компания/стартап
- Нужны логи, почта, VPN
- Один сервер (мощный)
- **Ресурсы:** 8 CPU, 16GB RAM, 200GB SSD

### Large ✅ используйте если:
- Enterprise
- Нужна высокая доступность (HA)
- Кластер Kubernetes
- 3+ узла Proxmox
- **Ресурсы:** 24+ CPU, 56GB RAM, 450GB SSD на каждый узел

---

**Последнее обновление:** 2025-01-XX  
**Версия:** 1.0  
**Статус:** ✅ Завершено
