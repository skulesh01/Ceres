# CERES Platform Deployment

## ⚠️ Security Notice

This is the **PUBLIC** repository. It does NOT contain:
- Real passwords
- Credentials
- Deployment scripts with hardcoded secrets

For actual deployment, you need the **PRIVATE** companion project.

## Structure

```
Ceres/                    # Public (this repo)
├── config/
│   ├── .env.example      # Template only
│   ├── compose/          # Docker Compose configs
│   └── ...
├── scripts/
│   └── ...               # Helper scripts (no passwords)
├── terraform/
│   └── terraform.tfvars.example  # Template only
└── ...

Ceres-Private/           # Private (NOT in Git)
├── credentials.json     # Real passwords
├── deploy-to-proxmox.py # Full automation
├── setup-ssh.py         # SSH setup
└── launcher.py          # Main entry point
```

## Quick Start

### 1. Clone this repository
```bash
git clone https://github.com/yourusername/Ceres.git
cd Ceres
```

### 2. Setup private deployment (not in Git)
```bash
# Create private directory
mkdir ../Ceres-Private
cd ../Ceres-Private

# Create credentials.json with your real data
cat > credentials.json << 'EOF'
{
  "proxmox": {
    "host": "YOUR_PROXMOX_IP",
    "user": "root",
    "password": "YOUR_PASSWORD"
  },
  ...
}
EOF

# Copy deployment scripts from secure location
# Or request access to private repo
```

### 3. Deploy
```bash
cd Ceres-Private
python launcher.py
```

## What's Included (Public)

- ✅ Docker Compose configurations
- ✅ Terraform templates
- ✅ Ansible playbooks  
- ✅ Documentation
- ✅ Architecture diagrams
- ✅ Example configs

## What's NOT Included (Private Only)

- ❌ Real passwords and credentials
- ❌ Automated deployment scripts
- ❌ SSH keys and certificates
- ❌ Production configurations

## Services

CERES deploys 20+ services:

**Core:**
- PostgreSQL, Redis, Keycloak (SSO)

**Apps:**
- GitLab CE, Zulip, Nextcloud, Mayan EDMS
- OnlyOffice, Collabora

**Monitoring:**
- Prometheus, Grafana, Alertmanager
- 7 exporters

**Network:**
- Caddy (reverse proxy), WireGuard (VPN), Mailu (SMTP)

## Documentation

See [docs/](docs/) for detailed guides:
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - Pre-deployment checklist

## Security Best Practices

1. **Never commit passwords to Git**
2. **Keep Ceres-Private/ outside Git**
3. **Use .gitignore properly**
4. **Rotate credentials regularly**
5. **Use SSH keys instead of passwords**
6. **Enable 2FA where possible**

## License

MIT License - See [LICENSE](LICENSE)

## Support

For issues with public code, open GitHub issue.
For deployment help (requires credentials), contact privately.
