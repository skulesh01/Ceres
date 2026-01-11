# CERES — Инструкции для AI-агента (Copilot)

Этот файл даёт краткие, практичные правила именно для этого репозитория. Основной фокус — модульные сервисы в Docker Compose, с опциональным GitOps/Kubernetes.

## Назначение проекта
- **Проблема:** Разрозненные self-hosted сервисы (файлы, Git, чат, проекты, знания) сложно разворачивать и поддерживать: нет единого входа, ручная настройка, слабая наблюдаемость и безопасность.
- **Цель:** Дать команде единую, воспроизводимую платформу из ключевых open‑source сервисов с централизованным SSO, единым входным шлюзом, наблюдаемостью и GitOps‑автоматизацией.
 - **Цель:** Дать команде единую, воспроизводимую платформу из ключевых open‑source сервисов с централизованным SSO, единым входным шлюзом, наблюдаемостью и GitOps‑автоматизацией; обеспечить «одну команду» деплой для нового стартапа: клонировать проект из Git, заполнить `config/.env` и запустить один скрипт (**DEPLOY.ps1**) для полного развёртывания готовой инфраструктуры.
- **Как это работает:**
  - Инфраструктура: **Proxmox** → **Terraform** создаёт 3 VM, **Ansible** настраивает ОС и зависимости, **k3s** формирует кластер Kubernetes.
  - Доставка: **FluxCD** синхронизирует манифесты/релизы из Git, **Sealed Secrets** безопасно хранят секреты.
  - Входной трафик: **Caddy** на edge (80/443), внутренний TLS, домены `auth|nextcloud|gitea|… .${DOMAIN}`.
  - Аутентификация: **Keycloak** как единый IdP (OIDC); bootstrap-скрипты создают клиентов для Grafana/Wiki.js/Redmine.
  - Данные: в Kubernetes — PVC/StorageClass; локально (dev) — именованные Docker‑тома.
  - Локальная отладка: **Docker Compose** как fallback для быстрого запуска отдельных модулей.

## Большая картина
- **Режим по умолчанию — Kubernetes (k3s) на Proxmox:** Автодеплой кластера и GitOps через **FluxCD**. Инфраструктура через **Terraform**, конфигурация через **Ansible**. См. [DEPLOY.ps1](DEPLOY.ps1), [terraform/README.md](terraform/README.md), [ansible/README.md](ansible/README.md), [flux/README.md](flux/README.md).
- **Альтернатива для локалки — Docker Compose:** Используется как fallback для локального тестирования отдельных сервисов. См. [config/compose](config/compose) и [scripts/start.ps1](scripts/start.ps1).
- **SSO как единая точка:** `Keycloak` — единственный IdP; приложения используют OIDC там, где поддерживается. См. [ARCHITECTURE.md](ARCHITECTURE.md).
- **Входной трафик:** Реверс‑прокси `Caddy` (`80/443`) с внутренним TLS; публичный DNS сопоставляет `auth|nextcloud|gitea|… .${DOMAIN}` с хостом. См. [config/caddy/Caddyfile](config/caddy/Caddyfile).
- **Данные:** В Kubernetes — PVC/StorageClass; в локальном Docker — именованные тома (`pg_data`, `gitea_data`, `grafana_data`).

## Кластер и Proxmox
- **3 VM архитектура (Proxmox):** Core (PostgreSQL, Redis, Keycloak), Apps (Nextcloud, Gitea, Mattermost, Redmine, Wiki.js), Edge & Observability (Caddy, Prometheus, Grafana, Portainer, Uptime Kuma). См. [README.md](README.md) → Архитектура.
- **Автодеплой k3s:** Запустите [DEPLOY.ps1](DEPLOY.ps1) — подготовит k3s, kubeconfig и секреты для GitHub Actions.
- **GitOps:** FluxCD управляет синхронизацией манифестов из Git. См. [flux/README.md](flux/README.md) (bootstrap, reconcile, мониторинг статуса).
- **Terraform/Ansible:** Создание VM и базовая конфигурация: см. [terraform](terraform) и [ansible](ansible).

