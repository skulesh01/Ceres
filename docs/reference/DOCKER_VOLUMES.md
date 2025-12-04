# Docker тома (volumes)

Список основных томов, используемых в `docker-compose.yml` и их назначение.

- `ceres_pg_data` — PostgreSQL data (все базы данных сервисов)
- `ceres_nextcloud_data` — Nextcloud файлы
- `ceres_taiga_data` — Taiga хранилище
- `ceres_gitea_data` — Gitea репозитории
- `ceres_mailcow_data` — Mailcow данные
- `ceres_prometheus_data` — Prometheus TSDB (метрики)
- `ceres_keycloak_data` — Keycloak конфигурация (если хранится в томе)

Резервное копирование:
- Том PostgreSQL можно бэкапить через `pg_dump` или копированием тома.
- Для Nextcloud — резервируйте и `data` и конфиг `config.php`.

Примеры команд:
```powershell
# Список томов
docker volume ls

# Информация о томе
docker volume inspect ceres_pg_data

# Резервное копирование тома (на Windows через временный контейнер)
docker run --rm -v ceres_pg_data:/data -v C:\backup:/backup alpine sh -c "cd /data && tar czf /backup/ceres_pg_data.tar.gz ."
```