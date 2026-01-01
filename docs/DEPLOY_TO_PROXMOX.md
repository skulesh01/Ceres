# Развертывание CERES на Proxmox сервере

## Варианты развертывания:

### 🎯 Вариант 1: Docker на самом Proxmox (РЕКОМЕНДУЕТСЯ)
**Плюсы:** Быстро, минимум накладных расходов, прямой доступ к ресурсам  
**Минусы:** Proxmox + Docker на одном хосте (меньше изоляции)

### 🎯 Вариант 2: LXC контейнер с Docker
**Плюсы:** Легковесный, быстрый, изолированный  
**Минусы:** Требует настройки nested containers

### 🎯 Вариант 3: Полноценная VM с Ubuntu/Debian
**Плюсы:** Полная изоляция, как отдельный сервер  
**Минусы:** Больше ресурсов (RAM/CPU)

---

## 🚀 Быстрый запуск - Вариант 1 (Docker на Proxmox)

### Шаг 1: Подключитесь к Proxmox
```bash
# Из Windows (если есть SSH):
ssh root@192.168.1.3

# Или через Proxmox Web UI: https://192.168.1.3:8006
# Node → Shell
```

### Шаг 2: Установите Docker на Proxmox

Скопируйте и запустите этот скрипт на Proxmox:

```bash
bash << 'DOCKEREOF'
#!/bin/bash
set -e

echo "=========================================="
echo "Installing Docker on Proxmox"
echo "=========================================="

# Update packages
apt-get update -qq

# Install dependencies
apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start Docker
systemctl enable docker
systemctl start docker

# Verify
docker --version
docker compose version

echo ""
echo "✅ Docker installed successfully!"
echo ""

DOCKEREOF
```

### Шаг 3: Перенесите проект CERES на Proxmox

#### Вариант A: Через Git (если проект в репозитории)
```bash
# На Proxmox
cd /opt
git clone https://github.com/your-repo/Ceres.git
cd Ceres
```

#### Вариант B: Через SCP с Windows
```powershell
# На Windows (если SSH установлен)
cd "e:\Новая папка"
scp -r Ceres root@192.168.1.3:/opt/
```

#### Вариант C: Через ZIP архив
```powershell
# На Windows
cd "e:\Новая папка"
Compress-Archive -Path Ceres -DestinationPath Ceres.zip

# Загрузите Ceres.zip через Proxmox Web UI:
# Node → local → Upload
# Или через SCP:
scp Ceres.zip root@192.168.1.3:/tmp/
```

Затем на Proxmox:
```bash
cd /opt
unzip /tmp/Ceres.zip
cd Ceres
```

### Шаг 4: Настройте окружение

```bash
cd /opt/Ceres/config

# Скопируйте шаблон .env
cp .env.example .env

# Отредактируйте .env
nano .env
```

Минимальные настройки в `.env`:
```bash
DOMAIN=ceres.local
POSTGRES_PASSWORD=your_secure_password_here
KEYCLOAK_ADMIN_PASSWORD=your_admin_password_here
```

### Шаг 5: Запустите CERES

```bash
cd /opt/Ceres/scripts

# Конвертируйте Windows скрипт в Linux
dos2unix start.sh 2>/dev/null || sed -i 's/\r$//' start.sh
chmod +x start.sh

# Запустите базовые сервисы
./start.sh core apps
```

Или напрямую через Docker Compose:
```bash
cd /opt/Ceres/config
docker compose -f compose/base.yml -f compose/core.yml -f compose/apps.yml up -d
```

### Шаг 6: Проверьте статус

```bash
docker ps
docker compose -f compose/base.yml -f compose/core.yml -f compose/apps.yml ps
```

### Шаг 7: Доступ к сервисам

Если запустили `edge` модуль (Caddy):
- Keycloak: https://auth.ceres.local
- Nextcloud: https://nextcloud.ceres.local
- Grafana: https://grafana.ceres.local

**Или через IP и локальные порты:**
- Keycloak: http://192.168.1.3:8081
- Nextcloud: http://192.168.1.3:8082
- Grafana: http://192.168.1.3:3001

---

## 🔧 Автоматический скрипт переноса

Я создам PowerShell скрипт, который:
1. Подключится к Proxmox
2. Установит Docker
3. Загрузит проект
4. Настроит окружение
5. Запустит сервисы

Хотите такой скрипт?

---

## 📦 Вариант 2: LXC контейнер (альтернатива)

```bash
# На Proxmox создайте LXC контейнер
pct create 100 local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst \
  --hostname ceres \
  --memory 8192 \
  --cores 4 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.10/24,gw=192.168.1.1 \
  --storage local-lvm \
  --features nesting=1

# Запустите контейнер
pct start 100

# Войдите в контейнер
pct enter 100

# Установите Docker (см. шаг 2 выше)
# Перенесите проект (см. шаг 3 выше)
```

---

## 🖥️ Вариант 3: Ubuntu VM (альтернатива)

```bash
# Создайте VM через Proxmox Web UI:
# Create VM → Ubuntu Server 22.04
# RAM: 8GB, CPU: 4 cores, Disk: 100GB

# После установки Ubuntu:
ssh root@<VM_IP>

# Установите Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Перенесите проект и запустите (шаги 3-5)
```

---

## ❓ Какой вариант выбрать?

**Для домашнего сервера:** Вариант 1 (Docker на Proxmox)  
**Для продакшена:** Вариант 2 или 3 (изоляция)  
**Если мало RAM:** Вариант 2 (LXC)

Какой вариант вам больше подходит?
