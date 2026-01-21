# SSO Integration Setup Complete

## 📋 Summary

CERES v3.1.0 upgrade completed with SSO infrastructure deployed:

- ✅ Keycloak 23.0.0 running (dev mode with H2 database)
- ✅ OAuth2 Proxy deployed (2 replicas)
- ✅ Domain-based Ingress configured for all services
- ✅ TLS certificates via Cert-Manager
- ✅ Platform health: 39/41 services Running (95%)

## 🔐 Keycloak Access

**Admin Console:** `http://192.168.1.3:30080/auth` or `http://keycloak.ceres.local` (after hosts config)

**Credentials:**
- Username: `admin`
- Password: `K3yClo@k!2025`

## 🌐 Domain Configuration

Add to `/etc/hosts` on your client machine:

```
192.168.1.3 keycloak.ceres.local gitlab.ceres.local grafana.ceres.local
192.168.1.3 chat.ceres.local files.ceres.local wiki.ceres.local
192.168.1.3 mail.ceres.local portainer.ceres.local db.ceres.local
192.168.1.3 minio.ceres.local prometheus.ceres.local projects.ceres.local vault.ceres.local
```

## 🔧 Manual Realm Import Required

Due to Keycloak container limitations (no `tar` utility), realm import must be done manually:

### Option 1: Via Web UI (Recommended)
1. Login to Keycloak Admin Console
2. Hover over "Master" realm dropdown (top-left)
3. Click "Create Realm"
4. Click "Browse" and select `/root/Ceres/config/keycloak-realm.json` (download from server first)
5. Click "Create"

### Option 2: Via REST API
```bash
# On server
POD=$(kubectl get pods -n ceres -l app=keycloak -o jsonpath='{.items[0].metadata.name}')

# Get admin token
TOKEN=$(kubectl exec -n ceres $POD -- curl -s -X POST \
  http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=K3yClo@k!2025" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

# Import realm
kubectl exec -n ceres $POD -- curl -X POST \
  http://localhost:8080/admin/realms \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @/opt/keycloak/data/import/realm.json
```

## 🔗 Service Integration

### Services with Direct OIDC Support

**GitLab**
1. Edit GitLab config: `kubectl edit configmap gitlab-config -n gitlab`
2. Add OIDC provider configuration (see `/root/Ceres/config/sso-configs.yaml`)
3. Restart: `kubectl rollout restart deployment/gitlab -n gitlab`

**Grafana**
1. Edit Grafana config: `kubectl edit configmap grafana -n monitoring`
2. Add `[auth.generic_oauth]` section
3. Restart: `kubectl rollout restart deployment/grafana -n monitoring`

**Mattermost**
1. Login as admin → System Console → Authentication → GitLab
2. Configure with Keycloak endpoints
3. Client ID: `mattermost`

**Nextcloud** (Auto-configurable)
Run: `/root/Ceres/bin/ceres sso integrate nextcloud`

**Wiki.js**
1. Login as admin → Administration → Authentication → OpenID Connect
2. Configure with Keycloak endpoints
3. Client ID: `wikijs`

### Services via OAuth2 Proxy

These services are automatically protected when accessing via domain names:
- Mailcow (`mail.ceres.local`)
- Portainer (`portainer.ceres.local`)
- Adminer (`db.ceres.local`)
- MinIO (`minio.ceres.local`)
- Prometheus (`prometheus.ceres.local`)

## 📝 Keycloak Realm Configuration

Pre-configured in `keycloak-realm.json`:

**Clients:**
- `gitlab` - GitLab OIDC
- `grafana` - Grafana OAuth
- `mattermost` - Mattermost OIDC
- `wikijs` - Wiki.js OIDC
- `nextcloud` - Nextcloud OIDC
- `oauth2-proxy` - OAuth2 Proxy for other services

**Roles:**
- `admin` - Administrator
- `user` - Standard user
- `developer` - Developer access

**Default User:**
- Username: `admin`
- Password: `Ceres@2025!`
- Roles: admin, user, developer

## 🎯 Next Steps

1. **Import Keycloak realm** (see above)
2. **Configure DNS/hosts** file
3. **Integrate services** with Keycloak:
   ```bash
   /root/Ceres/bin/ceres sso integrate gitlab
   /root/Ceres/bin/ceres sso integrate grafana
   /root/Ceres/bin/ceres sso integrate mattermost
   /root/Ceres/bin/ceres sso integrate wikijs
   /root/Ceres/bin/ceres sso integrate nextcloud
   ```
4. **Test SSO login** on each service

## 🔍 Verification Commands

```bash
# Check Keycloak status
kubectl get pods -n ceres -l app=keycloak
kubectl logs -n ceres -l app=keycloak --tail=20

# Check OAuth2 Proxy
kubectl get pods -n oauth2-proxy
kubectl logs -n oauth2-proxy -l app=oauth2-proxy

# Check Ingress routes
kubectl get ingress --all-namespaces

# Test Keycloak API
curl http://192.168.1.3:30080/auth/realms/master

# Platform health
/root/Ceres/bin/ceres health
```

## ⚙️ Technical Details

**Keycloak Deployment:**
- Mode: Development (`start-dev`)
- Database: H2 (in-memory, persisted to PVC)
- Security: Privileged container (K3s AppArmor compatibility)
- Storage: 5Gi PVC at `/opt/keycloak/data`

**OAuth2 Proxy:**
- Replicas: 2
- Provider: Keycloak OIDC
- Cookie domain: `.ceres.local`
- Session expiry: 168h (7 days)

**Ingress Configuration:**
- TLS: Cert-Manager with selfsigned-issuer
- SSL redirect: Enabled
- Specific host routing per service

## 🐛 Troubleshooting

**Keycloak not starting:**
```bash
kubectl describe pod -n ceres -l app=keycloak
kubectl logs -n ceres -l app=keycloak
```

**OAuth2 Proxy errors:**
```bash
kubectl logs -n oauth2-proxy -l app=oauth2-proxy
```

**Service integration failing:**
1. Verify Keycloak realm imported
2. Check client secrets: Login to Keycloak → Clients → [client] → Credentials
3. Verify service configuration matches Keycloak endpoints

**DNS resolution:**
- Ensure `/etc/hosts` configured correctly
- Alternative: Use NodePort `http://192.168.1.3:30080/auth`

## 📚 References

- Keycloak Documentation: https://www.keycloak.org/docs/latest/
- OAuth2 Proxy: https://oauth2-proxy.github.io/oauth2-proxy/
- CERES Technical Spec: `/root/Ceres/TECHNICAL_SPECIFICATION.md`
- SSO Configs: `/root/Ceres/config/sso-configs.yaml`

---

**Status:** ✅ Infrastructure Complete | ⏳ Manual Configuration Required
**Date:** 2026-01-21
**Version:** CERES v3.1.0
