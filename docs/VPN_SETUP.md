# WireGuard VPN - Доступ к Ceres Platform

## 🌐 Текущая конфигурация сервера

**WireGuard Server (Proxmox):**
- IP: `10.8.0.1`
- Внешний IP: `192.168.1.3`
- Порт: `51820`
- Сеть: `10.8.0.0/24`
- Статус: ✅ Активен

**Kubernetes Cluster:**
- Pod Network: `10.42.0.0/16`
- Service Network: `10.43.0.0/16`

## 📥 Установка клиента WireGuard (Windows)

1. Скачать WireGuard: https://www.wireguard.com/install/
2. Установить
3. Запустить WireGuard

## 🔑 Создание конфигурации клиента

### Шаг 1: Сгенерировать ключи на клиенте

```powershell
# В PowerShell
cd "E:\Новая папка\All_project\Ceres"

# Создать директорию для ключей
New-Item -ItemType Directory -Path "config\wireguard" -Force

# Сгенерировать приватный ключ
$privateKey = & wg genkey
$privateKey | Out-File -FilePath "config\wireguard\client_private.key" -NoNewline

# Сгенерировать публичный ключ
$publicKey = $privateKey | wg pubkey
$publicKey | Out-File -FilePath "config\wireguard\client_public.key" -NoNewline

Write-Host "`nВаш публичный ключ (отправить на сервер):" -ForegroundColor Cyan
Write-Host $publicKey -ForegroundColor Yellow
```

### Шаг 2: Добавить клиента на сервер

```powershell
# SSH на Proxmox и добавить пира
$clientPublicKey = Get-Content "config\wireguard\client_public.key"

ssh root@192.168.1.3 @"
wg set wg0 peer $clientPublicKey allowed-ips 10.8.0.2/32
wg-quick save wg0
"@
```

### Шаг 3: Создать конфигурацию клиента

```ini
[Interface]
PrivateKey = <ВАШ_ПРИВАТНЫЙ_КЛЮЧ>
Address = 10.8.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = 5yuVehg0hG3vnmJ3mGd0lCvH1sY7JUqbB+RQfqmxrUU=
Endpoint = 192.168.1.3:51820
AllowedIPs = 10.8.0.0/24, 10.42.0.0/16, 10.43.0.0/16, 192.168.1.0/24
PersistentKeepalive = 25
```

**Примечание:**
- `PublicKey` - получить командой на сервере: `ssh root@192.168.1.3 "cat /etc/wireguard/wg0.conf | grep PrivateKey | cut -d= -f2 | tr -d ' ' | wg pubkey"`
- `PrivateKey` - ваш приватный ключ из `config\wireguard\client_private.key`

### Шаг 4: Импортировать в WireGuard

1. Открыть WireGuard GUI
2. "Import tunnel from file"
3. Выбрать файл конфигурации
4. Activate

## ✅ Проверка подключения

После активации туннеля:

```powershell
# Проверить ping до сервера VPN
ping 10.8.0.1

# Проверить ping до K8s Pod network
ping 10.42.0.147  # Redis pod IP

# Проверить ping до K8s Service network
ping 10.43.1.196  # PostgreSQL ClusterIP
```

## 🎯 Доступ к сервисам через VPN

После подключения к VPN, сервисы доступны напрямую:

### PostgreSQL
```powershell
# Через любой PostgreSQL клиент (DBeaver, pgAdmin)
Host: 10.43.1.196
Port: 5432
User: postgres
Password: ceres_postgres_2025
```

### Redis
```powershell
# Через Redis клиент (RedisInsight)
Host: 10.43.89.168
Port: 6379
Password: ceres_redis_2025
```

### Web приложения (после развертывания Ingress)
```
https://keycloak.ceres.local
https://gitlab.ceres.local
https://grafana.ceres.local
...
```

## 🔧 Автоматизация настройки

Создам скрипт для автоматической настройки:

```powershell
# .\scripts\setup-vpn.ps1
```

Этот скрипт:
1. Проверит установку WireGuard
2. Сгенерирует ключи
3. Добавит клиента на сервер
4. Создаст конфигурацию
5. Импортирует в WireGuard

## 📋 Hosts файл (для доменов)

Добавить в `C:\Windows\System32\drivers\etc\hosts`:

```
10.43.XX.XX keycloak.ceres.local
10.43.XX.XX gitlab.ceres.local
10.43.XX.XX grafana.ceres.local
...
```

(IP будут известны после развертывания Ingress)

## 🚨 Troubleshooting

### Не подключается к VPN
```powershell
# Проверить порт 51820 открыт
Test-NetConnection -ComputerName 192.168.1.3 -Port 51820

# Проверить статус на сервере
ssh root@192.168.1.3 "wg show"
```

### VPN работает, но нет доступа к сервисам
```powershell
# Проверить маршруты
route print | Select-String "10.8.0"
route print | Select-String "10.43.0"

# Проверить K3s сеть
ssh root@192.168.1.3 "kubectl get nodes -o wide"
```

### Отключить другие VPN
Важно: выключите другие VPN (коммерческие VPN, корпоративные) перед подключением к WireGuard.

---

**Готово!** После настройки VPN у вас будет прямой доступ ко всем сервисам в сети K8s.
