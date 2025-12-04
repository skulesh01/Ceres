# Полезные Docker / Docker Compose команды

```powershell
# Перейти в конфиг
cd F:\Ceres\config

# Запустить все сервисы
docker compose up -d

# Остановить
docker compose down

# Посмотреть статус
docker compose ps -a

# Смотреть логи в реальном времени
docker compose logs -f

# Логи конкретного сервиса
docker compose logs -f keycloak

# Очистка неиспользуемых объектов
docker system prune -a --volumes

# Инспект тома
docker volume inspect ceres_pg_data
```

Советы:
- Используйте `docker compose logs -f service` для быстрой диагностики.
- Не используйте `docker compose down -v` в продакшн, если хотите сохранить данные томов.
