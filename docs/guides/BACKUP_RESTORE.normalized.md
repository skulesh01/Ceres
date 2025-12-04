# Резервное копирование и восстановление (Ceres)

Этот документ описывает, как сохранить конфигурацию и восстановить инфраструктуру Ceres.

## Что сохраняет `scripts/backup_configuration.py`
- Экспорт Keycloak (realms/clients/users) в `backups/config_YYYYMMDD_HHMMSS/keycloak_export.json`
- Копию `config/.env` в папке бэкапа
- Попытку скопировать `Nextcloud` `config.php` (если доступен)
- Информацию о Docker томах (`docker volume ls` → JSON)
- Скрипт восстановления `restore_config.ps1` и `BACKUP_REPORT.md`

## Полный сценарий бэкапа (ручной)
1. Убедитесь, что контейнеры запущены (Keycloak должен быть доступен для экспорта):
```powershell
cd F:\Ceres
docker compose ps -a
```
2. Запустите бэкап-скрипт:
```powershell
python scripts\backup_configuration.py
```
3. В папке `backups/` появится `config_YYYYMMDD_HHMMSS/` с набором файлов.

## Восстановление (ручное)
1. Расположите папку бэкапа рядом с проектом или скопируйте файлы обратно:
   - `backups/.../.env` → `config/.env`
   - `backups/.../keycloak_export.json` — использовать для импорта в Keycloak
   - `backups/.../nextcloud_config.php` → `nextcloud` конфиг (если нужно)
2. Запустите инфраструктуру:
```powershell
cd F:\Ceres\config
docker compose up -d
```
3. Импорт Keycloak (пример):
```powershell
# внутрь контейнера Keycloak
docker cp backups\config_YYYYMMDD_HHMMSS\keycloak_export.json ceres-keycloak-1:/tmp/keycloak-export.json
docker exec ceres-keycloak-1 /opt/keycloak/bin/kc.sh import --file=/tmp/keycloak-export.json
```

## Восстановление томов
- Том PostgreSQL: используйте `pg_restore`/`pg_dump` или клонирование тома (через временный контейнер).
- Для Nextcloud восстановите `data` и `config.php`.

## Автоматический restore (созданный скриптом)
- Скрипт `restore_config.ps1`, создаваемый в бэкапе, содержит подсказки и команды для восстановления.

## Рекомендации по безопасности
- Бэкапы содержат `config/.env` с паролями — храните резервные копии в защищённом месте.
- Шифруйте бэкапы при переносе вне локальной сети.

## Пример проверки после восстановления
1. Запустите `docker compose ps -a` и убедитесь, что контейнеры `Up`.
2. Откройте Keycloak (`https://auth.Ceres.local`) → проверьте существование realm/clients.
3. Откройте Nextcloud и проверьте файлы пользователя.
