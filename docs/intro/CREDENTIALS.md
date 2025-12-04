# 🔑 Учетные данные и доступ

> **ВАЖНО:** Эта информация ЧУВСТВИТЕЛЬНА. Используйте только в development/testing!

## 📋 Основные учетные данные

| Сервис | Пользователь | Пароль | Источник |
|--------|-------------|--------|---------|
| **Keycloak** | admin | K3yClo@k!2025 | `config/.env` |
| **PostgreSQL** | postgres | R@nd0mP@ssw0rd!2025 | `config/.env` |
| **FreeIPA** | admin | FreeIPA!2025 | `config/.env` |
| **ERPNext** | administrator | admin | Default |
| **SuiteCRM** | admin | admin | Default |
| **Taiga** | admin | admin | Default (задать свой) |
| **Gitea** | admin | admin | Default |
| **Grafana** | admin | admin | Default |
| **Mailcow** | admin | (почта) | В процессе настройки |
| **Nextcloud** | admin | (задать) | В процессе настройки |

---

## 🔗 URL всех сервисов

### 🔐 Аутентификация и доступ

```
https://auth.Ceres.local           → Keycloak (SSO/OIDC)
https://ipa.Ceres.local            → FreeIPA (LDAP)
https://cloud.Ceres.local          → Nextcloud (Cloud Storage)
```

### 💼 Бизнес-приложения

```
https://taiga.Ceres.local          → Taiga (Project Management)
https://edm.Ceres.local            → ProcessMaker (BPM)
https://erp.Ceres.local            → ERPNext (ERP)
https://crm.Ceres.local            → SuiteCRM (CRM)
```

### 🔧 Интеграция и мониторинг

```
https://git.Ceres.local            → Gitea (Git Repository)
https://mail.Ceres.local           → Mailcow (Email)
https://mesh.Ceres.local           → MeshCentral (Remote Desktop)
https://grafana.Ceres.local        → Grafana (Metrics Dashboard)
https://traefik.Ceres.local        → Traefik (Reverse Proxy Dashboard)
```

---

## 🌐 Внутренние адреса (для приложений)

| Сервис | Адрес (внутри сети) | Порт |
|--------|-------------------|------|
| Keycloak | keycloak | 8080 |
| PostgreSQL | postgres | 5432 |
| Redis | redis | 6379 |
| Taiga (backend) | taiga | 3000 |
| Taiga (frontend) | taiga-front | 80 |
| Nextcloud | nextcloud | 80 |
| ERPNext (backend) | frappe | 8000 |
| ERPNext (frontend) | frappe-nginx | 80 |
| SuiteCRM | suitecrm | 80 |
| Gitea | gitea | 3000 |
| Mailcow | mailcow | 443 |
| FreeIPA | freeipa | 443 |
| MeshCentral | meshcentral | 443 |
| Prometheus | prometheus | 9090 |
| Grafana | grafana | 3000 |

---

## 🔐 Переменные окружения (.env)

Все хранятся в `config/.env`:

```bash
# Основные настройки
DOMAIN=Ceres.local
COMPOSE_PROJECT_NAME=ceres

# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=K3yClo@k!2025
KEYCLOAK_ADMIN_EMAIL=admin@Ceres.local

# PostgreSQL
POSTGRES_USER=postgres
POSTGRES_PASSWORD=R@nd0mP@ssw0rd!2025
POSTGRES_DB=ceres

# Redis
REDIS_PASSWORD=

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=YourNextcloudPassword123

# FreeIPA
FREEIPA_ADMIN_USER=admin
FREEIPA_ADMIN_PASSWORD=FreeIPA!2025
FREEIPA_DOMAIN=ceres.local

# Taiga
TAIGA_SECRET_KEY=your-secret-key-here
TAIGA_ADMIN_USERNAME=admin
TAIGA_ADMIN_PASSWORD=TaigaPassword123

# ERPNext
ERPNEXT_ADMIN_USER=administrator
ERPNEXT_ADMIN_PASSWORD=admin

# SuiteCRM
SUITECRM_ADMIN_USER=admin
SUITECRM_ADMIN_PASSWORD=admin

# Gitea
GITEA_ADMIN_USER=admin
GITEA_ADMIN_PASSWORD=GitPassword123

# Grafana
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin
```

