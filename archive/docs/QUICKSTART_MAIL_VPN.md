# 🚀 БЫСТРЫЙ СТАРТ: Управление сотрудниками через веб-интерфейс

## ✅ Что добавлено в проект:

### 📧 **Mailu** - Полноценный почтовый сервер
- **Веб-админка**: Создание почтовых ящиков @ceres.local
- **Roundcube Webmail**: Чтение почты в браузере
- **SMTP/IMAP**: Поддержка почтовых клиентов
- **Доступ**: https://mail.ceres.local

### 🔒 **wg-easy** - Управление VPN через браузер
- **Веб-интерфейс**: Создание/удаление VPN пользователей
- **QR-коды**: Для быстрого подключения с телефона
- **Скачивание конфигов**: Один клик
- **Доступ**: https://vpn.ceres.local

---

## 🎯 СЦЕНАРИЙ 1: Создание нового сотрудника вручную

### Шаг 1: Создайте почтовый ящик
1. Откройте https://mail.ceres.local
2. Войдите как администратор:
   - Email: `admin@ceres.local`
   - Пароль: `admin123` (по умолчанию)
3. Перейдите в **Users** → **Add User**
4. Заполните:
   - Email: `ivan.petrov@ceres.local`
   - Password: `SecurePass123`
   - Display Name: `Иван Петров`
   - Quota: `1 GB`
5. Нажмите **Create**

### Шаг 2: Создайте VPN доступ
1. Откройте https://vpn.ceres.local
2. Войдите с паролем: `admin` (по умолчанию)
3. Нажмите **+ New Client**
4. Имя клиента: `ivan.petrov`
5. Нажмите **Create**
6. **Скачайте конфиг** или отсканируйте QR-код

### Шаг 3: Отправьте конфиг сотруднику
1. Откройте https://mail.ceres.local/webmail
2. Войдите как admin@ceres.local
3. Создайте письмо для ivan.petrov@ceres.local
4. Прикрепите скачанный .conf файл
5. Отправьте инструкцию по подключению

**ГОТОВО!** ✅ Сотрудник получит все данные на свою почту.

---

## 🤖 СЦЕНАРИЙ 2: Автоматическое создание (PowerShell)

### Один скрипт делает всё:
```powershell
cd scripts
.\create-employee.ps1 `
  -Username "ivan.petrov" `
  -FullName "Петров Иван Сергеевич" `
  -Password "SecurePass123"
```

**Что происходит автоматически:**
- ✅ Создаётся почтовый ящик ivan.petrov@ceres.local
- ✅ Генерируется VPN конфигурация
- ✅ Конфиг отправляется на созданную почту
- ✅ Сотрудник получает письмо с инструкциями

### Дополнительные параметры:
```powershell
# С созданием в Keycloak SSO
.\create-employee.ps1 -Username "maria" -FullName "Мария Иванова" -Password "Pass1234" -CreateKeycloak

# Свой домен
.\create-employee.ps1 -Username "alex" -FullName "Alex Smith" -Password "Pass1234" -Domain "company.com"
```

---

## 🌐 РАЗВЁРТЫВАНИЕ: Запуск почты и VPN

### Вариант 1: Запустить всё сразу
```powershell
cd scripts
.\start.ps1 core apps mail vpn edge
```

### Вариант 2: Только почта и VPN
```powershell
cd config
docker compose -f compose/base.yml -f compose/core.yml -f compose/mail.yml -f compose/vpn.yml -f compose/edge.yml up -d
```

### Проверка статуса:
```powershell
docker compose -f compose/mail.yml ps
docker compose -f compose/vpn.yml ps
```

---

## 🔑 ДОСТУПЫ ПО УМОЛЧАНИЮ

### Mailu (Почтовый сервер)
- URL: https://mail.ceres.local
- Админ: admin@ceres.local
- Пароль: admin123
- Webmail: https://mail.ceres.local/webmail

### wg-easy (VPN)
- URL: https://vpn.ceres.local
- Пароль: admin

### Keycloak (SSO)
- URL: https://auth.ceres.local
- Админ: admin
- Пароль: admin123

⚠️ **ВАЖНО:** Измените пароли сразу после первого входа!

---

## 📋 WORKFLOW: Жизненный цикл сотрудника

### Новый сотрудник:
```
1. Создать почтовый ящик (mail.ceres.local)
   └─> ivan.petrov@ceres.local

