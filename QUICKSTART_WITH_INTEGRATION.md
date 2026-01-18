# CERES Quick Start - Services Deployment with Integration

## ⚡ 5-Minute Setup

### Step 1: Prepare Environment
```bash
cd /opt/Ceres  # or your CERES directory

# Copy environment template
cp .env.example .env

# Edit .env with your passwords (required)
# Minimum required changes:
#   - POSTGRES_PASSWORD (database)
#   - KEYCLOAK_ADMIN_PASSWORD (SSO admin)
#   - NEXTCLOUD_ADMIN_PASSWORD (file storage)
#   - DOMAIN (your domain name)

nano .env
```

### Step 2: Run Auto-Setup Script
```bash
# Linux/macOS
chmod +x setup-services.sh
./setup-services.sh

# Windows (PowerShell)
powershell -ExecutionPolicy Bypass -File setup-services.ps1
```

The script will:
- ✅ Generate OIDC secrets for all services
- ✅ Create Docker network
- ✅ Deploy services with `docker-compose up -d`
- ✅ Display service URLs

### Step 3: Wait for Services
```bash
# Check status (wait for all "healthy")
docker-compose ps

# Or follow logs
docker-compose logs -f
```

Services startup time:
- PostgreSQL: ~10 seconds
- Keycloak: ~30 seconds
- GitLab: ~60 seconds
- Others: ~20 seconds each

**Total time**: 3-5 minutes from deployment to fully ready

---

## 🔗 Service Access

### Direct URLs (for initial setup)
| Service | URL | Default User |
|---------|-----|--------------|
| Keycloak | http://localhost:8080 | admin |
| GitLab | http://localhost:8081 | (created via Keycloak) |
| Nextcloud | http://localhost:8082 | admin |
| Redmine | http://localhost:8083 | admin |
| Wiki.js | http://localhost:8084 | (setup wizard) |
| Mattermost | http://localhost:8085 | (setup wizard) |

### Production URLs (with reverse proxy)
```
auth.ceres.local        → Keycloak
gitlab.ceres.local      → GitLab
nextcloud.ceres.local   → Nextcloud
redmine.ceres.local     → Redmine
wiki.ceres.local        → Wiki.js
chat.ceres.local        → Mattermost
```

### SSH Access to GitLab
```bash
ssh -p 2222 git@localhost

# Or with domain
ssh -p 2222 git@gitlab.ceres.local
```

---

## 🔐 First-Time Configuration

### 1. Keycloak (Authentication Hub)
```
1. Access http://localhost:8080
2. Click "Administration Console"
3. Login: admin / (password from .env KEYCLOAK_ADMIN_PASSWORD)
4. Left sidebar → "Clients" → Create OIDC clients:
   - gitlab (client_id: gitlab, redirect: https://gitlab.ceres.local/users/auth/openid_connect/callback)
   - mattermost (client_id: mattermost, redirect: https://chat.ceres.local/auth/openid)
   - wikijs (client_id: wikijs, redirect: https://wiki.ceres.local/auth/oidc/callback)
   - redmine (client_id: redmine)
5. Copy client secrets → update .env with GITLAB_OIDC_SECRET, etc.
6. Restart services: docker-compose up -d
```

### 2. GitLab (Repository + CI/CD)
```
1. Access http://localhost:8081
2. On login page, click "Keycloak" button
3. Authenticate with Keycloak credentials
4. GitLab admin account auto-created
5. Inside GitLab:
   - Create projects
   - Setup CI/CD runners
   - Configure webhooks
```

### 3. Nextcloud (File Storage)
```
1. Access http://localhost:8082
2. Admin login: admin / (from .env NEXTCLOUD_ADMIN_PASSWORD)
3. Go to Settings → Admin → Keycloak app
4. Enable Keycloak OIDC integration (optional)
5. Create user directories and shares
```

### 4. Mattermost (Team Chat)
```
1. Access http://localhost:8085
2. Setup wizard appears (first visit)
3. Create team and admin user
4. Go to System Console → Authentication → OpenID Connect
5. Enable Keycloak OIDC
6. Restart: docker-compose restart mattermost
```

### 5. Redmine (Project Management)
```
1. Access http://localhost:8083
2. Default login: admin / admin (CHANGE IMMEDIATELY)
3. Go to Administration → Users
4. Create projects and assign users
5. Optional: Install OpenID Connect plugin
```

### 6. Wiki.js (Knowledge Base)
```
1. Access http://localhost:8084
2. Setup wizard: create admin account
3. Go to Administration → Authentication
4. Enable Keycloak OIDC
5. Create namespaces and pages
```

---

## 🚀 Full Integration Test

### Test OIDC SSO Flow
```bash
# 1. Keycloak should be discoverable
curl -s http://localhost:8080/auth/realms/master/.well-known/openid-configuration | jq .

# 2. Try OIDC login at any integrated service
# Example for GitLab:
# - Go to http://localhost:8081
# - Click "Keycloak" on login page
# - Login with Keycloak credentials

# 3. Verify user was created in each service
docker exec compose-gitlab-1 gitlab-rails console
# > User.find_by(username: 'your_keycloak_user')
```

### Test Service Connectivity
```bash
# PostgreSQL from inside container
docker exec compose-postgres-1 psql -U postgres -l

# Redis connectivity
docker exec compose-redis-1 redis-cli ping

# Keycloak API
curl -s http://localhost:8080/auth/admin/realms/master \
  -H "Authorization: Bearer $(curl -s -X POST http://localhost:8080/auth/realms/master/protocol/openid-connect/token \
    -d "client_id=admin-cli&username=admin&password=$(grep KEYCLOAK_ADMIN_PASSWORD .env | cut -d= -f2)&grant_type=password" | jq -r .access_token)"
```

