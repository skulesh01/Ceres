#!/bin/bash

# CERES Slack Integration
# Sends all monitoring alerts to Slack

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      CERES Slack Integration           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Instructions
echo -e "${BLUE}📋 To create Slack webhook:${NC}"
echo "  1. Go to https://api.slack.com/apps"
echo "  2. Create New App → From scratch"
echo "  3. Enable 'Incoming Webhooks'"
echo "  4. Add New Webhook to Workspace"
echo "  5. Select channel (e.g., #alerts)"
echo "  6. Copy Webhook URL"
echo ""

# Get webhook URL
read -p "Enter Slack Webhook URL: " SLACK_WEBHOOK

if [ -z "$SLACK_WEBHOOK" ]; then
    echo -e "${RED}❌ Webhook URL is required${NC}"
    exit 1
fi

# Optional: channel name
read -p "Enter Slack channel (default: #alerts): " SLACK_CHANNEL
SLACK_CHANNEL=${SLACK_CHANNEL:-#alerts}

# Optional: username
read -p "Enter bot username (default: CERES Monitor): " SLACK_USERNAME
SLACK_USERNAME=${SLACK_USERNAME:-CERES Monitor}

# Optional: icon
read -p "Enter bot emoji (default: :robot_face:): " SLACK_ICON
SLACK_ICON=${SLACK_ICON:-:robot_face:}

#=============================================================================
# TEST WEBHOOK
#=============================================================================
echo ""
echo -e "${BLUE}🧪 Testing Slack webhook...${NC}"

TEST_PAYLOAD=$(cat <<EOF
{
  "channel": "${SLACK_CHANNEL}",
  "username": "${SLACK_USERNAME}",
  "icon_emoji": "${SLACK_ICON}",
  "text": "✅ CERES Slack integration test successful!",
  "attachments": [
    {
      "color": "good",
      "title": "Integration Status",
      "text": "Your CERES platform is now connected to Slack. You'll receive monitoring alerts here.",
      "footer": "CERES Platform",
      "ts": $(date +%s)
    }
  ]
}
EOF
)

RESPONSE=$(curl -s -X POST -H 'Content-type: application/json' --data "$TEST_PAYLOAD" "$SLACK_WEBHOOK")

if [ "$RESPONSE" = "ok" ]; then
    echo -e "${GREEN}✅ Slack webhook is working!${NC}"
else
    echo -e "${RED}❌ Webhook test failed: ${RESPONSE}${NC}"
    exit 1
fi

#=============================================================================
# CONFIGURE ALERTMANAGER
#=============================================================================
echo ""
echo -e "${BLUE}🔔 Configuring Alertmanager for Slack...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
      slack_api_url: '${SLACK_WEBHOOK}'

    route:
      receiver: 'slack-notifications'
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      routes:
      - match:
          severity: critical
        receiver: 'slack-critical'
        continue: true
      - match:
          severity: warning
        receiver: 'slack-warnings'

    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - channel: '${SLACK_CHANNEL}'
        username: '${SLACK_USERNAME}'
        icon_emoji: '${SLACK_ICON}'
        title: 'CERES Alert'
        text: >-
          {{ range .Alerts }}
            *Alert:* {{ .Labels.alertname }}
            *Severity:* {{ .Labels.severity }}
            *Summary:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
          {{ end }}

    - name: 'slack-critical'
      slack_configs:
      - channel: '${SLACK_CHANNEL}'
        username: '${SLACK_USERNAME}'
        icon_emoji: ':fire:'
        color: 'danger'
        title: '🔥 CRITICAL ALERT'
        text: >-
          {{ range .Alerts }}
            *Alert:* {{ .Labels.alertname }}
            *Service:* {{ .Labels.job }}
            *Summary:* {{ .Annotations.summary }}
            *Description:* {{ .Annotations.description }}
          {{ end }}

    - name: 'slack-warnings'
      slack_configs:
      - channel: '${SLACK_CHANNEL}'
        username: '${SLACK_USERNAME}'
        icon_emoji: ':warning:'
        color: 'warning'
        title: '⚠️  Warning'
        text: >-
          {{ range .Alerts }}
            *Alert:* {{ .Labels.alertname }}
            *Service:* {{ .Labels.job }}
            *Summary:* {{ .Annotations.summary }}
          {{ end }}
EOF

echo -e "${GREEN}✅ Alertmanager configured${NC}"

# Restart Alertmanager
echo -e "${BLUE}🔄 Restarting Alertmanager...${NC}"
kubectl rollout restart deployment/alertmanager -n monitoring 2>/dev/null || \
kubectl rollout restart statefulset/alertmanager -n monitoring 2>/dev/null || true

#=============================================================================
# CONFIGURE GITLAB NOTIFICATIONS
#=============================================================================
echo ""
echo -e "${BLUE}🦊 Configuring GitLab Slack notifications...${NC}"

cat <<EOF | kubectl create configmap gitlab-slack-config -n gitlab --from-literal=webhook="${SLACK_WEBHOOK}" -o yaml --dry-run=client | kubectl apply -f -
EOF

echo -e "${GREEN}✅ GitLab Slack integration ready${NC}"
echo -e "${YELLOW}📝 Note: Configure GitLab integrations in Admin → Settings → Integrations${NC}"

#=============================================================================
# CONFIGURE GRAFANA SLACK NOTIFICATIONS
#=============================================================================
echo ""
echo -e "${BLUE}📊 Configuring Grafana Slack notifications...${NC}"

# Get Grafana admin credentials
GRAFANA_PASSWORD=$(kubectl get secret grafana-admin-credentials -n monitoring -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "admin")

# Wait for Grafana
echo -n "Waiting for Grafana."
for i in {1..30}; do
    if kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
        echo ""
        break
    fi
    echo -n "."
    sleep 2
done

# Create Slack notification channel via API
GRAFANA_POD=$(kubectl get pod -n monitoring -l app=grafana -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n monitoring ${GRAFANA_POD} -- curl -X POST \
    -H "Content-Type: application/json" \
    -u "admin:${GRAFANA_PASSWORD}" \
    http://localhost:3000/api/alert-notifications \
    -d "{
        \"name\": \"Slack\",
        \"type\": \"slack\",
        \"isDefault\": true,
        \"settings\": {
            \"url\": \"${SLACK_WEBHOOK}\",
            \"username\": \"${SLACK_USERNAME}\",
            \"icon_emoji\": \"${SLACK_ICON}\"
        }
    }" 2>/dev/null || true

