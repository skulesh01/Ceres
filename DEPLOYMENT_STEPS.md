# 🚀 Пошаговое руководство по развертыванию CERES

Этот документ поможет вам развернуть Ceres на сервере.

## 📋 Предварительная проверка

### 1. Определите тип развертывания

**Вариант A: Локальное развертывание (Docker Compose)**
- Для разработки/тестирования
- Требования: Windows/Linux с Docker Desktop
- Время: 10-15 минут

**Вариант B: Развертывание на удаленном Linux сервере**
- Для production
- Требования: Ubuntu 22.04/Debian 12 с SSH доступом
- Время: 20-30 минут

**Вариант C: Развертывание на Proxmox через Terraform**
- Для production с автоматизацией
- Требования: Proxmox VE сервер
- Время: 30-45 минут

---

## 🔧 ШАГ 1: Подготовка окружения

### Для локального развертывания (Windows)

```powershell
# Проверка Docker
docker --version
docker-compose --version

# Если Docker не установлен, установите Docker Desktop:
# https://www.docker.com/products/docker-desktop
```

### Для развертывания на удаленном сервере

Убедитесь что у вас есть:
- ✅ SSH доступ к серверу
- ✅ IP адрес сервера
- ✅ Пользователь с sudo правами

---

## 📝 ШАГ 2: Настройка конфигурации

### Создание .env файла

```bash
# Скопируйте шаблон
cp config/.env.example config/.env

# Отредактируйте основные переменные:
# DOMAIN=your-domain.com (или ceres.local для локального)
# POSTGRES_PASSWORD=<сгенерируйте пароль>
# KEYCLOAK_ADMIN_PASSWORD=<сгенерируйте пароль>
# GRAFANA_ADMIN_PASSWORD=<сгенерируйте пароль>
```

---

## 🚀 ШАГ 3: Развертывание

### Вариант A: Локальное развертывание (Docker Compose)

```powershell
# Перейдите в папку со скриптами
cd scripts

# Запуск Core сервисов (PostgreSQL, Redis, Keycloak)
.\start.ps1 core

# Дождитесь готовности (2-3 минуты), затем запустите приложения
.\start.ps1 apps

# Запуск мониторинга (опционально)
.\start.ps1 monitoring

# Проверка статуса
.\status.ps1
```

### Вариант B: Развертывание на удаленном сервере

**Способ 1: Автоматический (рекомендуется)**

```powershell
# Используйте скрипт remote-deploy.ps1
cd scripts
.\remote-deploy.ps1 `
    -ServerHost 192.168.1.100 `
    -Username root `
    -Domain ceres.example.com `
    -FullDeploy
```

**Способ 2: Ручное развертывание на сервере**

```bash
# 1. Подключитесь к серверу
ssh user@server-ip

# 2. Установите Docker (если не установлен)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 3. Установите Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Клонируйте проект (или скопируйте файлы)
git clone https://github.com/skulesh01/Ceres.git
cd Ceres

# 5. Создайте .env файл
cp config/.env.example config/.env
nano config/.env  # Заполните переменные

# 6. Запустите развертывание
docker network create ceres_net
docker-compose -f config/compose/base.yml up -d
docker-compose -f config/compose/core.yml up -d

# Подождите 2-3 минуты для инициализации, затем:
docker-compose -f config/compose/apps.yml up -d
docker-compose -f config/compose/monitoring.yml up -d
docker-compose -f config/compose/edge.yml up -d

# 7. Проверьте статус
docker ps
```

### Вариант C: Развертывание на Proxmox (Terraform + Ansible)

```bash
# 1. Настройте Terraform переменные
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Заполните Proxmox credentials

# 2. Инициализируйте и примените Terraform
terraform init
terraform plan
terraform apply

# 3. Запустите Ansible playbook
cd ../ansible
ansible-playbook -i inventory/production.yml playbooks/deploy-ceres.yml
```

---

## ✅ ШАГ 4: Проверка развертывания

### Проверка статуса сервисов

```powershell
# Windows (локально)
.\scripts\status.ps1

# Linux/SSH
docker ps
docker-compose -f config/compose/core.yml ps
```

### Проверка доступности

Откройте в браузере:
- Keycloak: `http://auth.your-domain` или `http://localhost:8081`
- Nextcloud: `http://nextcloud.your-domain` или `http://localhost:8080`
- GitLab: `http://gitlab.your-domain` или `http://localhost:8082`
- Grafana: `http://grafana.your-domain` или `http://localhost:3000`

---

## 🔐 ШАГ 5: Первоначальная настройка

### Настройка Keycloak SSO

```powershell
# Запустите bootstrap скрипт
.\scripts\keycloak-bootstrap-full.ps1
```

Этот скрипт автоматически:
- Создаст OIDC клиенты для всех сервисов
- Настроит SSO интеграцию
- Применит настройки

### Настройка SMTP (опционально)

```powershell
.\scripts\keycloak-smtp.ps1
```

---

## 📊 ШАГ 6: Мониторинг и обслуживание

### Просмотр логов

```powershell
# Все сервисы
docker-compose logs -f

# Конкретный сервис
docker-compose logs -f postgres
docker-compose logs -f keycloak
```

### Backup

```powershell
.\scripts\backup.ps1
```

### Restore

```powershell
.\scripts\restore.ps1 <backup-timestamp>
```

---

## 🆘 Решение проблем

### Порты заняты

```powershell
# Проверьте какие порты заняты (Windows)
netstat -ano | findstr :80
netstat -ano | findstr :443

# Освободите порт или измените в config/.env
```

### Docker не запускается

```powershell
# Проверьте статус Docker Desktop (Windows)
Get-Service -Name com.docker.service

# Перезапустите Docker
Restart-Service -Name com.docker.service
```

### Проблемы с подключением к серверу

```powershell
# Проверьте SSH соединение
ssh -v user@server-ip

# Проверьте firewall на сервере
ssh user@server-ip "sudo ufw status"
```

---

## 📚 Дополнительная информация

- [Полное руководство по развертыванию](PRODUCTION_DEPLOYMENT_GUIDE.md)
- [Архитектура системы](ARCHITECTURE.md)
- [Быстрый старт](docs/00-QUICKSTART.md)

---

**Следующие шаги:**
1. Выберите вариант развертывания
2. Выполните подготовку окружения
3. Настройте .env файл
4. Запустите развертывание
5. Проверьте доступность сервисов
