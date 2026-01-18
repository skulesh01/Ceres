# Advanced Scripts

Специализированные скрипты для продвинутой конфигурации и оптимизации Ceres.

## 🔐 Security

### export-caddy-rootca.ps1
Экспорт корневого CA сертификата Caddy для добавления в доверенные хранилища.

**Использование:**
```powershell
.\export-caddy-rootca.ps1
```

**Что делает:**
- Извлекает Caddy root CA из контейнера
- Сохраняет в `caddy-root-ca.crt`
- Выводит инструкции по установке (Windows, Linux, macOS)

### generate-mtls-certs.ps1 / .sh
Генерация mTLS сертификатов для inter-service authentication.

**Использование:**
```powershell
# PowerShell
.\generate-mtls-certs.ps1 -ServiceName gitea

# Bash
./generate-mtls-certs.sh gitea
```

**Параметры:**
- `-ServiceName`: Имя сервиса (gitea, nextcloud, mattermost и т.д.)

## 🔄 High Availability

### setup-ha.sh
Настройка HA для PostgreSQL (Patroni) и Redis Sentinel.

**Использование:**
```bash
./setup-ha.sh
```

**Что настраивает:**
- PostgreSQL cluster с Patroni (3 узла)
- Redis Sentinel (3 узла)
- HAProxy для балансировки
- Automatic failover

**Требования:**
- Минимум 3 VM/хоста
- etcd или Consul для Patroni

### setup-multi-cluster.sh
Настройка multi-cluster Federation (кластер dev + prod).

**Использование:**
```bash
./setup-multi-cluster.sh
```

**Что настраивает:**
- KubeFed (Kubernetes Federation v2)
- Cross-cluster ingress
- Service mesh (Istio)
- Shared secrets

### monitor-ha-health.sh
Мониторинг health check для HA компонентов.

**Использование:**
```bash
./monitor-ha-health.sh [--interval 60]
```

**Параметры:**
- `--interval`: Интервал проверки в секундах (по умолчанию 60)

**Что проверяет:**
- Patroni cluster status
- Redis Sentinel status
- HAProxy backend health
- PostgreSQL replication lag

## 💰 Cost Optimization

### cost-optimization.sh
Анализ и оптимизация использования ресурсов.

**Использование:**
```bash
./cost-optimization.sh [--apply]
```

**Параметры:**
- `--apply`: Применить рекомендации автоматически (по умолчанию только анализ)

**Что делает:**
- Анализирует CPU/Memory requests/limits
- Выявляет overprovisioned resources
- Предлагает рекомендации по downsizing
- Опционально применяет изменения

## 📊 Observability

### instrument-services.sh
Добавление OpenTelemetry instrumentation к сервисам.

**Использование:**
```bash
./instrument-services.sh <service-name>
```

**Поддерживаемые сервисы:**
- `gitea`: Adds OTEL sidecar for Gitea
- `nextcloud`: Adds OTEL PHP instrumentation
- `mattermost`: Adds OTEL Go instrumentation
- `all`: Instruments all services

**Требования:**
- OpenTelemetry Collector deployed
- Tempo backend configured

## 🛠️ Когда использовать эти скрипты

**НЕ нужны для базового деплоя:**
- Базовое развёртывание: используйте `ceres start`
- Конфигурация: используйте `ceres configure`
- День 1 операции: используйте стандартные команды `ceres`

**Нужны для:**
- Production hardening (mTLS, HA)
- Multi-cluster deployments
- Cost optimization (>50 pods)
- Advanced observability (distributed tracing)
- Custom security requirements

## 📝 Примечания

- Все скрипты требуют прав администратора
- HA скрипты предполагают Kubernetes/k3s
- Cost optimization рекомендуется запускать weekly
- mTLS генерация должна выполняться до деплоя сервисов

## 🔗 См. также

- [Main CLI Reference](../../docs/03-CLI_REFERENCE.md) - основные команды `ceres`
- [HA Guide](../../docs/HA_GUIDE.md) - полный гайд по HA
- [Security Setup](../../SECURITY_SETUP.md) - настройка безопасности
