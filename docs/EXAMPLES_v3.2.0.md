# 🎯 CERES v3.2.0 - Quick Examples

**3 новых мощных фичи для production deployment**

---

## 📋 Table of Contents

1. [DNS Auto-Configuration](#1-dns-auto-configuration)
2. [Slack Integration](#2-slack-integration)
3. [Custom Branding](#3-custom-branding)
4. [Complete Workflows](#4-complete-workflows)

---

## 1. DNS Auto-Configuration

### Сценарий: У вас есть домен на Cloudflare

```bash
# Запустить скрипт
./scripts/configure-dns.sh

# Выбор:
# Choice [1-5]: 1  (Cloudflare)

# Ввести данные:
# Domain: mycompany.com
# Cloudflare API Token: abc123xyz...
# Cloudflare Zone ID: def456uvw...

# ✅ Результат через 2 минуты:
# https://keycloak.mycompany.com - работает с SSL
# https://gitlab.mycompany.com   - работает с SSL
# https://grafana.mycompany.com  - работает с SSL
# И все остальные сервисы!
```

**Как получить Cloudflare данные:**
1. Cloudflare Dashboard → My Profile → API Tokens
2. Create Token → Edit zone DNS (template)
3. Zone ID: Cloudflare Dashboard → выбрать домен → справа внизу

### Сценарий: У вас AWS Route53

```bash
./scripts/configure-dns.sh

# Choice: 2 (AWS Route53)
# AWS Access Key: AKIAIOSFODNN7EXAMPLE
# AWS Secret Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# AWS Region: us-east-1

# ✅ Автоматически создаст все DNS записи в Route53
```

### Сценарий: Провайдер не поддерживается

```bash
./scripts/configure-dns.sh

# Choice: 5 (Manual)

# Скрипт покажет что добавить:
# A Records:
#   keycloak.domain.com  →  192.168.1.3
#   gitlab.domain.com    →  192.168.1.3
#   ...
# 
# Wildcard:
#   *.domain.com         →  192.168.1.3

# После ручного добавления нажать Enter
# ✅ Скрипт настроит HTTPS
```

---

## 2. Slack Integration

### Сценарий: Базовая настройка с одним каналом

```bash
# 1. Создать Slack Webhook:
# https://api.slack.com/apps
# Create New App → From scratch
# App Name: "CERES Monitor"
# Workspace: выбрать свой
# Incoming Webhooks → Activate
# Add New Webhook → выбрать #alerts

# 2. Скопировать URL:
# https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX

# 3. Запустить скрипт:
./scripts/integrate-slack.sh

# Enter Slack Webhook URL: https://hooks.slack.com/services/...
# Enter Slack channel: #alerts
# Enter bot username: CERES Monitor
# Enter bot emoji: :robot_face:

# Send test alert? [y/N]: y

# ✅ Готово! Проверьте канал #alerts
```

### Сценарий: Разные каналы для разных алертов

**Сначала создать 2 webhook:**
- #critical-alerts - для критических
- #warnings - для предупреждений

**Отредактировать Alertmanager config вручную:**
```bash
kubectl edit configmap alertmanager-config -n monitoring

# Добавить:
receivers:
- name: 'slack-critical'
  slack_configs:
  - channel: '#critical-alerts'
    webhook_url: 'https://hooks.slack.com/services/XXX/YYY/ZZZ'

- name: 'slack-warnings'  
  slack_configs:
  - channel: '#warnings'
    webhook_url: 'https://hooks.slack.com/services/AAA/BBB/CCC'
```

### Сценарий: Интеграция с GitLab CI/CD

```bash
# После ./scripts/integrate-slack.sh

# GitLab → Admin → Settings → Integrations → Slack notifications
# Webhook: https://hooks.slack.com/services/...
# Channel: #ci-cd
# ✅ Enable: Push, Merge Request, Pipeline

# Теперь все CI/CD события в Slack!
```

---

## 3. Custom Branding

### Сценарий: Стартап с брендингом

```bash
./scripts/apply-branding.sh

# Company Name: TechStartup Inc
# Company Domain: techstartup.io
# Support Email: support@techstartup.io
# Primary Color: #FF6B35
# Logo URL: /path/to/logo.png

# ✅ Результат:
# - Keycloak login: "TechStartup Inc" вместо CERES
# - Grafana: Оранжевая navbar (#FF6B35)
# - Landing page: Градиент с вашим логотипом
# - Email: "From: TechStartup Inc <support@techstartup.io>"
```

**Пример для клиента MSP (Managed Service Provider):**

```bash
# Клиент A
./scripts/apply-branding.sh
# Company: "ACME Corp"
# Color: #007bff (синий)

# Клиент B  
./scripts/apply-branding.sh
# Company: "Beta Industries"
# Color: #28a745 (зеленый)

# Результат: Две платформы с разным брендингом!
```

### Сценарий: Только изменить цвета (без логотипа)

```bash
./scripts/apply-branding.sh

# Company Name: [Enter] - использует текущее
# Domain: company.com
# Support Email: [Enter] - использует текущее  
# Primary Color: #9B59B6  (фиолетовый)
# Logo: [Enter] - пропустить

# ✅ Только цвет изменится!
```

---

## 4. Complete Workflows

### Workflow 1: Полный Production Setup (45 минут)

**Для компании с доменом Cloudflare:**

```bash
# Шаг 1: Базовый деплой (30 мин)
./deploy-platform.sh --production

# Шаг 2: DNS настройка (2 мин)
./scripts/configure-dns.sh
# Choice: 1 (Cloudflare)
# Domain: company.com
# API Token: xxx
# Zone ID: yyy

# Шаг 3: Slack алерты (2 мин)
./scripts/integrate-slack.sh
# Webhook: https://hooks.slack.com/...
# Channel: #devops-alerts

# Шаг 4: Брендинг (3 мин)
./scripts/apply-branding.sh
# Company: "My Company"
# Color: #3498db
# Logo: /path/to/logo.png

# ✅ ГОТОВО!
# Результат: https://company.com
# Полностью брендированная платформа
# Все алерты в Slack
# SSL сертификаты Let's Encrypt
```

### Workflow 2: Development Setup (20 минут)

**Для локальной разработки:**

```bash
# Быстрый деплой без production фич
./deploy-platform.sh --skip-production --skip-backup -y

# Только Slack для алертов (опционально)
./scripts/integrate-slack.sh

# ✅ ГОТОВО! Платформа для тестирования
```

### Workflow 3: Миграция с IP на домен

**Сценарий: Платформа работает на http://192.168.1.3, нужен домен**

```bash
# Уже развернуто на IP
# Теперь добавить DNS:

./scripts/configure-dns.sh
# Domain: platform.company.com
# Provider: Cloudflare
# ...

# ✅ Через 2 минуты:
# https://platform.company.com - работает
# Старый IP тоже работает

# Опционально отключить доступ по IP
```

### Workflow 4: Только брендинг на существующей платформе

**Сценарий: CERES развернут месяц назад, теперь нужен ребрендинг**

```bash
# Просто запустить:
./scripts/apply-branding.sh

# ✅ Через 3 минуты - новый брендинг
# Данные не теряются
# Сервисы перезапускаются автоматически
```

---

## 🎯 Best Practices

### DNS
✅ **DO:**
- Использовать API провайдеров (Cloudflare, Route53)
- Тестировать на staging домене сначала
- Проверять DNS propagation: `dig keycloak.domain.com`

❌ **DON'T:**
- Запускать на production домене без backup
- Использовать shared API tokens
- Забывать про DNS TTL (может быть кеш)

### Slack
✅ **DO:**
- Разные каналы для critical/warning
- Тестировать webhook перед production
- Документировать webhook URL в secure vault

❌ **DON'T:**
- Публиковать webhook URL в git
- Использовать персональные каналы (@user)
- Слать все алерты в #general

### Branding
✅ **DO:**
- Подготовить логотип PNG/SVG заранее
- Использовать hex colors (#RRGGBB)
- Тестировать на одном сервисе сначала

❌ **DON'T:**
- Использовать огромные логотипы (>1MB)
- Забывать про контраст (белый текст на белом фоне)
- Менять брендинг каждый день (confuses users)

---

## 🐛 Troubleshooting

### DNS не работает

```bash
# Проверить DNS записи:
dig +short keycloak.domain.com
# Должно вернуть: SERVER_IP

# Проверить cert-manager:
kubectl get certificate -n ceres
# STATUS должен быть True

# Проверить Ingress:
kubectl get ingress -A
# Должны быть домены, не IP
```

### Slack не получает алерты

```bash
# Тест webhook вручную:
curl -X POST -H 'Content-type: application/json' \
  --data '{"text":"Test"}' \
  https://hooks.slack.com/services/...

# Должно вернуть: ok

# Проверить Alertmanager:
kubectl logs -n monitoring deployment/alertmanager
# Ошибок не должно быть
```

### Брендинг не применился

```bash
# Проверить поды (должны перезапуститься):
kubectl get pods -A | grep -v Running

# Очистить кеш браузера:
Ctrl+Shift+Delete → Clear cache

# Проверить ConfigMaps:
kubectl get configmap -n ceres | grep branding
```

---

## 📞 Support

**Вопросы?**
- 📖 Full docs: [RELEASE_v3.2.0.md](RELEASE_v3.2.0.md)
- 💬 GitHub Issues: https://github.com/skulesh01/Ceres/issues

**Примеры не работают?** 
Создайте issue с:
- Версия: `cat VERSION`
- Скрипт: какой запускали
- Вывод ошибки: полный лог
- Окружение: K8s version, cloud provider

---

**Happy Automating! 🚀**
