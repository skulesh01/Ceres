# 🚀 Production Deployment Guide - CERES Platform

Полное руководство по развертыванию CERES на production сервере.

## 📋 Что нужно для запуска

### Вариант 1: Proxmox + Terraform (Рекомендуется)

#### Железо:
- **Proxmox VE сервер:**
  - CPU: 12+ cores (рекомендуется 16)
  - RAM: 32GB+ (рекомендуется 48GB)
  - Disk: 500GB SSD (рекомендуется NVMe)
  - Network: 1Gbps+

#### Софт:
- Proxmox VE 8.x
- Terraform 1.6+ (на машине администратора)
- Ansible 2.14+ (на машине администратора)
- SSH ключи

#### Сеть:
- 3 статических IP адреса (для VM)
- Доменное имя (например, ceres.example.com)
- DNS доступ (для настройки A-записей)
- Открытые порты: 80, 443, 22, 51820 (VPN)

---

### Вариант 2: Docker Compose (Один сервер)

#### Железо:
- **Физический/VPS сервер:**
  - CPU: 8+ cores
  - RAM: 16GB+ (рекомендуется 24GB)
  - Disk: 200GB SSD
  - Network: 1Gbps+

#### Софт:
- Ubuntu 22.04 LTS / Debian 12
- Docker 24.x+
- Docker Compose 2.x+
- Git

#### Сеть:
- 1 публичный IP
- Доменное имя
- DNS доступ
- Открытые порты: 80, 443, 22, 51820

---

## 🎯 Pre-Deployment Checklist

### ✅ Подготовка (за 1 день до деплоя)

- [ ] **Сервер подготовлен:**
  - [ ] Установлена Ubuntu 22.04 LTS
  - [ ] Настроен SSH доступ
  - [ ] Создан sudo пользователь
  - [ ] Обновлены пакеты: `apt update && apt upgrade`
  - [ ] Настроен firewall (UFW/iptables)

- [ ] **DNS настроен:**
  - [ ] Куплен домен (например, ceres.example.com)
  - [ ] Настроены A-записи:
    - `*.ceres.example.com -> <SERVER_IP>`
    - `ceres.example.com -> <SERVER_IP>`

- [ ] **SSL сертификаты:**
  - [ ] Email для Let's Encrypt готов
  - [ ] ИЛИ wildcard сертификат получен

- [ ] **Секреты подготовлены:**
  - [ ] Сгенерированы SSH ключи
  - [ ] Записаны пароли для:
    - PostgreSQL root
    - Keycloak admin
    - GitLab root
    - Grafana admin
    - Email SMTP

- [ ] **Backup план:**
  - [ ] Настроен S3/MinIO для бэкапов
  - [ ] Тестовый бэкап выполнен
  - [ ] Документ recovery план создан

---

## 🚀 Deployment: Вариант 1 - Proxmox + Terraform

### Step 1: Подготовка Proxmox (30 минут)

```bash
# На Proxmox сервере

# 1. Скачайте Ubuntu Cloud Image
cd /var/lib/vz/template/iso
wget https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img

# 2. Создайте VM template
qm create 9000 --name ubuntu-2204-cloudinit --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 ubuntu-22.04-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# 3. Конвертируйте в template
qm template 9000

# 4. Создайте API Token
pveum user add terraform@pam
pveum passwd terraform@pam
pveum aclmod / -user terraform@pam -role PVEAdmin
pveum user token add terraform@pam ceres --privsep=0

# Сохраните Token ID и Secret!
```

### Step 2: Настройка Terraform (10 минут)

```bash
# На вашей машине

# 1. Клонируйте репозиторий
git clone https://github.com/skulesh01/Ceres.git
cd Ceres/terraform

# 2. Скопируйте и отредактируйте переменные
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# Заполните:
# - proxmox_api_url = "https://YOUR_PROXMOX:8006/api2/json"
# - proxmox_api_token_id = "terraform@pam!ceres"
# - proxmox_api_token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# - ssh_public_key = "ssh-rsa AAAAB3... your@email.com"
# - domain = "ceres.example.com"
# - Проверьте IP адреса VM

# 3. Инициализируйте Terraform
terraform init

# 4. Проверьте план
terraform plan

# Должно показать: Plan: 6 to add, 0 to change, 0 to destroy
```

### Step 3: Создание VM (5-10 минут)

```bash
# Запустите Terraform
terraform apply

# Проверьте вывод:
# - IP адреса всех 3 VM
# - SSH команды
# - DNS записи

# Проверьте доступность VM
terraform output ssh_commands

# Подключитесь к Core VM
ssh ceres@192.168.1.10
```

