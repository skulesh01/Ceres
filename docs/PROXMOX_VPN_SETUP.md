# Настройка VPN доступа к Proxmox серверу

> Для подключения к Proxmox серверу через VPN, когда он находится за NAT или в обычной сети без прямого доступа.

## Вариант 1: WireGuard на самом Proxmox (рекомендуется)

### Шаг 1. На Proxmox сервере установите WireGuard

Подключитесь по SSH к Proxmox и выполните:

```bash
# На Proxmox сервере (PVE)
apt-get update
apt-get install -y wireguard wireguard-tools

# Генерируем ключи
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
wg genkey | tee client_private.key | wg pubkey > client_public.key

# Сохраняем ключи
cat server_private.key
cat server_public.key
cat client_private.key
cat client_public.key
```

### Шаг 2. Создаём конфигурацию WireGuard на Proxmox

Создайте файл `/etc/wireguard/wg0.conf`:

```bash
sudo nano /etc/wireguard/wg0.conf
```

Вставьте (заменив значения ключей):

```ini
[Interface]
PrivateKey = <SERVER_PRIVATE_KEY>
Address = 10.8.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.8.0.2/32
```

Сохраните (Ctrl+O, Enter, Ctrl+X).

### Шаг 3. Активируем WireGuard на Proxmox

```bash
# Включаем IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Запускаем WireGuard
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Проверяем статус
sudo wg show
```

### Шаг 4. Открываем UDP порт 51820 в firewall

```bash
# Если используется UFW
sudo ufw allow 51820/udp

# Или если используется iptables напрямую
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
```

### Шаг 5. На клиенте (ваш ПК) создаём конфигурацию

На Windows/Linux машине создайте файл `wg0.conf`:

```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.8.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
AllowedIPs = 10.8.0.0/24, 192.168.1.0/24
Endpoint = <PROXMOX_PUBLIC_IP_OR_DOMAIN>:51820
PersistentKeepalive = 25
```

Где:
- `<CLIENT_PRIVATE_KEY>` — ключ из `client_private.key`
- `<SERVER_PUBLIC_KEY>` — ключ из `server_public.key`
- `<PROXMOX_PUBLIC_IP_OR_DOMAIN>` — ваш публичный IP или доменное имя Proxmox сервера
- `192.168.1.0/24` — замените на ваш локальный subnet Proxmox (если нужен доступ к локальной сети)

### Шаг 6. Подключаемся с клиента

**Windows:**
1. Скачайте [WireGuard для Windows](https://www.wireguard.com/install/)
2. Импортируйте созданный `wg0.conf`
3. Активируйте соединение

**Linux:**
```bash
sudo cp wg0.conf /etc/wireguard/
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

### Шаг 7. Проверяем подключение

```powershell
# На клиенте
ping 10.8.0.1

# Если работает, можно заходить на Proxmox
# https://10.8.0.1:8006 (Proxmox Web UI)
```

---

## Вариант 2: Использование CERES WireGuard (если запускаете CERES на том же сервере)

Если вы запускаете полный CERES стек на том же Proxmox сервере:

### Шаг 1. Настройте переменные в `config/.env`

```bash
# Ваш публичный IP/доменное имя Proxmox
WG_HOST=vpn.your-domain.com
# или
WG_HOST=203.0.113.42

# Пароль для admin UI (будет захеширован скриптом)
WG_EASY_PASSWORD=your_secure_password
```

### Шаг 2. Запустите CERES с VPN модулем

```powershell
cd scripts
./start.ps1 vpn core  # WireGuard + base services
```

### Шаг 3. Откройте admin UI

```
http://localhost:51821
```

Логин: admin  
Пароль: (то, что задали в WG_EASY_PASSWORD)

### Шаг 4. Сгенерируйте конфигурацию клиента

В admin UI:
1. Нажмите "Create Client"
2. Задайте имя клиента (например, "my-laptop")
3. Скачайте QR код или конфиг файл
4. Импортируйте в WireGuard на вашем ПК

---

## Вариант 3: Cloudflare Tunnel (без открытия портов)

Если вы не можете открыть порт 51820 в роутере:

### Шаг 1. Создайте Cloudflare Tunnel

На Cloudflare Dashboard:
1. Zero Trust → Networks → Tunnels
2. Create Tunnel (выберите WireGuard)
3. Скопируйте token

### Шаг 2. На Proxmox установите cloudflared

```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/warp-cli/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
sudo cloudflared tunnel login
sudo cloudflared tunnel create proxmox-vpn
```

### Шаг 3. На клиенте используйте Cloudflare WARP

1. Скачайте [Cloudflare WARP](https://1.1.1.1/)
2. Подключитесь к вашему Tunnel
3. Вам станет доступен Proxmox по IP 10.8.0.1

---

## Альтернатива: SSH Tunnel (простейший вариант)

Если нужен быстрый доступ к Proxmox Web UI:

```powershell
# На Windows (PowerShell)
ssh -L 8006:localhost:8006 root@<PROXMOX_IP>
```

Потом откройте: `https://localhost:8006`

---

## Диагностика проблем

### Проверить доступность WireGuard на Proxmox:

```bash
# На сервере
sudo wg show

# Должно показать интерфейс и пиры
```

### Проверить подключение клиента:

```powershell
# На клиенте
Get-NetIPAddress  # Должен показать 10.8.0.2

ping 10.8.0.1     # Должно пройти

# Если пинг не работает, проверьте firewall
# netsh advfirewall show allprofiles
```

### Если WireGuard не стартует на Proxmox:

```bash
sudo wg-quick up wg0
# Проверьте вывод ошибок

# Если ошибка с модулем ядра:
sudo modprobe wireguard
```

---

## Быстрая настройка (TL;DR)

```bash
# На Proxmox:
apt-get install -y wireguard wireguard-tools
umask 077
wg genkey | tee server.key | wg pubkey > server.pub
wg genkey | tee client.key | wg pubkey > client.pub

# Создайте /etc/wireguard/wg0.conf
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
sudo ufw allow 51820/udp

# На клиенте: используйте generated конфиг в WireGuard
```