## Сервисы (основные и опциональные)
- **Core:** PostgreSQL, Redis, Keycloak (SSO/OIDC).
- **Apps:** Nextcloud (файлы), Gitea (Git + SSH), Mattermost (чат), Redmine (проекты), Wiki.js (база знаний).
- **Observability:** Prometheus, Grafana (OIDC), cAdvisor, экспортёры (Postgres/Redis), опционально Loki + Promtail (логи).
- **Ops:** Portainer (управление контейнерами), Uptime Kuma (uptime/пинги).
- **Edge:** Caddy (TLS/домены, входной трафик), опции Cloudflare Tunnel.
- **Дополнительно:** Mayan EDMS (документооборот), WireGuard (wg‑easy, VPN), Mailu/SMTP интеграции.

## GitOps и рабочие потоки
- **Bootstrap FluxCD:** см. [flux/bootstrap.ps1](flux/bootstrap.ps1) или [flux/bootstrap.sh](flux/bootstrap.sh); затем `flux get all`, `flux reconcile ...` — пример команд в [flux/README.md](flux/README.md).
- **Структура GitOps:** [flux/apps](flux/apps) (core/app/monitoring), [flux/infrastructure](flux/infrastructure), [flux/clusters/*](flux/clusters) — kustomizations/namespace/политики.
 - **Текущая структура:** ключевой манифест — [flux/clusters/production/flux-system.yaml](flux/clusters/production/flux-system.yaml).
   - Примечание: в нём указаны пути `./flux/infrastructure` и `./flux/apps/...`; если этих директорий нет, используйте [config/flux/flux-releases.yml](config/flux/flux-releases.yml) (Helm/Kustomize) или скорректируйте пути под фактическую структуру.
- **Секреты:** Используйте [config/sealed-secrets](config/sealed-secrets) и `kubeseal` (описано в [flux/README.md](flux/README.md)).
- **Обновления образов:** Flux Image Update (пример политики в [flux/README.md](flux/README.md)).

## Локальная отладка (Docker Compose)
- **Быстрый старт локально (Windows):** [scripts/start.ps1](scripts/start.ps1) — генерирует `config/.env` и стартует `core, apps, monitoring, ops`.
  - Пример: только core+apps: `powershell -File scripts/start.ps1 core apps`.
  - Примечание: монолитный режим `-Clean` работает только если в `config` есть `docker-compose-CLEAN.yml` (в текущем репозитории может отсутствовать); по умолчанию используйте модульный режим.
- **Модули Compose:** [config/compose/base.yml](config/compose/base.yml), [core.yml](config/compose/core.yml), [apps.yml](config/compose/apps.yml), [monitoring.yml](config/compose/monitoring.yml), [ops.yml](config/compose/ops.yml), опционально [edge.yml](config/compose/edge.yml), [vpn.yml](config/compose/vpn.yml), [edms.yml](config/compose/edms.yml). Маппинг — `Get-CeresComposeFiles()` в [scripts/_lib/Ceres.ps1](scripts/_lib/Ceres.ps1).
- **Make-ярлыки:** [Makefile](Makefile) — `make start|status|logs|backup|restore|update` (Linux/macOS/WSL).

## Конфигурация и интеграции
- **Файл окружения (локалка):** Копируйте [config/.env.example](config/.env.example) → `.env`; `start.ps1` генерирует секреты для `CHANGE_ME`. Секреты не коммитить.
- **Домены:** `DOMAIN=ceres` (по умолчанию); `tls internal` в [config/caddy/Caddyfile](config/caddy/Caddyfile). Для `edge` освободите порты `80/443`.
- **Keycloak:** Публично `auth.${DOMAIN}`; внутри `http://keycloak:8080`. Bootstrap OIDC‑клиентов: [scripts/keycloak-bootstrap.ps1](scripts/keycloak-bootstrap.ps1).
- **VPN (wg‑easy):** Нужны `WG_HOST` и `WG_EASY_PASSWORD`; bcrypt‑хэш с `$` должен быть `$$` в `.env` (автоматически делает `start.ps1`). См. [config/compose/vpn.yml](config/compose/vpn.yml).
- **SMTP:** Заполните `SMTP_*` в `.env`; скрипт применит настройки к Keycloak.

## Конвенции и паттерны
- **Изоляция:** Публикуются только `Caddy` и SSH `Gitea` (`2222`); остальное — внутренние сервисы, доступ через Caddy/VPN.
- **Healthchecks:** В Compose заданы проверки; `start.ps1` ждёт `postgres, redis, keycloak, nextcloud, gitea, mattermost, redmine, wikijs` (+ monitoring/ops при выборе).
- **Безопасность:** Для админских UI (Prometheus/Portainer) — только через VPN/внутренние домены (`tls internal`). В GitOps — Sealed Secrets.

## Частые команды
- **Автодеплой (Windows):**
  - `powershell -File DEPLOY.ps1`
- **FluxCD статус:**
  - `flux get all`
  - `flux reconcile kustomization ceres-core`
- **Kubernetes базовые:**
  - `kubectl cluster-info`
  - `kubectl -n flux-system get events --sort-by='.lastTimestamp'`
- **Локалка (Docker Compose):**
  - `powershell -File scripts/start.ps1`
  - `make status` / `make logs service=gitea`

### Kubernetes-only: обновление сервиса через Flux
- Измените версию/настройки релиза в [config/flux/flux-releases.yml](config/flux/flux-releases.yml) (например, `HelmRelease` `postgresql`, `redis`, `ceres`).
- Закоммитьте изменения и выполните ручной reconcile (опционально):
  - `flux reconcile kustomization flux-system --with-source`
  - или точечно: `flux reconcile helmrelease postgresql -n ceres`
- Проверьте статус: `flux get all` и события `kubectl -n flux-system get events --sort-by='.lastTimestamp'`.

## Сценарии (примеры)
- **Онбординг сотрудника:**
  - Создайте ящик в Mailu: админ‑UI через `mail.${DOMAIN}` (см. [config/compose/mail.yml](config/compose/mail.yml)).
  - Создайте VPN‑клиента в `wg‑easy` (UI `vpn.${DOMAIN}`), скачайте `.conf` и отправьте сотруднику (см. [config/compose/vpn.yml](config/compose/vpn.yml)).
  - Пользователь входит в внутренние сервисы через `Keycloak` (`auth.${DOMAIN}`).
- **Внешняя публикация (Cloudflare Tunnel):**
  - Установите `CLOUDFLARED_TOKEN` в `config/.env` и включите модуль `tunnel`.
  - [scripts/start.ps1](scripts/start.ps1) переключит на [config/caddy/Caddyfile.tunnel](config/caddy/Caddyfile.tunnel) (origin HTTP).
- **Обновление версии сервиса (Flux):**
  - Обновите версию в [config/flux/flux-releases.yml](config/flux/flux-releases.yml), сделайте `git push`.
  - Проверьте применение: `flux get all`; при необходимости выполните `flux reconcile ...`.

## Подводные камни
- Освободите `80/443` перед включением `edge`; иначе `start.ps1` упадёт на префлайте.
- Не публикуйте Prometheus/Portainer наружу; держите за VPN (`tls internal` в Caddy).
- Для локалки — убедитесь, что в `.env` нет `CHANGE_ME`; для GitOps — корректно оформлены KUBECONFIG и GitHub Secrets (см. [DEPLOY.ps1](DEPLOY.ps1)).

Подробности см. в [README.md](README.md), [ARCHITECTURE.md](ARCHITECTURE.md) и [flux/README.md](flux/README.md).

## Правила конфигурации
- **Файл окружения:** Скопируйте [config/.env.example](config/.env.example) → `.env`; `start.ps1` генерирует безопасные секреты для ключей `CHANGE_ME`. Секреты не коммитить.
- **Домен:** `DOMAIN=ceres` по умолчанию; внутренний TLS (`tls internal`) настраивается в [Caddyfile](config/caddy/Caddyfile). При использовании `edge` освободите порты `80/443`.
- **Keycloak:** Публичный хост `auth.${DOMAIN}`; внутренний сервис `http://keycloak:8080`. `start.ps1` запускает [scripts/keycloak-bootstrap.ps1](scripts/keycloak-bootstrap.ps1) для провижининга OIDC-клиентов (Grafana, Wiki.js и т.д.).
- **VPN (wg-easy):** Требует `WG_HOST` и админ-пароль; bcrypt-хэш содержит `$` и должен записываться как `$$` в `.env` (автоматически делает `start.ps1`). См. [config/compose/vpn.yml](config/compose/vpn.yml).
- **SMTP:** Заполните `SMTP_*` в `.env`; `keycloak-bootstrap.ps1` применит SMTP к Keycloak.

## Конвенции и паттерны
- **Фиксация образов:** Образы в Compose зафиксированы по digest (`image: ...@sha256:...`) для воспроизводимости.
- **Сетевая изоляция:** Внешне доступны только `Caddy` и SSH `Gitea` (`2222`); остальные сервисы — внутренние и проксируются через Caddy.
- **Healthchecks:** В Compose заданы проверки; `start.ps1` ожидает `postgres, redis, keycloak, nextcloud, gitea, mattermost, redmine, wikijs` и добавляет monitoring/ops при выборе.
- **Модули в приоритете:** Предпочитайте модульный Compose вместо монолита; передавайте имена модулей в `start.ps1`.

## Точки интеграции
- **OIDC:** Клиенты Keycloak для `Grafana`, `Wiki.js`, `Redmine` через bootstrap-скрипты.
- **Reverse proxy:** Роутинги в [config/caddy/Caddyfile](config/caddy/Caddyfile) для `auth|nextcloud|gitea|mattermost|wiki|grafana|mail|vpn`.
- **Cloudflare Tunnel:** Если включён модуль `tunnel` и задан `CLOUDFLARED_TOKEN`, `start.ps1` переключит на `Caddyfile.tunnel` (origin HTTP). См. [config/caddy](config/caddy).

## Частые задачи (примеры)
- Старт по умолчанию: запустите `powershell -File scripts/start.ps1`.
- Старт с VPN: `powershell -File scripts/start.ps1 core apps monitoring ops vpn`.
- Статус и логи: `make status` / `make logs service=gitea`.
- Бэкап/восстановление: используйте скрипты из [scripts/README.md](scripts/README.md) или `make backup|restore`.
- Обновление образов: `make update`, затем `make restart`.

## Подводные камни
- Освободите `80/443` перед включением `edge`; иначе `start.ps1` упадёт на префлайте.
- Не публикуйте Prometheus/Portainer наружу; держите за VPN (`tls internal` в Caddy).
- Убедитесь, что в `.env` не осталось `CHANGE_ME` перед продуктивным запуском.

Подробности см. в [README.md](README.md) и [ARCHITECTURE.md](ARCHITECTURE.md).

## Production Readiness Checklist

### Pre-Deploy (инфраструктура + Kubernetes)
- [ ] **Proxmox сервер** доступен и имеет минимум 12 CPU, 24GB RAM, 200GB SSD.
- [ ] **Networking:** IP адреса для 3 VM зарезервированы (192.168.1.10-12 по умолчанию); порты 22 (SSH), 80/443 (edge), 51820 (VPN) проверены на firewalling.
- [ ] **DNS:** Публичные домены `auth|nextcloud|gitea|mattermost|wiki|grafana|mail|vpn .${DOMAIN}` разрешены на IP вашего edge-сервера.
- [ ] **Terraform/Ansible:** Переменные в [terraform/terraform.tfvars](terraform/terraform.tfvars) и [ansible/inventory/production.yml](ansible/inventory/production.yml) установлены.
- [ ] **Секреты GitHub:** KUBECONFIG, SSH_PRIVATE_KEY, DEPLOY_HOST, DEPLOY_USER, DEPLOY_PASSWORD добавлены в Settings → Secrets/Actions.

### Pre-Deploy (локальная среда)
- [ ] **config/.env:** Скопирован из [config/.env.example](config/.env.example), все `CHANGE_ME` заменены.
  - Критично: `POSTGRES_PASSWORD`, `KEYCLOAK_ADMIN_PASSWORD`, `GRAFANA_OIDC_CLIENT_SECRET`, `GRAFANA_ADMIN_PASSWORD`.
  - Если нужна почта: `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`.
  - Если нужен VPN: `WG_HOST`, `WG_EASY_PASSWORD`.
- [ ] **Docker/Compose:** Установлены; проверьте: `docker --version`, `docker compose version`.
- [ ] **PowerShell:** Execution Policy установлена на RemoteSigned или Bypass: `Get-ExecutionPolicy`.

### Deploy Workflow (Kubernetes)
- [ ] **Запуск:** Выполните `powershell -File DEPLOY.ps1` — подготовит k3s на Proxmox, kubeconfig, GitHub секреты.
- [ ] **Flux Bootstrap:** После успеха DEPLOY.ps1 выполните (из Linux/WSL/Cloud VM с kubeconfig):
  ```bash
  flux bootstrap github --owner skulesh01 --repository Ceres --branch main --path ./flux/clusters/production --personal
  ```
- [ ] **Проверка:** 
  ```bash
  flux get all
  kubectl -n flux-system get events --sort-by='.lastTimestamp'
  kubectl -n ceres get helmrelease,pods
  ```

### Day-1 Post-Deploy Verification
- [ ] **Сервисы запущены:** `kubectl -n ceres get all` показывает pods в `Running`.
- [ ] **Доступ к UI (через VPN или внутреннюю сеть):**
  - `https://auth.${DOMAIN}` → Keycloak (admin/KEYCLOAK_ADMIN_PASSWORD).
  - `https://nextcloud.${DOMAIN}` → Nextcloud (admin/NEXTCLOUD_ADMIN_PASSWORD).
  - `https://gitea.${DOMAIN}` → Gitea (admin/admin).
  - `https://grafana.${DOMAIN}` → Grafana (OIDC или admin/GRAFANA_ADMIN_PASSWORD).
- [ ] **SSO:** Keycloak bootstrap создал OIDC-клиентов для Grafana/Wiki.js/Redmine (см. [scripts/keycloak-bootstrap.ps1](scripts/keycloak-bootstrap.ps1)).
- [ ] **VPN (если требуется):** Создайте клиента в `https://vpn.${DOMAIN}`, скачайте `.conf`, проверьте подключение.
- [ ] **Почта (если требуется):** Заправьте `SMTP_*` в `.env`, проверьте отправку письма через Keycloak.
- [ ] **Метрики:** `https://grafana.${DOMAIN}` показывает дашборды (CPU, память, контейнеры).

### Rollback процедура
- **Docker Compose локально:** `make stop` (сохранит volumes).
- **Flux/Kubernetes:** `git revert <commit-hash>` (Git откатит, Flux автоматически синхронизирует).
- **Бэкап/восстановление:** [scripts/backup.ps1](scripts/backup.ps1) и [scripts/restore.ps1](scripts/restore.ps1).

### Production Hardening
- **Firewall:** Закройте 80/443 извне; используйте VPN или Cloudflare Tunnel.
- **Сертификаты:** Включите Let's Encrypt (раскомментируйте `ACME_EMAIL` в [config/caddy/Caddyfile](config/caddy/Caddyfile)).
- **Логи:** Включите `monitoring` модуль или Flux `ceres-releases` Kustomization.
- **Backup:** Настройте автоматический бэкап через cron/Task Scheduler.
- **Sealed Secrets:** Используйте [config/sealed-secrets](config/sealed-secrets) и `kubeseal` для критических секретов в Kubernetes.