#!/bin/bash
# Network Policy Enforcement for CERES using iptables
# Implements Zero Trust network segmentation

set -e

echo "🔒 Enforcing CERES Network Policies"
echo "===================================="

# Get Docker network bridge names
DMZ_BRIDGE="br-ceres-dmz"
CORE_BRIDGE="br-ceres-core"
APPS_BRIDGE="br-ceres-apps"
MONITORING_BRIDGE="br-ceres-monitoring"
MGMT_BRIDGE="br-ceres-mgmt"

# Clear existing rules
iptables -F DOCKER-USER 2>/dev/null || true
iptables -N DOCKER-USER 2>/dev/null || true

echo "✓ Cleared existing rules"

# Default policy: DENY ALL between networks
iptables -A DOCKER-USER -j DROP -m comment --comment "CERES: Default Deny"

echo "✓ Default deny policy applied"

# DMZ → Apps (Caddy can reach apps)
iptables -I DOCKER-USER -i $DMZ_BRIDGE -o $APPS_BRIDGE -p tcp --dport 80 -j ACCEPT -m comment --comment "CERES: DMZ to Apps HTTP"
iptables -I DOCKER-USER -i $DMZ_BRIDGE -o $APPS_BRIDGE -p tcp --dport 443 -j ACCEPT -m comment --comment "CERES: DMZ to Apps HTTPS"

# Apps → Core (Apps can reach database)
iptables -I DOCKER-USER -i $APPS_BRIDGE -o $CORE_BRIDGE -p tcp --dport 5432 -j ACCEPT -m comment --comment "CERES: Apps to PostgreSQL"
iptables -I DOCKER-USER -i $APPS_BRIDGE -o $CORE_BRIDGE -p tcp --dport 6379 -j ACCEPT -m comment --comment "CERES: Apps to Redis"

# Monitoring → Core (Exporters can scrape)
iptables -I DOCKER-USER -i $MONITORING_BRIDGE -o $CORE_BRIDGE -p tcp --dport 9187 -j ACCEPT -m comment --comment "CERES: Monitoring to PG Exporter"
iptables -I DOCKER-USER -i $MONITORING_BRIDGE -o $CORE_BRIDGE -p tcp --dport 9121 -j ACCEPT -m comment --comment "CERES: Monitoring to Redis Exporter"

# Monitoring → Apps (Prometheus scraping)
iptables -I DOCKER-USER -i $MONITORING_BRIDGE -o $APPS_BRIDGE -p tcp --dport 8080 -j ACCEPT -m comment --comment "CERES: Monitoring to Apps metrics"

# Management → All (Admin access)
iptables -I DOCKER-USER -i $MGMT_BRIDGE -o $CORE_BRIDGE -j ACCEPT -m comment --comment "CERES: Management to Core"
iptables -I DOCKER-USER -i $MGMT_BRIDGE -o $APPS_BRIDGE -j ACCEPT -m comment --comment "CERES: Management to Apps"
iptables -I DOCKER-USER -i $MGMT_BRIDGE -o $MONITORING_BRIDGE -j ACCEPT -m comment --comment "CERES: Management to Monitoring"

# Allow established connections
iptables -I DOCKER-USER -m state --state ESTABLISHED,RELATED -j ACCEPT -m comment --comment "CERES: Allow established"

# Allow loopback
iptables -I DOCKER-USER -i lo -j ACCEPT -m comment --comment "CERES: Allow loopback"

# Logging denied packets (for debugging)
iptables -A DOCKER-USER -m limit --limit 5/min -j LOG --log-prefix "CERES-BLOCKED: " --log-level 4

echo "✓ Network policies applied"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     ZERO TRUST NETWORK POLICIES ACTIVE!                    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Policy Summary:"
echo "  ✓ DMZ → Apps (HTTP/HTTPS only)"
echo "  ✓ Apps → Core (PostgreSQL, Redis only)"
echo "  ✓ Monitoring → Core (Exporters only)"
echo "  ✓ Monitoring → Apps (Metrics scraping)"
echo "  ✓ Management → All (Admin access)"
echo "  ✗ Everything else DENIED"
echo ""
echo "View rules: iptables -L DOCKER-USER -v -n"
echo "Monitor blocks: tail -f /var/log/kern.log | grep CERES-BLOCKED"

# Keep running to maintain policies
trap 'echo "Stopping policy enforcement..."; exit 0' SIGTERM SIGINT
tail -f /dev/null
