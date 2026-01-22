# 🚀 CERES Quick Start - 30 Minutes to Production

**Everything pre-configured. No manual setup required.**

---

## ⚡ What You Get

One command deploys **7 fully integrated services**:

- ✅ **Keycloak** - Central SSO authentication
- ✅ **GitLab** - Git + CI/CD (SSO integrated)
- ✅ **Grafana** - Monitoring dashboards (SSO integrated)
- ✅ **Mattermost** - Team chat (SSO integrated)
- ✅ **Nextcloud** - File storage (SSO integrated)
- ✅ **MinIO** - S3-compatible storage (SSO integrated)
- ✅ **Wiki.js** - Team documentation

**Plus automated infrastructure:**
- 🔒 HTTPS (cert-manager + Let's Encrypt)
- 💾 Daily + Weekly backups (Velero)
- 🏥 Health monitoring
- 🔄 One-click updates

**Login once → Access everything. Zero manual configuration.**

---

## 🚀 Three Commands, 30 Minutes

```bash
# 1. Install Kubernetes (5 min)
curl -sfL https://get.k3s.io | sh -

# 2. Deploy CERES (25 min)
git clone https://github.com/skulesh01/Ceres.git && cd Ceres && ./deploy-platform.sh -y

# 3. Access (instant)
http://YOUR_SERVER_IP/
# Login: demo / demo123
```

**That's it!** All services pre-configured with SSO. 🎉

---

## 🆕 Optional: Advanced Setup (v3.2.0)

**Add custom domain + SSL + Branding (10 extra minutes):**

```bash
# Auto-configure DNS (Cloudflare, Route53, GCP, DigitalOcean)
./scripts/configure-dns.sh

# Integrate Slack notifications
./scripts/integrate-slack.sh

# Apply your company branding
./scripts/apply-branding.sh
```

**See [Examples Guide](docs/EXAMPLES_v3.2.0.md) for detailed workflows.**

---

## 📖 Detailed Guide

See [Full QuickStart Guide](QUICKSTART_DETAILED.md) for:
- Prerequisites
- Step-by-step installation
- Service access instructions
- First login workflow
- Common tasks
- Troubleshooting

---

## ✅ What's Automatically Configured

**SSO Integration:**
- All services connected to Keycloak
- One login = access to everything
- No manual OAuth configuration

**Security:**
- HTTPS certificates (Let's Encrypt or self-signed)
- HTTP → HTTPS redirect
- Secure secrets management

**Backups:**
- Daily backups (2 AM, 30-day retention)
- Weekly backups (Sunday 3 AM, 90-day retention)
- One-command restore

**Monitoring:**
- Health checks for all services
- Grafana dashboards
- Prometheus metrics

---

## 🔑 Default Credentials

**All Services:**
- Username: `demo`
- Password: `demo123`

**Admin:**
- Keycloak: `admin` / `admin123`
- MinIO: `minioadmin` / `MinIO@Admin2025`

⚠️ **Change in production!**

---

## 💰 Value Proposition

| Item | Traditional | CERES | Savings |
|------|-------------|-------|---------|
| DevOps Engineer | $120k/year | $0 | $120k |
| AWS Services | $24k/year | $0 | $24k |
| Server | $0 | $1.2k/year | -$1.2k |
| Setup Time | 2-4 weeks | 30 min | 🚀 |
| **Total Year 1** | **$144k** | **$1.2k** | **$142.8k** 💰 |

---

## 🆘 Quick Links

- 📖 [Detailed QuickStart](QUICKSTART_DETAILED.md)
- 📚 [Full Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- 📝 [Command Reference](QUICK_REFERENCE.md)
- 🏗️ [Architecture](ARCHITECTURE_ANALYSIS.md)
- 🐛 [GitHub Issues](https://github.com/skulesh01/Ceres/issues)

---

**Ready to deploy?**

```bash
curl -fsSL https://github.com/skulesh01/Ceres/raw/main/deploy-platform.sh | bash -s -- -y
```

30 minutes later → Enterprise platform! 🚀
