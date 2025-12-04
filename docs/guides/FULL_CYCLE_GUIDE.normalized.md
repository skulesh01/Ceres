# 🔄 ПОЛНЫЙ ЦИКЛ: РАЗВЁРТЫВАНИЕ → НАСТРОЙКА → СОХРАНЕНИЕ → СВОРАЧИВАНИЕ

## 📊 ОБЗОР ПРОЦЕССА

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ РАЗВЁРТ. │ →  │  ТЕСТ.   │ →  │ НАСТРОЙ  │ →  │ СВОРАЧ.  │  │
│  │  (уже    │    │ (30 мин) │    │ (60 мин) │    │ (5 мин)  │  │
│  │ запущено)│    │          │    │          │    │          │  │
│  └──────────┘    └──────────┘    └──────────┘    └──────────┘  │
│                                                                 │
│                                                ↓                │
│                                                                 │
│                      ┌──────────────────┐                      │
│                      │  ВОССТАНОВЛЕНИЕ  │                      │
│                      │  (15 мин)        │                      │
│                      └──────────────────┘                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🚀 ЭТАП 1: ОЖИДАНИЕ РАЗВЁРТЫВАНИЯ (ПРОИСХОДИТ СЕЙЧАС)

### Статус:
- ✅ Docker контейнеры запущены
- ⏳ Инициализация базы данных (~5-10 минут)
- ⏳ Запуск Keycloak (~3-5 минут)
- ⏳ Запуск остальных сервисов (~5-10 минут)

### Проверить статус:
```bash
docker compose ps -a
```

Дождитесь, пока все контейнеры будут в состоянии **Up** или **healthy**

---

## 🧪 ЭТАП 2: ТЕСТИРОВАНИЕ (30-60 минут)

### Шаг 1: Добавить в файл hosts

**Откройте файл:** `C:\Windows\System32\drivers\etc\hosts` (от администратора)

**Добавьте строки:**
```
127.0.0.1 Ceres.local
127.0.0.1 traefik.Ceres.local
127.0.0.1 auth.Ceres.local
127.0.0.1 taiga.Ceres.local
127.0.0.1 edm.Ceres.local
127.0.0.1 cloud.Ceres.local
127.0.0.1 git.Ceres.local
127.0.0.1 mail.Ceres.local
127.0.0.1 erp.Ceres.local
127.0.0.1 crm.Ceres.local
127.0.0.1 remote.Ceres.local
127.0.0.1 freeipa.Ceres.local
127.0.0.1 grafana.Ceres.local
```

**Сохраните файл** (Ctrl+S)

### Шаг 2: Протестировать каждый сервис

Откройте браузер и проверьте:

| Сервис | URL | Логин | Статус |
|--------|-----|-------|--------|
| Keycloak | https://auth.Ceres.local | admin / K3yClo@k!2025 | ✅ |
| Taiga | https://taiga.Ceres.local | (создать) | ✅ |
| ProcessMaker | https://edm.Ceres.local | (создать) | ✅ |
| Nextcloud | https://cloud.Ceres.local | (создать) | ✅ |
| Grafana | https://grafana.Ceres.local | (создать) | ✅ |
| SuiteCRM | https://crm.Ceres.local | (создать) | ✅ |
| ERPNext | https://erp.Ceres.local | (создать) | ✅ |
| Gitea | https://git.Ceres.local | (создать) | ✅ |

---

## ⚙️ ЭТАП 3: НАСТРОЙКА (60-120 минут)

### 3.1 Keycloak (ОБЯЗАТЕЛЬНО!)

**Цель:** Настроить единый вход для всех приложений

#### Шаг 1: Войти в Keycloak
1. Откройте: https://auth.Ceres.local
2. Логин: `admin`
3. Пароль: `K3yClo@k!2025`

#### Шаг 2: Создать новый Realm
1. В левом меню нажмите на "Master"
2. Нажмите "Create Realm"
3. Имя: `Ceres`
4. Нажмите "Create"

#### Шаг 3: Создать Clients
В Realm "Ceres" → Clients → Create:

**Client 1: ProcessMaker**
- Client type: OpenID Connect
- Client ID: `processmaker`
- Valid redirect URIs: `https://edm.Ceres.local/*`
- Web origins: `https://edm.Ceres.local`

**Client 2: Taiga**
- Client type: OpenID Connect
- Client ID: `taiga`
- Valid redirect URIs: `https://taiga.Ceres.local/*`

**Client 3: Nextcloud**
- Client type: OpenID Connect
- Client ID: `nextcloud`
- Valid redirect URIs: `https://cloud.Ceres.local/*`

#### Шаг 4: Создать пользователей
1. Users → Add user
2. Создайте пользователей:
   - admin@ceres.local
   - user@ceres.local
   - manager@ceres.local
3. Установите пароли в Credentials

