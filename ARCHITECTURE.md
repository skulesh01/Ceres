# CERES — архитектура (Docker, single-host)

Этот документ объясняет:

- какие сервисы входят в стек и зачем они нужны
- как устроены связи (SSO, БД, метрики, логи)
- какие порты открыты наружу и где лежат данные

Источник истины по составу сервисов: `config/compose/*.yml` (модульно) и `config/docker-compose-CLEAN.yml` (монолит).

## 1) Общая схема

CERES запускается одним Docker Compose проектом (по умолчанию `ceres`). Все контейнеры сидят в общей docker-сети `internal`. Наружу (на хост) публикуются только нужные HTTP/SSH порты.

```text
                    Host (Windows/Linux)

   Browser / CLI  --->  localhost:<ports>
                          |
                          v
                 +-------------------+
                 |  Published ports  |
                 | (Keycloak/apps)   |
                 +-------------------+
                          |
                          v
      +------------------------------------------------+
      | Docker network: internal (bridge)               |
      |                                                |
      |  +---------+    +----------+    +------------+  |
      |  | Keycloak|--->| Postgres |<---|  Apps DBs  |  |
      |  +---------+    +----------+    +------------+  |
      |        ^              ^                 ^       |
      |        |              |                 |       |
      |  OIDC  |         shared DB        per-app init  |
      |        |              |                 |       |
      |  +-----------+   +---------+   +----------------+|
      |  | Grafana   |   | Redis   |   | Nextcloud      ||
      |  | Prometheus|   +---------+   | Gitea          ||
      |  | Loki      |                 | Mattermost     ||
      |  | Redmine   |                 | Wiki.js        ||
      |  +-----------+                 +----------------+|
      +------------------------------------------------+
```

Ключевая идея: **Keycloak — единственный IdP**. Сервисы либо логинятся через OIDC (настроено/поддерживается), либо работают локально (если OIDC ещё не доведён для конкретного сервиса).

## 2) Сервисы: что это и зачем

Ниже — кратко, без маркетинга.

### Core

- Postgres: единая БД для Keycloak и приложений (разные базы внутри).
- Redis: кэш/очереди для части приложений (например Nextcloud).

### Apps

- Keycloak (OIDC): единая учётка/SSO.
- Nextcloud: файлы, шаринг, WebDAV.
- Gitea: Git + Web UI, SSH доступ.
- Mattermost: командный чат.
- Redmine: управление проектами.
- Wiki.js: внутренняя база знаний.

### Monitoring

- Prometheus: сбор метрик.
- Grafana: дашборды; вход через Keycloak OIDC.
- cAdvisor: метрики контейнеров.
- postgres_exporter, redis_exporter: метрики Postgres/Redis.
- Loki + Promtail: централизованные логи контейнеров (просмотр через Grafana).

### Ops

- Portainer: UI для управления контейнерами/volumes.
- Uptime Kuma: простые проверки доступности (SLA/uptime) с UI.

### Edge (опционально)

- Caddy: reverse-proxy (HTTPS + домены `*.${DOMAIN}`), единая точка входа на `80/443`.

## 3) Порты и внешняя поверхность

По умолчанию наружу открыто:

- Caddy (модуль `edge`): `80/443` (весь web-трафик)
- Gitea SSH (опционально): `2222`

Раньше сервисы были доступны по `http://localhost:<порт>`. После hardening эти порты **не публикуются** и доступны только внутри docker-сети.

Важное:

- Postgres/Redis не публикуются на хост (доступны только внутри docker-сети).
- Loki/Promtail/exporters обычно не публикуются (используются внутри monitoring).

## 4) SSO (Keycloak-only)

- Публичный вход (через `edge`): `https://auth.${DOMAIN}`.
- Локальная отладка (если публикуете legacy-порт вручную): `http://localhost:8081`.
- Внутри docker-сети сервисы обращаются к Keycloak как `http://keycloak:8080`.

OIDC клиенты, которые поддерживаются автоматизацией:

- Grafana (generic OAuth)
- Redmine (OIDC через плагины/SSO-плагин; при необходимости локальные учётки)
- Wiki.js (Keycloak provider)

Скрипты:

- `scripts/keycloak-bootstrap.ps1`: создаёт/обновляет OIDC клиентов в Keycloak (идемпотентно).
- `scripts/fix-wikijs-keycloak.ps1`: нормализует/чинит провайдера Keycloak в Wiki.js (через SQL в Postgres).

## 5) Данные и где они лежат

Данные не живут в контейнерах. Они в volumes (примерно):

- `pg_data`: Postgres
- `redis_data`: Redis
- `nextcloud_data`, `nextcloud_config`
- `gitea_data`
- `mattermost_data`, `mattermost_logs`, `mattermost_config`
- `grafana_data`, `prometheus_data`
- `loki_data`
- `portainer_data`
- `uptime_kuma_data`

Бэкапы/восстановление: `scripts/backup.ps1` и `scripts/restore.ps1`.

## 6) Модули compose и точки входа

- `config/compose/base.yml`: общие примитивы (сеть `internal`).
- `config/compose/core.yml`: Postgres + Redis.
- `config/compose/apps.yml`: пользовательские приложения.
- `config/compose/monitoring.yml`: метрики/логи.
- `config/compose/ops.yml`: операционные UI.
- `config/compose/edms.yml`: EDMS + согласование документов (Mayan EDMS).
- `config/compose/edge.yml`: опциональный edge reverse-proxy (Caddy).
- `config/compose/vpn.yml`: self-host VPN (WireGuard via wg-easy; UDP 51820 + localhost UI).

Рекомендуемые точки входа:

- `scripts/start.ps1`: запуск + генерация секретов + best-effort bootstrap.
- `scripts/status.ps1`: быстрый статус контейнеров + HTTP-проверки.
- `scripts/cleanup.ps1`: остановка без удаления volumes.

## 6.1) Доступ через VPN (без внешнего сайта)

Рекомендуемый режим для команды:

- VPN: подключение сотрудников к “внутренней” сети (например Tailscale).
- Доменные имена: резолвим внутри VPN через `hosts` или внутренний DNS на VPN.
- HTTPS: Caddy работает с `tls internal`; чтобы браузеры не ругались, клиентам нужно доверять root CA Caddy (см. `scripts/export-caddy-rootca.ps1`).

Дополнительно:

- SMTP (почта/уведомления): задаётся через `config/.env` (переменные `SMTP_*`) и применяется к Keycloak скриптом `scripts/keycloak-bootstrap.ps1`.

## 7) Структура репозитория (что где лежит)

```text
Ceres/
  config/
    .env.example
    compose/              # модульный compose
    docker-compose-CLEAN.yml
    grafana/ prometheus/  # конфиги метрик/дашбордов
    loki/ promtail/       # конфиги логов
    caddy/                # edge reverse-proxy (Caddyfile)
    nginx/ static/        # legacy edge (больше не используется по умолчанию)
  scripts/
    _lib/                 # общие функции для скриптов
    start/status/cleanup  # основные операции
  taiga/                  # legacy-конфиги Taiga (сейчас не используется)
```

## 8) Нормальные “особенности” при проверках

-- `Mattermost` healthcheck может отвечать HTTP 404/302 на HEAD — используйте GET с `--spider`.
