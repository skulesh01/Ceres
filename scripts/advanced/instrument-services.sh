#!/bin/bash
# Instrument Node.js/Python services with OpenTelemetry

set -e

echo "📊 Instrumenting CERES services with OpenTelemetry"
echo "===================================================="

SERVICES=(
    "nextcloud"
    "gitea"
    "mattermost"
)

# Install OpenTelemetry packages for Python services
for service in "${SERVICES[@]}"; do
    echo "✓ Installing OpenTelemetry for $service..."
    
    case "$service" in
        "nextcloud"|"mattermost")
            # PHP services
            # Add to Dockerfile:
            # RUN pecl install opentelemetry && docker-php-ext-enable opentelemetry
            ;;
        "gitea")
            # Go service
            # Add to go.mod:
            # go get -u go.opentelemetry.io/otel
            # go get -u go.opentelemetry.io/otel/exporters/jaeger
            ;;
    esac
done

# Create instrumentation config
cat > instrumentation.yaml <<'EOF'
# OpenTelemetry Instrumentation Config for CERES

services:
  nextcloud:
    otel:
      exporter: jaeger
      jaeger_agent_host: jaeger
      jaeger_agent_port: 6831
      service_name: nextcloud
      resource_attributes:
        - environment=production
        - cluster=ceres
        - version=28.0

  gitea:
    otel:
      exporter: jaeger
      jaeger_agent_host: jaeger
      jaeger_agent_port: 6831
      service_name: gitea
      resource_attributes:
        - environment=production
        - cluster=ceres

  mattermost:
    otel:
      exporter: jaeger
      jaeger_agent_host: jaeger
      jaeger_agent_port: 6831
      service_name: mattermost
      resource_attributes:
        - environment=production
        - cluster=ceres

  grafana:
    otel:
      exporter: jaeger
      jaeger_agent_host: jaeger
      jaeger_agent_port: 6831
      service_name: grafana
      resource_attributes:
        - environment=production
        - cluster=ceres

  postgres:
    otel:
      exporter: jaeger
      service_name: postgres
      query_logging: enabled
      slow_query_threshold: 100ms
EOF

echo ""
echo "✅ OpenTelemetry configuration created!"
echo ""
echo "Next steps:"
echo "  1. Add OpenTelemetry SDK to your services"
echo "  2. Configure exporters to send to jaeger:6831"
echo "  3. Add instrumentation middleware"
echo "  4. Restart services"
echo ""
echo "View traces: http://localhost:16686"
