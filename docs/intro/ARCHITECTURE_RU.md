```markdown
# Архитектура и руководство по развертыванию — Ceres

## 📦 Обзор
Репозиторий **Ceres** — модульный набор сервисов, развертываемый через Docker Compose. Сервисы управляются `Traefik` (обратный прокси) и интегрированы через `Keycloak` (SSO). Стек включает мониторинг, CI/CD, документооборот, CRM, ERP, почту и удалённый доступ.

---

## 🧩 Карта сервисов (кратко)
```
┌─────────────────────────────────────────────────────────────────────┐
│                      Traefik (reverse-proxy)                       │
│  ┌─────────────────────────────────────────────────────────────── ──┘
│  │  nextcloud (файлы)      processmaker (EDM/Workflow)             │
│  │      ↳ PostgreSQL (shared DB)  ↳ WebDAV (Nextcloud)              │
└─────────────────────────────────────────────────────────────────────┘
```

| Категория | Сервис | Роль |
|---|---|---|
| Обратный прокси / TLS | Traefik | Входной шлюз, автоматический TLS |
| База данных | PostgreSQL | Хранение данных сервисов |
| Кэш / очереди | Redis | Сессии и очереди задач |
| Аутентификация | Keycloak | SSO / OIDC |
| Хранилище файлов | Nextcloud | WebDAV, хранение документов |
| BPM / Workflow | ProcessMaker | Процессы согласования (EDM) |
| Проекты | Taiga | Управление задачами |
| Репозитории | Gitea | Git сервер |
| Почта | Mailcow | SMTP/IMAP, webmail |
| LDAP/AD | FreeIPA | Каталог пользователей |
| Мониторинг | Prometheus + Grafana | Метрики и дашборды |

---

## 🚀 Быстрое развертывание (локально)
1. Подготовьте окружение: Docker Desktop (Windows), Git.
2. Перейдите в папку проекта (если вы на локальной машине):
```powershell
cd F:\Ceres
```
3. Создайте `config/.env` на основе `config/.env.example` и заполните значения.
4. Запустите инфраструктуру:
```powershell
cd F:\Ceres\config
docker compose up -d
```
Или используйте батник (двойной клик):
```
F:\Ceres\scripts\quick_deploy.bat
```

5. Проверьте статус:
```powershell
cd F:\Ceres\config
docker compose ps -a
```

---

## 🔧 Важные настройки (фрагменты)

### Traefik (пример)
```yaml
entryPoints:
  websecure:
    address: ":443"
providers:
  docker:
    exposedByDefault: false
certificatesResolvers:
  myresolver:
    acme:
      email: admin@${DOMAIN}
      storage: /letsencrypt/acme.json
      tlsChallenge: {}
```

### Keycloak (OIDC) — пример переменных
```yaml
OIDC_ISSUER: https://auth.${DOMAIN}/realms/ceres
OIDC_CLIENT_ID: processmaker
OIDC_CLIENT_SECRET: ${KEYCLOAK_CLIENT_SECRET_PM}
```

### ProcessMaker → Nextcloud (WebDAV)
```yaml
NEXTCLOUD_URL: https://cloud.${DOMAIN}/remote.php/dav/files
NEXTCLOUD_TOKEN: ${NEXTCLOUD_TOKEN}
```

---

## 📚 Ссылки и справка
- Keycloak: https://www.keycloak.org/documentation
- Traefik v3: https://doc.traefik.io/traefik/v3.0/
- Nextcloud Admin: https://docs.nextcloud.com/server/latest/admin_manual/
- Docker Compose: https://docs.docker.com/compose/compose-file/

---

## 🗂️ Где что находится (локально)
```
F:\Ceres\
├─ config\docker-compose.yml
├─ config\.env
├─ scripts\quick_deploy.bat
├─ scripts\backup_configuration.py
├─ scripts\cleanup_containers.py
├─ docs\intro\ARCHITECTURE.md
├─ docs\intro\ARCHITECTURE_RU.md  # <- этот файл
```

---

*Обновлено: 04.12.2025.*
```