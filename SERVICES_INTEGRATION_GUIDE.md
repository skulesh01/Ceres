# CERES Services Integration Guide

## Architecture Overview

CERES platform implements **deep cross-service integration** via:
- **Keycloak**: Central Identity Provider (OIDC/SAML)
- **PostgreSQL**: Unified database backend for all services
- **Redis**: Session store and caching layer
- **Internal Docker network**: Service-to-service communication
- **Traefik/Nginx**: Reverse proxy and routing

### Service Integration Map

```
┌─────────────────────────────────────────────────────────────┐
│                     KEYCLOAK (OIDC Provider)                │
│                     auth.ceres.local:8080                   │
└────────────┬────────────────────┬──────────────┬────────────┘
             │                    │              │
    ┌────────▼────────┐  ┌────────▼──────┐  ┌───▼─────────┐
    │     GitLab      │  │   Mattermost   │  │  Wiki.js    │
    │ git.ceres.local │  │ chat.ceres.l.. │  │ wiki.c....  │
    └────────┬────────┘  └────────┬──────┘  └───┬─────────┘
             │                    │              │
    ┌────────▼─────────────────────▼──────────────▼───────┐
    │         Nextcloud / Redmine (can use OIDC)         │
    │  files.ceres.local / pm.ceres.local                 │
    └──────────────────┬────────────────────────────────┘
                       │
        ┌──────────────┴───────────┬─────────┐
        │                          │         │
    ┌───▼─────────┐        ┌───────▼──┐  ┌──▼──────┐
    │ PostgreSQL  │        │  Redis   │  │ Volumes │
    │    16       │        │  Cache   │  │  Data   │
    └─────────────┘        └──────────┘  └─────────┘
```

## Auto-Configuration Features

All services are configured to **automatically integrate** via environment variables:

### 1. Keycloak OIDC Provider
- **Role**: Central authentication broker
- **Configuration**: Automatic OIDC discovery
- **Discovery URL**: `http://keycloak:8080/auth/realms/master/.well-known/openid-configuration`

### 2. GitLab Integration
**Automatic Setup**:
```yaml
- OIDC provider: Keycloak
- Auto-linking: Users from Keycloak → GitLab accounts
- SSH access: git+ssh://gitlab.ceres.local:2222
- Internal URL: http://gitlab:80 (Docker network)
- External URL: https://gitlab.ceres.local (reverse proxy)
```

**Environment Variables**:
```env
GITLAB_OIDC_SECRET=<generate-random-32-chars>
```

**First-Time Setup**:
1. Access GitLab: http://192.168.1.3:8081
2. Login with Keycloak credentials
3. GitLab admin account auto-created from Keycloak admin

### 3. Nextcloud Integration
**Automatic Setup**:
```yaml
- Redis session store: Redis 6379
- OIDC provider: Keycloak (optional plugin)
- File backend: PostgreSQL + local volumes
- Caching: Redis for user sessions
```

**First-Time Setup**:
1. Access Nextcloud: http://192.168.1.3:8082
2. Admin credentials: `NEXTCLOUD_ADMIN` / `NEXTCLOUD_ADMIN_PASSWORD`
3. Optional: Install OIDC plugin for Keycloak SSO

### 4. Mattermost Integration
**Automatic Setup**:
```yaml
- OIDC provider: Keycloak (auto-discovered)
- Database: PostgreSQL + Redis
- User provisioning: Auto from Keycloak
- Channel sync: Available via API
```

**Environment Variables** (required):
```env
MM_OIDC_SECRET=<generate-random-32-chars>
MM_LOGINSETTINGS_OAUTH_OPENID_CLIENTID=mattermost
```

**First-Time Setup**:
1. Configure OIDC in Keycloak:
   - Client ID: `mattermost`
   - Redirect URI: `https://chat.ceres.local/auth/openid`
   - Scope: `openid profile email`
2. Set `MM_OIDC_SECRET` in `.env`
3. Restart Mattermost
4. Login via Keycloak on login page

