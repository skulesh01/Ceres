# Переменные окружения (`config/.env`)

Описание ключевых переменных, используемых в `docker-compose.yml`.

- `DOMAIN` — домен для Traefik/Keycloak (по умолчанию `Ceres.local`)
- `COMPOSE_PROJECT_NAME` — префикс проекта в Docker Compose

Keycloak:
- `KEYCLOAK_ADMIN` — админ пользователя
- `KEYCLOAK_ADMIN_PASSWORD` — пароль администратора

PostgreSQL:
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`

Nextcloud:
- `NEXTCLOUD_ADMIN_USER`
- `NEXTCLOUD_ADMIN_PASSWORD`

FreeIPA:
- `FREEIPA_ADMIN_USER`
- `FREEIPA_ADMIN_PASSWORD`

Taiga / ERPNext / SuiteCRM / Gitea — отдельные секции в `config/.env`.

Рекомендации:
- НЕ КОММИТЬТЕ `config/.env` в Git. Используйте `config/.env.example` как шаблон.
- Для production используйте менеджер секретов (Vault, AWS Secrets, Kubernetes Secrets).
