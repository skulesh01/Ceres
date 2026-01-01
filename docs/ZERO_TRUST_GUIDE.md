# 🔒 CERES Zero Trust Security Architecture

Полное руководство по реализации модели Zero Trust в CERES.

## 📋 Содержание

- [Что такое Zero Trust?](#что-такое-zero-trust)
- [Архитектура безопасности](#архитектура-безопасности)
- [Компоненты](#компоненты)
- [Настройка Vault](#настройка-vault)
- [Настройка OPA](#настройка-opa)
- [mTLS для сервисов](#mtls-для-сервисов)
- [Сетевая сегментация](#сетевая-сегментация)
- [Best Practices](#best-practices)

## 🎯 Что такое Zero Trust?

**Zero Trust** — модель безопасности, основанная на принципе "никогда не доверяй, всегда проверяй".

### Ключевые принципы:

1. **Verify Explicitly** — всегда аутентифицируй и авторизуй
2. **Least Privilege** — минимальные необходимые права
3. **Assume Breach** — предполагай, что система уже скомпрометирована

### Отличия от традиционной модели:

| Traditional Security | Zero Trust |
|---------------------|------------|
| Доверие внутри периметра | Нет доверия по умолчанию |
| Аутентификация на входе | Постоянная аутентификация |
| Широкие права доступа | Минимальные привилегии |
| Статичные политики | Динамические политики |

## 🏗️ Архитектура безопасности

```
┌─────────────────────────────────────────────────────────────┐
│                     User / Service Request                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  1. Identity Verification                    │
│                      (Keycloak SSO)                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               2. Certificate Validation (mTLS)               │
│                    (Vault PKI + TLS)                         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│               3. Policy Evaluation (OPA)                     │
│         Can user X access resource Y with action Z?          │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
                 ALLOW                DENY
                    │                   │
                    ▼                   ▼
┌─────────────────────────────┐  ┌──────────────┐
│   4. Network Segmentation    │  │  Audit Log   │
│     (iptables policies)      │  │   & Alert    │
└─────────────────────────────┘  └──────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│              5. Secure Communication (mTLS)                  │
│         Service A ←───encrypted───→ Service B                │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                  6. Audit & Monitoring                       │
│            (Prometheus, Grafana, Loki)                       │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Компоненты

### 1. HashiCorp Vault

**Назначение:** Централизованное управление секретами и PKI для mTLS.

**Возможности:**
- Динамическая генерация паролей БД
- PKI для выпуска сертификатов
- Шифрование данных (transit engine)
- Audit logging всех операций

**Файлы:**
- [config/compose/vault.yml](../config/compose/vault.yml)
- [config/vault/config.hcl](../config/vault/config.hcl)
- [config/vault/init-scripts/init-vault.sh](../config/vault/init-scripts/init-vault.sh)

### 2. Open Policy Agent (OPA)

**Назначение:** Централизованный движок политик авторизации.

**Возможности:**
- Fine-grained access control
- Service-to-service authorization
- Rate limiting
- Audit decisions

**Файлы:**
- [config/compose/opa.yml](../config/compose/opa.yml)
- [config/opa/policies/authz.rego](../config/opa/policies/authz.rego)
- [config/opa/policies/mtls.rego](../config/opa/policies/mtls.rego)

### 3. Mutual TLS (mTLS)

**Назначение:** Двусторонняя аутентификация между сервисами.

**Возможности:**
- Service identity verification
- Encrypted communication
- Certificate-based authentication

**Скрипты:**
- [scripts/generate-mtls-certs.sh](../scripts/generate-mtls-certs.sh)
- [scripts/generate-mtls-certs.ps1](../scripts/generate-mtls-certs.ps1)

### 4. Network Segmentation

**Назначение:** Микросегментация сетевого трафика.

**Возможности:**
- Isolated Docker networks
- iptables firewall rules
- Traffic monitoring

**Файлы:**
- [config/compose/network-policies.yml](../config/compose/network-policies.yml)
- [config/network-policies/enforce.sh](../config/network-policies/enforce.sh)

## 🚀 Быстрый старт

### Шаг 1: Запуск Vault

```bash
# Запустите Vault
docker compose -f config/compose/base.yml -f config/compose/vault.yml up -d

# Дождитесь инициализации
docker logs -f ceres-vault-init

# Сохраните unseal keys и root token!
docker exec ceres-vault-init cat /vault/keys/vault-keys.json > vault-keys.json

# Экспортируйте root token
export VAULT_TOKEN=$(cat vault-keys.json | jq -r '.root_token')
```

### Шаг 2: Генерация mTLS сертификатов

```bash
# Bash
export VAULT_TOKEN="your-root-token"
./scripts/generate-mtls-certs.sh ./certs

# PowerShell
$env:VAULT_TOKEN = "your-root-token"
.\scripts\generate-mtls-certs.ps1 -CertsDir .\certs
```

### Шаг 3: Запуск OPA

```bash
# Запустите OPA с политиками
docker compose -f config/compose/base.yml -f config/compose/opa.yml up -d

# Проверьте статус
curl http://localhost:8181/health
```

### Шаг 4: Применение сетевых политик

```bash
# Запустите network policy enforcer
docker compose -f config/compose/network-policies.yml up -d

# Проверьте правила
docker exec ceres-network-policy iptables -L DOCKER-USER -v -n
```

### Шаг 5: Обновление сервисов

Добавьте в docker-compose файлы сервисов:

```yaml
services:
  postgres:
    volumes:
      - ./certs/postgres.crt:/var/lib/postgresql/server.crt:ro
      - ./certs/postgres.key:/var/lib/postgresql/server.key:ro
      - ./certs/root-ca.crt:/var/lib/postgresql/root.crt:ro
    command: >
      postgres
      -c ssl=on
      -c ssl_cert_file=/var/lib/postgresql/server.crt
      -c ssl_key_file=/var/lib/postgresql/server.key
      -c ssl_ca_file=/var/lib/postgresql/root.crt
```

## 🔐 Настройка Vault

### Инициализация

```bash
# Автоматическая инициализация через скрипт
docker compose -f config/compose/vault.yml up

# Vault будет инициализирован с:
# - 5 unseal keys (threshold: 3)
# - KV secrets engine для секретов
# - PKI engine для сертификатов
# - Database secrets engine для динамических паролей
```

### Управление секретами

```bash
# Сохранить секрет
vault kv put ceres/nextcloud admin_password="supersecret"

# Получить секрет
vault kv get ceres/nextcloud

# Получить динамический пароль БД
vault read database/creds/ceres-apps
```

### Выпуск сертификатов

```bash
# Выпустить сертификат для сервиса
vault write pki/issue/ceres-services \
    common_name="myservice.ceres.local" \
    ttl="8760h"

# Просмотреть выпущенные сертификаты
vault list pki/certs
```

### Ротация секретов

```bash
# Автоматическая ротация через API
curl -X POST -H "X-Vault-Token: $VAULT_TOKEN" \
    http://localhost:8200/v1/database/rotate-root/postgres

# Обновить все пароли приложений
vault write -force database/rotate-role/ceres-apps
```

## ⚖️ Настройка OPA

### Структура политик

```
config/opa/policies/
├── authz.rego          # Основные правила авторизации
├── mtls.rego           # Валидация mTLS сертификатов
├── network.rego        # Сетевые политики
└── rate-limit.rego     # Rate limiting
```

### Тестирование политик

```bash
# Проверить политику
curl -X POST http://localhost:8181/v1/data/ceres/authz/allow \
  -H 'Content-Type: application/json' \
  -d '{
    "input": {
      "user": {"id": "user1", "role": "admin"},
      "method": "GET",
      "resource": {"type": "file", "owner_id": "user1"}
    }
  }'

# Результат: {"result": true}
```

### Создание новых политик

```rego
# config/opa/policies/custom.rego
package ceres.custom

# Allow access to public resources
allow if {
    input.resource.visibility == "public"
}

# Allow team members to access team resources
allow if {
    input.user.team_id == input.resource.team_id
}
```

### Интеграция с приложениями

```python
# Python example
import requests

def check_authorization(user, resource, action):
    opa_url = "http://opa:8181/v1/data/ceres/authz/allow"
    
    payload = {
        "input": {
            "user": user,
            "resource": resource,
            "method": action
        }
    }
    
    response = requests.post(opa_url, json=payload)
    return response.json().get("result", False)

# Usage
if check_authorization(current_user, file, "GET"):
    return file_contents
else:
    return "Access Denied"
```

## 🔒 mTLS для сервисов

### PostgreSQL

```yaml
# docker-compose.yml
services:
  postgres:
    volumes:
      - ./certs/postgres.crt:/var/lib/postgresql/server.crt:ro
      - ./certs/postgres.key:/var/lib/postgresql/server.key:ro
      - ./certs/root-ca.crt:/var/lib/postgresql/root.crt:ro
    command: >
      postgres
      -c ssl=on
      -c ssl_cert_file=/var/lib/postgresql/server.crt
      -c ssl_key_file=/var/lib/postgresql/server.key
      -c ssl_ca_file=/var/lib/postgresql/root.crt
      -c ssl_ciphers='HIGH:MEDIUM:+3DES:!aNULL'
```

### Redis

```yaml
services:
  redis:
    volumes:
      - ./certs/redis.crt:/etc/ssl/certs/redis.crt:ro
      - ./certs/redis.key:/etc/ssl/private/redis.key:ro
      - ./certs/root-ca.crt:/etc/ssl/certs/ca.crt:ro
      - ./redis/redis-tls.conf:/usr/local/etc/redis/redis.conf:ro
    command: redis-server /usr/local/etc/redis/redis.conf
```

```conf
# redis-tls.conf
tls-port 6380
port 0
tls-cert-file /etc/ssl/certs/redis.crt
tls-key-file /etc/ssl/private/redis.key
tls-ca-cert-file /etc/ssl/certs/ca.crt
tls-auth-clients yes
```

### Caddy (Reverse Proxy)

```caddyfile
# Caddyfile with mTLS
https://nextcloud.ceres.local {
    tls /certs/caddy.crt /certs/caddy.key {
        client_auth {
            mode require_and_verify
            trusted_ca_cert_file /certs/root-ca.crt
        }
    }
    
    reverse_proxy nextcloud:80 {
        transport http {
            tls
            tls_client_auth /certs/caddy.crt /certs/caddy.key
            tls_trusted_ca_certs /certs/root-ca.crt
        }
    }
}
```

## 🌐 Сетевая сегментация

### Архитектура сетей

```
DMZ Network (172.20.0.0/24)
  ├─ Caddy (reverse proxy)
  └─ Keycloak (SSO)

Core Network (172.21.0.0/24) - Internal only
  ├─ PostgreSQL
  └─ Redis

Apps Network (172.22.0.0/24) - Internal only
  ├─ Nextcloud
  ├─ Gitea
  ├─ Mattermost
  └─ Redmine

Monitoring Network (172.23.0.0/24) - Internal only
  ├─ Prometheus
  ├─ Grafana
  └─ Loki

Management Network (172.24.0.0/24)
  ├─ Portainer
  └─ Vault
```

### Правила межсетевого взаимодействия

| Source | Destination | Ports | Protocol |
|--------|-------------|-------|----------|
| DMZ | Apps | 80, 443 | TCP |
| Apps | Core | 5432, 6379 | TCP |
| Monitoring | Core | 9187, 9121 | TCP |
| Monitoring | Apps | 8080 | TCP |
| Management | All | Any | TCP |

### Применение правил

```bash
# Применить сетевые политики
docker compose -f config/compose/network-policies.yml up -d

# Проверить активные правила
docker exec ceres-network-policy iptables -L DOCKER-USER -v -n

# Мониторинг заблокированных пакетов
docker exec ceres-network-policy tail -f /var/log/kern.log | grep CERES-BLOCKED
```

## 📊 Мониторинг безопасности

### Vault Metrics

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'vault'
    metrics_path: '/v1/sys/metrics'
    params:
      format: ['prometheus']
    bearer_token: 'your-vault-token'
    static_configs:
      - targets: ['vault:8200']
```

### OPA Metrics

```yaml
scrape_configs:
  - job_name: 'opa'
    static_configs:
      - targets: ['opa:8181']
```

### Audit Logs

```bash
# Vault audit logs
docker exec ceres-vault tail -f /vault/logs/audit.log | jq

# OPA decision logs
docker logs -f ceres-opa | jq 'select(.decision_id)'
```

### Grafana Dashboards

Импортируйте готовые дашборды:
- Vault Operations (ID: 12904)
- OPA Decisions (custom)
- mTLS Certificate Expiry (custom)

## 📝 Best Practices

### 1. Регулярная ротация секретов

```bash
# Автоматическая ротация каждые 90 дней
0 0 */90 * * /scripts/rotate-secrets.sh
```

### 2. Мониторинг истечения сертификатов

```bash
# Проверка сертификатов
for cert in certs/*.crt; do
  openssl x509 -in "$cert" -noout -enddate
done
```

### 3. Регулярный аудит политик

```bash
# Проверка политик OPA
opa test config/opa/policies/
```

### 4. Backup unseal keys

```bash
# Зашифруйте и сохраните ключи
gpg -c vault-keys.json
# Сохраните в безопасном месте (не Git!)
```

### 5. Least Privilege

- Создавайте отдельные роли для каждого сервиса
- Ограничивайте TTL токенов
- Используйте AppRole для автоматизации

## 🔍 Troubleshooting

### Vault sealed

```bash
# Unseal Vault
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
```

### OPA policy denied

```bash
# Debug политику
opa eval -d config/opa/policies/ \
  -i test-input.json \
  "data.ceres.authz.allow"
```

### mTLS handshake failed

```bash
# Проверьте сертификаты
openssl s_client -connect service:port \
  -cert client.crt \
  -key client.key \
  -CAfile root-ca.crt
```

### Network policy блокирует трафик

```bash
# Временно отключите правила
docker stop ceres-network-policy

# Проверьте, работает ли сервис
# Затем исправьте правила и запустите снова
```

## 📚 Дополнительные ресурсы

- [Zero Trust Architecture (NIST SP 800-207)](https://csrc.nist.gov/publications/detail/sp/800-207/final)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/)
- [mTLS Best Practices](https://www.cloudflare.com/learning/access-management/what-is-mutual-tls/)

---

**⚠️ ВАЖНО:** Zero Trust — это не однократная настройка, а постоянный процесс улучшения безопасности!
