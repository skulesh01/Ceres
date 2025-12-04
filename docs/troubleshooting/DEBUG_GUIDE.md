# Руководство по отладке (Debug)

1. Проверка контейнеров
```powershell
cd F:\Ceres\config
docker compose ps -a
```

2. Сбор логов
```powershell
docker compose logs --no-color > F:\Ceres\debug_all_logs.txt
```

3. Диагностика конкретного сервиса
```powershell
docker compose logs -f keycloak
# или
docker exec -it ceres-keycloak-1 bash
journalctl -u keycloak
```

4. Проверка состояния томов
```powershell
docker volume inspect ceres_pg_data
```

5. Быстрая проверка сети
```powershell
# из хоста
ping auth.Ceres.local

# внутри контейнера (пример)
docker exec -it ceres-keycloak-1 ping postgres
```

6. Снятие дампа БД
```powershell
docker exec -t ceres-postgres-1 pg_dumpall -c -U postgres > F:\Ceres\backups\pg_dumpall.sql
```

7. Следующие шаги
- Соберите все логи и файлы конфигурации
- Убедитесь, что `config/.env` актуален
- При необходимости пересоздайте контейнеры: `docker compose up -d --force-recreate`