#### Шаг 5: Создать роли
1. Realm roles → Create role
2. Создайте:
   - administrator
   - project-manager
   - user

#### Шаг 6: Назначить роли пользователям
1. Users → выберите пользователя
2. Role mapping → Assign role

**✅ Keycloak готов к использованию!**

### 3.2 Nextcloud

**Цель:** Настроить облачное хранилище и WebDAV токен

#### Шаг 1: Первоначальная настройка
1. Откройте: https://cloud.Ceres.local
2. Создайте администраторский аккаунт:
   - Username: `admin`
   - Password: (установите сильный пароль)

#### Шаг 2: Сгенерировать WebDAV токен
1. Settings (иконка пользователя) → Security
2. App passwords
3. Создайте новый токен: `Ceres-WebDAV`
4. **СОХРАНИТЕ ЭТОТ ТОКЕН!** (он понадобится для ProcessMaker)

#### Шаг 3: Настроить дополнительные параметры
1. Settings → Admin
2. Настройте лимиты и политики безопасности

**✅ Nextcloud готов!**

### 3.3 Taiga

**Цель:** Настроить систему управления проектами

#### Шаг 1: Первоначальная настройка
1. Откройте: https://taiga.Ceres.local
2. Регистрация → создайте аккаунт
3. Создайте организацию: `Ceres`

#### Шаг 2: Создать проекты
1. Создайте тестовый проект
2. Пригласите членов команды
3. Настройте рабочие процессы

**✅ Taiga готова!**

### 3.4 ProcessMaker

**Цель:** Настроить автоматизацию бизнес-процессов

#### Шаг 1: Интеграция с Keycloak
1. Откройте: https://edm.Ceres.local
2. Admin → Settings → Authentication
3. Настройте OIDC:
   - Server: `https://auth.Ceres.local`
   - Realm: `Ceres`
   - Client ID: `processmaker`
   - Client Secret: (из Keycloak)

#### Шаг 2: Создать процессы
1. Design → New Process
2. Создайте тестовый процесс
3. Назначьте ответственных

**✅ ProcessMaker готов!**

### 3.5 Прочие сервисы

- **Grafana:** Добавьте Prometheus как источник данных
- **Gitea:** Создайте репозитории
- **SuiteCRM:** Создайте компанию и контакты
- **ERPNext:** Инициализируйте компанию

---

## 💾 ЭТАП 4: СОХРАНЕНИЕ КОНФИГУРАЦИИ (5-10 минут)

### Шаг 1: Запустить скрипт резервного копирования

```bash
cd F:\Ceres
python backup_configuration.py
```

Этот скрипт сохранит:
- ✅ Конфигурацию Keycloak (Realms, Clients, Users)
- ✅ Конфигурацию Nextcloud
- ✅ Переменные окружения (.env)
- ✅ Информацию о Docker томах
- ✅ docker-compose.yml

### Шаг 2: Проверить резервную копию

```bash
ls backups/config_*
```

Должна быть папка с датой/временем, содержащая:
- `keycloak_export.json`
- `nextcloud_config.php`
- `.env.backup`
- `docker-compose.yml.backup`
- `restore_config.ps1`
- `backup.log`

---

## 🛑 ЭТАП 5: СВОРАЧИВАНИЕ (5 минут)

### Шаг 1: Запустить скрипт очистки

```bash
cd F:\Ceres
python cleanup_containers.py
```

Этот скрипт:
- ✅ Остановит все контейнеры
- ✅ Очистит логи и временные файлы
- ✅ СОХРАНИТ конфигурацию
- ✅ Создаст отчёт

### Шаг 2: Проверить статус

```bash
docker compose ps -a
```

Все контейнеры должны быть в состоянии **Exit** или удалены

### ⚠️ ВАЖНО!

**Docker тома сохранены в системе:**
- Все конфигурации Keycloak
- Все данные Nextcloud
- Все базы данных PostgreSQL
- Все остальные конфигурации

Поэтому при следующем запуске `docker compose up -d` всё восстановится автоматически!

---

## 🚀 ЭТАП 6: БЫСТРОЕ ВОССТАНОВЛЕНИЕ (15-30 минут)

### Вариант 1: Простой перезапуск (РЕКОМЕНДУЕТСЯ)

```bash
cd F:\Ceres
docker compose up -d
```

**ВСЕ КОНФИГУРАЦИИ ВОССТАНОВЯТСЯ АВТОМАТИЧЕСКИ!**

Благодаря Docker томам:
- ✅ Keycloak Realms вернутся
- ✅ Все пользователи вернутся
- ✅ Nextcloud данные вернутся
- ✅ Все базы данных восстановятся

Время: **15-30 минут**

### Вариант 2: Двойной клик батника

```
Откройте: F:\Ceres\quick_deploy.bat
```
