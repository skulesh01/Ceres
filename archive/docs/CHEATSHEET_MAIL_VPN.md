# 📋 ШПАРГАЛКА: Почта + VPN для сотрудников

## ⚡ БЫСТРЫЙ СТАРТ

### 1️⃣ Запуск сервисов
```bash
cd config
docker compose -f compose/base.yml -f compose/core.yml -f compose/mail.yml -f compose/vpn.yml -f compose/edge.yml up -d
```

### 2️⃣ Доступ к веб-интерфейсам
- **Почта**: https://mail.ceres.local (admin@ceres.local / admin123)
- **VPN**: https://vpn.ceres.local (пароль: admin)

---

## 👤 СОЗДАНИЕ СОТРУДНИКА

### Вариант A: Автоматически (PowerShell)
```powershell
.\scripts\create-employee.ps1 -Username "ivan" -FullName "Иван Петров" -Password "Pass123"
```
✅ Создаст почту, VPN, отправит конфиг на email автоматически

### Вариант B: Вручную через веб
1. https://mail.ceres.local → Add User → создать ivan@ceres.local
2. https://vpn.ceres.local → New Client → создать ivan
3. Скачать .conf файл
4. Отправить конфиг на ivan@ceres.local через webmail

---

## 🔧 УПРАВЛЕНИЕ

### Отключить VPN сотрудника
```
https://vpn.ceres.local → найти пользователя → Delete
```

### Отключить почту
```
https://mail.ceres.local → Users → ivan@ceres.local → Disable
```

### Просмотр логов
```bash
docker compose -f compose/mail.yml logs -f
docker compose -f compose/vpn.yml logs -f
```

---

## 📧 ДЛЯ СОТРУДНИКА

### Настройка WireGuard
1. Скачать: https://www.wireguard.com/install/
2. Импортировать файл .conf из письма
3. Активировать → доступ к корпоративной сети

### Чтение почты
- **Webmail**: https://mail.ceres.local/webmail
- **IMAP**: mail.ceres.local:993 (SSL)
- **SMTP**: mail.ceres.local:587 (STARTTLS)

### Корпоративные ресурсы (через VPN)
- https://wiki.ceres.local - база знаний
- https://mattermost.ceres.local - чат
- https://nextcloud.ceres.local - файлы
- https://taiga.ceres.local - задачи

---

## 🐛 ПРОБЛЕМЫ

### Почта не отправляется
```bash
docker compose -f compose/mail.yml logs mailu-smtp
docker exec -it mailu-smtp-1 postqueue -p
```

### VPN не подключается
- Проверить порт 51820/UDP открыт
- Проверить WG_HOST в .env
- Проверить логи: `docker compose -f compose/vpn.yml logs wg-easy`

### Забыли пароль админа
```bash
# Mailu
docker exec -it mailu-admin-1 flask mailu admin admin ceres.local NewPassword123

# wg-easy - отредактировать PASSWORD_HASH в .env и перезапустить
```

---

## 📁 ФАЙЛЫ ПРОЕКТА

```
config/compose/mail.yml          ← Mailu сервер
config/compose/vpn.yml           ← wg-easy VPN
scripts/create-employee.ps1      ← Автоматизация
QUICKSTART_MAIL_VPN.md          ← Полная инструкция
WORKFLOW_DIAGRAM.md             ← Визуальные схемы
```

---

## 🎯 ПОЛНАЯ ДОКУМЕНТАЦИЯ

📖 **QUICKSTART_MAIL_VPN.md** - детальная инструкция со всеми шагами
