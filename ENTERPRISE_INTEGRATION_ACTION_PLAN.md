# 🚀 ENTERPRISE INTEGRATION - ACTION PLAN

---

## 📋 ФАЗА 1: КРИТИЧНЫЕ ИСПРАВЛЕНИЯ (Week 1)

### Задача 1.1: Alertmanager Configuration & Setup

**СТАТУС:** 🔴 КРИТИЧНО  
**ВРЕМЯ:** 3 часа  
**СЛОЖНОСТЬ:** 🟢 Низкая

**ЧТО ДЕЛАТЬ:**
```bash
1. Создать config/compose/alertmanager.yml
   • Alert routing (по severity: critical, warning, info)
   • Webhook receiver (для Mattermost)
   • Email receiver (для резервного алертинга)
   • Grouping (group by: alertname, instance, severity)

2. Создать prometheus/alert-rules.yml
   • CriticalHighCPU: cpu_usage > 80% за 5 мин
   • CriticalHighMemory: memory_usage > 85% за 5 мин
   • CriticalDiskSpace: disk_free < 10%
   • CriticalDatabaseLatency: query_duration > 5s
   • CriticalAPILatency: http_request_duration > 2s
   • ServiceDown: up == 0 за 2 мин

3. Обновить config/compose/monitoring.yml
   • Добавить alertmanager service
   • Добавить alert rules volume
   • Настроить prometheus для работы с alertmanager

4. Создать runbooks/ALERTS.md
   • Что означает каждый alert
   • Как его исправить
   • На кого направить на эскалацию
```

**DELIVERABLES:**
- [ ] alertmanager.yml создан и протестирован
- [ ] prometheus/alert-rules.yml создан
- [ ] monitoring.yml обновлён
- [ ] runbooks/ALERTS.md документирован
- [ ] Проверено: alert firing → alertmanager → (email/webhook)

---

### Задача 1.2: Mattermost Webhooks Integration

**СТАТУС:** 🔴 КРИТИЧНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟢 Низкая

**ЧТО ДЕЛАТЬ:**
```bash
1. Создать webhook в Mattermost
   curl -X POST https://mattermost.domain/api/v4/hooks/incoming \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "channel_id": "GENERAL_CHANNEL_ID",
       "display_name": "Gitea Webhook",
       "description": "Auto notifications from Gitea"
     }'

2. Настроить Gitea webhooks (в UI или API)
   POST /api/v1/repos/{owner}/{repo}/hooks
   - URL: https://mattermost.domain/hooks/WEBHOOK_ID
   - Events: push, pull_request, release, issue_opened

3. Настроить Redmine webhooks
   POST /api/webhooks/config.json
   - URL: https://mattermost.domain/hooks/REDMINE_WEBHOOK_ID
   - Events: issue_created, issue_updated, project_created

4. Настроить Alertmanager webhook receiver
   alertmanager.yml:
   receivers:
     - name: 'mattermost'
       webhook_configs:
         - url: 'https://mattermost.domain/hooks/ALERTMANAGER_WEBHOOK_ID'
           send_resolved: true

5. Настроить Uptime Kuma notifications
   • Тип: Webhook (custom)
   • URL: https://mattermost.domain/hooks/UPTIME_WEBHOOK_ID
   • Method: POST
```

**DELIVERABLES:**
- [ ] 4 webhooks созданы в Mattermost
- [ ] Gitea → Mattermost notifications работают
- [ ] Redmine → Mattermost notifications работают
- [ ] Alertmanager → Mattermost alerts работают
- [ ] Uptime Kuma → Mattermost notifications работают
- [ ] Проверено: сообщение в Gitea → появляется в Mattermost в течение 5 сек

---

### Задача 1.3: Audit Logging Centralization

**СТАТУС:** 🔴 КРИТИЧНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟢 Низкая

**ЧТО ДЕЛАТЬ:**
```bash
1. Настроить Keycloak logging
   • Collect audit events
   • Send to Loki (через Promtail)
   • Dashboard в Grafana

2. Настроить PostgreSQL logging
   config/postgresql/postgresql.conf:
   • log_statement = 'all'
   • log_duration = on
   • log_min_duration_statement = 1000 (логировать query > 1s)

3. Настроить Redis logging
   • CONFIG SET loglevel debug
   • Slow log capture

4. Настроить Nextcloud logging
   • /var/www/nextcloud/config/config.php:
     'loglevel' => 1 (minimum)

5. Настроить Gitea logging
   • config.yml: LOG_MODE = file, level = info

6. Собрать все логи в Loki через Promtail
   • Promtail scrape config:
     - path: /var/log/keycloak/audit.log
     - path: /var/log/postgresql/
     - path: /var/log/redis/
     - labels: {job: audit, service: keycloak|postgres|redis}
```