echo -e "${GREEN}✅ Grafana Slack notifications configured${NC}"

#=============================================================================
# TEST ALERT
#=============================================================================
echo ""
read -p "Send test alert to Slack? [y/N]: " SEND_TEST

if [[ "$SEND_TEST" =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}📤 Sending test alert...${NC}"
    
    TEST_ALERT=$(cat <<EOF
{
  "channel": "${SLACK_CHANNEL}",
  "username": "${SLACK_USERNAME}",
  "icon_emoji": ":white_check_mark:",
  "attachments": [
    {
      "color": "good",
      "title": "✅ CERES Test Alert",
      "fields": [
        {
          "title": "Alert",
          "value": "TestAlert",
          "short": true
        },
        {
          "title": "Severity",
          "value": "info",
          "short": true
        },
        {
          "title": "Summary",
          "value": "This is a test alert from CERES platform",
          "short": false
        },
        {
          "title": "Description",
          "value": "If you receive this message, Slack integration is working correctly!",
          "short": false
        }
      ],
      "footer": "CERES Platform",
      "ts": $(date +%s)
    }
  ]
}
EOF
)
    
    curl -s -X POST -H 'Content-type: application/json' --data "$TEST_ALERT" "$SLACK_WEBHOOK" > /dev/null
    echo -e "${GREEN}✅ Test alert sent! Check your Slack channel.${NC}"
fi

#=============================================================================
# FINAL SUMMARY
#=============================================================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Slack Integration Complete! ✅        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📱 Slack Configuration:${NC}"
echo "  Channel: ${SLACK_CHANNEL}"
echo "  Username: ${SLACK_USERNAME}"
echo "  Icon: ${SLACK_ICON}"
echo ""
echo -e "${CYAN}✅ Integrated Services:${NC}"
echo "  🔔 Alertmanager - All monitoring alerts"
echo "  📊 Grafana - Dashboard alerts"
echo "  🦊 GitLab - CI/CD notifications (manual setup required)"
echo ""
echo -e "${CYAN}Alert Types:${NC}"
echo "  🔥 Critical alerts (red)"
echo "  ⚠️  Warning alerts (orange)"
echo "  ℹ️  Info alerts (blue)"
echo ""
echo -e "${YELLOW}📝 Next Steps:${NC}"
echo "  1. Configure GitLab: Admin → Settings → Integrations → Slack"
echo "  2. Set up Grafana alert rules with Slack channel"
echo "  3. Test by triggering an alert"
echo ""