### Step 4: Ansible Deployment (15-20 минут)

```bash
# 1. Проверьте inventory
cd ../ansible
cat inventory/production.yml

# 2. Проверьте подключение
ansible all -i inventory/production.yml -m ping

# 3. Запустите deployment
ansible-playbook -i inventory/production.yml playbooks/deploy-ceres.yml

# Ansible выполнит:
# - Установку Docker + Docker Compose
# - Настройку firewall (UFW)
# - Деплой Core services (PostgreSQL, Redis, Keycloak)
# - Деплой Apps (GitLab, Zulip, Nextcloud, Mayan)
# - Деплой Edge (Caddy, Prometheus, Grafana)
# - Bootstrap Keycloak (SSO)
# - Настройку webhooks
# - Настройку автоматических бэкапов
```

### Step 5: Post-Deployment Verification (10 минут)

```bash
# 1. Проверьте статус сервисов
ssh ceres@192.168.1.10
docker ps

# Должны быть running:
# - postgres
# - redis
# - keycloak

ssh ceres@192.168.1.11
docker ps

# Должны быть running:
# - gitlab
# - zulip
# - nextcloud
# - mayan

ssh ceres@192.168.1.12
docker ps

# Должны быть running:
# - caddy
# - prometheus
# - grafana
# - portainer

# 2. Запустите health check
ssh ceres@192.168.1.12
cd /opt/ceres
./scripts/health-check.ps1

# 3. Откройте в браузере:
# - https://auth.ceres.example.com (Keycloak)
# - https://gitlab.ceres.example.com (GitLab CE)
# - https://grafana.ceres.example.com (Grafana)

# 4. Проверьте SSO
# Войдите через Keycloak в Grafana
```

**Итого время:** ~60-90 минут

---

## 🚀 Deployment: Вариант 2 - Docker Compose

### Step 1: Подготовка сервера (15 минут)

```bash
# SSH на сервер
ssh root@your-server.com

# 1. Обновите систему
apt update && apt upgrade -y

# 2. Установите Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 3. Установите Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 4. Установите Git
apt install -y git vim curl wget htop

# 5. Создайте пользователя
adduser ceres
usermod -aG sudo,docker ceres

# 6. Настройте SSH ключ
mkdir -p /home/ceres/.ssh
echo "ssh-rsa AAAAB3... your@email.com" >> /home/ceres/.ssh/authorized_keys
chown -R ceres:ceres /home/ceres/.ssh
chmod 700 /home/ceres/.ssh
chmod 600 /home/ceres/.ssh/authorized_keys

# 7. Настройте firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 51820/udp
ufw --force enable
```

### Step 2: Клонирование проекта (5 минут)

```bash
# Войдите как ceres
su - ceres

# Клонируйте репозиторий
git clone https://github.com/skulesh01/Ceres.git
cd Ceres

# Создайте .env
cp config/.env.example config/.env
vim config/.env

# Заполните критичные переменные:
# DOMAIN=ceres.example.com
# POSTGRES_PASSWORD=<сильный пароль>
# KEYCLOAK_ADMIN_PASSWORD=<сильный пароль>
# GITLAB_ROOT_PASSWORD=<сильный пароль>
# GRAFANA_ADMIN_PASSWORD=<сильный пароль>
# SMTP_HOST=smtp.example.com
# SMTP_USER=noreply@example.com
# SMTP_PASSWORD=<SMTP пароль>
# S3_BACKUP_BUCKET=s3://ceres-backups
```

### Step 3: Deployment (10 минут)

```bash
# Запустите автодеплой
powershell -File scripts/auto-migrate-all.ps1

# ИЛИ вручную по шагам:

# 1. Core services
docker network create ceres_net
docker-compose -f config/compose/base.yml up -d
docker-compose -f config/compose/core.yml up -d

# Дождитесь готовности (2-3 минуты)
docker-compose -f config/compose/core.yml logs -f

# 2. Application services
docker-compose -f config/compose/gitlab.yml up -d
docker-compose -f config/compose/zulip.yml up -d
docker-compose -f config/compose/apps.yml up -d
docker-compose -f config/compose/office-suite.yml up -d
docker-compose -f config/compose/mayan-edms.yml up -d

# Дождитесь инициализации (5-10 минут)

# 3. Monitoring & Edge
docker-compose -f config/compose/monitoring.yml up -d
docker-compose -f config/compose/monitoring-exporters.yml up -d
docker-compose -f config/compose/ops.yml up -d
docker-compose -f config/compose/edge.yml up -d

# 4. Optional: VPN
docker-compose -f config/compose/vpn.yml up -d
```

