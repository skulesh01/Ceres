# ⚡ CERES - Quick Start Guide

**Version**: 3.1.0  
**Updated**: January 22, 2026

> 🔧 **New in 3.1**: Fixed Ingress controller issues - now using Traefik (built-in K3s)  
> See [INGRESS_FIX.md](docs/INGRESS_FIX.md) for details

---

## 🎯 ONE Command Deployment

### Linux / macOS
```bash
git clone https://github.com/skulesh01/ceres.git
cd ceres
./quick-deploy.sh
```

### Windows
```powershell
git clone https://github.com/skulesh01/ceres.git
cd ceres
.\quick-deploy.ps1
```

**That's it! 🎉** The script will:
- ✅ Auto-detect Docker or install Go
- ✅ Build CERES CLI automatically
- ✅ Show you next steps

---

## 🚀 After Deployment

### 1. Validate
```bash
./bin/ceres validate
```

### 2. Configure
```bash
./bin/ceres config show
```

### 3. Deploy (Dry Run)
```bash
./bin/ceres deploy --dry-run --cloud aws --environment dev
```

### 4. Deploy (Production)
```bash
./bin/ceres deploy --cloud aws --environment prod
```

### 5. Check Status
```bash
./bin/ceres status
```

---

## 📋 Alternative Methods

### Method 1: Docker Build (No Local Go)
```bash
./scripts/docker-build.sh        # Linux/macOS
.\scripts\docker-build.ps1       # Windows
```

### Method 2: Auto-Install Go
```bash
./scripts/setup-go.sh            # Linux/macOS
.\scripts\setup-go.ps1           # Windows
```

### Method 3: Manual (Requires Go 1.21+)
```bash
make build
```

---

## � Troubleshooting

### Ingress Not Working?
If services are not accessible via web browser:
```bash
./scripts/fix-ingress.sh
```

This will:
- ✅ Switch from problematic ingress-nginx to Traefik
- ✅ Fix Keycloak permissions
- ✅ Enable direct IP access (no hosts file needed)

See full guide: [docs/INGRESS_FIX.md](docs/INGRESS_FIX.md)

### Access Services

**Option 1: Direct IP (easiest)**
- Keycloak: `http://192.168.1.3/`
- Login: `admin` / `admin123`

**Option 2: Domains (requires hosts file)**
Add to `/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts`:
```
192.168.1.3 keycloak.ceres.local gitlab.ceres.local grafana.ceres.local
```

---

## �📚 Documentation

- **Full Guide**: [docs/AUTO_INSTALL.md](docs/AUTO_INSTALL.md)
- **Structure**: [PROJECT_STRUCTURE_FINAL.md](PROJECT_STRUCTURE_FINAL.md)
- **Building**: [docs/BUILDING.md](docs/BUILDING.md)

---

## ⚙️ Prerequisites

**Choose ONE:**
- ✅ Docker 20.10+ (Recommended)
- ✅ curl + bash (Auto-install Go)
- ✅ Go 1.21+ (Manual build)

---

## 🎯 Deployment Time

- **With Docker**: ~3 minutes
- **Without Docker**: ~5 minutes (includes Go installation)
- **With Go installed**: ~30 seconds

---

## 🆘 Troubleshooting

### Issue: Docker not found
```bash
# Install Docker
curl -sSL https://get.docker.com | sh
```

### Issue: Permission denied
```bash
chmod +x quick-deploy.sh scripts/*.sh
```

### Issue: Go installation failed
```bash
# Use Docker instead
./scripts/docker-build.sh
```

---

## ✅ Verify Installation

```bash
# Check CLI version
./bin/ceres version

# Show help
./bin/ceres --help

# List commands
./bin/ceres
```

**Expected output:**
```
CERES Platform v3.0.0
Cloud Infrastructure Deployment Tool

Available Commands:
  deploy      Deploy CERES platform
  status      Show deployment status
  config      Manage configuration
  validate    Validate infrastructure
```

---

## 🎉 Success!

If you see the commands above, you're ready to deploy! 🚀

**Next**: Read [docs/AUTO_INSTALL.md](docs/AUTO_INSTALL.md) for deployment scenarios.

---

**Support**: https://github.com/skulesh01/ceres/issues  
**License**: MIT
