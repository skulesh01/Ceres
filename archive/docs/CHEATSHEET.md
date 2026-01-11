# CERES Platform - Development Helpers
# Quick reference card for common commands

## Windows PowerShell

### Starting Services
```powershell
# Default modules (core, apps, monitoring, ops)
.\scripts\start.ps1

# Specific modules
.\scripts\start.ps1 core apps

# Monolithic mode
.\scripts\start.ps1 -Clean
```

### Status and Monitoring
```powershell
# Quick status
.\scripts\status.ps1

# Detailed with resource usage
.\scripts\status.ps1 -Detailed

# Legacy port checks
.\scripts\status.ps1 -LegacyPorts
```

### Maintenance
```powershell
# Create backup
.\scripts\backup.ps1

# Restore from backup
.\scripts\restore.ps1 backups\backup-20260101-120000.tar.gz

# Stop services
cd config
docker compose --project-name ceres down

# Clean everything (DANGER!)
.\scripts\cleanup.ps1
```

### Logs
```powershell
# All services
docker compose --project-name ceres logs -f

# Specific service
docker compose logs -f postgres

# Last 100 lines
docker compose logs --tail=100
```

## Linux/Mac/WSL with Makefile

### Quick Commands
```bash
make help           # Show all commands
make start          # Start services
make stop           # Stop services
make status         # Check health
make logs           # Follow logs
make backup         # Create backup
```

### With Parameters
```bash
make start modules="core apps"
make logs service=postgres
make backup name=before-upgrade
```

## Docker Commands

### Container Management
```bash
# List containers
docker compose ps

# Restart specific service
docker compose restart postgres

# View resource usage
docker stats

# Execute command in container
docker exec -it ceres-postgres-1 bash
```

### Database Access
```bash
# PostgreSQL
docker exec -it ceres-postgres-1 psql -U postgres

# Redis
docker exec -it ceres-redis-1 redis-cli
```

### Images and Updates
```bash
# Pull latest images
docker compose pull

# Remove unused images
docker image prune -a

# Check image versions
docker compose images
```

## Troubleshooting

### Check if Docker is running
```powershell
docker info
```

### Restart Docker Desktop
```powershell
# Windows
Stop-Process -Name "Docker Desktop" -Force
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

### View container logs
```bash
docker compose logs postgres --tail=50
docker compose logs keycloak --tail=50
```

### Check service health
```bash
# PostgreSQL
docker exec ceres-postgres-1 pg_isready

# Redis
docker exec ceres-redis-1 redis-cli ping

# HTTP endpoints
curl -k https://auth.ceres.local/
```

### Reset services
```bash
# Stop everything
docker compose down

# Remove volumes (DANGER: data loss!)
docker compose down -v

# Start fresh
.\scripts\start.ps1
```

## Performance

### Check resource usage
```powershell
# PowerShell
docker stats --no-stream

# Detailed per-service
.\scripts\status.ps1 -Detailed
```

### Optimize images
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove build cache
docker builder prune
```

## Security

### Change default passwords
Edit `config/.env`:
```env
POSTGRES_PASSWORD=<strong-password>
KEYCLOAK_ADMIN_PASSWORD=<strong-password>
```

### Export Caddy certificates
```powershell
.\scripts\export-caddy-rootca.ps1
```

### View secrets (masked)
```powershell
Get-Content config\.env | Select-String "PASSWORD" | ForEach-Object { 
    $line = $_ -replace '=.*', '=***' 
    Write-Host $line 
}
```

## Networking

### Update hosts file
```powershell
# Automatic
.\scripts\Update-Hosts.ps1

# Manual
# Add to C:\Windows\System32\drivers\etc\hosts:
192.168.1.12  auth.ceres.local nextcloud.ceres.local wiki.ceres.local
```

### Check connectivity
```bash
# From host
ping 192.168.1.12
curl -k https://auth.ceres.local/

# Between containers
docker exec ceres-keycloak-1 ping postgres
```

## Backup Strategy

### Regular backups
```powershell
# Daily backup
$date = Get-Date -Format "yyyyMMdd"
.\scripts\backup.ps1 -Name "daily-$date"

# Before updates
.\scripts\backup.ps1 -Name "before-update"
```

### Automated backups (Task Scheduler)
```powershell
# Create scheduled task (Windows)
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\path\to\scripts\backup.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "CERES Daily Backup"
```

## Useful Aliases

### PowerShell Profile
Add to `$PROFILE`:
```powershell
# CERES shortcuts
function ceres-start { Set-Location "E:\Новая папка\Ceres\scripts"; .\start.ps1 }
function ceres-stop { Set-Location "E:\Новая папка\Ceres\config"; docker compose down }
function ceres-status { Set-Location "E:\Новая папка\Ceres\scripts"; .\status.ps1 }
function ceres-logs { Set-Location "E:\Новая папка\Ceres\config"; docker compose logs -f $args }
```

### Bash Aliases
Add to `~/.bashrc` or `~/.zshrc`:
```bash
alias ceres-start='cd ~/ceres && make start'
alias ceres-stop='cd ~/ceres && make stop'
alias ceres-status='cd ~/ceres && make status'
alias ceres-logs='cd ~/ceres && make logs'
```

## Common Issues

### "Docker daemon not running"
→ Start Docker Desktop

### "Port already in use"
→ Check for conflicting services: `netstat -ano | findstr :8080`

### "Out of memory"
→ Increase Docker Desktop memory limit (Settings → Resources)

### "Permission denied"
→ Run PowerShell as Administrator

### Services not accessible
→ Check hosts file: `.\scripts\Update-Hosts.ps1`

---

**Quick Help:** `make help` or `.\scripts\LAUNCH.ps1 --help`  
**Documentation:** `README.md`, `docs/`  
**Version:** 2.1