2. Создать VPN доступ (vpn.ceres.local)
   └─> Скачать конфиг ivan.petrov.conf

3. Отправить конфиг на почту
   └─> Сотрудник получает письмо с инструкциями

4. Сотрудник подключается:
   ├─> Устанавливает WireGuard
   ├─> Импортирует конфиг
   ├─> Активирует VPN
   └─> Получает доступ ко всем внутренним ресурсам
```

### Увольнение сотрудника:
```
1. Удалить VPN клиента (vpn.ceres.local)
   └─> Доступ к сети отключён ❌

2. Отключить почтовый ящик (mail.ceres.local)
   └─> Пометить как disabled

3. Отозвать SSO (auth.ceres.local)
   └─> Удалить из Keycloak
```

---

## 🛠️ НАСТРОЙКА: Первый запуск

### 1. Настройте переменные окружения
Файл: `config/.env`

```bash
# Домен
DOMAIN=ceres.local

# Mailu
MAILU_SECRET_KEY=ChangeThisSecretKey123456789012
MAIL_DOMAIN=ceres.local
MAILU_ADMIN_PASSWORD=admin123

# WireGuard
WG_HOST=your-public-ip-or-domain
WG_EASY_PASSWORD_HASH=<generated-hash>
```

### 2. Создайте базы данных
```sql
-- Подключитесь к PostgreSQL
docker exec -it ceres-postgres-1 psql -U postgres

-- Создайте БД для Mailu
CREATE DATABASE mailu;
CREATE DATABASE roundcube;
GRANT ALL PRIVILEGES ON DATABASE mailu TO postgres;
GRANT ALL PRIVILEGES ON DATABASE roundcube TO postgres;
```

### 3. Запустите сервисы
```powershell
cd config
docker compose -f compose/base.yml -f compose/core.yml -f compose/mail.yml -f compose/vpn.yml -f compose/edge.yml up -d
```

### 4. Дождитесь инициализации
```powershell
# Проверка логов
docker compose -f compose/mail.yml logs -f mailu-admin
docker compose -f compose/vpn.yml logs -f wg-easy

# Статус контейнеров (должны быть "Up")
docker compose -f compose/mail.yml ps
```

### 5. Первый вход
1. https://mail.ceres.local → войти как admin@ceres.local
2. https://vpn.ceres.local → войти с паролем admin

---

## 📊 МОНИТОРИНГ

### Логи почтового сервера:
```powershell
docker compose -f compose/mail.yml logs -f mailu-smtp
docker compose -f compose/mail.yml logs -f mailu-imap
```

### Логи VPN:
```powershell
docker compose -f compose/vpn.yml logs -f wg-easy
```

### Список активных VPN клиентов:
```bash
# На сервере WireGuard
docker exec wg-easy wg show
```

### Статистика почты:
- Откройте https://mail.ceres.local
- **Dashboard** → статистика отправленных/полученных писем

---

## 🔥 TROUBLESHOOTING

### Почтовый ящик не создаётся
```powershell
# Проверить логи
docker compose -f compose/mail.yml logs mailu-admin

# Проверить БД
docker exec -it ceres-postgres-1 psql -U postgres -d mailu -c "SELECT * FROM users;"
```

### VPN не подключается
1. Проверьте порт 51820/UDP открыт в firewall
2. Проверьте WG_HOST в .env (должен быть публичный IP)
3. Проверьте логи: `docker compose -f compose/vpn.yml logs wg-easy`

### Email не отправляется
```powershell
# Проверить SMTP сервис
docker compose -f compose/mail.yml logs mailu-smtp

# Тестовая отправка
docker exec -it mailu-smtp-1 telnet localhost 25
```

---

## 🎯 ИТОГ

**Теперь у вас есть:**
✅ Полноценный почтовый сервер с веб-админкой
✅ VPN с удобным веб-интерфейсом  
✅ Автоматизация создания сотрудников
✅ Интеграция почты + VPN + Keycloak

**Все доступно через браузер!**
- https://mail.ceres.local - управление почтой
- https://vpn.ceres.local - управление VPN
- https://auth.ceres.local - управление пользователями

**Начните работу:**
```powershell
# Создать первого сотрудника
.\scripts\create-employee.ps1 -Username "test" -FullName "Test User" -Password "Test1234"
```

🚀 Готово к использованию!