---

## 🚀 Первый запуск

### После развертывания

Первый запуск требует инициализации:

1. **PostgreSQL инициализирует базы** (~2-3 мин)
2. **Keycloak инициализирует realm** (~2-3 мин)
3. **ERPNext создает workspace** (~5-10 мин)
4. **Остальные сервисы стартуют** (~5 мин)

**Итого:** 15-30 минут (первый раз медленнее)

### Что проверить

```powershell
# Все ли контейнеры работают?
cd F:\Ceres\config
docker compose ps -a

# Смотрите статус каждого
# Up (healthy) - готов
# Up - работает, но инициализируется
# Exited - ошибка

# Проверьте логи
docker compose logs -f keycloak
docker compose logs -f postgres
docker compose logs -f erpnext
```

---

## 🔧 Изменение пароля

### Для Keycloak (на лету)

1. Откройте: https://auth.Ceres.local
2. Войдите как admin
3. Меню → Administration Console
4. Users → admin
5. Credentials → Set Password

### Для PostgreSQL (требует перезапуска)

1. Отредактируйте `config/.env`:
   ```
   POSTGRES_PASSWORD=YourNewPassword123
   ```
2. Запустите миграцию:
   ```powershell
   cd F:\Ceres\config
   docker compose down -v          # Удалит БД!
   docker compose up -d postgres   # Пересоздаст с новым паролем
   ```
   **⚠️ ОСТОРОЖНО:** Это удалит все данные!

### Для остальных сервисов

Смотрите документацию каждого сервиса в `docs/guides/CONFIGURATION.md`

---

## 🔐 Production Security

**⚠️ Для production используйте:**

### 1. Измените все пароли
```bash
# Генерируйте сложные пароли
openssl rand -base64 32
```

### 2. Используйте .env.example как шаблон
```bash
cp config/.env.example config/.env
# Отредактируйте все значения
```

### 3. Используйте Secret Manager
- HashiCorp Vault
- Kubernetes Secrets
- AWS Secrets Manager

### 4. Не коммитьте `.env`
```bash
echo "config/.env" >> .gitignore
git rm --cached config/.env
```

### 5. Используйте HTTPS с валидными сертификатами
- Let's Encrypt (автоматически через Traefik)
- Купите сертификат для production домена

### 6. Настройте firewall
- Ограничьте доступ только к портам 80, 443
- Используйте VPN для доступа к внутренним адресам

---

## 📝 Логирование доступа

### Проверьте кто заходил

```powershell
# Логи Keycloak
docker compose logs keycloak | grep -i "login\|fail"

# Логи всех контейнеров
docker compose logs -f

# Проверьте временные метки
# Найдите подозрительную активность
```

---

## ⚠️ Важные замечания

1. **Не используйте default пароли в production** ⚠️
2. **Меняйте пароли каждые 90 дней** 📅
3. **Делайте резервные копии перед изменением** 💾
4. **Логируйте все изменения доступа** 📋
5. **Используйте 2FA где возможно** 🔐

---

## 🆘 Забыли пароль?

### Keycloak

```powershell
cd F:\Ceres\config

# Зайдите в контейнер
docker exec -it ceres-keycloak-1 bash

# Установите новый пароль
/opt/keycloak/bin/kc.sh set-password -r master -u admin -p NewPassword123
```

### PostgreSQL

Необходимо пересоздать контейнер (удалит данные).

### Остальные

Смотрите документацию сервиса или пересоздайте контейнер.

---

**Версия:** 1.0  
**Дата:** 04.12.2025  
**Статус:** ✅ Актуально