### Step 4: Post-Deployment Setup (15 минут)

```bash
# 1. Bootstrap Keycloak (создание OIDC клиентов)
./scripts/keycloak-bootstrap-full.ps1

# 2. Настройка webhooks
./scripts/setup-webhooks.ps1

# 3. Настройка автоматических бэкапов
crontab -e

# Добавьте:
0 2 * * * cd /home/ceres/Ceres && ./scripts/backup-full.ps1 >> /var/log/ceres-backup.log 2>&1

# 4. Health check
./scripts/health-check.ps1

# 5. E2E тесты
python3 scripts/test-integration.py
```

### Step 5: Verification (10 минут)

```bash
# 1. Проверьте все контейнеры
docker ps

# Должно быть ~20-25 контейнеров в статусе "Up"

# 2. Откройте в браузере:
curl -k https://auth.ceres.example.com
curl -k https://gitlab.ceres.example.com
curl -k https://grafana.ceres.example.com

# 3. Проверьте логи
docker-compose -f config/compose/core.yml logs --tail=100

# 4. Проверьте ресурсы
docker stats --no-stream

# 5. Импортируйте Grafana dashboards
# Grafana UI → Dashboards → Import → Upload JSON
# - config/grafana/dashboards/ceres-devops-dashboard.json
# - config/grafana/dashboards/ceres-infrastructure-dashboard.json
```

**Итого время:** ~45-60 минут

---

## 🔐 Security Hardening (Production)

```bash
# 1. Настройте fail2ban
apt install fail2ban
systemctl enable fail2ban
systemctl start fail2ban

# 2. Настройте автообновления
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# 3. Закройте ненужные порты
ufw status
ufw delete allow <port>

# 4. Настройте Let's Encrypt (автоматические SSL)
# В config/caddy/Caddyfile.full раскомментируйте:
# email admin@ceres.example.com

# 5. Ротация секретов
./scripts/rotate-secrets.ps1  # Создайте этот скрипт

# 6. Настройте VPN для админских UI
docker-compose -f config/compose/vpn.yml up -d

# Prometheus/Portainer доступны только через VPN
```

---

## 📊 Monitoring & Alerts

```bash
# 1. Проверьте Prometheus targets
curl http://localhost:9090/targets

# Все targets должны быть "UP"

# 2. Проверьте Grafana dashboards
# https://grafana.ceres.example.com
# - CERES DevOps Dashboard (12 панелей)
# - CERES Infrastructure Dashboard (8 панелей)

# 3. Настройте алерты
# Проверьте config/alertmanager/alertmanager.yml
# Убедитесь что SMTP настроен

# 4. Тестовый алерт
docker exec alertmanager amtool alert add test severity=warning

# Должны прийти уведомления:
# - Email (ops@ceres.example.com)
# - Zulip (#monitoring)
```

---

## 🔄 Maintenance Tasks

### Ежедневно:
- [ ] Проверка health check: `./scripts/health-check.ps1`
- [ ] Проверка бэкапов: `ls -lh /backup/ceres/`
- [ ] Проверка логов: `docker-compose logs --tail=100`

### Еженедельно:
- [ ] Обновление образов: `docker-compose pull && docker-compose up -d`
- [ ] Проверка дискового пространства: `df -h`
- [ ] Проверка алертов: Grafana UI

### Ежемесячно:
- [ ] Тестовое восстановление из бэкапа
- [ ] Обновление SSL сертификатов (если ручные)
- [ ] Review логов безопасности
- [ ] Обновление документации

---

## 🐛 Troubleshooting

### Проблема: Сервис не стартует

```bash
# 1. Проверьте логи
docker-compose -f config/compose/<module>.yml logs

# 2. Проверьте ресурсы
docker stats

# 3. Проверьте зависимости
docker-compose -f config/compose/core.yml ps

# PostgreSQL и Redis должны быть Up

# 4. Пересоздайте контейнер
docker-compose -f config/compose/<module>.yml down
docker-compose -f config/compose/<module>.yml up -d
```

### Проблема: Не работает SSO

```bash
# 1. Проверьте Keycloak
curl http://keycloak:8080/health

# 2. Проверьте OIDC клиенты
docker exec keycloak /opt/keycloak/bin/kcadm.sh get clients -r ceres

# 3. Пересоздайте клиенты
./scripts/keycloak-bootstrap-full.ps1
```

