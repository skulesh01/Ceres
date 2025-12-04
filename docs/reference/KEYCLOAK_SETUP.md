# Keycloak — быстрая настройка для Ceres

1. Откройте: https://auth.Ceres.local
2. Войдите как администратор (см. `config/.env`)
3. Создайте Realm `ceres` (если нужно) или используйте `master` для локальной разработки
4. Создайте клиента для каждого приложения (например: `taiga`, `processmaker`, `nextcloud`)
   - Тип: confidential
   - Включите `Standard Flow` (OIDC)
   - Укажите Redirect URI для приложения (например `https://taiga.Ceres.local/*`)
5. Создайте роли и группы, затем пользователей и назначьте роли
6. Для экспорта конфигурации:
```bash
# внутри контейнера Keycloak (пример имени контейнера)
docker exec ceres-keycloak-1 /opt/keycloak/bin/kc.sh export --file=/tmp/keycloak-export.json --realm=ceres
docker cp ceres-keycloak-1:/tmp/keycloak-export.json ./backups/
```

Примечания:
- Для production храните секреты клиентов в безопасном месте.
- Настройка LDAP/FreeIPA требует создания соответствующего user federation в Keycloak.