### 5. Redmine Integration
**Automatic Setup**:
```yaml
- Database: PostgreSQL (redmine_db)
- Email: SMTP configured for notifications
- OIDC: OpenID Connect plugin support
- API: Available for integrations
```

**First-Time Setup**:
1. Access Redmine: http://192.168.1.3:8083
2. Default login: `admin` / `admin` (change immediately!)
3. Optional: Install OpenID Connect plugin
4. Configure Keycloak in plugin settings

### 6. Wiki.js Integration
**Automatic Setup**:
```yaml
- OIDC provider: Keycloak (auto-configured)
- Database: PostgreSQL (wikijs_db)
- User provisioning: Auto from Keycloak groups
- Group mapping: Automatic role sync
```

**Environment Variables**:
```env
WIKIJS_OIDC_SECRET=<generate-random-32-chars>
```

**First-Time Setup**:
1. Access Wiki.js: http://192.168.1.3:8084
2. Complete setup wizard
3. Enable Keycloak OIDC auth
4. Admin user → `admin@ceres.local`

## Database Architecture

Each service has its own dedicated database:

```
PostgreSQL Instance (5432)
├── keycloak_db        (Keycloak authentication)
├── gitlab_db          (GitLab repositories)
├── nextcloud_db       (File metadata)
├── mattermost_db      (Team chat)
├── redmine_db         (Project management)
└── wikijs_db          (Wiki content)
```

### Database Initialization
- **Automatic**: Init containers create databases on first deployment
- **Idempotent**: Safe to re-run (skips existing databases)
- **Credentials**: All use `postgres` user with `POSTGRES_PASSWORD`

## Session & Caching Integration

### Redis Cache Layer
```
Redis (6379)
├── Keycloak sessions
├── Mattermost sessions  
├── Nextcloud user cache
└── Application cache
```

### Session Configuration
All services configured to use Redis for:
- User session storage
- Cache layer (reduces DB queries)
- Real-time data sharing between containers

## Email Integration (SMTP)

All services use unified SMTP configuration:

```env
SMTP_ENABLED=false                    # Toggle email
SMTP_HOST=smtp.gmail.com              # Mail server
SMTP_PORT=587                         # TLS port
SMTP_USER=your-email@gmail.com        # From address
SMTP_PASSWORD=your-app-password       # App-specific password
SMTP_FROM=noreply@ceres.local         # Sender
```

Services using SMTP:
- **Keycloak**: Account verification, password reset
- **GitLab**: Notifications, account creation
- **Mattermost**: Direct messages, notifications
- **Redmine**: Issue updates, notifications
- **Nextcloud**: Sharing, password recovery
- **Wiki.js**: Invitations, notifications

## Port Mapping & External Access

### Direct Docker Ports (for initial setup/debugging)

```
Service        | Container Port | Host Port | URL
─────────────────────────────────────────────────────────
Keycloak       | 8080           | 8080      | http://192.168.1.3:8080
Nextcloud      | 80             | 8082      | http://192.168.1.3:8082
GitLab         | 80             | 8081      | http://192.168.1.3:8081
GitLab SSH     | 22             | 2222      | ssh://git@192.168.1.3:2222
Mattermost     | 8000           | 8085      | http://192.168.1.3:8085
Redmine        | 3000           | 8083      | http://192.168.1.3:8083
Wiki.js        | 3000           | 8084      | http://192.168.1.3:8084
```

### Domain Names (via reverse proxy/DNS)

When DNS/reverse proxy configured:
```
Keycloak       → auth.ceres.local
GitLab         → gitlab.ceres.local
Nextcloud      → nextcloud.ceres.local
Mattermost     → chat.ceres.local
Redmine        → redmine.ceres.local
Wiki.js        → wiki.ceres.local
```

## Service Communication Matrix

### Internal Service-to-Service URLs

