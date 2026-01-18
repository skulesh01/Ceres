# CERES Remote Deployment - Quick Start Guide

## 🚀 Автоматический деплой через SSH

Этот скрипт позволяет развернуть CERES на удаленном сервере **автоматически** через SSH.

## 📋 Требования

### На вашей машине (Windows):
- PowerShell 5.1+
- PuTTY (plink.exe)
- SSH ключ в формате .ppk

### На сервере:
- Ubuntu 22.04 / Debian 12
- SSH доступ (порт 22)
- Root или sudo права
- Минимум: 8 CPU, 16GB RAM, 200GB disk

## 🔧 Подготовка

### 1. Установите PuTTY (если нет):

```powershell
# Через Chocolatey
choco install putty

# Или скачайте: https://www.putty.org/
```

### 2. Создайте SSH ключ (если нет):

```powershell
# В PuTTYgen:
# 1. Generate new key (RSA, 4096 bits)
# 2. Save private key as: ~/.ssh/id_rsa.ppk
# 3. Copy public key

# На сервере добавьте публичный ключ:
ssh root@your-server
mkdir -p ~/.ssh
echo "ssh-rsa AAAAB3... your@email" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 3. Проверьте подключение:

```powershell
plink -ssh -i ~/.ssh/id_rsa.ppk root@your-server "echo OK"
```

Должно вывести `OK` без запроса пароля.

## 🎯 Использование

### Вариант 1: Только проверка системы

```powershell
.\scripts\remote-deploy.ps1 `
    -ServerHost 192.168.1.100 `
    -Username root `
    -CheckOnly
```

Проверит:
- SSH подключение
- OS версию
- CPU, RAM, Disk
- Установлен ли Docker

### Вариант 2: Полный автоматический деплой

```powershell
.\scripts\remote-deploy.ps1 `
    -ServerHost 192.168.1.100 `
    -Username root `
    -Domain ceres.example.com `
    -FullDeploy
```

**Что сделает скрипт:**

1. ✅ Обновит систему (`apt update && upgrade`)
2. ✅ Установит Docker + Docker Compose
3. ✅ Установит Git, vim, htop, Python
4. ✅ Клонирует CERES в `/opt/Ceres`
5. ✅ Сгенерирует безопасные пароли
6. ✅ Создаст `config/.env` с настройками
7. ✅ Настроит firewall (UFW)
8. ✅ Создаст Docker network
9. ✅ Запустит все сервисы:
   - Core (PostgreSQL, Redis, Keycloak)
   - Apps (GitLab, Zulip, Nextcloud, Mayan)
   - Monitoring (Prometheus, Grafana)
   - Edge (Caddy)
10. ✅ Проверит статус

**Время выполнения:** 15-20 минут

### Параметры:

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `-ServerHost` | IP или hostname сервера | **Обязательно** |
| `-Username` | SSH пользователь | `root` |
| `-SSHKey` | Путь к .ppk ключу | `~/.ssh/id_rsa.ppk` |
| `-Domain` | Доменное имя | `ceres.local` |
| `-CheckOnly` | Только проверка | - |
| `-FullDeploy` | Полный деплой | - |

## 📊 Что происходит во время деплоя

```
🔍 Проверка plink...
✅ OK

🔌 Проверка SSH подключения к 192.168.1.100...
→ Тест подключения
✅ SSH OK
✅ SSH подключение работает!

🚀 НАЧИНАЮ ПОЛНЫЙ ДЕПЛОЙ...

📦 Шаг 1/10: Обновление системы...
→ apt update && upgrade
✅ OK

🐳 Шаг 2/10: Установка Docker...
Docker не установлен, устанавливаю...
→ Установка Docker
✅ OK

... (8 шагов) ...

✅ Шаг 10/10: Проверка сервисов...
postgres: Up 2 minutes
redis: Up 2 minutes
keycloak: Up 1 minute
gitlab: Up 1 minute (health: starting)
...

════════════════════════════════════════════════════
   ✅ ДЕПЛОЙ ЗАВЕРШЁН!
════════════════════════════════════════════════════

🌐 Доступные сервисы:
   https://auth.ceres.example.com - Keycloak
   https://gitlab.ceres.example.com - GitLab CE
   https://grafana.ceres.example.com - Grafana

🔑 Пароли:
   PostgreSQL: xK9mP2...
   Keycloak:   7nQ4vR...
   GitLab:     8zW5tY...
   Grafana:    3bM7cX...

📝 Следующие шаги:
   1. Настройте DNS: *.ceres.example.com -> 192.168.1.100
   2. Дождитесь инициализации (5-10 мин)
   3. Откройте https://auth.ceres.example.com
```

