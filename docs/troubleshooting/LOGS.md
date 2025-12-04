# Логи: как собирать и читать

## Сбор всех логов
```powershell
cd F:\Ceres\config
docker compose logs --no-color > F:\Ceres\logs_all.txt
```

## Логи конкретного сервиса
```powershell
docker compose logs -f keycloak
```

## Поиск ошибок в логах
- Ищите слова `ERROR`, `Exception`, `Traceback`, `panic`
- Проверьте таймстемпы — совпадают ли с моментом инцидента

## Рекомендации
- Храните логи временно и передавайте только необходимую часть
- Для долгосрочного логирования используйте Loki / ELK