```yaml
Keycloak:
  discovery_endpoint: http://keycloak:8080/auth/realms/master/.well-known/openid-configuration

GitLab:
  keycloak_oidc: http://keycloak:8080/auth/realms/master/protocol/openid-connect
  postgres_host: postgres:5432
  redis_host: redis:6379

Nextcloud:
  postgres_host: postgres:5432
  redis_host: redis:6379
  oidc_provider: http://keycloak:8080 (optional)

Mattermost:
  postgres_host: postgres:5432
  redis_host: redis:6379
  oidc_endpoint: http://keycloak:8080/auth/realms/master/protocol/openid-connect
  
Redmine:
  postgres_host: postgres:5432
  
Wiki.js:
  postgres_host: postgres:5432
  oidc_provider: http://keycloak:8080/auth/realms/master
```

## Deployment Flow

### 1. **Environment Configuration**
```bash
cd /opt/Ceres
cp .env.example .env
# Edit .env with your passwords and domain
```

### 2. **Auto-Initialization**
```bash
docker-compose up -d
# Sequence:
# 1. PostgreSQL starts
# 2. Init containers create databases
# 3. Services start (depends_on conditions met)
# 4. OIDC providers auto-discover
# 5. Services ready for use
```

### 3. **Service Verification**
```bash
# Check all services healthy
docker-compose ps

# Verify database connectivity
docker exec compose-postgres-1 psql -U postgres -l

# Verify OIDC discovery
curl -s http://192.168.1.3:8080/auth/realms/master/.well-known/openid-configuration | jq .
```

### 4. **Post-Deployment Configuration**

**For Production Deployment**:

1. **Keycloak**:
   - Configure Keycloak clients for each service
   - Set up SMTP for account notifications
   - Configure password policies

2. **GitLab**:
   - Import projects from GitHub/GitLab
   - Configure CI/CD runners
   - Setup webhooks for integrations

3. **Mattermost**:
   - Create teams and channels
   - Invite users
   - Configure integrations (GitLab, etc.)

4. **Redmine**:
   - Create projects
   - Configure workflows
   - Set up project managers

5. **Wiki.js**:
   - Create wikis/namespaces
   - Configure access permissions
   - Set homepage

## Environment Variables Required

### Critical (must change)
```env
POSTGRES_PASSWORD=<strong-password>
KEYCLOAK_ADMIN_PASSWORD=<strong-password>
NEXTCLOUD_ADMIN_PASSWORD=<strong-password>
GITLAB_OIDC_SECRET=<random-32-chars>
MM_OIDC_SECRET=<random-32-chars>
REDMINE_OIDC_SECRET=<random-32-chars>
WIKIJS_OIDC_SECRET=<random-32-chars>
DOMAIN=ceres.local
```

### Optional (for SMTP/email)
```env
SMTP_ENABLED=true
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=user@example.com
SMTP_PASSWORD=password
```

## Troubleshooting Integration Issues

### Keycloak OIDC Discovery Failing
```bash
# Check Keycloak is running
curl http://192.168.1.3:8080/auth/realms/master

# Check discovery endpoint
curl http://192.168.1.3:8080/auth/realms/master/.well-known/openid-configuration
```

### GitLab Can't Connect to Keycloak
```bash
# From inside GitLab container
docker exec -it compose-gitlab-1 curl http://keycloak:8080/auth/realms/master

# Check GitLab logs
docker compose logs gitlab | grep -i keycloak
```

### Service Can't Connect to PostgreSQL
```bash
# Test connectivity
docker exec -it compose-postgres-1 psql -U postgres -l

# Check network
docker network inspect compose_internal
```

### Redis Session Issues
```bash
# Check Redis connectivity
docker exec -it compose-redis-1 redis-cli ping

# View Redis keys
docker exec -it compose-redis-1 redis-cli KEYS '*'
```

## Next Steps

1. ✅ **Deploy with this config**: All settings are environment-driven
2. ✅ **Access services** via port mappings (see table above)
3. ✅ **Setup Keycloak clients** for each service
4. ✅ **Configure DNS** for domain access
5. ✅ **Customize workflows** per service needs

All services automatically integrate with zero additional configuration!