### Проблема: Нет доступа к UI

```bash
# 1. Проверьте DNS
nslookup gitlab.ceres.example.com

# 2. Проверьте Caddy
docker logs caddy

# 3. Проверьте firewall
ufw status
telnet <IP> 443

# 4. Проверьте SSL
curl -vk https://gitlab.ceres.example.com
```

### Проблема: Медленная работа

```bash
# 1. Проверьте ресурсы
docker stats
htop

# 2. Проверьте диск
iotop
df -h

# 3. Проверьте сеть
iftop
netstat -tulpn

# 4. Оптимизируйте PostgreSQL
# См. config/postgresql/postgresql.conf
# Увеличьте shared_buffers, work_mem
```

---

## 📚 Что дальше?

### После успешного деплоя:

1. **Создайте первого пользователя:**
   - Keycloak: https://auth.ceres.example.com
   - Создайте realm "ceres" (если не создан)
   - Добавьте пользователя

2. **Настройте проекты:**
   - GitLab: Создайте первый проект
   - Zulip: Создайте streams (#general, #deployments, #monitoring)

3. **Настройте CI/CD:**
   - Скопируйте `.gitlab-ci.yml` из `config/gitlab/gitlab-ci-examples/`
   - Настройте Portainer API token
   - Настройте Zulip bot

4. **Настройте мониторинг:**
   - Импортируйте Grafana dashboards
   - Настройте алерты (Email + Zulip)
   - Настройте uptime checks (Uptime Kuma)

5. **Обучите команду:**
   - Документация: README.md, ARCHITECTURE.md
   - Chat-driven development: `/issue`, `/deploy` команды в Zulip
   - CI/CD workflows: автодеплой через GitLab

---

## ✅ Production Ready Checklist

- [ ] Все сервисы запущены и healthy
- [ ] SSL сертификаты настроены (Let's Encrypt)
- [ ] DNS A-записи настроены (*.domain -> IP)
- [ ] Firewall настроен (только 80, 443, 22, 51820)
- [ ] VPN настроен (WireGuard для админов)
- [ ] Бэкапы автоматические (daily 2am)
- [ ] Мониторинг настроен (Prometheus + Grafana)
- [ ] Алерты настроены (Email + Zulip)
- [ ] SSO работает (Keycloak для всех сервисов)
- [ ] CI/CD настроен (GitLab + Portainer)
- [ ] Документация обновлена
- [ ] Команда обучена

**Время до полной готовности:** 2-3 часа (включая тестирование)

---

## 💰 Стоимость инфраструктуры

### Вариант 1: Self-hosted (У вас уже есть сервер) ✅
- Сервер: **$0** (уже есть)
- Электричество: ~$20-30/мес (зависит от тарифа)
- Интернет: **$0** (уже оплачен)
- S3 бэкапы (опционально): ~$5-10/мес
- **Итого:** ~$20-40/мес (только электричество)
- **ROI:** Окупаемость мгновенная, т.к. оборудование уже есть

### Вариант 2: VPS (Если нет своего сервера)
- VPS (16GB RAM, 8 vCPU, 200GB): ~$40-60/мес
- S3 бэкапы (500GB): ~$10/мес
- **Итого:** $50-70/мес

### Вариант 3: Cloud (Для сравнения)
- EC2 t3.xlarge (4 vCPU, 16GB): ~$120/мес
- EBS Storage (200GB): ~$20/мес
- S3 бэкапы: ~$10/мес
- **Итого:** $150/мес

**Ваш случай:** У вас физический сервер → **почти бесплатно** (только электричество ~$20-30/мес)

**Экономия vs VPS:** ~$30-50/мес = ~$360-600/год
**Экономия vs Cloud:** ~$120-140/мес = ~$1440-1680/год

---

## 🎉 Готово!

Ваша CERES платформа развернута и готова к работе!

**Основные URL:**
- https://auth.ceres.example.com - Keycloak (SSO)
- https://gitlab.ceres.example.com - GitLab CE (Git + CI/CD)
- https://zulip.ceres.example.com - Zulip (Chat)
- https://nextcloud.ceres.example.com - Nextcloud (Files)
- https://grafana.ceres.example.com - Grafana (Monitoring)
- https://mayan.ceres.example.com - Mayan EDMS (Documents)

**Поддержка:**
- GitHub Issues: https://github.com/skulesh01/Ceres/issues
- Документация: README.md, ARCHITECTURE.md
- Copilot Instructions: .github/copilot-instructions.md
