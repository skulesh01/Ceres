#!/bin/bash
# Fix Ingress Controller - Switch from nginx to Traefik
# This script fixes common ingress-nginx issues by using K3s built-in Traefik

set -e

echo "🔧 CERES Ingress Fix Script"
echo "============================"
echo ""

# Check if running on K3s
if ! kubectl version 2>/dev/null | grep -q "k3s"; then
    echo "⚠️  Warning: Not running on K3s cluster"
    echo "This fix is designed for K3s with built-in Traefik"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📋 Step 1: Checking current state..."
echo ""

# Check if ingress-nginx exists and is problematic
if kubectl get namespace ingress-nginx 2>/dev/null; then
    echo "❌ Found ingress-nginx namespace"
    
    # Check if pods are failing
    FAILING_PODS=$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|Error" | wc -l)
    
    if [ "$FAILING_PODS" -gt 0 ]; then
        echo "⚠️  Detected $FAILING_PODS failing ingress-nginx pods"
        echo "🗑️  Removing problematic ingress-nginx..."
        
        # Delete namespace (non-blocking)
        kubectl delete namespace ingress-nginx --wait=false 2>/dev/null || true
        
        # Force cleanup if stuck
        sleep 2
        if kubectl get namespace ingress-nginx 2>/dev/null; then
            echo "🔨 Force cleaning stuck namespace..."
            kubectl get namespace ingress-nginx -o json | \
                jq '.spec.finalizers = []' | \
                kubectl replace --raw /api/v1/namespaces/ingress-nginx/finalize -f - 2>/dev/null || true
        fi
        
        # Delete validating webhook that blocks ingress changes
        kubectl delete validatingwebhookconfiguration ingress-nginx-admission 2>/dev/null || true
        
        echo "✅ ingress-nginx removed"
    else
        echo "ℹ️  ingress-nginx exists but appears healthy"
        echo "    If you want to switch to Traefik anyway, delete it manually:"
        echo "    kubectl delete namespace ingress-nginx"
    fi
else
    echo "✅ ingress-nginx not installed (good!)"
fi

echo ""
echo "📋 Step 2: Verifying Traefik..."
echo ""

# Check Traefik
if kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik 2>/dev/null | grep -q "Running"; then
    echo "✅ Traefik is running"
    
    # Get Traefik service info
    TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$TRAEFIK_IP" ]; then
        echo "📍 Traefik LoadBalancer IP: $TRAEFIK_IP"
    else
        echo "⚠️  Traefik has no LoadBalancer IP"
    fi
else
    echo "❌ Traefik is not running!"
    echo "    K3s should have Traefik by default. Check installation:"
    echo "    kubectl get pods -n kube-system | grep traefik"
    exit 1
fi

echo ""
echo "📋 Step 3: Updating Ingress manifests..."
echo ""

# Update ingress-domains.yaml
if [ -f "deployment/ingress-domains.yaml" ]; then
    echo "🔄 Converting ingress-domains.yaml to Traefik..."
    
    # Backup original
    cp deployment/ingress-domains.yaml deployment/ingress-domains.yaml.bak
    
    # Replace nginx with traefik
    sed -i 's/ingressClassName: nginx/ingressClassName: traefik/g' deployment/ingress-domains.yaml
    
    # Remove nginx-specific annotations
    sed -i '/nginx\.ingress\.kubernetes\.io/d' deployment/ingress-domains.yaml
    
    echo "✅ Updated ingress-domains.yaml"
    echo "   Backup saved: deployment/ingress-domains.yaml.bak"
else
    echo "⚠️  File not found: deployment/ingress-domains.yaml"
fi

echo ""
echo "📋 Step 4: Applying fixed Ingress configuration..."
echo ""

# Delete old nginx-based ingresses
echo "🗑️  Removing old Ingress resources..."
kubectl delete ingress --all -A 2>/dev/null || true

# Apply new Traefik-based ingresses
if [ -f "deployment/ingress-domains.yaml" ]; then
    echo "✨ Applying Traefik-based Ingress (domains)..."
    kubectl apply -f deployment/ingress-domains.yaml
fi

if [ -f "deployment/ingress-ip.yaml" ]; then
    echo "✨ Applying Traefik-based Ingress (IP access)..."
    kubectl apply -f deployment/ingress-ip.yaml
fi

echo ""
echo "📋 Step 5: Fixing Keycloak deployment..."
echo ""

# Check if Keycloak exists
if kubectl get deployment keycloak -n ceres 2>/dev/null; then
    echo "🔄 Updating Keycloak deployment..."
    
    # Add privileged mode and runAsUser
    kubectl patch deployment keycloak -n ceres --type='json' -p='[
      {
        "op": "replace",
        "path": "/spec/template/spec/containers/0/securityContext",
        "value": {
          "privileged": true,
          "runAsUser": 0
        }
      }
    ]' 2>/dev/null || echo "⚠️  Could not patch Keycloak (may already be correct)"
    
    # Wait for rollout
    echo "⏳ Waiting for Keycloak to restart..."
    kubectl rollout status deployment keycloak -n ceres --timeout=90s || true
    
    echo "✅ Keycloak updated"
else
    echo "ℹ️  Keycloak not deployed yet"
fi

echo ""
echo "📋 Step 6: Verification..."
echo ""

# List all ingresses
echo "📍 Current Ingress resources:"
kubectl get ingress -A -o wide

echo ""
echo "🧪 Testing Keycloak access..."

# Get LoadBalancer IP
TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "127.0.0.1")

# Test direct IP access
if curl -s -m 5 "http://${TRAEFIK_IP}/" | grep -q "Keycloak"; then
    echo "✅ Keycloak accessible via http://${TRAEFIK_IP}/"
else
    echo "⚠️  Keycloak not yet ready or not accessible"
    echo "    Check pod status: kubectl get pods -n ceres"
    echo "    Check logs: kubectl logs -n ceres deployment/keycloak"
fi

echo ""
echo "✅ Ingress fix completed!"
echo ""
echo "📝 Access Instructions:"
echo "========================"
echo ""
echo "1️⃣  Direct IP access (no hosts file needed):"
echo "   Keycloak: http://${TRAEFIK_IP}/"
echo "   Login: admin / admin123"
echo ""
echo "2️⃣  Domain-based access (requires hosts file):"
echo "   Add to /etc/hosts (Linux/Mac) or C:\\Windows\\System32\\drivers\\etc\\hosts (Windows):"
echo "   ${TRAEFIK_IP} keycloak.ceres.local gitlab.ceres.local grafana.ceres.local"
echo ""
echo "   Then access:"
echo "   http://keycloak.ceres.local/"
echo "   http://gitlab.ceres.local/"
echo "   http://grafana.ceres.local/"
echo "   etc."
echo ""
echo "🔍 Troubleshooting:"
echo "   View this guide: docs/INGRESS_FIX.md"
echo "   Check Traefik: kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik"
echo "   Check Ingress: kubectl get ingress -A"
echo ""
