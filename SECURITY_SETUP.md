# Security Configuration Guide

This guide explains how to securely configure the Ceres platform without exposing sensitive credentials.

## Quick Start

1. **Copy the environment template:**
   ```powershell
   Copy-Item .env.example .env
   ```

2. **Edit `.env` and fill in your actual values:**
   ```powershell
   notepad .env
   ```

3. **Load environment variables before running scripts:**
   ```powershell
   # PowerShell
   Get-Content .env | ForEach-Object {
       if ($_ -match '^([^#=]+)=(.*)$') {
           [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
       }
   }
   
   # Or source the helper
   . .\scripts\_lib\Load-Env.ps1
   ```

4. **Run deployment:**
   ```powershell
   .\DEPLOY.ps1
   ```

## Environment Variables

### Required for Deployment

| Variable | Description | Example |
|----------|-------------|---------|
| `DEPLOY_SERVER_IP` | Proxmox host IP | `192.168.1.3` |
| `DEPLOY_SERVER_USER` | SSH username | `root` |
| `DEPLOY_SERVER_PASSWORD` | SSH password | `YourStrongPassword123!` |
| `K3S_CORE_IP` | Core VM IP | `192.168.1.10` |
| `POSTGRES_PASSWORD` | PostgreSQL password | `StrongDbPass123!` |
| `KEYCLOAK_ADMIN_PASSWORD` | Keycloak admin password | `StrongKeycloakPass!` |

### Optional Services

| Variable | Description | Required For |
|----------|-------------|--------------|
| `GITHUB_TOKEN` | GitHub PAT | GitOps/Flux |
| `WG_EASY_PASSWORD` | VPN admin password | WireGuard |
| `SMTP_HOST` | Mail server | Email notifications |
| `CLOUDFLARED_TOKEN` | Cloudflare tunnel token | External access |

## Security Best Practices

### ✅ DO

- **Use strong passwords:** Minimum 16 characters with mixed case, numbers, symbols
- **Store `.env` securely:** Never commit to git (already in `.gitignore`)
- **Rotate credentials regularly:** Especially after team member changes
- **Use SSH keys:** Generate and add SSH keys instead of passwords when possible
- **Enable 2FA:** For GitHub, Proxmox, and all admin accounts

### ❌ DON'T

- **Never commit `.env`** to version control
- **Don't share passwords** in chat/email - use password managers
- **Don't use default passwords** like `admin`/`password`
- **Don't reuse passwords** across different services
- **Don't hardcode secrets** in scripts or configuration files

## Password Generation

Generate strong passwords with PowerShell:

```powershell
# Generate 24-character password
-join ((48..57) + (65..90) + (97..122) + @(33,35,36,37,38,42,43,45,61,63) | Get-Random -Count 24 | ForEach-Object {[char]$_})
```

## SSH Key Setup (Recommended)

Instead of using passwords, set up SSH keys:

```powershell
# 1. Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/ceres_deploy -C "ceres-deploy"

# 2. Copy to server (will ask for password once)
type ~/.ssh/ceres_deploy.pub | ssh root@192.168.1.3 "cat >> ~/.ssh/authorized_keys"

# 3. Update scripts to use key instead of password
# Remove -pw flag and add -i flag in scripts
```

## Kubernetes Secrets

For Kubernetes deployments, use Sealed Secrets:

```bash
# Install kubeseal
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Create secret and seal it
kubectl create secret generic my-secret --from-literal=password=secret123 --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml

# Apply sealed secret (safe to commit)
kubectl apply -f sealed-secret.yaml
```

## Troubleshooting

### Environment variables not loaded

```powershell
# Check if variables are set
[Environment]::GetEnvironmentVariable('DEPLOY_SERVER_IP')

# If null, reload .env
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^#=]+)=(.*)$') {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
    }
}
```

### Scripts failing with "variable not set"

Make sure to load environment variables **before** running scripts:

```powershell
# Wrong
.\DEPLOY.ps1

# Correct
. .\scripts\_lib\Load-Env.ps1
.\DEPLOY.ps1
```

## Support

For security concerns, open an issue at: https://github.com/skulesh01/Ceres/issues

**Never** include actual passwords or secrets in issue reports!
