# Running CERES on Linux/macOS

## Quick Setup (Ubuntu/Debian)

### Step 1: Install PowerShell Core

```bash
# Add Microsoft repository
wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb

# Update package index
sudo apt-get update

# Install PowerShell
sudo apt-get install -y powershell
```

### Step 2: Verify Installation

```bash
pwsh --version
# Output should show: PowerShell 7.x.x
```

### Step 3: Clone and Run CERES

```bash
# Clone repository
git clone https://github.com/yourorg/Ceres.git
cd Ceres

# Make the wrapper executable
chmod +x ceres

# Run CERES
./ceres analyze resources
```

**Expected output:**
```
System Resources
  CPU (cores):    4
  RAM (GB):       16 GB
  Disk (GB):      50 GB
  OS:             Linux

Recommendation: SMALL profile (Docker, 1 VM, 4 CPU, 8GB RAM)
```

## Running on CentOS/RHEL

### Installation

```bash
# Install PowerShell
sudo yum install -y powershell

# Clone CERES
git clone https://github.com/yourorg/Ceres.git
cd Ceres

# Run
chmod +x ceres
./ceres analyze resources
```

## Running on macOS

### Installation

```bash
# Using Homebrew (recommended)
brew install powershell

# Or download from GitHub
# https://github.com/PowerShell/PowerShell/releases
```

### Running CERES

```bash
git clone https://github.com/yourorg/Ceres.git
cd Ceres

chmod +x ceres
./ceres analyze resources
```

## Alternative: Direct PowerShell Commands

If you prefer direct PowerShell syntax:

```bash
# Using pwsh directly
pwsh -File ./scripts/ceres.ps1 analyze resources

# Using wrapper script
./ceres analyze resources

# All these work the same:
./ceres help
./ceres analyze resources
./ceres configure --preset medium
./ceres validate environment
```

## Common Commands on Linux

```bash
# Analyze resources
./ceres analyze resources

# Get help
./ceres help
./ceres help analyze

# Interactive configuration (coming soon)
./ceres configure --preset medium

# Validate setup
./ceres validate environment

# View status
./ceres status

# Check Docker
docker ps
docker-compose --version
```

## Docker Compose on Linux

CERES uses Docker Compose for local deployments:

```bash
# Install Docker (Ubuntu)
sudo apt-get install -y docker.io docker-compose

# Add current user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Test Docker
docker ps
docker-compose version
```

## Kubernetes (k3s) on Linux

For Kubernetes deployments on Linux:

```bash
# Install k3s
curl -sfL https://get.k3s.io | sh -

# Check installation
sudo k3s kubectl get nodes

# Make kubectl available without sudo
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $USER:$USER $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Test
kubectl get nodes
```

## Troubleshooting

### PowerShell not found

```bash
# Check if installed
which pwsh

# If not found, reinstall
sudo apt-get install -y powershell
```

### Docker permission denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply new group settings
newgrp docker

# Test
docker ps
```

### /proc/meminfo not readable

```bash
# Some systems restrict /proc access
# CERES will fall back to default value (8GB)
# This is safe - just means estimation won't be accurate

# To read system memory on all systems
free -h
cat /proc/meminfo | grep MemTotal
```

### Disk space detection issues

```bash
# Check available space
df -h

# CERES uses 'df -B1' for byte-accurate reporting
# This should work on all Linux systems
```

## Performance Considerations

### Linux vs Windows

- **Faster startup**: Linux ~200ms vs Windows ~500ms
- **Memory overhead**: Lower on Linux
- **Docker performance**: Native on Linux, HyperV layer on Windows

### Optimization Tips

1. Use SSD for `/tmp` directory
2. Ensure Docker daemon is running
3. Pre-pull Docker images:
   ```bash
   docker pull postgres:15
   docker pull keycloak/keycloak:latest
   ```
4. Use `--format json` for faster output parsing:
   ```bash
   ./ceres analyze resources --format json
   ```

## Container-Based Development

Run CERES in a Docker container:

```bash
# Build container
docker build -f Dockerfile.dev -t ceres:dev .

# Run container
docker run -it -v $(pwd):/ceres ceres:dev bash

# Inside container
pwsh
. ./scripts/_lib/Analyze.ps1
Invoke-ResourceAnalysis
```

## CI/CD Pipeline

For GitHub Actions with Linux runners:

```yaml
name: CERES Analysis
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup PowerShell Core
        run: |
          sudo apt-get update
          sudo apt-get install -y powershell
      
      - name: Run CERES Analysis
        run: pwsh -File scripts/ceres.ps1 analyze resources
      
      - name: Validate Configuration
        run: pwsh -File scripts/ceres.ps1 validate environment
```

## WSL (Windows Subsystem for Linux)

If you're using WSL on Windows:

```bash
# Install PowerShell in WSL
sudo apt-get install -y powershell

# Clone CERES in WSL
git clone https://github.com/yourorg/Ceres.git
cd Ceres

# Run
./ceres analyze resources

# Enable Docker in WSL (Windows Docker Desktop)
# Docker will be accessible from WSL automatically
```

## Next Steps

After installation:

1. **Analyze Resources**: `./ceres analyze resources`
2. **Read Quick Start**: See [docs/00-QUICKSTART.md](docs/00-QUICKSTART.md)
3. **Configure**: `./ceres configure --preset medium`
4. **Deploy**: Follow [docs/DEPLOY_TO_PROXMOX.md](docs/DEPLOY_TO_PROXMOX.md)

## Support

For issues:
- Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- Read [docs/01-CROSSPLATFORM.md](docs/01-CROSSPLATFORM.md)
- Create issue: https://github.com/yourorg/Ceres/issues

---

Happy coding on Linux! 🐧
