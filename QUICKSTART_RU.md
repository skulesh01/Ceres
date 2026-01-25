# 🚀 CERES v3.0.0 - Быстрый Старт

## 📋 Автоматическое Управление Платформой

Все операции выполняются **АВТОМАТИЧЕСКИ** через приложение `ceres`.

---

## ⚡ Быстрый Запуск

### 1. Сборка приложения

```powershell
cd E:\Новая папка\All_project\Ceres
go build -o ceres.exe cmd/ceres/main.go
```

### 2. Интерактивное меню

Запустите без параметров:

```powershell
.\ceres.exe
```

**Появится меню**:

```
╔═══════════════════════════════════════════════╗
║  CERES v3.0.0 - Управление Платформой        ║
╚═══════════════════════════════════════════════╝

  1. 🚀 Развернуть платформу (deploy)
  2. 📊 Показать статус (status)
  3. 🔧 Исправить проблемы (fix)
  4. 🔍 Диагностика кластера (diagnose)
  5. 🔄 Обновить платформу (upgrade)
  6. 🌐 Управление VPN (vpn)
  7. ⚙️  Конфигурация (config)
  0. ❌ Выход

Выберите действие: 
```

---

## 🎯 Основные Команды

### ✅ Развертывание (Автоматическое)

**Интерактивно**:
```powershell
.\ceres.exe
# Выберите: 1
```

**Из командной строки**:
```powershell
.\ceres.exe deploy --cloud proxmox
```

**Что происходит**:
- ✅ Проверка наличия в системе (идемпотентность)
- ✅ Создание namespaces
- ✅ Развертывание PostgreSQL + Redis
- ✅ Создание баз данных для всех сервисов
- ✅ Развертывание 21+ сервиса
- ✅ Настройка NodePort доступа
- ✅ Показ информации о доступе

---

### 📊 Статус Платформы

**Интерактивно**:
```powershell
.\ceres.exe
# Выберите: 2
```

**Из командной строки**:
```powershell
.\ceres.exe status
```

**Вывод**:
```
📊 CERES Status (namespace: ceres)
=====================================
Deployment: proxmox (prod environment)
Namespace: ceres
Services: 22 deployed
  - postgresql: 1/1 ready (Running)
  - redis: 1/1 ready (Running)
  - grafana: 1/1 ready (Running)
  ...
```

---

### 🔧 Исправление Проблем (АВТОМАТИЧЕСКИ!)

**Интерактивно**:
```powershell
.\ceres.exe
# Выберите: 3
```

**Из командной строки**:
```powershell
# Исправить ВСЕ проблемные сервисы
.\ceres.exe fix

# Исправить конкретный сервис
.\ceres.exe fix nextcloud
```

**Что происходит автоматически**:
1. 🔍 Поиск всех failing pods
2. 📋 Анализ логов каждого пода
3. 🔧 Применение fix по типу проблемы:
   - Permission denied → Перезапуск с правильными правами
   - Unix socket → Исправление RabbitMQ конфигурации
   - Cache config → Исправление Harbor настроек
4. ⏱️ Ожидание 30 секунд
5. ✅ Показ обновленного статуса

---

### 🔍 Диагностика Кластера

**Интерактивно**:
```powershell
.\ceres.exe
# Выберите: 4
```

**Из командной строки**:
```powershell
.\ceres.exe diagnose
```

**Что проверяется**:
1. ✅ Cluster connectivity (kubectl cluster-info)
2. 📊 Nodes status (kubectl get nodes)
3. 📈 Pods summary (Running / Crashing / Pending)
4. ⚠️ Failed pods details
5. 💾 Resource usage (CPU/Memory)
6. 💿 Storage (PVCs)

---

### 🔄 Обновление Платформы

**Интерактивно**:
```powershell
.\ceres.exe
# Выберите: 5
```

**Из командной строки**:
```powershell
.\ceres.exe deploy
```

**Что происходит**:
- 🔍 Проверка текущей версии
- 🆕 Если версия новая → Upgrade
- 📦 Если та же версия → Reconcile (kubectl apply -f)
- ✅ Обновление state ConfigMap

---

## 🌐 Доступ к Сервисам

### NodePort (192.168.1.3)

После развертывания автоматически доступны:

| Сервис | URL |
|--------|-----|
| Grafana | http://192.168.1.3:30300 |
| Wiki.js | http://192.168.1.3:30301 |
| Redmine | http://192.168.1.3:30310 |
| Kibana | http://192.168.1.3:30561 |
| Mattermost | http://192.168.1.3:30806 |
| Adminer | http://192.168.1.3:30808 |
| Vault | http://192.168.1.3:30820 |
| Uptime Kuma | http://192.168.1.3:30880 |
| Portainer | http://192.168.1.3:30900 |
| Alertmanager | http://192.168.1.3:30901 |
| MinIO | http://192.168.1.3:30902 |
| SonarQube | http://192.168.1.3:30904 |
| Elasticsearch | http://192.168.1.3:30920 |

### Учетные данные (по умолчанию)

- **PostgreSQL**: `postgres` / `ceres_postgres_2025`
- **Redis**: пароль `ceres_redis_2025`
- **Grafana**: `admin` / `Grafana@Admin2025`
- **Keycloak**: `admin` / `K3yClo@k!2025`

---

## 🔄 Идемпотентность

Приложение **умное**:

