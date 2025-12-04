# Зависимости между сервисами

Краткая карта зависимостей (кто от кого зависит):

- PostgreSQL — база для Keycloak, Taiga, ERPNext, SuiteCRM, Gitea, Nextcloud
- Redis — кэш/очереди для Taiga, ERPNext
- Keycloak — SSO для Taiga, ProcessMaker, Nextcloud и др.
- Traefik — маршрутизация всех входящих запросов, зависит от корректной настройки DNS/hosts
- Nextcloud — хранит файлы для ProcessMaker (WebDAV)
- Prometheus — собирает метрики из доступных сервисов

Рекомендация: при отладке сначала проверяйте базу данных и Keycloak — большинство сервисов зависят от них.