**DELIVERABLES:**
- [ ] Keycloak audit events → Loki
- [ ] PostgreSQL slow queries → Loki
- [ ] Redis slow log → Loki
- [ ] Dashboard в Grafana созданы для каждого источника
- [ ] Проверено: query в Loki показывает последние логи всех сервисов

---

### Задача 1.4: MFA Configuration in Keycloak

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 1 час  
**СЛОЖНОСТЬ:** 🟢 Низкая

**ЧТО ДЕЛАТЬ:**
```bash
1. Включить OTP (One-Time Password)
   • Keycloak UI → Realm Settings → Authentication → OTP Policy
   • Type: TOTP (Time-based)
   • Digits: 6
   • Period: 30 seconds

2. Сделать OTP обязательным для всех пользователей (optional)
   • Authentication → Required Actions: Configure OTP

3. Включить U2F/WebAuthn (если нужно)
   • Webauthn Policy
   • Attestation: none, direct, indirect

4. Документировать процесс для пользователей
   • docs/MFA_SETUP.md
```

**DELIVERABLES:**
- [ ] MFA настроена в Keycloak
- [ ] Админ может включить MFA для пользователя
- [ ] Документация создана

---

### Задача 1.5: Runbooks & Incident Response Documentation

**СТАТУС:** 🔴 КРИТИЧНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟢 Низкая

**ЧТО ДЕЛАТЬ:**
```bash
1. Создать runbooks/ALERTS.md
   Для каждого alert:
   - Что означает
   - Вероятные причины
   - Как исправить (step-by-step)
   - На кого направить

   ПРИМЕР:
   ## CriticalHighCPU Alert
   **Severity:** 🔴 Critical
   **Trigger:** CPU > 80% за 5 мин
   
   ### Возможные причины:
   - [ ] Heavy batch job запущен
   - [ ] Memory leak в приложении
   - [ ] DDoS атака
   - [ ] Bad query в БД
   
   ### Как исправить:
   1. Проверить top процессов: docker stats
   2. Если приложение: перезагрузить сервис
   3. Если БД: проверить slow queries
   4. Если нет решения: эскалировать на инженера

2. Создать runbooks/ESCALATION.md
   • Первый уровень: chat (Mattermost)
   • Второй уровень: SMS/Telegram (если есть)
   • Третий уровень: Phone call
   • Четвёртый уровень: On-call инженер

3. Создать runbooks/FAILOVER.md
   • Как переключиться на backup (если есть)
   • Команды для рестарта сервисов
   • Проверка здоровья после failover

4. Создать runbooks/RECOVERY.md
   • Как восстановить из backup
   • Шаги по синхронизации БД
   • Проверка целостности данных
```

**DELIVERABLES:**
- [ ] runbooks/ALERTS.md документирован для всех alerts
- [ ] runbooks/ESCALATION.md создан
- [ ] runbooks/FAILOVER.md создан
- [ ] runbooks/RECOVERY.md создан
- [ ] Все runbooks загружены в Wiki.js (или Nextcloud)

---

## ИТОГО ФАЗА 1:

```
✅ Alertmanager configuration & rules         (3 часа)
✅ Mattermost webhooks (4 интеграции)         (2 часа)
✅ Audit logging centralization               (2 часа)
✅ MFA setup в Keycloak                       (1 час)
✅ Runbooks & documentation                   (2 часа)

ИТОГО: ~10 часов (1.5 дня full-time)
РЕЗУЛЬТАТ: 57% → 65% enterprise ready
```

---

## 📋 ФАЗА 2: ИНТЕГРАЦИЯ (Week 2)

### Задача 2.1: oauth2-proxy on Caddy

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟡 Средняя

