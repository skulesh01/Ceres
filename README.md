# CERES v3.0.0 — Enterprise Kubernetes Platform

![CERES](https://img.shields.io/badge/CERES-v3.0.0-blue?style=flat-square)
![Go](https://img.shields.io/badge/Go-1.21+-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

**CERES** is a production-ready, multi-cloud Kubernetes platform built with:
- 🏗️ **Terraform** - Infrastructure as Code (AWS/Azure/GCP)
- 📦 **Helm** - Service deployment (20+ services)
- 🔄 **Flux CD** - GitOps automation
- 🎯 **Go CLI** - Modern command-line interface

## 🚀 Quick Start

### Prerequisites
- Go 1.21+
- Make (optional)

### Build & Deploy

```bash
# 1. Build CLI
make build

# 2. Deploy infrastructure
./bin/ceres deploy --cloud aws --environment prod

# 3. Check status
./bin/ceres status

# 4. Validate
./bin/ceres validate
```

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
