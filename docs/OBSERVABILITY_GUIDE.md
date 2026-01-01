# 📊 CERES Advanced Observability Guide

Полное руководство по распределенному трейсированию, SLO/SLA мониторингу и анализу стоимости.

## 📋 Содержание

- [Что входит в Advanced Observability](#что-входит)
- [Компоненты](#компоненты)
- [Архитектура](#архитектура)
- [Быстрый старт](#быстрый-старт)
- [Distributed Tracing](#distributed-tracing)
- [SLO/SLA Tracking](#slosla-tracking)
- [Cost Analysis](#cost-analysis)
- [Service Instrumentation](#service-instrumentation)
- [Best Practices](#best-practices)

## 🎯 Что входит

**Advanced Observability** расширяет базовый мониторинг (Prometheus + Grafana) путем добавления:

1. **Distributed Tracing** — отслеживание запросов через все сервисы
2. **SLO/SLA Metrics** — мониторинг соответствия сервис-левел объектам
3. **Cost Tracking** — анализ затрат на ресурсы
4. **Service Instrumentation** — детальная инструментация приложений

## 🏗️ Компоненты

### 1. Jaeger — Distributed Tracing Platform

**Назначение:** Отслеживание и анализ запросов через микросервисы.

**Возможности:**
- Trace visualization
- Service dependencies
- Latency analysis
- Error tracking

**Порты:**
- UI: 16686
- Collector gRPC: 14250
- Collector HTTP: 14268
- Agent UDP: 6831

### 2. OpenTelemetry Collector

**Назначение:** Сбор и агрегация telemetry данных.

**Возможности:**
- Multiple receivers (OTLP, Zipkin, Jaeger)
- Data processing (batch, memory limiter)
- Multiple exporters (Jaeger, Prometheus, Loki)

**Порты:**
- OTLP gRPC: 4317
- OTLP HTTP: 4318
- Prometheus: 8888

### 3. Grafana Tempo

**Назначение:** Масштабируемое хранилище traces.

**Возможности:**
- Trace storage and retrieval
- Service graph generation
- Integration с Grafana

**Порты:**
- UI: 3200
- OTLP gRPC: 4317
- OTLP HTTP: 4318

### 4. SLO/SLA Rules

**Назначение:** Автоматическое расчет метрик SLO/SLA.

**Метрики:**
- Latency (P99, P95, P50)
- Error rate
- Availability
- Throughput
- Error budget

**Файл:** [config/prometheus/slo-rules.yml](../config/prometheus/slo-rules.yml)

## 🌐 Архитектура

```
┌──────────────────────────────────────────────────────────┐
│                    CERES Services                         │
│  (Nextcloud, Gitea, Mattermost, PostgreSQL, Redis, etc)  │
└──────────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐  ┌──────────────┐  ┌──────────┐
    │  Jaeger │  │ OTel        │  │Prometheus│
    │ (Traces)│  │ Collector   │  │(Metrics) │
    └─────────┘  │(Processing) │  └──────────┘
         │       └──────────────┘        │
         │               │               │
         └───────────────┼───────────────┘
                         │
                    ┌────▼────┐
                    │  Tempo   │
                    │ (Storage)│
                    └────┬────┘
                         │
              ┌──────────┴──────────┐
              │                     │
              ▼                     ▼
        ┌─────────────┐        ┌────────────────┐
        │  Grafana    │        │ Alert Manager  │
        │ (Dashboards)│        │  (SLO Alerts)  │
        └─────────────┘        └────────────────┘
```

## 🚀 Быстрый старт

### Шаг 1: Запуск Observability Stack

```bash
# Запустите стек наблюдения
docker compose -f config/compose/base.yml \
               -f config/compose/monitoring.yml \
               -f config/compose/observability.yml up -d

# Дождитесь готовности
docker compose ps | grep -E "jaeger|otel|tempo"
```

### Шаг 2: Проверка компонентов

```bash
# Jaeger UI
curl http://localhost:16686

# OTel Collector health
curl http://localhost:13133

# Tempo
curl http://localhost:3200/api/search
```

### Шаг 3: Инструментация сервисов

```bash
# Для Python сервисов
pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-jaeger

# Для Go сервисов
go get -u go.opentelemetry.io/otel

# Для Node.js сервисов
npm install @opentelemetry/api @opentelemetry/sdk-node @opentelemetry/exporter-jaeger
```

### Шаг 4: Добавление инструментации в код

**Python:**
```python
from config.otel.instrumentation import setup_opentelemetry, get_tracer

setup_opentelemetry("nextcloud")
tracer = get_tracer(__name__)

@app.route("/api/files")
def get_files():
    with tracer.start_as_current_span("get_files"):
        # Your code
        pass
```

**Go:**
```go
import "config/otel"

tracer, err := InitTracer("gitea")
ctx, span := tracer.Start(context.Background(), "ProcessRequest")
defer span.End()
```

### Шаг 5: Просмотр traces

```bash
# Откройте Jaeger UI
http://localhost:16686

# Или используйте Grafana
http://localhost:3000 → Explore → Tempo
```

## 🔍 Distributed Tracing

### Как работает

```
User Request
    │
    ├─ Span: HTTP Request (Caddy)
    │   │
    │   ├─ Span: Auth Check (Keycloak)
    │   │
    │   ├─ Span: Get File (Nextcloud)
    │   │   │
    │   │   ├─ Span: DB Query (PostgreSQL)
    │   │   │   Duration: 45ms
    │   │   │
    │   │   └─ Span: Cache Lookup (Redis)
    │   │       Duration: 5ms
    │   │
    │   └─ Span: Response (Caddy)
    │
    └─ Total Duration: 120ms
```

### Структура Trace

| Компонент | Описание |
|-----------|---------|
| Trace | Вся цепочка запроса |
| Span | Отдельная операция |
| Attributes | Метаданные span |
| Events | Логированные события |
| Links | Связи между traces |

### Типы spans

```yaml
Span Types:
  CLIENT: Отправка запроса клиентом
  SERVER: Обработка запроса сервером
  INTERNAL: Внутренняя операция
  PRODUCER: Отправка в очередь
  CONSUMER: Получение из очереди
```

### Анализ traces

```bash
# Поиск медленных запросов
# Jaeger UI → Search → Latency > 500ms

# Поиск ошибок
# Jaeger UI → Search → Tags → error=true

# Анализ зависимостей
# Jaeger UI → Service Dependencies
```

### Интеграция с Prometheus

```yaml
# Prometheus scrape config
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['localhost:8888']
```

### Интеграция с Grafana

```bash
# Добавьте Tempo как источник данных
# Grafana → Configuration → Data Sources → Add → Tempo
# URL: http://tempo:3200

# Создайте dashboard
# Explore → Metrics → tempo
```

## 📊 SLO/SLA Tracking

### SLO vs SLA

| Аспект | SLO | SLA |
|--------|-----|-----|
| Определение | Service Level **Objective** | Service Level **Agreement** |
| Назначение | Внутренняя цель | Контрактное обязательство |
| Нарушение | Action item | Штраф/компенсация |
| Пример | P99 < 500ms | Uptime > 99.9% |

### Метрики SLO в CERES

```yaml
Request Latency:
  P99: < 1.0s
  P95: < 500ms
  P50: < 100ms

Error Rate:
  Target: < 5%
  Alert: > 5% for 5min

Availability:
  Target: 95%
  Alert: < 95% for 5min

Throughput:
  Minimum: 100 req/s
```

### Error Budget

```
Monthly Error Budget = (1 - SLA Target) × Seconds in Month
Example: (1 - 0.95) × 2.592M = 129,600 seconds = 36 hours
```

### Просмотр SLO в Grafana

```bash
# Dashboard: CERES SLO/SLA Tracking
# Metrics:
#   - slo:request_latency_p99:5m
#   - slo:error_rate:5m
#   - slo:availability:5m
#   - sla:uptime_monthly
#   - sla:error_budget_remaining
```

### Алерты на нарушение SLO

```yaml
Alert: HighLatency
  Condition: slo:request_latency_p99:5m > 1.0
  Duration: 5m
  Severity: warning

Alert: HighErrorRate
  Condition: slo:error_rate:5m > 0.05
  Duration: 5m
  Severity: critical

Alert: ServiceUnavailable
  Condition: slo:availability:5m < 0.95
  Duration: 5m
  Severity: critical
```

## 💰 Cost Analysis

### Метрики затрат

```yaml
Memory Cost: $0.0001 per GB per minute
CPU Cost: $0.00005 per CPU per minute
Storage Cost: $0.0002 per GB per minute

Examples:
  4 GB RAM: $0.0004 / min = $5.76 / day
  2 CPU cores: $0.0001 / min = $1.44 / day
  50 GB storage: $0.01 / min = $14.4 / day
```

### Просмотр затрат

```bash
# Dashboard: CERES Cost Analysis
# Metrics:
#   - cost:total_per_hour
#   - cost:total_per_day
#   - cost:total_per_month
#   - cost:memory_per_minute
#   - cost:cpu_per_minute
#   - cost:storage_per_minute
```

### Оптимизация затрат

```bash
# Рекомендации по экономии:
1. Уменьшить memory limits
2. Использовать Horizontal Pod Autoscaling
3. Оптимизировать SQL queries
4. Использовать caching
5. Удалить неиспользуемые сервисы
```

## 🛠️ Service Instrumentation

### Python Instrumentation

```python
# instrumentation.py
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor

def setup_otel(app, service_name):
    FlaskInstrumentor().instrument_app(app)
    
    jaeger_exporter = JaegerExporter(
        agent_host_name="jaeger",
        agent_port=6831,
    )
    
    trace.set_tracer_provider(
        TracerProvider()
    )
    trace.get_tracer_provider().add_span_processor(
        BatchSpanProcessor(jaeger_exporter)
    )
```

### Go Instrumentation

```go
// main.go
package main

import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/jaeger"
    "go.opentelemetry.io/otel/sdk/trace"
)

func init() {
    exp, _ := jaeger.New(jaeger.WithAgentHost("jaeger"))
    tp := trace.NewTracerProvider(trace.WithBatcher(exp))
    otel.SetTracerProvider(tp)
}
```

### Node.js Instrumentation

```javascript
// instrumentation.js
const api = require('@opentelemetry/api');
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { JaegerExporter } = require('@opentelemetry/exporter-trace-jaeger');

const sdk = new NodeSDK({
  traceExporter: new JaegerExporter({
    host: 'jaeger',
    port: 6831,
  }),
});

sdk.start();
```

### Собственные spans

```python
# Создание собственного span
tracer = trace.get_tracer(__name__)

with tracer.start_as_current_span("custom_operation") as span:
    span.set_attribute("user_id", user_id)
    span.add_event("operation_started")
    
    # Your code
    
    span.add_event("operation_completed")
```

## 📈 Best Practices

### 1. Instrumentируйте критические пути

```python
# Инструментируйте:
# ✓ API endpoints
# ✓ Database queries
# ✓ External API calls
# ✗ Не instrumentируйте каждую функцию
```

### 2. Используйте meaningful span names

```python
# ✓ Good
tracer.start_as_current_span("db.query.users.select")

# ✗ Bad
tracer.start_as_current_span("query")
```

### 3. Добавляйте атрибуты

```python
span.set_attribute("user_id", 123)
span.set_attribute("query_type", "SELECT")
span.set_attribute("duration_ms", 45)
```

### 4. Регулярно пересматривайте SLO

```yaml
# Квартальный review:
- Достигли ли мы целей?
- Нужно ли пересчитать budget?
- Какие сервисы нуждаются в оптимизации?
```

### 5. Оповещайте о нарушениях

```yaml
# Настройте alerts для:
- Нарушение SLO (warning)
- Исчерпание error budget (critical)
- Аномальная стоимость (warning)
```

### 6. Документируйте SLO/SLA

```markdown
# Service SLOs

## Nextcloud
- Availability: 95%
- Latency P99: 1.0s
- Error Rate: < 5%

## PostgreSQL
- Availability: 99.9%
- Query Latency P99: 100ms
```

## 🔍 Troubleshooting

### Spans не отправляются в Jaeger

```bash
# Проверьте:
1. Jaeger запущен: curl http://localhost:16686
2. OTel Collector запущен: curl http://localhost:13133
3. Service отправляет spans: проверьте логи
4. Network connectivity между сервисами
```

### Высокое использование памяти OTel Collector

```yaml
# Уменьшите batch size
processors:
  batch:
    send_batch_size: 512  # было 1024
    timeout: 5s           # было 10s

# Или используйте memory limiter
memory_limiter:
  check_interval: 1s
  limit_mib: 256  # было 512
```

### Traces исчезают

```bash
# Проверьте:
1. Tempo запущен и имеет place на диске
2. Retention policy: docker exec ceres-tempo curl http://localhost:3200/config
3. Используете правильный exporter в OTel Collector
```

## 📚 Дополнительные ресурсы

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Grafana Tempo Documentation](https://grafana.com/docs/tempo/)
- [SLO Best Practices](https://sre.google/sre-book/service-level-objectives/)

---

**⚡ Advanced Observability — это фундамент надежного production!**
