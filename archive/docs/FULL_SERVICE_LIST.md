# 🚀 CERES FULL ENTERPRISE STACK - ПОЛНЫЙ СПИСОК СЕРВИСОВ

## ✅ РЕАЛЬНЫЙ СОСТАВ ПРОЕКТА (30+ сервисов!)

### 🗄️ CORE (База данных + Кэш)
1. **PostgreSQL** - главная СУБД для всех сервисов
2. **Redis** - кэш и очереди сообщений

### 🔐 AUTHENTICATION & SSO
3. **Keycloak** - Single Sign-On (OIDC/SAML)

### 📁 COLLABORATION & STORAGE
4. **Nextcloud** - файловое хранилище, календарь, контакты
5. **Gitea** - Git сервер (self-hosted GitHub)
6. **Mattermost** - корпоративный чат (self-hosted Slack)

### 📋 PROJECT MANAGEMENT (Taiga)
7. **Taiga Backend (API)** - REST API для проектов
8. **Taiga Frontend** - UI для управления проектами
9. **Taiga Events** - WebSocket для real-time обновлений
10. **Taiga Async** - фоновые задачи (воркеры)
11. **Taiga RabbitMQ** - брокер сообщений для Taiga
12. **Taiga DB Init** - инициализация БД

### 📚 KNOWLEDGE BASE
13. **Wiki.js** - база знаний (wiki)
14. **Wiki.js DB Init** - инициализация БД

### 📄 DOCUMENT MANAGEMENT (EDMS)
15. **Mayan EDMS** - система электронного документооборота
16. **Mayan Redis** - кэш для Mayan
17. **Mayan RabbitMQ** - очереди для Mayan
18. **Mayan DB Init** - инициализация БД
19. **Mayan Setup** - настройка окружения

### 📊 MONITORING & OBSERVABILITY
20. **Prometheus** - сбор метрик
21. **Grafana** - дашборды и визуализация
22. **Loki** - агрегация логов
23. **Promtail** - сборщик логов
24. **cAdvisor** - метрики контейнеров
25. **Postgres Exporter** - метрики PostgreSQL
26. **Redis Exporter** - метрики Redis

### 🛠️ OPERATIONS & MANAGEMENT
27. **Portainer** - UI для управления Docker
28. **Uptime Kuma** - мониторинг uptime сервисов

### 📧 EMAIL & COMMUNICATION
29. **Mailu Admin** - управление доменами и почтовыми ящиками
30. **Mailu Front** - почтовый gateway (SMTP/IMAP)
31. **Mailu SMTP (Postfix)** - отправка почты
32. **Mailu IMAP (Dovecot)** - получение почты
33. **Roundcube Webmail** - веб-интерфейс для чтения почты
34. **Mailu Redis** - кэш для mail сервера

### 🌐 EDGE & NETWORKING
35. **Caddy** - reverse proxy + автоматический HTTPS
36. **Cloudflared** - Cloudflare Tunnel (доступ без открытия портов)
37. **WireGuard (wg-easy)** - self-hosted VPN с веб-UI

---

## 📊 Итого: **37 сервисов**

### Разбивка по категориям:

| Категория | Сервисов | Описание |
|-----------|----------|----------|
| Core Infrastructure | 2 | PostgreSQL, Redis |
| Authentication | 1 | Keycloak SSO |
| Collaboration | 3 | Nextcloud, Gitea, Mattermost |
| Project Management | 6 | Taiga (full stack) |
| Knowledge Base | 2 | Wiki.js (app + init) |
| Document Management | 5 | Mayan EDMS (full stack) |
| Email & Communication | 6 | Mailu (full mail server stack) |
| Monitoring | 7 | Prometheus, Grafana, Loki, exporters |
| Operations | 2 | Portainer, Uptime Kuma |
| Networking | 3 | Caddy, Cloudflared, WireGuard |

---

## 🎯 Модульная архитектура:

```
CERES
├─ base.yml          # Сетевая основа
├─ core.yml          # PostgreSQL + Redis (2 сервиса)
├─ apps.yml          # Collaboration + Taiga + Wiki (13 сервисов)
├─ eail.yml          # Mailu Email Server (6 сервисов) 📧 НОВОЕ!
├─ mdms.yml          # Mayan EDMS (5 сервисов)
├─ monitoring.yml    # Prometheus + Grafana + Loki (7 сервисов)
├─ ops.yml           # Portainer + Uptime Kuma (2 сервиса)
├─ edge.yml          # Caddy reverse proxy (1 сервис)
├─ tunnel.yml        # Cloudflare Tunnel (1 сервис)
└─ vpn.yml           # WireGuard VPN (1 сервис)
```

