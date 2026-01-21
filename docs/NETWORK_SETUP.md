# 🌐 Wake-on-LAN и Network Setup Guide

## 📋 Что добавлено

### 1. **Wake-on-LAN Scripts**
- `scripts/wol.sh` - Wake-on-LAN для Linux/macOS
- `scripts/wol.ps1` - Wake-on-LAN для Windows

### 2. **Network Diagnostics**
- `scripts/network-check.sh` - Проверка сети Linux/macOS
- `scripts/network-check.ps1` - Проверка сети Windows

### 3. **Network Configuration**
- `config/network.yaml` - Централизованная конфигурация сети

### 4. **Auto-WOL Integration**
- `quick-deploy.sh` - Автоматически будит сервер перед развертыванием
- `quick-deploy.ps1` - То же для Windows

---

## 🔧 Настройка

### Шаг 1: Найти MAC адрес Proxmox сервера

**На Windows (с вашего компьютера):**
```powershell
# Посмотреть ARP таблицу
arp -a | findstr "192.168.1.3"
```

**На Proxmox сервере (если доступен по SSH):**
```bash
# Показать все сетевые интерфейсы
ip link show

# Или более детально
ip addr show
```

**Из Proxmox Web UI:**
1. Откройте https://192.168.1.3:8006
2. System → Network
3. Найдите интерфейс (обычно vmbr0 или eth0)
4. MAC address будет указан

### Шаг 2: Обновить config/network.yaml

```yaml
network:
  proxmox:
    mac: "AA:BB:CC:DD:EE:FF"  # ← Замените на реальный MAC
```

### Шаг 3: Включить Wake-on-LAN на Proxmox

**В BIOS/UEFI:**
1. Перезагрузить сервер → Войти в BIOS (обычно Delete или F2)
2. Advanced → APM Configuration
3. Power On By PCI-E/PCI → **Enabled**
4. Wake On LAN → **Enabled**
5. Save & Exit

**В Linux (Proxmox):**
```bash
# Проверить поддержку WOL
ethtool eth0 | grep Wake-on

# Включить WOL (g = magic packet)
ethtool -s eth0 wol g

# Сделать постоянным (добавить в /etc/network/interfaces)
echo "post-up ethtool -s eth0 wol g" >> /etc/network/interfaces
```

---

## 🚀 Использование

### Базовое использование

**Разбудить Proxmox сервер:**
```bash
# Linux/macOS
./scripts/wol.sh

# Windows
.\scripts\wol.ps1
```

**Проверить сеть:**
```bash
# Linux/macOS
./scripts/network-check.sh

# Windows
.\scripts\network-check.ps1
```

**Quick Deploy с автоматическим WOL:**
```bash
# Автоматически разбудит сервер и развернет CERES
./quick-deploy.sh
```

### Продвинутое использование

**Разбудить конкретную VM:**
```bash
./scripts/wol.sh config/network.yaml core
./scripts/wol.sh config/network.yaml apps
./scripts/wol.sh config/network.yaml edge
```

**Проверить статус всех хостов:**
```bash
./scripts/network-check.sh
```

---

## 🔍 Диагностика

### Проблема: WOL не работает

**Проверка 1: Сервер включен?**
```bash
ping 192.168.1.3
```

**Проверка 2: MAC адрес правильный?**
```bash
# На Windows
arp -a | findstr "192.168.1.3"

# Должен показать MAC адрес
```

**Проверка 3: WOL включен в BIOS?**
- Перезагрузить → войти в BIOS → проверить Wake On LAN

**Проверка 4: Сетевая карта поддерживает WOL?**
```bash
# На Proxmox (если доступен)
ethtool eth0 | grep Wake-on
# Должно быть: Supports Wake-on: g
```

### Проблема: Сервер не отвечает после WOL

**Возможные причины:**
1. **Долгая загрузка** - подождите 60-90 секунд
2. **SSH не запущен** - проверьте `systemctl status sshd`
3. **Firewall блокирует** - проверьте `iptables -L`

### Проблема: "wakeonlan command not found"

**Ubuntu/Debian:**
```bash
sudo apt-get install wakeonlan
```

**CentOS/RHEL:**
```bash
sudo yum install wakeonlan
```

**macOS:**
```bash
brew install wakeonlan
```

---

## 📊 Network Configuration Reference

### config/network.yaml структура