**ЧТО ДЕЛАТЬ:**
```bash
1. Добавить oauth2-proxy сервис в config/compose/edge.yml
   docker-compose.yml (oauth2-proxy):
   • Image: quay.io/oauth2-proxy/oauth2-proxy:latest
   • Env: OAUTH2_PROXY_PROVIDER=oidc
   • Env: OAUTH2_PROXY_OIDC_ISSUER_URL=https://auth.ceres/
   • Env: OAUTH2_PROXY_CLIENT_ID=caddy-oauth2-proxy
   • Env: OAUTH2_PROXY_CLIENT_SECRET=$OAUTH2_CLIENT_SECRET
   • Env: OAUTH2_PROXY_COOKIE_SECRET=$OAUTH2_COOKIE_SECRET

2. Обновить Caddy конфиг
   Caddyfile:
   # Защитить все приложения через oauth2-proxy
   *.ceres {
     reverse_proxy oauth2-proxy:4180 {
       # Redirect на oauth2-proxy перед приложением
     }
     
     # Исключения: Keycloak, Gitea SSH не нужны OAuth2
     @public_routes {
       path /auth* /git-ssh*
     }
     route @public_routes {
       reverse_proxy keycloak:8080
       # или не проксировать
     }
   }

3. Создать Keycloak OIDC client для oauth2-proxy
   • Client ID: caddy-oauth2-proxy
   • Client Secret: [генерировать]
   • Redirect URI: https://*/oauth2/callback
   • Access type: public
   • Valid scopes: openid, profile, email

4. Протестировать:
   • Заходим на https://nextcloud.ceres/
   • Редирект на oauth2-proxy → Keycloak
   • После логина → nextcloud
```

**DELIVERABLES:**
- [ ] oauth2-proxy добавлен в compose
- [ ] Caddyfile обновлён
- [ ] Keycloak OIDC client создан
- [ ] Проверено: защита on all services except Keycloak

---

### Задача 2.2: File Sync Setup (Nextcloud ↔ Gitea ↔ Redmine)

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 4 часа  
**СЛОЖНОСТЬ:** 🟡 Средняя

**ЧТО ДЕЛАТЬ:**
```bash
1. Настроить Nextcloud WebDAV для Gitea wiki
   • Создать shared folder в Nextcloud: /Project/WikiBackup
   • Включить WebDAV доступ
   • Создать user для sync: gitea-sync (с password)

2. Создать скрипт: scripts/sync-gitea-wiki-to-nextcloud.sh
   #!/bin/bash
   GITEA_WIKI_REPO="https://gitea.ceres/user/project.wiki.git"
   NEXTCLOUD_PATH="/Project/WikiBackup"
   NEXTCLOUD_USER="gitea-sync"
   NEXTCLOUD_PASS="$NEXTCLOUD_SYNC_PASSWORD"
   
   # Clone wiki repo
   git clone $GITEA_WIKI_REPO /tmp/wiki
   
   # Upload to Nextcloud via WebDAV
   cadaver https://nextcloud.ceres/remote.php/dav/
   # cd $NEXTCLOUD_PATH
   # mput /tmp/wiki/*

3. Создать скрипт: scripts/sync-redmine-files-to-nextcloud.sh
   #!/bin/bash
   # Экспортировать файлы из Redmine
   # Загрузить в Nextcloud shared folder

4. Добавить cron jobs для автоматического sync
   # Sync gitea wiki every hour
   0 * * * * /opt/ceres/scripts/sync-gitea-wiki-to-nextcloud.sh
   
   # Sync redmine files every day at 2am
   0 2 * * * /opt/ceres/scripts/sync-redmine-files-to-nextcloud.sh

5. Документировать в Wiki.js
   • Architecture diagram
   • Sync schedule
   • Troubleshooting
```

**DELIVERABLES:**
- [ ] Nextcloud WebDAV настроена
- [ ] Sync скрипты созданы и тестированы
- [ ] Cron jobs добавлены
- [ ] Документация в Wiki.js
- [ ] Проверено: файлы в Gitea wiki → Nextcloud в течение часа

---

### Задача 2.3: Wiki.js Git Sync Module Setup

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟡 Средняя

**ЧТО ДЕЛАТЬ:**
```bash
1. Если Wiki.js поддерживает Git sync (есть модуль):
   • Включить в config
   • Настроить Gitea repository
   • Настроить branch (main)
   • Настроить sync interval (hourly)

2. Если нет встроенного модуля - создать скрипт:
   scripts/wiki-js-git-sync.sh:
   #!/bin/bash
   # Export wiki pages as Markdown
   # Commit to Gitea repo
   # On pull: import from Gitea

3. Добавить в cron:
   */30 * * * * /opt/ceres/scripts/wiki-js-git-sync.sh

4. Результат: Wiki.js pages ↔ Gitea repository (version control!)
```

**DELIVERABLES:**
- [ ] Wiki.js → Gitea sync работает
- [ ] Gitea → Wiki.js sync работает
- [ ] Cron job настроен
- [ ] Проверено: edit in Wiki.js → commit in Gitea

---

