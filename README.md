# 🚀 CERES v3.1.0 — "AWS for the Rest of Us"

![CERES](https://img.shields.io/badge/CERES-v3.1.0-blue?style=flat-square)
![Deployment](https://img.shields.io/badge/deployment-30min-brightgreen?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Savings](https://img.shields.io/badge/savings-%2425k%2Fyear-gold?style=flat-square)

> **Enterprise infrastructure in 30 minutes. No DevOps team required.**

**CERES** is the fastest way to deploy production-ready infrastructure — like AWS, but:
- ✅ **$100/month** instead of $2,000+/month
- ✅ **30 minutes** instead of 2-4 weeks
- ✅ **No DevOps team** required
- ✅ **Complete control** — your servers, your data

### 💡 Why CERES?

Traditional cloud deployment:
- Hire DevOps engineer: **$120k/year**
- AWS services (GitLab CI, monitoring, etc.): **$24k/year**
- Setup time: **2-4 weeks**
- **Total first year: ~$27,000**

With CERES:
- Server rental: **$1,200/year**
- Setup time: **30 minutes**
- Maintenance: **automated**
- **Total first year: ~$1,200** = **$25,800 saved** 💰

---

## 🎯 What You Get

One command deploys:
- **Authentication** (Keycloak SSO)
- **Git & CI/CD** (GitLab with runners)
- **Monitoring** (Grafana + Prometheus + Loki)
- **Team Chat** (Mattermost)
- **File Storage** (Nextcloud)
- **Wiki** (Wiki.js)
- **Email** (Mailcow optional)
- **VPN** (WireGuard)
- **Backups** (Velero, automated daily/weekly)
- **HTTPS** (cert-manager with Let's Encrypt)

**All services integrated with SSO. Everything works out of the box.**

---

## 🚀 Quick Start (30 Minutes)

### Prerequisites
- Server with 16GB RAM, 4 CPU cores, 100GB disk
- Ubuntu 22.04 LTS (or similar Linux)
- Root access

### Step 1: Install Kubernetes (5 min)

```bash
# K3s (recommended - lightweight)
curl -sfL https://get.k3s.io | sh -

# Verify
kubectl get nodes
```

### Step 2: Deploy CERES (1 command!)

```bash
git clone https://github.com/skulesh01/Ceres.git
cd Ceres
chmod +x deploy-platform.sh
./deploy-platform.sh -y
```

**That's it!** ✨ 

Script will:
1. ✅ Validate system (RAM, CPU, disk, ports)
2. ✅ Deploy all services
3. ✅ Configure SSL/TLS (HTTPS)
4. ✅ Setup SSO (single sign-on) **with full service integration**
5. ✅ Configure automated backups
6. ✅ **Setup service content** (dashboards, projects, channels, apps)
7. ✅ Run health checks

**All services are pre-configured AND pre-populated with content!**
- Grafana has dashboards
- GitLab has example project
- Mattermost has team & channels  
- Nextcloud has apps installed
- MinIO has buckets created
- Wiki.js has documentation

**Truly ready to work immediately - no manual setup needed.**

### Step 3: Access Your Platform

Open browser: `http://YOUR_SERVER_IP/`

**Default credentials:**
- Admin: `admin` / `admin123`
- Demo user: `demo` / `demo123`

**⚠️ IMPORTANT:** Change passwords after first login!

---

## 📖 Documentation

- **[Quick Start Guide](QUICKSTART.md)** - Get started in 5 minutes
- **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)** - Complete step-by-step instructions
- **[Architecture](ARCHITECTURE_ANALYSIS.md)** - Technical deep dive
- **[Troubleshooting](docs/user/TROUBLESHOOTING.md)** - Common issues & solutions

---

## 🛠️ Automation Scripts

CERES includes production-ready automation:

```bash
# System validation before deployment
./scripts/preflight-check.sh

# Platform health monitoring
./scripts/health-check.sh

# SSL/TLS setup (Let's Encrypt or self-signed)
./scripts/configure-ssl.sh

# SSO configuration (auto-create OIDC clients)
./scripts/configure-sso-auto.sh

# Services content setup (dashboards, projects, channels)
./scripts/setup-services.sh

# Production essentials (CI/CD runners, alerts, email, security)
./scripts/production-essentials.sh

# Backup automation (daily + weekly schedules)
./scripts/configure-backup.sh

# Disaster recovery
./scripts/rollback.sh

# Update to latest version
./scripts/update.sh

# 🆕 Advanced Features (v3.2.0)
# Auto-configure DNS with cloud providers
./scripts/configure-dns.sh

# Integrate Slack notifications
./scripts/integrate-slack.sh

# Apply custom company branding
./scripts/apply-branding.sh
```

**Or run everything at once:**
```bash
./deploy-platform.sh --production  # Full production setup

# Optional: Advanced customization
./scripts/configure-dns.sh      # Auto DNS setup
./scripts/integrate-slack.sh    # Slack alerts
./scripts/apply-branding.sh     # Custom branding
```

---

## 🎯 Who Is This For?

✅ **Startups** (5-50 people) — Get enterprise tools without enterprise costs  
✅ **Compliance-Required Orgs** — GDPR, HIPAA, etc. Need data on-premise  
✅ **DevOps Teams** — Testing, staging, development environments  
✅ **Migrating from SaaS** — Replace GitHub + Slack + Google Workspace  

---

## 💰 Cost Comparison

| Service | Traditional SaaS | CERES (Self-Hosted) |
|---------|------------------|---------------------|
| GitLab CI/CD | $99/user/month | $0 (included) |
| Slack Business | $8/user/month | $0 (Mattermost) |
| Google Workspace | $12/user/month | $0 (Nextcloud) |
| Monitoring (Datadog) | $15/host/month | $0 (Grafana) |
| VPN (Tailscale) | $5/user/month | $0 (WireGuard) |
| **Total (10 users)** | **$1,390/month** | **~$100/month** |
| **Annual savings** | — | **~$15,480** 💰 |

---

## 🔧 Advanced Usage

### Prerequisites
- **Option 1 (Recommended)**: Docker 20.10+
- **Option 2**: Auto-install scripts (curl/PowerShell)
- **Option 3**: Go 1.21+ (manual)

### Build & Deploy

```bash
# 1. Quick deploy (builds automatically)
./quick-deploy.sh

# 2. Deploy infrastructure
./bin/ceres deploy --cloud aws --environment prod

# 3. Check status
./bin/ceres status

# 4. Validate
./bin/ceres validate
```

📚 **Full documentation**: [docs/AUTO_INSTALL.md](docs/AUTO_INSTALL.md)

## 📋 What's Included

- **Terraform**: Multi-cloud IaC (AWS EKS, Azure AKS, GCP GKE)
- **Kubernetes**: Ingress, TLS (Cert-Manager), networking
- **Helm**: 20+ pre-configured services
- **Flux CD**: Continuous deployment via Git
- **Monitoring**: Prometheus, Grafana, Loki, Jaeger
- **Documentation**: Comprehensive guides

## 🏗️ Architecture

```
Your Git Repository
        ↓
    Flux CD watches
        ↓
Terraform: Provisions Cloud Infrastructure
        ├─ VPC/Network
        ├─ Kubernetes Cluster (3 nodes)
        ├─ Database (RDS/CloudSQL)
        └─ Cache (Redis/Memorystore)
        ↓
Helm: Deploys 20+ Services
        ├─ Core: PostgreSQL, Redis, Keycloak
        ├─ Apps: GitLab, Nextcloud, Mattermost
        ├─ DevOps: Redmine, Wiki.js, Zulip
        └─ Observability: Prometheus, Grafana, Loki
        ↓
Applications: Accessible via HTTPS
        ├─ https://keycloak.ceres.local
        ├─ https://gitlab.ceres.local
        └─ ... (20 services)
```

## 📁 Project Structure

```
ceres/
├── cmd/ceres/              ← Go CLI entry point
├── pkg/                    ← Core packages
├── infrastructure/         ← Terraform + K8s + Flux configs
├── deployment/             ← Helm charts
├── docs/                   ← Documentation
└── examples/               ← Configuration examples
```

See [docs/STRUCTURE.md](docs/STRUCTURE.md) for detailed structure.

## 📖 Documentation

| Document | Purpose |
|----------|---------|
| [Deployment Flow](docs/user/DEPLOYMENT_FLOW.md) | Complete step-by-step deployment guide |
| [Kubernetes Setup](docs/user/KUBERNETES_DEPLOYMENT_GUIDE.md) | K8s cluster setup |
| [Quick Reference](docs/user/QUICK_REFERENCE_K8S.md) | Quick commands reference |
| [Building](docs/BUILDING.md) | Build CLI from source |
| [Security](docs/architecture/SECURITY_SETUP.md) | Security configuration |
| [Architecture](docs/architecture/IMPLEMENTATION_COMPLETE.md) | System architecture |
| [Structure](docs/STRUCTURE.md) | Project organization |

## 🎯 CLI Commands

```bash
# Deploy platform
ceres deploy --cloud aws --environment prod
ceres deploy --cloud azure --environment staging
ceres deploy --dry-run               # Preview changes

# Check status
ceres status                         # Overall status
ceres status --namespace ceres       # Specific namespace
ceres status --watch                 # Watch for changes

# Configuration
ceres config show                    # Show current config
ceres config validate                # Validate config

# Validation
ceres validate                       # Full validation
```

## ✨ Features

✅ **Multi-Cloud**
- AWS EKS with auto-scaling
- Azure AKS with managed PostgreSQL
- GCP GKE with Cloud SQL
- Same code, multiple deployments

✅ **Production Ready**
- High availability (3-node clusters)
- Auto-scaling (1-6 nodes)
- Automated backups (30 days)
- Security hardened with RBAC

✅ **GitOps Driven**
- Flux CD continuous deployment
- Git as source of truth
- Automatic reconciliation (5min)
- Easy rollbacks

✅ **20+ Services**
- **Core**: PostgreSQL, Redis, Keycloak
- **Apps**: GitLab, Nextcloud, Mattermost, Redmine, Wiki.js, Zulip, Mayan EDMS, OnlyOffice
- **Observability**: Prometheus, Grafana, Loki, Promtail, Jaeger, Tempo, Alertmanager
- **Infrastructure**: Cert-Manager, Ingress-Nginx

✅ **Modern CLI**
- Go-based for cross-platform support
- Cobra framework for rich CLI experience
- Command-line help and examples
- Deployment management

## 📊 Statistics

| Metric | Value |
|--------|-------|
| **Total Files** | 50+ |
| **Go Packages** | 4 |
| **Terraform Files** | 6 |
| **Services** | 20+ |
| **Supported Clouds** | 3 (AWS, Azure, GCP) |
| **Documentation** | 7 guides |
| **Size Reduction** | 90% |

## 🔧 Development

### Build from Source

```bash
# Download dependencies
go mod download

# Build CLI
make build

# Run tests
make test

# Format code
make fmt

# Generate coverage
make coverage
```

### Cross-Platform Build

```bash
make build-all  # Linux, macOS, Windows
```

## 🚀 Deployment Modes

### Development
```bash
./bin/ceres deploy --cloud aws --environment dev --dry-run
```

### Staging
```bash
./bin/ceres deploy --cloud azure --environment staging
```

### Production
```bash
./bin/ceres deploy --cloud aws --environment prod
```

## 🔐 Security

- TLS encryption end-to-end (Cert-Manager)
- Kubernetes RBAC enabled
- Secrets management
- Security groups configured
- Network isolation
- See [docs/architecture/SECURITY_SETUP.md](docs/architecture/SECURITY_SETUP.md)

## 📚 Learn More

- [Deployment Flow - Complete Guide](docs/user/DEPLOYMENT_FLOW.md)
- [Kubernetes Setup - Step by Step](docs/user/KUBERNETES_DEPLOYMENT_GUIDE.md)
- [Architecture - System Design](docs/architecture/IMPLEMENTATION_COMPLETE.md)
- [Building - From Source](docs/BUILDING.md)

## 📝 License

MIT License - See [LICENSE](LICENSE) for details

## 🤝 Contributing

CERES is open source. We welcome contributions!

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 🆘 Support

- 📖 [Documentation](docs/)
- 🐛 [Issues](https://github.com/skulesh01/Ceres/issues)
- 💬 [Discussions](https://github.com/skulesh01/Ceres/discussions)

---

**Ready to deploy? Start with [Deployment Flow](docs/user/DEPLOYMENT_FLOW.md)!** 🚀