```yaml
network:
  # Proxmox хост
  proxmox:
    hostname: "pve"
    ip: "192.168.1.3"
    mac: "AA:BB:CC:DD:EE:FF"        # ← ВАЖНО: реальный MAC
    subnet: "192.168.1.0/24"
    gateway: "192.168.1.1"
    
    wol:
      enabled: true                  # Включить авто-WOL
      port: 9                        # UDP порт (обычно 9)
      broadcast: "192.168.1.255"     # Broadcast адрес
      wait_timeout: 60               # Сколько ждать загрузки (сек)
  
  # Виртуальные машины
  vms:
    core:
      ip: "192.168.1.10"
      mac: "BB:CC:DD:EE:FF:00"      # MAC VM
      hostname: "ceres-core"
    
    apps:
      ip: "192.168.1.11"
      mac: "CC:DD:EE:FF:00:11"
      hostname: "ceres-apps"
    
    edge:
      ip: "192.168.1.12"
      mac: "DD:EE:FF:00:11:22"
      hostname: "ceres-edge"
  
  # Настройки проверок
  checks:
    ping_timeout: 5                  # Timeout для ping
    ssh_timeout: 10                  # Timeout для SSH
    max_retries: 3                   # Количество попыток
    retry_delay: 5                   # Задержка между попытками
```

---

## 🎯 Workflow с WOL

### Автоматический (Recommended)

```bash
# Просто запустить quick-deploy
./quick-deploy.sh

# Внутри:
# 1. Проверяет config/network.yaml
# 2. Если WOL enabled → будит Proxmox
# 3. Ждет 60 секунд загрузки
# 4. Собирает CERES CLI
# 5. Деплоит инфраструктуру
```

### Ручной (для контроля)

```bash
# Шаг 1: Разбудить сервер
./scripts/wol.sh
# Вывод: Waiting for proxmox to boot... ✅ proxmox is online! (23s)

# Шаг 2: Проверить сеть
./scripts/network-check.sh
# Вывод: ✅ All systems operational!

# Шаг 3: Развернуть CERES
./bin/ceres deploy --cloud aws --environment prod
```

---

## 🔐 Security Notes

### WOL Security

**Безопасность Wake-on-LAN:**
- WOL пакеты **не шифруются**
- Любой в локальной сети может отправить WOL пакет
- **Рекомендация**: Используйте только в доверенной сети

**Улучшение безопасности:**
1. **SecureOn** - требует пароль для WOL (не все карты поддерживают)
2. **VLAN** - изолировать управляющую сеть
3. **Firewall** - ограничить доступ к WOL порту (UDP 9)

---

## 📝 Example: First Time Setup

```bash
# 1. Настроить network.yaml
nano config/network.yaml
# Изменить MAC адреса на реальные

# 2. Проверить что WOL работает
./scripts/wol.sh

# Вывод:
# 🌐 CERES Wake-on-LAN
# ═══════════════════════════════════════════════════════
# 📡 Target: proxmox
#    MAC: AA:BB:CC:DD:EE:FF
#    IP:  192.168.1.3
# 
# 🔍 Checking if proxmox is already online...
# 📡 Sending Wake-on-LAN magic packet...
# ⏳ Waiting for proxmox to boot (timeout: 60s)...
# ........
# ✅ proxmox is online! (18s)
# ⏳ Waiting 10s for services to initialize...
# 🎉 Ready for deployment!

# 3. Проверить сеть
./scripts/network-check.sh

# Вывод:
# 🔍 CERES Network Diagnostics
# ═══════════════════════════════════════════════════════
# 📍 Proxmox Server Configuration:
#    IP:  192.168.1.3
#    MAC: AA:BB:CC:DD:EE:FF
# 
# 1️⃣  Testing network connectivity (ping)...
#    ✅ Ping successful
# 
# 2️⃣  Testing SSH (port 22)...
#    ✅ SSH port is open
# 
# 3️⃣  Testing Proxmox API (port 8006)...
#    ✅ Proxmox API port is open
# 
# ✅ All systems operational!
#    Ready for deployment.

# 4. Развернуть CERES
./quick-deploy.sh
```

---

## ✅ Checklist

### Pre-deployment Checklist

- [ ] MAC адрес Proxmox добавлен в `config/network.yaml`
- [ ] Wake-on-LAN включен в BIOS сервера
- [ ] Wake-on-LAN включен на сетевой карте (`ethtool -s eth0 wol g`)
- [ ] Сервер подключен к сети Ethernet (не WiFi)
- [ ] Тест WOL выполнен успешно (`./scripts/wol.sh`)
- [ ] Network check показывает всё OK (`./scripts/network-check.sh`)
- [ ] SSH доступен (порт 22 открыт)
- [ ] Proxmox API доступен (порт 8006 открыт)

---

**Автор**: CERES Platform Team  
**Дата**: January 20, 2026  
**Версия**: 3.0.0
