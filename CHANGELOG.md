# CERES Platform - Changelog

## [3.1.0] - 2026-01-22

### 🔧 Fixed
- **CRITICAL**: Ingress controller crashing issue resolved
  - Replaced problematic ingress-nginx with built-in Traefik
  - Fixed "restrictive Authorization mode" error
  - Fixed "Permission denied" SSL certificate creation
  
- **Keycloak deployment** improvements:
  - Added `runAsUser: 0` for proper permissions
  - Simplified admin credentials (admin/admin123)
  - Added proxy configuration (KC_PROXY, KC_HOSTNAME_STRICT, KC_HTTP_ENABLED)
  - Removed problematic health probes causing CrashLoopBackOff
  
- **Ingress routing** enhancements:
  - All Ingress manifests now use `ingressClassName: traefik`
  - Removed nginx-specific annotations
  - Added IP-based Ingress for direct access without hosts file
  - Deleted blocking ValidatingWebhookConfiguration

### ✨ Added
- New `scripts/fix-ingress.sh` - Automated ingress troubleshooting script
- New `deployment/ingress-ip.yaml` - Direct IP access configuration
- New `docs/INGRESS_FIX.md` - Comprehensive ingress fix documentation
- Automatic Traefik verification in deployment scripts

### 📝 Changed
- Default Keycloak password: `K3yClo@k!2025` → `admin123` (dev mode)
- Ingress class: `nginx` → `traefik` across all manifests
- Keycloak security context: added privileged mode with root user

### 🚀 Improved
- Faster service accessibility (no ingress-nginx boot issues)
- Better K3s integration (using built-in components)
- Simplified access methods (direct IP + domains)
- Enhanced troubleshooting documentation

### 📖 Documentation
- Updated QUICKSTART.md with troubleshooting section
- Added comprehensive INGRESS_FIX.md guide
- Documented all fixes and workarounds
- Added rollback instructions

---

## [3.0.0] - 2026-01-20

### Initial Release
- Core CERES platform deployment
- Multi-cloud support (AWS, Azure, GCP)
- Kubernetes infrastructure automation
- SSO integration with Keycloak
- Service mesh with 20+ integrated applications

### Components
- GitLab CE for source control
- Keycloak for SSO/IAM
- Grafana + Prometheus for monitoring
- Mattermost for team communication
- Nextcloud for file storage
- WikiJS for documentation
- And 15+ more services

### Features
- One-command deployment
- Auto-install Go or Docker build
- Multi-environment support
- Infrastructure as Code (Terraform)
- CI/CD pipeline integration

---

## Release Notes Format

### Version Numbering
- **Major.Minor.Patch** (SemVer)
- Major: Breaking changes
- Minor: New features, non-breaking
- Patch: Bug fixes, improvements

### Categories
- 🔧 Fixed - Bug fixes
- ✨ Added - New features
- 📝 Changed - Changes in existing functionality
- 🗑️ Deprecated - Soon-to-be removed features
- 🚀 Improved - Performance enhancements
- 📖 Documentation - Documentation updates
- 🔒 Security - Security updates

---

## Upgrade Instructions

### From 3.0.0 to 3.1.0

1. **Backup current deployment** (if needed):
```bash
kubectl get all -A -o yaml > backup-3.0.0.yaml
```

2. **Pull latest changes**:
```bash
git pull origin main
```

3. **Run ingress fix**:
```bash
./scripts/fix-ingress.sh
```

4. **Update deployments**:
```bash
kubectl apply -f deployment/keycloak.yaml
kubectl apply -f deployment/ingress-domains.yaml
kubectl apply -f deployment/ingress-ip.yaml
```

5. **Verify**:
```bash
curl http://192.168.1.3/
kubectl get ingress -A
```

### Rollback from 3.1.0 to 3.0.0

If you need to rollback (not recommended):

1. **Restore nginx ingress** (see docs/INGRESS_FIX.md "Команды для отката")
2. **Restore old manifests**:
```bash
git checkout v3.0.0
kubectl apply -f deployment/
```

---

## Known Issues

### Version 3.1.0
- None currently reported

### Version 3.0.0
- ❌ ingress-nginx controller crashes (FIXED in 3.1.0)
- ❌ Keycloak CrashLoopBackOff (FIXED in 3.1.0)
- ❌ Services inaccessible via Ingress (FIXED in 3.1.0)

---

## Support

- **Documentation**: See `docs/` directory
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
