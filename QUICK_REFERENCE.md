# 🚀 CERES Quick Reference

**One-page cheat sheet for daily operations**

---

## 📦 Deployment

```bash
# Full automated deployment (recommended)
./deploy-platform.sh -y

# Interactive deployment
./deploy-platform.sh

# Skip specific steps
./deploy-platform.sh --skip-ssl --skip-backup
```

---

## 🏥 Health Checks

```bash
# Quick health check
./scripts/health-check.sh

# Pod status
kubectl get pods -A

# Resource usage
kubectl top nodes
kubectl top pods -A
```

---

## 🔒 SSL/TLS

```bash
# Configure SSL
./scripts/configure-ssl.sh

# Check certificate status
kubectl get certificate -A
kubectl describe certificate ceres-tls -n ceres

# Verify HTTPS
curl -k https://YOUR_DOMAIN
```

---

## 🔐 SSO (Keycloak)

```bash
# Configure SSO
./scripts/configure-sso.sh

# Access Keycloak admin
http://keycloak.ceres.local/admin
# Login: admin / admin123

# Get client secret
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh get clients -r ceres --fields id,clientId

# Create user
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh create users -r ceres \
  -s username=newuser \
  -s email=user@example.com \
  -s enabled=true
```

---

## 💾 Backups

```bash
# Configure automated backups
./scripts/configure-backup.sh

# List backups
kubectl get backups -n velero

# Create manual backup
kubectl create -f - <<EOF
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: manual-$(date +%Y%m%d-%H%M%S)
  namespace: velero
spec:
  includedNamespaces:
  - '*'
  ttl: 720h0m0s
EOF

# Check backup status
kubectl describe backup BACKUP_NAME -n velero
```

---

## 🔄 Rollback

```bash
# Restore from backup
./scripts/rollback.sh

# Manual restore
kubectl create -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-$(date +%Y%m%d-%H%M%S)
  namespace: velero
spec:
  backupName: BACKUP_NAME
  includedNamespaces:
  - '*'
EOF
```

---

## 🔄 Updates

```bash
# Check for updates
./scripts/update.sh

# Manual update
git pull origin main
kubectl apply -f deployment/
```

---

## 📊 Logs

```bash
# View logs for specific service
kubectl logs -n ceres deployment/keycloak --tail=100 -f

# All containers in namespace
kubectl logs -n gitlab --all-containers=true --tail=50

# Logs from last hour
kubectl logs --since=1h deployment/grafana -n monitoring

# Previous container (after crash)
kubectl logs deployment/keycloak -n ceres --previous
```

---

## 🔍 Troubleshooting

### Service Not Accessible

```bash
# Check ingress
kubectl get ingress -A
kubectl describe ingress keycloak -n ceres

# Check Traefik
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik

# Run ingress fix
./scripts/fix-ingress.sh
```

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n ceres

# Describe pod
kubectl describe pod POD_NAME -n ceres

# Check events
kubectl get events -n ceres --sort-by='.lastTimestamp'

# Restart deployment
kubectl rollout restart deployment DEPLOYMENT_NAME -n ceres
```

### Out of Resources

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A --sort-by=memory

# Scale down non-critical services
kubectl scale deployment gitlab -n gitlab --replicas=0

# Clean up
kubectl delete pods --field-selector=status.phase=Succeeded -A
kubectl delete pods --field-selector=status.phase=Failed -A
```

---

## 🌐 Access URLs

**Direct IP:**
```
http://YOUR_SERVER_IP/
```

**Domain-based (add to /etc/hosts):**
```
YOUR_SERVER_IP keycloak.ceres.local gitlab.ceres.local grafana.ceres.local
```

**Services:**
- **Keycloak**: http://keycloak.ceres.local/
- **GitLab**: http://gitlab.ceres.local/
- **Grafana**: http://grafana.ceres.local/
- **Prometheus**: http://prometheus.ceres.local/
- **Mattermost**: http://chat.ceres.local/
- **Nextcloud**: http://files.ceres.local/
- **Wiki.js**: http://wiki.ceres.local/
- **MinIO**: http://minio.ceres.local/
- **Portainer**: http://portainer.ceres.local/
- **Vault**: http://vault.ceres.local/

---

## 🔑 Default Credentials

**Keycloak:**
- Admin: `admin` / `admin123`
- Demo user: `demo` / `demo123`

**MinIO:**
- Admin: `minioadmin` / `MinIO@Admin2025`

**⚠️ CHANGE THESE PASSWORDS IN PRODUCTION!**

---

## ⚙️ Common Tasks

### Add New User

```bash
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh create users -r ceres \
  -s username=USERNAME \
  -s email=EMAIL \
  -s firstName=FIRST \
  -s lastName=LAST \
  -s enabled=true

# Set password
kubectl exec -n ceres deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh set-password -r ceres \
  --username USERNAME \
  --new-password PASSWORD
```

### Scale Deployment

```bash
# Scale up
kubectl scale deployment keycloak -n ceres --replicas=3

# Scale down
kubectl scale deployment gitlab -n gitlab --replicas=0

# Auto-scale
kubectl autoscale deployment keycloak -n ceres --min=2 --max=5 --cpu-percent=80
```

### Restart Service

```bash
# Restart deployment
kubectl rollout restart deployment keycloak -n ceres

# Restart all in namespace
kubectl rollout restart deployment -n ceres

# Delete pod (auto-recreated)
kubectl delete pod POD_NAME -n ceres
```

### Update Image

```bash
# Update to specific version
kubectl set image deployment/keycloak -n ceres \
  keycloak=quay.io/keycloak/keycloak:23.0.0

# Update to latest
kubectl set image deployment/keycloak -n ceres \
  keycloak=quay.io/keycloak/keycloak:latest

# Rollback
kubectl rollout undo deployment/keycloak -n ceres
```

---

## 🔧 Maintenance

### Daily
```bash
./scripts/health-check.sh
```

### Weekly
```bash
kubectl get backups -n velero
./scripts/update.sh
```

### Monthly
```bash
# Security updates
kubectl rollout restart deployment -n ceres

# Clean old images
k3s crictl rmi --prune

# Check disk space
df -h
```

---

## 📞 Support

**Documentation:**
- [Quick Start](QUICKSTART.md)
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Architecture](ARCHITECTURE_ANALYSIS.md)
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md)

**GitHub:**
- Repository: https://github.com/skulesh01/Ceres
- Issues: https://github.com/skulesh01/Ceres/issues

---

**Last updated**: v3.1.0 (January 22, 2026)
