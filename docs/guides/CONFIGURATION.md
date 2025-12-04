# Настройка сервисов Ceres — шаг за шагом

Этот документ собирает практические шаги по настройке основных сервисов после их развертывания.

Важно: все глобальные значения берутся из `config/.env`.

## 1. Keycloak (SSO)
1. Откройте: `https://auth.Ceres.local`
2. Войдите как админ (см. `config/.env`): `KEYCLOAK_ADMIN` / `KEYCLOAK_ADMIN_PASSWORD`.
3. Создайте Realm `ceres` (рекомендуется для разделения окружений) или используйте `master` для локальной разработки.
4. Создайте клиент для каждого приложения (пример — `processmaker`):
   - Client ID: `processmaker`
   - Client Type: `confidential`
   - Valid Redirect URIs: `https://edm.Ceres.local/*`
   - Включите `Standard Flow`.
5. Скопируйте `Client Secret` в `config/.env` (перезапустите сервисы при необходимости).
6. Создайте базовые роли (например `admin`, `user`, `approver`) и назначьте пользователям.
7. Экспорт конфигурации (для бэкапа):
```powershell
cd F:\Ceres
# имя контейнера может отличаться, проверьте docker compose ps
docker exec ceres-keycloak-1 /opt/keycloak/bin/kc.sh export --file=/tmp/keycloak-export.json --realm=ceres
docker cp ceres-keycloak-1:/tmp/keycloak-export.json backups\keycloak_export.json
```

## 2. Nextcloud (WebDAV для ProcessMaker и хранение файлов)
1. Откройте: `https://cloud.Ceres.local`
2. Создайте администратора или используйте данные из `config/.env`.
3. Создайте приложение-пароль (Settings → Security → Create App Password) — сохраните токен.
4. В `config/.env` укажите `NEXTCLOUD_TOKEN` и `NEXTCLOUD_URL` (обычно `https://cloud.Ceres.local/remote.php/dav/files`).
5. Проверьте доступ из ProcessMaker: настройте WebDAV-учётные данные в интерфейсе ProcessMaker.

## 3. ProcessMaker (BPM)
1. Откройте: `https://edm.Ceres.local`
2. В админке укажите параметры OIDC:
   - Issuer: `https://auth.Ceres.local/realms/ceres`
   - Client ID и Secret — те же, что создали в Keycloak
3. Настройте WebDAV с `NEXTCLOUD_URL` и `NEXTCLOUD_TOKEN`.
4. Проверьте сценарий загрузки файлов и интеграцию с Keycloak.

## 4. Taiga / Gitea / ERPNext / SuiteCRM
- Taiga: настройте OIDC клиент в Keycloak и введите redirect URIs `https://taiga.Ceres.local/*`.
- Gitea: укажите подключение к базе (см. `config/.env`) и создайте админ-аккаунт.
- ERPNext и SuiteCRM: проверьте параметры подключения к PostgreSQL в `config/.env`.

## 5. Traefik
- Dashboard доступен по `https://traefik.Ceres.local`.
- Убедитесь, что лейблы (`labels`) в `docker-compose.yml` содержат правило `Host(...)` и `tls.certresolver`.
- В `config/traefik` (если есть) храните дополнительные конфиги.

## 6. Общие рекомендации
- После правок в `config/.env` выполните перезапуск сервисов:
```powershell
cd F:\Ceres\config
docker compose down
docker compose up -d
```
- При проблемах собирайте логи и проверяйте зависимости (Keycloak и PostgreSQL — первыми).
