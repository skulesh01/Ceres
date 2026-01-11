# 🎯 QUICK START: Развёртывание за 5 минут

## Предварительные требования
- ✅ Сервер доступен по SSH (192.168.1.3)
- ✅ K3s установлен и работает
- ✅ WireGuard установлен на хосте
- ✅ plink.exe в корне проекта

## Шаг 1: Проверка доступа (30 сек)

```powershell
# Запустить из корня проекта
cd 'E:\Новая папка\Ceres'

# Проверить ping
Test-Connection 192.168.1.3 -Count 2

# Проверить SSH (должен вернуть hostname)
.\plink.exe -pw "$env:DEPLOY_SERVER_PASSWORD" -batch $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "hostname"
```

## Шаг 2: Применение манифестов (2 мин)

```powershell
# Копируем и применяем манифесты
.\scripts\deploy-quick.ps1
```

Или вручную:

```powershell
$plink = ".\plink.exe"

# 1. Загружаем манифесты
Get-Content 'k8s-mail-vpn-simple.yaml' -Raw | 
    & $plink -pw "$env:DEPLOY_SERVER_PASSWORD" -batch $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "cat > /tmp/mail-vpn.yaml"

Get-Content 'k8s-webhook-listener-fixed.yaml' -Raw | 
    & $plink -pw "$env:DEPLOY_SERVER_PASSWORD" -batch $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "cat > /tmp/webhook.yaml"

# 2. Применяем
& $plink -pw "$env:DEPLOY_SERVER_PASSWORD" -batch $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP @"
kubectl apply -f /tmp/mail-vpn.yaml
kubectl apply -f /tmp/webhook.yaml
echo 'Манифесты применены!'
"@
```

## Шаг 3: Проверка pods (1 мин)

```powershell
# Ждём запуска pods
Start-Sleep -Seconds 60

# Проверяем статус
& $plink -pw "$env:DEPLOY_SERVER_PASSWORD" -batch $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "kubectl get pods -n mail-vpn"
```

**Ожидаемый результат:**
```
NAME                               READY   STATUS    RESTARTS   AGE
postfix-xxxxx                      1/1     Running   0          1m
webhook-listener-xxxxx             1/1     Running   0          1m
wg-easy-xxxxx                      1/1     Running   0          1m (если есть интернет)
```

## Шаг 4: Тестирование (1 мин)

```powershell
# Тест 1: Health check webhook
Invoke-RestMethod -Uri 'http://192.168.1.3:30500/health'
# Ожидается: {"status":"healthy"}

# Тест 2: Создание VPN пользователя
$body = @{
    username = 'testuser'
    email = 'test@company.com'
} | ConvertTo-Json

Invoke-RestMethod -Uri 'http://192.168.1.3:30500/webhook/keycloak' `
    -Method POST -Body $body -ContentType 'application/json' `
    -Headers @{'X-Webhook-Token'='change-me'}

# Ожидается: {"status":"success","username":"testuser","ip":"10.8.0.X"}

# Тест 3: Проверка WireGuard peers
& $plink -pw "$env:DEPLOY_SERVER_PASSWORD" -batch $env:DEPLOY_SERVER_USER@$env:DEPLOY_SERVER_IP "wg show wg0"
```

## ✅ Готово!

Система развёрнута и работает. Теперь можно:

1. **Создавать VPN пользователей** через webhook или PowerShell скрипты
2. **Интегрировать с Keycloak** для автоматизации
3. **Мониторить** через Prometheus/Grafana (если развёрнуто)

---

## 🔧 Частые проблемы

### ImagePullBackOff на pods
**Причина:** Нет интернета на сервере  
**Решение:** 
```bash
# На сервере
ping 8.8.8.8  # проверить интернет
ip route show  # проверить gateway

# Если gateway есть, но пинг не идёт:
# 1. Проверить физическое подключение
# 2. Проверить firewall на роутере
# 3. Использовать кешированные образы (старые pods)
```

### Webhook возвращает 503
**Причина:** Pod ещё не запустился  
**Решение:** Подождать 1-2 минуты и повторить

### WireGuard peer не добавляется
**Причина:** В pod нет wireguard-tools  
**Решение:** 
```bash
# Пересоздать pod
kubectl delete pod -n mail-vpn -l app=webhook-listener
# Подождать 90 секунд
kubectl get pods -n mail-vpn
```

### Email не отправляется
**Причина:** DNS не резолвит postfix  
**Решение:** Уже исправлено в k8s-webhook-listener-fixed.yaml (используется IP 10.43.28.213)

---

## 📚 Дополнительная документация

- [RECOVERY_RUNBOOK.md](RECOVERY_RUNBOOK.md) - Полное восстановление системы
- [KEYCLOAK_AUTOMATION.md](KEYCLOAK_AUTOMATION.md) - Интеграция с Keycloak
- [scripts/onboard-employee.ps1](scripts/onboard-employee.ps1) - Ручное добавление сотрудников
- [config/](config/) - Конфигурационные файлы всех сервисов