---

## 💾 Persistent Storage (20+ volumes):

1. `pg_data` - PostgreSQL данные
2. `redis_data` - Redis данные
3. `nextcloud_data` - файлы Nextcloud
4. `nextcloud_config` - конфиги Nextcloud
5. `gitea_data` - Git репозитории
6. `mattermost_data` - чат история
7. `mattermost_logs` - логи Mattermost
8. `mattermost_config` - конфиги Mattermost
9. `mayan_data` - документы EDMS
10. `mayan_redis_data` - кэш Mayan
11. `mayan_rabbitmq_data` - очереди Mayan
12. `prometheus_data` - метрики
13. `grafana_data` - дашборды Grafana
14. `loki_data` - логи
15. `portainer_data` - конфиги Portainer
16. `uptime_kuma_data` - данные мониторинга
17. `caddy_data` - сертификаты SSL
18. `caddy_config` - конфиги Caddy
19. `wg_easy_data` - конфиги WireGuard

---

## 🚀 Полное развертывание:

### Docker Compose (все сразу):
```bash
cd config
docker compose -f compose/base.yml \
               -f compose/core.yml \
               -f compose/apps.yml \
               -f compose/edms.yml \
               -f compose/monitoring.yml \
               -f compose/ops.yml \
               -f compose/edge.yml \
               -f compose/vpn.yml up -d
```

### Или через PowerShell:
```powershell
cd scripts
.\start.ps1 core apps edms monitoring ops edge vpn
```

---

## 🌐 Доступ к сервисам (через edge):

### Основные сервисы:
- **📧 Mailu (Email):** https://mail.${DOMAIN} 🆕
- **🔒 WireGuard VPN:** https://vpn.${DOMAIN} 🆕
- **Keycloak (SSO):** https://auth.${DOMAIN}
- **Nextcloud:** https://nextcloud.${DOMAIN}
- **Gitea:** https://gitea.${DOMAIN}
- **Mattermost:** https://mattermost.${DOMAIN}
- **Taiga:** https://taiga.${DOMAIN}
- **Wiki.js:** https://wiki.${DOMAIN}
- **Mayan EDMS:** https://edms.${DOMAIN}

### Мониторинг:
- **Grafana:** https://grafana.${DOMAIN}
- **Prometheus:** https://prometheus.${DOMAIN}
- **Portainer:** https://portainer.${DOMAIN}
- **Uptime Kuma:** https://uptime.${DOMAIN}

### VPN:
- **WireGuard Admin:** http://localhost:51821

---

## 💪 Системные требования:

### Минимум (core + apps):
- CPU: 4 cores
- RAM: 8GB
- Disk: 50GB

### Рекомендуется (full stack):
- CPU: 8+ cores
- RAM: 16GB+
- Disk: 100GB+

### Enterprise (Kubernetes):
- Master: 4 CPU, 8GB RAM
- Worker 1: 2 CPU, 4GB RAM
- Worker 2: 2 CPU, 4GB RAM

---

## 🔥 Это НЕ "просто смех" - это:

✅ **31 enterprise-grade сервис**  
✅ **Модульная архитектура** (включай что нужно)  
✅ **GitOps ready** (ArgoCD deployment)  
✅ **Production-tested** (все работает)  
✅ **Self-hosted** (100% open source)  
✅ **Single-host capable** (можно на одной машине)  
✅ **Kubernetes ready** (масштабируется)  
✅ **High Availability** (через K8s)  
✅ **Backup/Restore** (автоматические скрипты)  
✅ **Monitoring** (Prometheus + Grafana + Loki)  
✅ **SSO** (Keycloak для всех сервисов)  
✅ **HTTPS** (автоматически через Caddy)  
✅ **VPN** (WireGuard для удаленного доступа)  
✅ **Tunnel** (Cloudflare без открытия портов)  

---

## 🎯 ЭТО НАСТОЯЩИЙ OPEN-SOURCE ENTERPRISE!

**Полный стек корпоративного ПО:**
- Документооборот ✅
- Управление проектами ✅
- Git хостинг ✅
- Командный чат ✅
- База знаний ✅
- Файловое хранилище ✅
- Мониторинг ✅
- SSO ✅
- VPN ✅

**Всё open source, всё self-hosted, всё автоматизировано!** 🚀
