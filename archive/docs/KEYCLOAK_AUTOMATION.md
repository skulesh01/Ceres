# 🎯 ПОЛНАЯ АВТОМАТИЗАЦИЯ: Keycloak → VPN → Email

## ✅ РАЗВЁРНУТО:

- **WireGuard VPN**: 192.168.1.3:51820
- **Postfix SMTP**: для отправки писем
- **Webhook Listener**: http://192.168.1.3:30500

## 🔄 КАК РАБОТАЕТ:

```
1. Вы создаёте пользователя в Keycloak (веб)
        ↓
2. Webhook автоматически:
   • Генерирует VPN ключи
   • Создаёт конфигурацию
   • Добавляет в WireGuard
   • Отправляет email
        ↓
3. Сотрудник получает письмо с .conf файлом ✅
```

## 📋 НАСТРОЙКА (один раз):

### В Keycloak:
1. https://auth.ceres.local → admin/admin123
2. **Realm Settings** → **Events** → **Event Listeners**
3. Добавить: `http://192.168.1.3:30500/webhook/keycloak`
4. Events: `REGISTER`, `CREATE_USER`

## 🧪 ТЕСТ:

```powershell
# Создать тестового пользователя
$body = @{
    username = "ivan"
    email = "ivan@company.com"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://192.168.1.3:30500/webhook/keycloak" `
    -Method POST `
    -Body $body `
    -ContentType "application/json"
```

## 🎯 ИСПОЛЬЗОВАНИЕ:

1. Откройте https://auth.ceres.local
2. **Users** → **Add User**
3. Укажите email сотрудника
4. **Save**

**ВСЁ!** Сотрудник получит письмо с VPN конфигом автоматически.

## 🔍 МОНИТОРИНГ:

```powershell
# Логи webhook
.\plink.exe -pw "!r0oT3dc" -batch root@192.168.1.3 "kubectl logs -n mail-vpn -l app=webhook-listener -f"

# Проверка VPN
.\plink.exe -pw "!r0oT3dc" -batch root@192.168.1.3 "wg show"
```

**Готово! Полная автоматизация работает!** 🚀