## 🔐 Безопасность

**Скрипт НЕ хранит пароли!**

Пароли генерируются случайно и **выводятся в консоль ОДИН РАЗ**.

**ОБЯЗАТЕЛЬНО сохраните пароли** в password manager (1Password, KeePass, Bitwarden).

## 🐛 Troubleshooting

### Ошибка: "plink не найден"

```powershell
# Установите PuTTY
choco install putty

# Или добавьте в PATH
$env:PATH += ";C:\Program Files\PuTTY"
```

### Ошибка: "Permission denied (publickey)"

```powershell
# Проверьте SSH ключ
plink -ssh -i ~/.ssh/id_rsa.ppk root@your-server "whoami"

# Если не работает, добавьте публичный ключ на сервер:
ssh-copy-id -i ~/.ssh/id_rsa.pub root@your-server
```

### Ошибка: "Connection refused"

- Проверьте что сервер включен
- Проверьте что SSH работает: `telnet your-server 22`
- Проверьте firewall на сервере

### Сервисы не стартуют

```powershell
# Подключитесь к серверу
plink -ssh -i ~/.ssh/id_rsa.ppk root@your-server

# Проверьте логи
cd /opt/Ceres
docker-compose -f config/compose/core.yml logs

# Проверьте ресурсы
docker stats
free -h
df -h
```

## 📚 Следующие шаги

После успешного деплоя:

1. **Настройте DNS:**
   ```
   *.ceres.example.com A 192.168.1.100
   ```

2. **Дождитесь инициализации:**
   - GitLab: ~5-7 минут
   - Zulip: ~3-5 минут
   - Остальные: ~2-3 минуты

3. **Откройте сервисы:**
   - https://auth.ceres.example.com (Keycloak)
   - https://gitlab.ceres.example.com (root + пароль из консоли)
   - https://grafana.ceres.example.com (admin + пароль из консоли)

4. **Настройте SSO:**
   ```powershell
   # На сервере
   cd /opt/Ceres
   ./scripts/keycloak-bootstrap-full.ps1
   ```

5. **Импортируйте Grafana dashboards:**
   - Grafana UI → Dashboards → Import
   - Upload: `config/grafana/dashboards/*.json`

6. **Настройте автоматические бэкапы:**
   ```bash
   crontab -e
   # Добавьте:
   0 2 * * * cd /opt/Ceres && ./scripts/backup-full.ps1
   ```

## 💡 Tips

### Запуск в фоне (background)

```powershell
Start-Job -ScriptBlock {
    .\scripts\remote-deploy.ps1 `
        -ServerHost 192.168.1.100 `
        -FullDeploy `
        -Domain ceres.example.com
}

# Проверить статус
Get-Job
Receive-Job -Id 1
```

### Логирование

```powershell
.\scripts\remote-deploy.ps1 `
    -ServerHost 192.168.1.100 `
    -FullDeploy `
    -Domain ceres.example.com `
    | Tee-Object -FilePath deploy.log
```

### Множество серверов

```powershell
$servers = @('192.168.1.100', '192.168.1.101', '192.168.1.102')

foreach ($server in $servers) {
    Write-Host "Deploying to $server..."
    .\scripts\remote-deploy.ps1 -ServerHost $server -CheckOnly
}
```

## 🔗 Дополнительная информация

- [PRODUCTION_DEPLOYMENT_GUIDE.md](../PRODUCTION_DEPLOYMENT_GUIDE.md) - Полное руководство
- [README.md](../README.md) - Обзор проекта
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Архитектура

## 🆘 Поддержка

GitHub Issues: https://github.com/skulesh01/Ceres/issues
