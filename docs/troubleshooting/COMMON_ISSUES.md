# Частые проблемы и решения (Ceres)

## 1) Docker не запускается
- Проверьте, включена ли виртуализация в BIOS/UEFI.
- Убедитесь, что Docker Desktop запущен и вы вошли в систему.
- Перезапустите Docker Desktop.

## 2) Сервисы в `Exited` или `CrashLoop`
- Проверьте логи: `docker compose logs -f <service>`.
- Убедитесь, что `config/.env` содержит правильные пароли.
- Проверьте подключение к PostgreSQL (сетевые ошибки).

## 3) Ошибки TLS/HTTPS
- Проверьте Traefik dashboard: https://traefik.Ceres.local
- Убедитесь, что домен настроен в hosts и Traefik имеет доступ к ACME.

## 4) Keycloak не принимает логины
- Проверьте логи Keycloak
- Убедитесь, что realm/client настроены и redirect URI совпадают

## 5) Nextcloud проблемы с данными
- Проверьте том Nextcloud и `config.php`
- Убедитесь, что права на файлы корректны внутри контейнера

## 6) Нет соединения с PostgreSQL
- Проверьте, что контейнер postgres `Up`
- Используйте `docker exec -it <pg_container> psql -U postgres -d <db>` для диагностики

# Что делать, если не помогло
1. Соберите логи: `docker compose logs --no-color > all_logs.txt` и приложите их к issue.
2. Проверьте `docker system df` на предмет заполненного диска.
3. Свяжитесь с автором проекта (см. README).
