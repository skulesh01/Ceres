# 🚀 CERES Platform - Complete Deployment Guide

**Version**: 3.1.0  
**Target Audience**: System Administrators, DevOps Engineers  
**Deployment Time**: 30 minutes (automated) to 2 hours (with customization)

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start (30 minutes)](#quick-start)
3. [Detailed Deployment](#detailed-deployment)
4. [Post-Deployment Configuration](#post-deployment)
5. [Maintenance](#maintenance)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Minimum System Requirements

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **CPU** | 4 cores | 8+ cores | More cores = faster deployments |
| **RAM** | 16 GB | 32+ GB | Critical for multiple services |
| **Disk** | 100 GB | 500+ GB SSD | SSD strongly recommended |
| **Network** | 100 Mbps | 1 Gbps | For downloads and service communication |

### Software Requirements

- **Kubernetes**: K3s v1.28+ (recommended) or K8s v1.28+
- **kubectl**: Latest version
- **Helm**: v3.12+ (optional but recommended)
- **Linux**: Ubuntu 22.04 LTS, Debian 12, RHEL 9, or similar

### Network Requirements

- Open ports: 80, 443, 6443
- Internet access (for initial setup)
- Static IP or DDNS for production

---

## Quick Start

### Option 1: Fully Automated (Recommended)

```bash
# 1. Clone repository
git clone https://github.com/skulesh01/Ceres.git
cd Ceres

# 2. Run automated deployment
chmod +x deploy-platform.sh
./deploy-platform.sh -y

# 3. Access platform
# http://YOUR_SERVER_IP/
# Login: admin / admin123
```

**That's it!** 🎉 Platform will be deployed in ~30 minutes.

### Option 2: Step-by-Step

```bash
# 1. Pre-flight check
./scripts/preflight-check.sh

# 2. Deploy core platform
kubectl apply -f deployment/all-services.yaml
kubectl apply -f deployment/keycloak.yaml
kubectl apply -f deployment/ingress-domains.yaml
kubectl apply -f deployment/ingress-ip.yaml

# 3. Configure SSL
./scripts/configure-ssl.sh

# 4. Configure SSO
./scripts/configure-sso.sh

# 5. Setup backups
./scripts/configure-backup.sh

# 6. Health check
./scripts/health-check.sh
```

---

## Detailed Deployment

### Phase 1: Preparation (5 minutes)

#### 1.1 Install K3s (if not already installed)

```bash
# On your target server
curl -sfL https://get.k3s.io | sh -

# Verify installation
kubectl get nodes
```

#### 1.2 Configure kubectl (for remote management)

```bash
# Copy K3s config from server
scp root@YOUR_SERVER:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Edit config to use server IP
sed -i 's/127.0.0.1/YOUR_SERVER_IP/g' ~/.kube/config

# Test connection
kubectl get nodes
```

#### 1.3 Run pre-flight checks

```bash
./scripts/preflight-check.sh
```

Expected output:
```
✅ RAM: 32GB
✅ CPU cores: 8
✅ Disk space: 250GB free
✅ kubectl installed: v1.28.0
✅ Kubernetes cluster accessible
```

### Phase 2: Core Deployment (10-15 minutes)

#### 2.1 Deploy infrastructure services

```bash
# PostgreSQL and Redis (databases)
kubectl apply -f deployment/postgresql.yaml
kubectl apply -f deployment/redis.yaml

# Wait for databases to be ready
kubectl wait --for=condition=ready pod -l app=postgresql --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis --timeout=300s
```

#### 2.2 Deploy application services

```bash
# Deploy all services at once
kubectl apply -f deployment/all-services.yaml

# Or deploy individually for more control
kubectl apply -f deployment/keycloak.yaml
kubectl apply -f deployment/gitlab.yaml
kubectl apply -f deployment/grafana.yaml
# ... etc
```

#### 2.3 Setup Ingress routing

```bash
# Domain-based routing
kubectl apply -f deployment/ingress-domains.yaml

# Direct IP access
kubectl apply -f deployment/ingress-ip.yaml

# Verify ingress
kubectl get ingress -A
```

Expected output:
```
NAMESPACE    NAME       CLASS     HOSTS                    ADDRESS
ceres        keycloak   traefik   keycloak.ceres.local     192.168.1.3
gitlab       gitlab     traefik   gitlab.ceres.local       192.168.1.3
...
```

### Phase 3: SSL/TLS Configuration (5 minutes)

#### 3.1 Automated SSL setup

```bash
./scripts/configure-ssl.sh
```

Choose certificate type:
- **Option 1**: Let's Encrypt Production (requires public domain)
- **Option 2**: Let's Encrypt Staging (for testing)
- **Option 3**: Self-signed (for local/development) ← **Recommended for first deployment**

#### 3.2 Manual SSL configuration

For advanced users who want custom certificates:

```yaml
# Create TLS secret
kubectl create secret tls ceres-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n ceres

# Update ingress to use certificate
kubectl patch ingress keycloak -n ceres \
  --type=merge \
  -p '{"spec":{"tls":[{"hosts":["keycloak.ceres.local"],"secretName":"ceres-tls"}]}}'
```

### Phase 4: SSO Integration (10-15 minutes)

#### 4.1 Automated SSO setup

```bash
./scripts/configure-sso.sh
```

This will:
- Import Keycloak realm
- Create OIDC clients for all services
- Create demo user account
- Configure basic SSO settings

#### 4.2 Manual service integration

For each service, get the client secret:

```bash
# Get client secret for GitLab
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh get clients/GITLAB_CLIENT_ID/client-secret \
  --config /tmp/kcadm.config
```

Then configure the service. Example for **GitLab**:

```ruby
# gitlab.rb configuration
gitlab_rails['omniauth_providers'] = [
  {
    name: 'openid_connect',
    label: 'CERES SSO',
    args: {
      name: 'openid_connect',
      scope: ['openid','profile','email'],
      response_type: 'code',
      issuer: 'http://keycloak.ceres.local/realms/ceres',
      client_auth_method: 'query',
      uid_field: 'preferred_username',
      client_options: {
        identifier: 'gitlab',
        secret: 'YOUR_CLIENT_SECRET_HERE',
        redirect_uri: 'http://gitlab.ceres.local/users/auth/openid_connect/callback'
      }
    }
  }
]
```

### Phase 5: Backup Configuration (5 minutes)

#### 5.1 Setup automated backups

```bash
./scripts/configure-backup.sh
```

This creates:
- Daily backups at 2:00 AM (retention: 30 days)
- Weekly backups on Sundays at 3:00 AM (retention: 90 days)
- Backup storage in MinIO (S3-compatible)

#### 5.2 Verify backup configuration

```bash
# List backup schedules
kubectl get schedules -n velero

# List existing backups
kubectl get backups -n velero

# Create manual backup
kubectl create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%Y%m%d)
  namespace: velero
spec:
  includedNamespaces:
  - ceres
  ttl: 720h0m0s
EOF
```

---

## Post-Deployment

### 1. Access Your Platform

#### Direct IP access (no configuration needed):
```
http://YOUR_SERVER_IP/
```

#### Domain-based access:

**On Linux/Mac:**
```bash
sudo nano /etc/hosts
```

**On Windows (as Administrator):**
```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```

Add this line:
```
YOUR_SERVER_IP keycloak.ceres.local gitlab.ceres.local grafana.ceres.local chat.ceres.local files.ceres.local wiki.ceres.local mail.ceres.local
```

Then access:
- Keycloak: http://keycloak.ceres.local/
- GitLab: http://gitlab.ceres.local/
- Grafana: http://grafana.ceres.local/
- etc.

### 2. Change Default Passwords

**CRITICAL**: Change default passwords immediately for production!

```bash
# Keycloak admin
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh set-password \
  --username admin \
  --new-password "YOUR_SECURE_PASSWORD"

# Update deployment
kubectl set env deployment/keycloak -n ceres \
  KEYCLOAK_ADMIN_PASSWORD="YOUR_SECURE_PASSWORD"
```

### 3. Configure Email (Optional)

For notifications and user invitations:

```bash
# Configure SMTP in Keycloak
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh update realms/ceres \
  -s 'smtpServer.host=smtp.gmail.com' \
  -s 'smtpServer.port=587' \
  -s 'smtpServer.from=noreply@yourdomain.com' \
  -s 'smtpServer.auth=true' \
  -s 'smtpServer.user=your-email@gmail.com' \
  -s 'smtpServer.password=your-app-password'
```

### 4. Create User Accounts

#### Via Keycloak Admin UI:
1. Go to http://keycloak.ceres.local/admin
2. Login with admin credentials
3. Select "ceres" realm
4. Click "Users" → "Add user"

#### Via CLI:
```bash
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh create users -r ceres \
  -s username=john.doe \
  -s email=john.doe@company.com \
  -s firstName=John \
  -s lastName=Doe \
  -s enabled=true
```

---

## Maintenance

### Daily Operations

#### Health Monitoring
```bash
# Quick health check
./scripts/health-check.sh

# Detailed pod status
kubectl get pods -A

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

#### Viewing Logs
```bash
# Keycloak logs
kubectl logs -n ceres deployment/keycloak --tail=100 -f

# All services in namespace
kubectl logs -n gitlab --all-containers=true --tail=50

# Specific time range
kubectl logs --since=1h deployment/keycloak -n ceres
```

### Weekly Operations

#### Backup Verification
```bash
# List recent backups
kubectl get backups -n velero --sort-by=.metadata.creationTimestamp

# Verify latest backup
LATEST_BACKUP=$(kubectl get backups -n velero -o jsonpath='{.items[-1].metadata.name}')
kubectl describe backup $LATEST_BACKUP -n velero
```

#### Update Check
```bash
./scripts/update.sh
```

### Monthly Operations

#### Security Updates
```bash
# Update all deployments to latest images
kubectl set image deployment/keycloak -n ceres \
  keycloak=quay.io/keycloak/keycloak:latest

# Or update all at once
for ns in ceres gitlab monitoring mattermost nextcloud wiki; do
  kubectl rollout restart deployment -n $ns
done
```

#### Disaster Recovery Test
```bash
# Test backup restoration (in test environment!)
./scripts/rollback.sh
```

---

## Troubleshooting

### Issue: Services not accessible

**Symptoms**: Cannot access http://YOUR_SERVER_IP/

**Solution**:
```bash
# 1. Check Traefik
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# 2. Check ingress
kubectl get ingress -A

# 3. Run fix script
./scripts/fix-ingress.sh
```

### Issue: Keycloak not starting

**Symptoms**: Pod in CrashLoopBackOff

**Solution**:
```bash
# Check logs
kubectl logs -n ceres deployment/keycloak --previous

# Common fix: permissions
kubectl patch deployment keycloak -n ceres --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/securityContext","value":{"privileged":true,"runAsUser":0}}]'
```

### Issue: Out of disk space

**Symptoms**: Pods being evicted

**Solution**:
```bash
# Check disk usage
df -h

# Clean Docker images (if using Docker)
docker system prune -a

# Clean K3s (if using K3s)
k3s crictl rmi --prune

# Delete old logs
kubectl delete pods --field-selector=status.phase=Succeeded -A
```

### Issue: High memory usage

**Solution**:
```bash
# Identify memory hogs
kubectl top pods -A --sort-by=memory

# Reduce replicas
kubectl scale deployment gitlab -n gitlab --replicas=0  # Temporarily disable GitLab

# Restart high-memory pods
kubectl rollout restart deployment -n nextcloud
```

---

## Advanced Configuration

### High Availability (HA) Setup

For production deployments requiring 99.9%+ uptime:

```bash
# 1. Add more K3s nodes
curl -sfL https://get.k3s.io | K3S_URL=https://MASTER_IP:6443 K3S_TOKEN=YOUR_TOKEN sh -

# 2. Scale deployments
kubectl scale deployment keycloak -n ceres --replicas=3
kubectl scale deployment gitlab -n gitlab --replicas=2

# 3. Configure pod anti-affinity
kubectl patch deployment keycloak -n ceres --patch '
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - keycloak
            topologyKey: kubernetes.io/hostname
'
```

### External Database

Replace in-cluster PostgreSQL with external database:

```yaml
# Update keycloak deployment
env:
- name: KC_DB
  value: postgres
- name: KC_DB_URL
  value: jdbc:postgresql://external-postgres.company.com:5432/keycloak
- name: KC_DB_USERNAME
  value: keycloak
- name: KC_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
```

---

## Next Steps

- ✅ **Security Hardening**: See [SECURITY.md](SECURITY.md)
- ✅ **Performance Tuning**: See [PERFORMANCE.md](PERFORMANCE.md)
- ✅ **Monitoring Setup**: See [MONITORING.md](MONITORING.md)
- ✅ **Backup Strategy**: See [BACKUP.md](BACKUP.md)

---

**Need help?** Open an issue on GitHub or check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