### Задача 2.4: Backup & Restore Automation

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟡 Средняя

**ЧТО ДЕЛАТЬ:**
```bash
1. Создать scripts/backup-full.sh
   #!/bin/bash
   BACKUP_DIR="/backups/$(date +%Y%m%d_%H%M%S)"
   
   # Backup PostgreSQL
   docker exec postgres pg_dump -U postgres ceres > $BACKUP_DIR/db.sql
   
   # Backup volumes
   docker run -v pg_data:/data -v $BACKUP_DIR:/backup \
     alpine tar czf /backup/pg_data.tar.gz -C /data .
   
   docker run -v nextcloud_data:/data -v $BACKUP_DIR:/backup \
     alpine tar czf /backup/nextcloud_data.tar.gz -C /data .
   
   # Backup configs
   cp -r config/ $BACKUP_DIR/config.backup/
   
   # Compress all
   tar czf $BACKUP_DIR.tar.gz $BACKUP_DIR/
   
   # Upload to S3/Cloud storage
   aws s3 cp $BACKUP_DIR.tar.gz s3://backups/

2. Создать scripts/restore-full.sh
   #!/bin/bash
   BACKUP_FILE=$1
   
   # Extract
   tar xzf $BACKUP_FILE -C /restore/
   
   # Restore database
   docker exec postgres psql -U postgres < /restore/db.sql
   
   # Restore volumes
   # ... restore logic

3. Добавить в cron (ежедневно в 3 часа ночи):
   0 3 * * * /opt/ceres/scripts/backup-full.sh

4. Документировать в runbooks/RECOVERY.md
```

**DELIVERABLES:**
- [ ] backup-full.sh работает
- [ ] restore-full.sh тестирован
- [ ] Cron job настроен
- [ ] Backup upload в cloud storage (S3/Dropbox/etc)

---

## ИТОГО ФАЗА 2:

```
✅ oauth2-proxy on Caddy                      (2 часа)
✅ File sync (Nextcloud ↔ Gitea ↔ Redmine)    (4 часа)
✅ Wiki.js Git sync                           (2 часа)
✅ Backup & restore automation                (2 часа)

ИТОГО: ~10 часов (1.5 дня full-time)
РЕЗУЛЬТАТ: 65% → 85% enterprise ready
```

---

## 📋 ФАЗА 3: HA & RESILIENCE (Week 3)

### Задача 3.1: PostgreSQL Patroni HA Setup

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 4 часа  
**СЛОЖНОСТЬ:** 🔴 Высокая

**ЧТО ДЕЛАТЬ:**
```bash
1. Deploy 3 PostgreSQL nodes с Patroni
   • Один master, два replica
   • etcd как distributed config store
   • Automatic failover if master dies

2. Обновить compose конфиг
   config/compose/core.yml:
   • postgresql-1 (master)
   • postgresql-2 (replica)
   • postgresql-3 (replica)
   • patroni-1, patroni-2, patroni-3
   • etcd (ключ-значение хранилище для координации)

3. Настроить Patroni конфигурацию
   • VIP (virtual IP): 192.168.1.50 (postgres.ceres)
   • Automatic failover
   • Streaming replication

4. Подключить все приложения к VIP
   • POSTGRES_HOST=postgres.ceres (вместо postgres-1)
   • Автоматический failover к replica if master dies

5. Тестировать failover
   • Остановить master PostgreSQL
   • Проверить, что replica становится master
   • Приложения продолжают работать (прозрачно)
```

**DELIVERABLES:**
- [ ] 3 PostgreSQL nodes deployed
- [ ] Patroni configured with automatic failover
- [ ] etcd running as cluster coordinator
- [ ] Virtual IP (VIP) working
- [ ] All apps connected to VIP
- [ ] Failover tested: master down → replica takes over

---

### Задача 3.2: Redis Sentinel HA Setup

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟡 Средняя

**ЧТО ДЕЛАТЬ:**
```bash
1. Deploy Redis Sentinel для мониторинга
   • Один Redis master
   • Два Redis replicas
   • Три Sentinel nodes (мониторинг + failover)

2. Обновить compose конфиг
   config/compose/core.yml:
   • redis-master
   • redis-replica-1, redis-replica-2
   • sentinel-1, sentinel-2, sentinel-3

3. Настроить Sentinel
   • Monitor Redis master
   • Quorum: 2 (majority)
   • Failover trigger: master not responding for 30 sec

4. Подключить приложения к Sentinel
   • Nextcloud, Mattermost нужно указать sentinel endpoints
   • Sentinel автоматически скажет где master

5. Тестировать failover
   • Остановить Redis master
   • Sentinel переводит replica в master
   • Приложения переключаются (может быть минута downtime)
```