---

## 📊 Monitoring & Health Checks

### Service Health Status
```bash
# Full status with health
docker-compose ps

# Real-time logs for all services
docker-compose logs -f

# Logs for specific service
docker-compose logs -f gitlab
docker-compose logs -f keycloak

# Health check details
docker ps --format "table {{.Names}}\t{{.Status}}"
```

### Database Status
```bash
# List all databases
docker exec compose-postgres-1 psql -U postgres -l

# Connect to specific database
docker exec -it compose-postgres-1 psql -U postgres -d gitlab_db

# Check database size
docker exec compose-postgres-1 psql -U postgres -c \
  "SELECT datname, pg_size_pretty(pg_database.dblocks * 8192) as size FROM pg_database ORDER BY dblocks DESC;"
```

### Redis Status
```bash
# Check Redis info
docker exec compose-redis-1 redis-cli info

# Monitor Redis operations
docker exec compose-redis-1 redis-cli monitor

# List all keys
docker exec compose-redis-1 redis-cli KEYS '*'
```

---

## 🔧 Common Tasks

### Restart All Services
```bash
docker-compose restart
```

### Restart Specific Service
```bash
docker-compose restart gitlab
docker-compose restart keycloak
docker-compose restart mattermost
```

### View Logs
```bash
# Last 50 lines
docker-compose logs --tail=50

# Follow logs (live)
docker-compose logs -f

# Only errors
docker-compose logs gitlab | grep -i error
```

### Stop All Services
```bash
docker-compose stop
```

### Stop & Remove Everything (WARNING: Deletes data!)
```bash
docker-compose down -v
```

### Backup Databases
```bash
# PostgreSQL backup
docker exec compose-postgres-1 pg_dump -U postgres -d gitlab_db > gitlab_db_backup.sql

# All databases
for db in keycloak gitlab nextcloud mattermost redmine wikijs; do
  docker exec compose-postgres-1 pg_dump -U postgres -d ${db}_db > ${db}_db_backup.sql
done
```

### Restore Database
```bash
# From backup file
docker exec -i compose-postgres-1 psql -U postgres -d gitlab_db < gitlab_db_backup.sql
```

---

## 🐛 Troubleshooting

### Service Won't Start
```bash
# Check logs
docker-compose logs <service_name>

# Verify environment variables
docker exec <container_name> env | grep -i postgres

# Check port conflicts
netstat -tulpn | grep LISTEN
```

### Database Connection Errors
```bash
# Test PostgreSQL connectivity
docker exec compose-postgres-1 psql -h localhost -U postgres -c "SELECT 1"

# Check network
docker network inspect compose_internal

# Test from service container
docker exec compose-gitlab-1 psql -h postgres -U postgres -d postgres -c "SELECT 1"
```

### Keycloak OIDC Not Working
```bash
# Check Keycloak logs
docker-compose logs keycloak | grep -i oidc

# Verify client exists
curl -s http://localhost:8080/auth/realms/master/.well-known/openid-configuration | jq .

# Check if client secret matches
grep GITLAB_OIDC_SECRET .env
# Compare with what's in Keycloak Admin Console
```

### Services Can't Communicate
```bash
# Check network connectivity between containers
docker exec compose-gitlab-1 ping keycloak
docker exec compose-gitlab-1 ping postgres
docker exec compose-gitlab-1 ping redis

# Check DNS resolution inside container
docker exec compose-gitlab-1 nslookup keycloak
```

---

## 📝 Important Notes

### Default Passwords
All default passwords in services must be changed:
- Keycloak: Change admin password
- GitLab: Auto-created via Keycloak (use Keycloak credentials)
- Nextcloud: Change admin password
- Redmine: Change admin password (login: admin/admin)
- Wiki.js: Set during setup wizard
- Mattermost: Set during setup wizard

### Data Persistence
All data stored in Docker volumes:
```bash
# List volumes
docker volume ls | grep compose

# Inspect volume
docker volume inspect compose_postgres_data

# Backup volumes
docker run --rm -v compose_postgres_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

### SMTP Configuration
For email notifications, update `.env`:
```env
SMTP_ENABLED=true
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### Domain Setup
For production access with domain names:
1. Update DNS: `*.ceres.local` → your server IP
2. Setup reverse proxy (Nginx/Caddy) with SSL
3. Or use services directly on ports 8080-8085

---

## 📚 Documentation

- **[SERVICES_INTEGRATION_GUIDE.md](SERVICES_INTEGRATION_GUIDE.md)** — Detailed integration architecture
- **[config/compose/apps.yml](config/compose/apps.yml)** — Docker Compose services definition
- **[.env.example](.env.example)** — All available environment variables
- **[QUICKSTART.md](QUICKSTART.md)** — Original quick start guide

---

## 🎓 What's Next?

1. ✅ Services deployed and running
2. ✅ OIDC SSO working
3. 📋 Setup projects in GitLab
4. 📋 Create teams in Mattermost
5. 📋 Configure wikis in Wiki.js
6. 📋 Setup projects in Redmine
7. 🔒 Configure SSL certificates for HTTPS
8. 🚀 Move to production Kubernetes deployment

---

## 🆘 Need Help?

- **Check logs**: `docker-compose logs <service>`
- **Verify health**: `docker-compose ps`
- **Test connectivity**: `docker exec <container> ping <host>`
- **Read docs**: See documentation links above

**Happy deploying! 🚀**
