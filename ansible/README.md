---
# CERES Ansible Configuration

This directory contains Ansible playbooks and roles for automated CERES deployment.

## 📋 Structure

```
ansible/
├── inventory/
│   ├── production.yml      # Production environment
│   ├── staging.yml         # Staging environment
│   └── development.yml     # Development environment
├── roles/
│   ├── common/            # Base system configuration
│   ├── docker/            # Docker installation
│   ├── ceres-core/        # Core services deployment
│   ├── ceres-apps/        # Application services
│   ├── ceres-edge/        # Edge & reverse proxy
│   └── monitoring-agent/  # Monitoring agents
├── deploy.yml             # Main deployment playbook
├── rollback.yml           # Rollback playbook
├── backup.yml             # Backup playbook
└── ansible.cfg            # Ansible configuration

## 🚀 Quick Start

### 1. Install Ansible

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install ansible -y

# macOS
brew install ansible

# Python pip
pip install ansible
```

### 2. Configure Inventory

Edit inventory file for your environment:

```bash
nano inventory/production.yml
```

Update:
- IP addresses of VMs
- SSH user and keys
- Domain names
- Paths

### 3. Test Connectivity

```bash
# Ping all hosts
ansible all -i inventory/production.yml -m ping

# Check if Docker is installed
ansible all -i inventory/production.yml -m shell -a "docker --version"
```

### 4. Deploy CERES

```bash
# Full deployment
ansible-playbook -i inventory/production.yml deploy.yml

# Deploy specific role
ansible-playbook -i inventory/production.yml deploy.yml --tags core

# Dry run (check mode)
ansible-playbook -i inventory/production.yml deploy.yml --check

# With verbose output
ansible-playbook -i inventory/production.yml deploy.yml -vvv
```

## 📦 Available Playbooks

### Deploy Full Stack

```bash
ansible-playbook -i inventory/production.yml deploy.yml
```

### Deploy by Tags

```bash
# Only prepare systems (common + docker)
ansible-playbook -i inventory/production.yml deploy.yml --tags prepare

# Only core services
ansible-playbook -i inventory/production.yml deploy.yml --tags core

# Only apps
ansible-playbook -i inventory/production.yml deploy.yml --tags apps

# Only edge/monitoring
ansible-playbook -i inventory/production.yml deploy.yml --tags edge,monitoring
```

### Backup

```bash
ansible-playbook -i inventory/production.yml backup.yml
```

### Rollback

```bash
ansible-playbook -i inventory/production.yml rollback.yml
```

### Update Services

```bash
# Pull latest code and restart
ansible-playbook -i inventory/production.yml deploy.yml --tags deploy
```

## 🔐 SSH Key Management

### Generate SSH Key Pair

```bash
ssh-keygen -t ed25519 -C "ceres-deployment" -f ~/.ssh/ceres_deploy_key
```

### Copy Public Key to VMs

```bash
# Copy to all VMs
ssh-copy-id -i ~/.ssh/ceres_deploy_key.pub ceres@192.168.1.10
ssh-copy-id -i ~/.ssh/ceres_deploy_key.pub ceres@192.168.1.11
ssh-copy-id -i ~/.ssh/ceres_deploy_key.pub ceres@192.168.1.12
```

### Configure Ansible to Use Key

Edit `ansible.cfg`:

```ini
[defaults]
private_key_file = ~/.ssh/ceres_deploy_key
```

## 🎯 Environment-Specific Deployments

### Development

```bash
ansible-playbook -i inventory/development.yml deploy.yml
```

### Staging

```bash
ansible-playbook -i inventory/staging.yml deploy.yml
```

### Production

```bash
# Always use check mode first!
ansible-playbook -i inventory/production.yml deploy.yml --check

# Then deploy
ansible-playbook -i inventory/production.yml deploy.yml
```

## 🔧 Advanced Usage

### Run Specific Task

```bash
# Restart only Docker services
ansible ceres_cluster -i inventory/production.yml -m systemd -a "name=docker state=restarted" --become

# Check disk space
ansible all -i inventory/production.yml -m shell -a "df -h"

# View logs
ansible edge_vms -i inventory/production.yml -m shell -a "docker logs caddy"
```

### Parallel Execution

```bash
# Run on 5 hosts in parallel (default is 5)
ansible-playbook -i inventory/production.yml deploy.yml --forks=10

# Serial execution (one host at a time)
ansible-playbook -i inventory/production.yml deploy.yml --serial=1
```

### Limit to Specific Hosts

```bash
# Deploy only to core VM
ansible-playbook -i inventory/production.yml deploy.yml --limit core_vms

# Deploy to specific host
ansible-playbook -i inventory/production.yml deploy.yml --limit ceres-apps
```

## 🔍 Troubleshooting

### Debug Mode

```bash
# Verbose level 1
ansible-playbook -i inventory/production.yml deploy.yml -v

# Maximum verbosity (level 4)
ansible-playbook -i inventory/production.yml deploy.yml -vvvv
```

### Test Role Individually

```bash
# Test common role
ansible-playbook -i inventory/production.yml deploy.yml --tags common --limit ceres-core

# Test with check mode
ansible-playbook -i inventory/production.yml deploy.yml --check --diff
```

### Common Issues

**Issue: "Host unreachable"**
```bash
# Check connectivity
ping 192.168.1.10

# Check SSH
ssh ceres@192.168.1.10
```

**Issue: "Permission denied"**
```bash
# Ensure SSH key is added
ssh-add ~/.ssh/ceres_deploy_key

# Check sudoers
ansible all -i inventory/production.yml -m shell -a "sudo whoami" --ask-become-pass
```

**Issue: "Docker not found"**
```bash
# Install Docker first
ansible-playbook -i inventory/production.yml deploy.yml --tags common,docker
```

## 🔗 Integration with CI/CD

This Ansible configuration integrates with:
- GitHub Actions (`.github/workflows/gitops.yml`)
- Terraform outputs (`../terraform/outputs.json`)
- FluxCD for GitOps

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Docker Ansible Module](https://docs.ansible.com/ansible/latest/collections/community/docker/)
- [CERES GitOps Guide](../docs/GITOPS_GUIDE.md)