**DELIVERABLES:**
- [ ] Redis Sentinel deployed
- [ ] Automatic failover working
- [ ] Apps configured for Sentinel
- [ ] Failover tested

---

### Задача 3.3: HAProxy Load Balancing

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 2 часа  
**СЛОЖНОСТЬ:** 🟡 Средняя

**ЧТО ДЕЛАТЬ:**
```bash
1. Deploy HAProxy для load balancing
   • Внутреннее (для Docker)
   • Распределяет нагрузку между контейнерами

2. Обновить compose конфиг
   • Добавить HAProxy сервис

3. Настроить HAProxy
   • Nextcloud backend (может быть несколько инстансов)
   • Gitea backend
   • Redmine backend
   • Round-robin или least connections

4. Обновить Caddy для использования HAProxy
   reverse_proxy haproxy:80

5. Результат: load распределяется между несколькими инстансами
```

**DELIVERABLES:**
- [ ] HAProxy deployed
- [ ] Backends configured
- [ ] Load balancing working
- [ ] Health checks enabled

---

### Задача 3.4: Keepalived Virtual IP (VIP)

**СТАТУС:** 🟡 ВАЖНО  
**ВРЕМЯ:** 1 час  
**СЛОЖНОСТЬ:** 🟡 Средняя

**ЧТО ДЕЛАТЬ:**
```bash
1. Deploy Keepalived для virtual IP
   • Active-passive failover
   • Если Caddy/HAProxy node dies → VIP переводится на backup

2. Обновить compose конфиг
   • keepalived-1 (active)
   • keepalived-2 (passive)

3. Настроить VIP
   • Primary VIP: 192.168.1.100 (caddy.ceres)
   • Failover: если primary dies → VIP на secondary

4. Тестировать failover
   • Остановить primary Caddy/HAProxy
   • VIP переводится на secondary
   • DNS должен указывать на VIP
```

**DELIVERABLES:**
- [ ] Keepalived deployed (active-passive)
- [ ] Virtual IP configured
- [ ] Failover tested
- [ ] DNS pointing to VIP

---

## ИТОГО ФАЗА 3:

```
✅ PostgreSQL Patroni HA                      (4 часа)
✅ Redis Sentinel                             (2 часа)
✅ HAProxy Load Balancing                     (2 часа)
✅ Keepalived Virtual IP                      (1 час)

ИТОГО: ~9 часов (1.5 дня full-time)
РЕЗУЛЬТАТ: 85% → 92% enterprise ready
```

---

## 🎯 ИТОГОВЫЙ TIMELINE

```
ФАЗА 1 (Week 1):  ~10 часов → 57% до 65% ready
  ✅ Alertmanager + webhooks
  ✅ Audit logging
  ✅ MFA
  ✅ Runbooks

ФАЗА 2 (Week 2):  ~10 часов → 65% до 85% ready
  ✅ oauth2-proxy
  ✅ File sync
  ✅ Wiki Git sync
  ✅ Backup automation

ФАЗА 3 (Week 3):  ~9 часов → 85% до 92% ready
  ✅ PostgreSQL HA
  ✅ Redis HA
  ✅ Load Balancing
  ✅ VIP Failover

ИТОГО: ~29 часов (~4 дня full-time)

РЕЗУЛЬТАТ: 🎉 92%+ ENTERPRISE READY
```

---

## ✅ ГОТОВ НАЧИНАТЬ?

**Рекомендуемый порядок:**

1. **ДЕНЬ 1:** Фаза 1 - Alertmanager, webhooks, audit (10 часов)
   - Это КРИТИЧНО! Система должна знать о проблемах.

2. **ДЕНЬ 2:** Фаза 2 - Интеграция файлов и backup (10 часов)
   - Это ВАЖНО! Данные должны быть синхронизированы.

3. **ДЕНЬ 3-4:** Фаза 3 - HA и resilience (9 часов)
   - Это NICE-TO-HAVE! Для 99.9% uptime.

**ВЫБОР:**
- 🟢 Только Фаза 1? (10 часов) → 65% ready (хорошо для MVP)
- 🟡 Фаза 1 + 2? (20 часов) → 85% ready (отлично для production)
- 🔴 Все фазы? (29 часов) → 92%+ ready (enterprise-grade!)

**ДАВАЙТЕ НАЧИНАТЬ С ФАЗЫ 1? ✨**