```powershell
# Первый запуск
.\ceres.exe deploy
# → Fresh install (полная установка)

# Второй запуск (та же версия)
.\ceres.exe deploy
# → Reconcile (kubectl apply, ничего не ломает)

# Третий запуск (новая версия)
.\ceres.exe deploy
# → Upgrade (обновление с сохранением данных)
```

**Никогда не сломает существующую установку!**

---

## ❌ Что НЕ НУЖНО Делать

### ❌ НЕ используйте kubectl напрямую:
```powershell
# ❌ ПЛОХО
ssh root@192.168.1.3 "kubectl apply -f ..."
kubectl get pods --all-namespaces

# ✅ ХОРОШО
.\ceres.exe status
.\ceres.exe fix
```

### ❌ НЕ используйте PowerShell скрипты:
```powershell
# ❌ ПЛОХО (старые скрипты удалены)
.\deploy-all.ps1
.\quick-deploy.ps1

# ✅ ХОРОШО
.\ceres.exe deploy
```

### ❌ НЕ редактируйте манифесты вручную на сервере:
```bash
# ❌ ПЛОХО
ssh root@192.168.1.3 "vim /root/all-services.yaml"

# ✅ ХОРОШО
# Отредактируйте deployment/all-services.yaml
# Запустите: .\ceres.exe deploy
```

---

## 🎓 Примеры Сценариев

### Сценарий 1: Первое развертывание

```powershell
# 1. Сборка
go build -o ceres.exe cmd/ceres/main.go

# 2. Развертывание
.\ceres.exe deploy

# 3. Проверка
.\ceres.exe status

# 4. Доступ к сервисам
start http://192.168.1.3:30300  # Grafana
```

### Сценарий 2: Есть проблемы с сервисами

```powershell
# 1. Диагностика
.\ceres.exe diagnose

# 2. Автоматическое исправление
.\ceres.exe fix

# 3. Проверка результата
.\ceres.exe status
```

### Сценарий 3: Обновление платформы

```powershell
# 1. Обновили код
git pull

# 2. Пересборка
go build -o ceres.exe cmd/ceres/main.go

# 3. Развертывание (автоматически определит upgrade)
.\ceres.exe deploy
```

---

## 🏗️ Архитектура Автоматизации

### Идемпотентный Flow

```
ceres deploy
    ↓
checkInstalled() → Проверка ConfigMap "ceres-deployment-state"
    ↓
┌───────────────────────────────────────┐
│ НЕ установлен → freshInstall()        │
│   ├── Создать namespaces              │
│   ├── Развернуть PostgreSQL + Redis   │
│   ├── Создать базы данных             │
│   ├── Развернуть 21 сервис            │
│   └── Показать Access Info            │
└───────────────────────────────────────┘
    ИЛИ
┌───────────────────────────────────────┐
│ Установлен, та же версия → update()   │
│   ├── kubectl apply (идемпотентно)    │
│   └── Reconcile конфигурация          │
└───────────────────────────────────────┘
    ИЛИ
┌───────────────────────────────────────┐
│ Установлен, новая версия → upgrade()  │
│   ├── Применить новые манифесты       │
│   ├── Обновить версию в ConfigMap     │
│   └── Показать изменения              │
└───────────────────────────────────────┘
```

### State Management

**ConfigMap** `ceres-deployment-state` в namespace `kube-system`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ceres-deployment-state
  namespace: kube-system
data:
  version: "3.0.0"
  installed: "true"
  installDate: "2026-01-21T20:00:00Z"
```

---

## 📚 Дополнительная Информация

---

## ✉️ Вариант установки: почта на хостинге (ISPmanager/reg.ru)

Если вы не хотите VPS, можно включить почту на хостинге и использовать её как SMTP для CERES/Keycloak.

1) В панели ISPmanager:
- создайте почтовый домен `praximo.tech`
- включите DKIM/DMARC/SSL
- выпустите Let’s Encrypt для `mail.praximo.tech` и привяжите его к почтовому домену
- создайте ящик `no-reply@praximo.tech`

2) На сервере CERES (Proxmox) выполните один скрипт:

```bash
cd /root/Ceres
sudo bash ./scripts/configure-ceres-smtp.sh
```

Скрипт запишет `/etc/ceres/ceres.env`, настроит SMTP в Keycloak и предложит отправить тестовое письмо.

Подробно: [docs/MAIL_HOSTING_ISPMANAGER_RU.md](docs/MAIL_HOSTING_ISPMANAGER_RU.md)

### Просмотр состояния

```powershell
kubectl get configmap ceres-deployment-state -n kube-system -o yaml
```

### Ручной сброс состояния (если нужно)

```powershell
kubectl delete configmap ceres-deployment-state -n kube-system
.\ceres.exe deploy  # Будет fresh install
```

---

## ✅ Итого

**ВСЁ управление через одно приложение `ceres.exe`:**

1. ✅ Развертывание: `.\ceres.exe deploy` или интерактивное меню
2. ✅ Статус: `.\ceres.exe status`
3. ✅ Исправление: `.\ceres.exe fix`
4. ✅ Диагностика: `.\ceres.exe diagnose`
5. ✅ Никаких PowerShell скриптов
6. ✅ Никаких ручных kubectl команд
7. ✅ 100% автоматизация

**Просто запустите `.\ceres.exe` и выберите нужное действие! 🚀**
