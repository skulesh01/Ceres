#!/bin/bash
# Generate observability dashboards and alerts

set -e

echo "📊 Generating Observability Dashboards and Alerts"
echo "=================================================="

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="${GRAFANA_PASSWORD:-admin}"

echo "✓ Creating observability dashboards..."

# Dashboard: Distributed Tracing Overview
curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Basic $(echo -n "$GRAFANA_USER:$GRAFANA_PASS" | base64)" \
  -H "Content-Type: application/json" \
  -d @- <<'EOF'
{
  "dashboard": {
    "title": "CERES Distributed Tracing",
    "tags": ["observability", "tracing"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Trace Latency Distribution",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, rate(trace_span_duration_bucket[5m]))"
          }
        ]
      },
      {
        "title": "Service Dependencies",
        "type": "nodeGraph",
        "targets": [
          {
            "expr": "span_service_calls_total"
          }
        ]
      },
      {
        "title": "Error Traces",
        "targets": [
          {
            "expr": "increase(trace_error_spans_total[5m])"
          }
        ]
      }
    ]
  }
}
EOF

# Dashboard: SLO/SLA Tracking
curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Basic $(echo -n "$GRAFANA_USER:$GRAFANA_PASS" | base64)" \
  -H "Content-Type: application/json" \
  -d @- <<'EOF'
{
  "dashboard": {
    "title": "CERES SLO/SLA Tracking",
    "tags": ["observability", "slo"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Uptime SLA",
        "targets": [
          {
            "expr": "sla:uptime_monthly"
          }
        ]
      },
      {
        "title": "Error Budget",
        "targets": [
          {
            "expr": "sla:error_budget_remaining"
          }
        ]
      },
      {
        "title": "P99 Latency vs Target",
        "targets": [
          {
            "expr": "slo:request_latency_p99:5m"
          }
        ]
      }
    ]
  }
}
EOF

# Dashboard: Cost Analysis
curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Basic $(echo -n "$GRAFANA_USER:$GRAFANA_PASS" | base64)" \
  -H "Content-Type: application/json" \
  -d @- <<'EOF'
{
  "dashboard": {
    "title": "CERES Cost Analysis",
    "tags": ["observability", "cost"],
    "timezone": "browser",
    "panels": [
      {
        "title": "Hourly Cost",
        "targets": [
          {
            "expr": "cost:total_per_hour"
          }
        ]
      },
      {
        "title": "Daily Cost",
        "targets": [
          {
            "expr": "cost:total_per_day"
          }
        ]
      },
      {
        "title": "Monthly Cost Projection",
        "targets": [
          {
            "expr": "cost:total_per_day * 30"
          }
        ]
      },
      {
        "title": "Cost by Component",
        "targets": [
          {
            "expr": "cost:memory_per_minute",
            "legendFormat": "Memory"
          },
          {
            "expr": "cost:cpu_per_minute",
            "legendFormat": "CPU"
          },
          {
            "expr": "cost:storage_per_minute",
            "legendFormat": "Storage"
          }
        ]
      }
    ]
  }
}
EOF

echo "✅ Dashboards created successfully!"
echo ""
echo "Access Grafana: http://localhost:3000"
echo "Access Jaeger: http://localhost:16686"
echo "Access Tempo: http://localhost:3200"
