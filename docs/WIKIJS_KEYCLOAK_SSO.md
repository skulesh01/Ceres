# Wiki.js ↔ Keycloak SSO (OIDC) — CERES

## Симптомы
- На `http://localhost:8083/login/keycloak` появляется `Invalid authentication provider.`
- В логах Wiki.js: `Authentication Strategy Keycloak ... [ FAILED ]` и/или `host is required`

## Причина
Wiki.js хранит настройки провайдеров в Postgres (`wikijs_db`, таблица `authentication`).
Если ключ провайдера **не равен** ожидаемому роутом (например, UUID вместо `keycloak`) или если в `config` пустой `host`, то вход ломается.

## Автофикс (рекомендуется)
Запустить:
- `powershell -ExecutionPolicy Bypass -File .\scripts\fix-wikijs-keycloak.ps1`

Скрипт:
- гарантирует `authentication.key = 'keycloak'` для стратегии `keycloak`
- заполняет обязательные поля (`host/realm/clientId/clientSecret` + URL’ы)
- рестартит контейнер Wiki.js
- печатает результат `curl -I http://localhost:8083/login/keycloak`

Ожидаемо: ответ **302** и редирект на `http://localhost:8081/.../auth?...`.

## Ручная проверка
- HTTP проверка:
  - `curl.exe -I http://localhost:8083/login/keycloak`
  - должно быть `HTTP/1.1 302 Found`
- Логи:
  - `docker logs ceres-wikijs-1 --tail 100`
  - должно быть `Authentication Strategy Keycloak: [ OK ]`

## Важные URL
- Keycloak (снаружи): `http://localhost:8081`
- Keycloak (внутри docker network): `http://keycloak:8080`
- Wiki.js: `http://localhost:8083`
- Callback: `http://localhost:8083/login/keycloak/callback`

## Примечания
- Secret клиента Keycloak хранится в `config/.env` как `WIKIJS_OIDC_CLIENT_SECRET`.
- Если вы пересоздали клиента в Keycloak и поменяли secret — обновите `config/.env` и прогоните скрипт снова.
