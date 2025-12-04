# ⏱️ Быстрый старт Ceres (5 минут)

> **Цель:** Максимально быстро развернуть инфраструктуру и убедиться, что она работает

## Шаг 1: Запустить инфраструктуру (2 мин)

### Способ A: PowerShell (рекомендуется)

```powershell
cd F:\Ceres\config
docker compose up -d
```

### Способ B: Батник (Windows, двойной клик)

Двойной клик на: `F:\Ceres\scripts\quick_deploy.bat`

## Шаг 2: Ждать инициализации (10-15 мин)

```powershell
cd F:\Ceres\config
docker compose ps -a
```

Дождитесь, пока большинство контейнеров будут в статусе **Up** или **healthy**.

**Первый запуск медленнее** - Docker скачивает образы (~2-5 GB).

## Шаг 3: Добавить в hosts (2 мин)

Откройте **от администратора**: `C:\Windows\System32\drivers\etc\hosts`

Добавьте эти строки:
```
127.0.0.1 Ceres.local
127.0.0.1 auth.Ceres.local
127.0.0.1 taiga.Ceres.local
127.0.0.1 cloud.Ceres.local
127.0.0.1 erp.Ceres.local
127.0.0.1 crm.Ceres.local
127.0.0.1 git.Ceres.local
127.0.0.1 mail.Ceres.local
127.0.0.1 mesh.Ceres.local
127.0.0.1 grafana.Ceres.local
127.0.0.1 traefik.Ceres.local
127.0.0.1 ipa.Ceres.local
127.0.0.1 edm.Ceres.local
```

Сохраните файл.

## Шаг 4: Открыть главный сервис (1 мин)

Откройте в браузере: **https://auth.Ceres.local**

- **Пользователь:** admin
- **Пароль:** K3yClo@k!2025 (из `config/.env`)

### Полный список сервисов:

| Сервис | URL | Логин |
|--------|-----|-------|
| 🔐 **Keycloak (SSO)** | https://auth.Ceres.local | admin / K3yClo@k!2025 |
| 📁 **Nextcloud** | https://cloud.Ceres.local | See `config/.env` |
| 📊 **Taiga** | https://taiga.Ceres.local | See `config/.env` |
| 💼 **ERPNext** | https://erp.Ceres.local | administrator / admin |
| 📞 **SuiteCRM** | https://crm.Ceres.local | admin / admin |
| 📧 **Mailcow** | https://mail.Ceres.local | See `config/.env` |
| 🔧 **Gitea** | https://git.Ceres.local | admin / admin |
| 📈 **Grafana** | https://grafana.Ceres.local | admin / admin |
| 📡 **Traefik** | https://traefik.Ceres.local | - (dashboard) |
| 👥 **FreeIPA** | https://ipa.Ceres.local | admin / FreeIPA!2025 |

---

## ✅ Готово!

**Вы успешно развернули Ceres!**

### Что дальше?

1. **Хочу тестировать:** → Читайте `docs/guides/TESTING.md`
2. **Хочу настроить:** → Читайте `docs/guides/CONFIGURATION.md`
3. **Нужна полная информация:** → Читайте `README.md`

### Полезные команды

```powershell
# Проверить статус
cd .\config && docker compose ps -a

# Посмотреть логи
docker compose logs -f keycloak

# Остановить все
docker compose down

# Очистить и сохранить конфиг
python ..\scripts\backup_configuration.py
python ..\scripts\cleanup_containers.py
```

---

**Время до рабочей инфраструктуры:** ~20-25 минут  
**Сложность:** 🟢 Очень просто
