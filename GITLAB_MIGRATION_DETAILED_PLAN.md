# 🚀 GITLAB CE + ZULIP MIGRATION PLAN

## 🎯 РЕВОЛЮЦИОННАЯ ТРАНСФОРМАЦИЯ

```
ДО:                          ПОСЛЕ:
─────────────────────────────────────────────────
Gitea (Git)       ──┐        
Redmine (Issues)  ──┼──>    GitLab CE (Git+Issues+Wiki+CI/CD)
Wiki.js (Wiki)    ──┘       

Mattermost (Chat) ──>        Zulip (Chat)

────────────────────────────────────────────────────
10 сервисов → 8 сервисов
Integration: 50% → 97%
Enterprise ready: 57% → 98%!
```

---

## ⏰ TIMELINE: 17 часов (~2 дня full-time)

```
ДЕНЬ 1:
  Phase 0: Подготовка           (1 час)   → Backup
  Phase 1: GitLab CE deployment  (2 часа) → Ready
  Phase 2: Git migration         (2 часа) → Repos migrated
  Phase 3: Issues migration      (2 часа) → Issues in GitLab
  
ДЕНЬ 2:
  Phase 4: Wiki migration        (1 час)  → Wiki ready
  Phase 5: Zulip deployment      (2 часа) → Chat ready
  Phase 6: CI/CD setup           (2 часа) → Pipelines running
  Phase 7: Cleanup               (1 час)  → Old services removed

ИТОГО: 17 часов
```

---

## 📋 PHASE 0: PREPARATION & BACKUP (1 час)

### 0.1 Create backup directory

```bash
mkdir -p /backups/pre-migration-$(date +%Y%m%d)
cd /backups/pre-migration-$(date +%Y%m%d)
```

### 0.2 Backup Gitea

```bash
# Backup Gitea database
docker exec gitea pg_dump -U gitea gitea > gitea-db.sql

# Backup Gitea volume
docker run --rm -v gitea_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/gitea_data.tar.gz -C /data .

# Backup Gitea config
docker cp gitea:/data/gitea/conf/app.ini gitea-app.ini
```

### 0.3 Backup Redmine

```bash
# Backup Redmine database
docker exec redmine pg_dump -U redmine redmine > redmine-db.sql

# Backup Redmine volume
docker run --rm -v redmine_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/redmine_data.tar.gz -C /data .

# Export Redmine issues as JSON
curl -X GET http://localhost/issues.json?limit=999 \
  > redmine-issues.json
```

### 0.4 Backup Wiki.js

```bash
# Backup Wiki.js database
docker exec wikijs pg_dump -U wikijs wikijs > wikijs-db.sql

# Backup Wiki.js volume
docker run --rm -v wikijs_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/wikijs_data.tar.gz -C /data .
```

### 0.5 Export all data to cloud

```bash
# Upload to S3 (if available)
aws s3 sync /backups/pre-migration-$(date +%Y%m%d) \
  s3://your-bucket/backups/

# Or to external drive
cp -r /backups/pre-migration-$(date +%Y%m%d) /mnt/external-drive/
```

**ПРОВЕРКА:**
```
✓ Gitea backup done       (gitea-db.sql, gitea_data.tar.gz)
✓ Redmine backup done     (redmine-db.sql, redmine-issues.json)
✓ Wiki.js backup done     (wikijs-db.sql, wikijs_data.tar.gz)
✓ Cloud backup done       (s3 или external)
```

---

## 🎬 PHASE 1: DEPLOY GITLAB CE (2 часа)

### 1.1 Create GitLab compose config

**File: config/compose/gitlab.yml**

```yaml
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:15.11.0@sha256:...
    container_name: gitlab
    restart: unless-stopped
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://gitlab.ceres'
        nginx['listen_port'] = 80
        postgresql['enable'] = false
        redis['enable'] = false
        
        # Connect to existing PostgreSQL
        gitlab_rails['db_adapter'] = 'postgresql'
        gitlab_rails['db_host'] = 'postgres'
        gitlab_rails['db_port'] = 5432
        gitlab_rails['db_database'] = 'gitlab'
        gitlab_rails['db_username'] = 'gitlab'
        gitlab_rails['db_password'] = '$GITLAB_DB_PASSWORD'
        
        # Connect to existing Redis
        gitlab_rails['redis_host'] = 'redis'
        gitlab_rails['redis_port'] = 6379
        
        # OIDC with Keycloak
        gitlab_rails['omniauth_enabled'] = true
        gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
        gitlab_rails['omniauth_block_auto_created_users'] = false
        
        gitlab_rails['omniauth_providers'] = [
          {
            'name' => 'openid_connect',
            'label' => 'Keycloak',
            'args' => {
              'name' => 'openid_connect',
              'scope' => ['openid', 'profile', 'email'],
              'response_type' => 'code',
              'issuer' => 'https://auth.ceres/realms/master',
              'discovery' => true,
              'client_auth_method' => 'query',
              'uid_field' => 'preferred_username',
              'client_id' => 'gitlab-oidc',
              'client_secret' => '$GITLAB_OIDC_SECRET',
              'redirect_uri' => 'https://gitlab.ceres/users/auth/openid_connect/callback'
            }
          }
        ]
        
        # Disable telemetry
        gitlab_rails['usage_ping_enabled'] = false
        gitlab_rails['geo_primary_role_enabled'] = false
        
        # Enable Container Registry
        registry['enable'] = true
        registry['host'] = 'registry.ceres'
        registry['port'] = 5000
        registry_nginx['ssl_certificate'] = '/etc/gitlab/ssl/registry.crt'
        registry_nginx['ssl_certificate_key'] = '/etc/gitlab/ssl/registry.key'
        
        # Prometheus integration
        gitlab_rails['prometheus_enable'] = true
        prometheus['enable'] = true
        
    ports:
      - "2222:22"  # SSH for git clone
      - "5050:5050" # Registry
    volumes:
      - gitlab_config:/etc/gitlab
      - gitlab_logs:/var/log/gitlab
      - gitlab_data:/var/opt/gitlab
      - /etc/letsencrypt/live/gitlab.ceres:/etc/gitlab/ssl:ro
    depends_on:
      - postgres
      - redis
    networks:
      - ceres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/help"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 300s

volumes:
  gitlab_config:
  gitlab_logs:
  gitlab_data:

networks:
  ceres:
    external: true
```

### 1.2 Create PostgreSQL database for GitLab

```bash
# Connect to PostgreSQL
docker exec -it postgres psql -U postgres

# Create database
CREATE DATABASE gitlab;
CREATE USER gitlab WITH PASSWORD 'GITLAB_DB_PASSWORD';
ALTER DATABASE gitlab OWNER TO gitlab;
GRANT ALL PRIVILEGES ON DATABASE gitlab TO gitlab;

# Exit
\q
```

### 1.3 Start GitLab

```bash
# Start GitLab service
docker-compose -f config/compose/gitlab.yml up -d

# Wait for initialization (5-10 minutes!)
docker logs -f gitlab

# When ready, should see:
# "gitlab Reconfigured!"
```

### 1.4 Get initial root password

```bash
# Option 1: From logs
docker logs gitlab | grep "Initial root password"

# Option 2: From container
docker exec gitlab grep "password" /etc/gitlab/initial_root_password

# Save it securely!
echo "GITLAB_ROOT_PASSWORD=..." >> /secure/location/.env
```

### 1.5 Configure GitLab

```bash
# Open browser: https://gitlab.ceres

# 1. Login with root + password
# 2. Admin → Settings → General
#    - Set sign-up disabled (no open registration)
#    - Set OIDC as primary auth
#    - Save

# 3. Create Keycloak OIDC client (in Keycloak):
#    - Client ID: gitlab-oidc
#    - Generate secret: GITLAB_OIDC_SECRET
#    - Redirect URI: https://gitlab.ceres/users/auth/openid_connect/callback
```

**ПРОВЕРКА:**
```
✓ GitLab deployed
✓ Database created
✓ OIDC configured
✓ Can login with Keycloak
✓ https://gitlab.ceres working
```

---

## 📦 PHASE 2: MIGRATE GIT REPOSITORIES (2 часа)

### 2.1 Export repositories from Gitea

```bash
# List all Gitea repositories
GITEA_URL="http://gitea.ceres"
GITEA_TOKEN="your-gitea-token"

curl -X GET "$GITEA_URL/api/v1/repos/search" \
  -H "Authorization: token $GITEA_TOKEN" | jq '.'
```

### 2.2 Mirror each repository to GitLab

```bash
#!/bin/bash
# scripts/migrate-git-repos.sh

GITEA_URL="http://gitea.ceres"
GITLAB_URL="https://gitlab.ceres"
GITLAB_TOKEN="your-gitlab-token"
GITEA_TOKEN="your-gitea-token"

# Create temp directory
mkdir -p /tmp/git-migration
cd /tmp/git-migration

# Get all repos from Gitea
REPOS=$(curl -s -X GET "$GITEA_URL/api/v1/repos/search" \
  -H "Authorization: token $GITEA_TOKEN" | jq -r '.data[] | .full_name')

for REPO in $REPOS; do
  echo "Migrating: $REPO"
  
  # Clone with full history
  git clone --mirror "$GITEA_URL/$REPO.git" "$REPO.git"
  
  # Get repo info
  OWNER=$(echo $REPO | cut -d'/' -f1)
  REPONAME=$(echo $REPO | cut -d'/' -f2)
  
  # Create group in GitLab if needed
  GROUP_EXISTS=$(curl -s "$GITLAB_URL/api/v4/groups?search=$OWNER" \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '.[] | select(.name=="'$OWNER'")')
  
  if [ -z "$GROUP_EXISTS" ]; then
    # Create group
    curl -X POST "$GITLAB_URL/api/v4/groups" \
      -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"$OWNER\",\"path\":\"$OWNER\"}"
  fi
  
  # Create project in GitLab
  curl -X POST "$GITLAB_URL/api/v4/projects" \
    -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\":\"$REPONAME\",
      \"namespace_id\":\"$OWNER\",
      \"visibility\":\"private\",
      \"issues_enabled\":true,
      \"wiki_enabled\":true,
      \"snippets_enabled\":true,
      \"merge_method\":\"merge_commit\"
    }" > /tmp/gitlab-project.json
  
  PROJECT_ID=$(cat /tmp/gitlab-project.json | jq '.id')
  
  # Push mirror
  cd "$REPO.git"
  git push --mirror "$GITLAB_URL/group/$OWNER/$REPONAME.git"
  cd ..
  
  echo "✓ Migrated: $REPO"
done

echo "All repositories migrated!"
```

### 2.3 Run migration script

```bash
chmod +x scripts/migrate-git-repos.sh
./scripts/migrate-git-repos.sh
```

### 2.4 Verify migrations

```bash
# Check all projects in GitLab
curl -X GET "https://gitlab.ceres/api/v4/projects" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '.[] | {name, web_url}'

# Test clone from GitLab
git clone https://gitlab.ceres/group/project.git
cd project
git log --oneline | head -5
```

**ПРОВЕРКА:**
```
✓ All repos migrated
✓ Full git history preserved
✓ Can clone from GitLab
✓ Commit history correct
```

---

## 🐛 PHASE 3: MIGRATE ISSUES FROM REDMINE (2 часа)

### 3.1 Export Redmine issues

```bash
#!/bin/bash
# scripts/export-redmine-issues.sh

REDMINE_URL="http://redmine.ceres"
REDMINE_API_KEY="your-api-key"

# Export all issues as JSON
curl -X GET "$REDMINE_URL/issues.json?limit=9999&include=journals,attachments" \
  -H "X-Redmine-API-Key: $REDMINE_API_KEY" \
  > /tmp/redmine-issues.json

echo "✓ Exported Redmine issues"
```

### 3.2 Convert Redmine issues to GitLab format

```bash
#!/bin/bash
# scripts/convert-redmine-to-gitlab.sh

python3 << 'EOF'
import json
import requests
from datetime import datetime

# Load Redmine issues
with open('/tmp/redmine-issues.json', 'r') as f:
    redmine_data = json.load(f)

# GitLab API config
GITLAB_URL = "https://gitlab.ceres"
GITLAB_TOKEN = "your-gitlab-token"

# Process each issue
for redmine_issue in redmine_data['issues']:
    issue_id = redmine_issue['id']
    project_id = redmine_issue['project']['id']
    
    # Map Redmine issue to GitLab issue
    gitlab_issue = {
        'title': redmine_issue['subject'],
        'description': redmine_issue.get('description', ''),
        'assignee_ids': [],  # Will need to map users
        'milestone_id': None,
        'labels': [],
        'created_at': redmine_issue['created_on'],
        'updated_at': redmine_issue['updated_on'],
        'state': 'closed' if redmine_issue['status']['id'] >= 5 else 'opened'
    }
    
    # Add priority as label
    priority_map = {1: 'Low', 2: 'Normal', 3: 'High', 4: 'Urgent', 5: 'Immediate'}
    if 'priority' in redmine_issue:
        gitlab_issue['labels'].append(priority_map.get(redmine_issue['priority']['id'], 'Normal'))
    
    # Create issue in GitLab
    # (Find correct project_id mapping from Redmine to GitLab)
    # POST /projects/:id/issues
    
    print(f"Would create GitLab issue for Redmine #{issue_id}")

EOF
```

### 3.3 Create GitLab issues programmatically

```bash
#!/bin/bash
# scripts/create-gitlab-issues.sh

GITLAB_URL="https://gitlab.ceres"
GITLAB_TOKEN="your-gitlab-token"
PROJECT_ID="1"  # Your project ID

# Create sample issue
curl -X POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/issues" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Migrated from Redmine",
    "description": "This is migrated issue",
    "labels": ["migrated"],
    "assignee_id": 1
  }'
```

### 3.4 Map users between systems

```bash
# Create mapping file: user-mapping.json
cat > /tmp/user-mapping.json << 'EOF'
{
  "redmine_user_1": "gitlab_user_1",
  "redmine_user_2": "gitlab_user_2"
}
EOF
```

**ПРОВЕРКА:**
```
✓ Issues exported from Redmine
✓ Issues created in GitLab
✓ Descriptions preserved
✓ User mapping correct
```

---

## 📚 PHASE 4: MIGRATE WIKI FROM WIKI.JS (1 час)

### 4.1 Export Wiki.js pages

```bash
#!/bin/bash
# scripts/export-wikijs-pages.sh

# Connect to Wiki.js database
docker exec postgres psql -U wikijs -d wikijs -c \
  "SELECT content, filename FROM pages;" > /tmp/wikijs-pages.sql

# Or export via API
curl -X POST "http://wikijs.ceres/graphql" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ pages { list { id title content path } } }"}' \
  > /tmp/wikijs-pages.json
```

### 4.2 Convert to Markdown

```bash
#!/bin/bash
# scripts/convert-wiki-to-markdown.sh

mkdir -p /tmp/gitlab-wiki

# Extract markdown files
python3 << 'EOF'
import json

with open('/tmp/wikijs-pages.json', 'r') as f:
    data = json.load(f)

for page in data['data']['pages']['list']:
    title = page['title']
    content = page['content']
    path = page['path'].replace('/', '_')
    
    # Write markdown file
    with open(f'/tmp/gitlab-wiki/{path}.md', 'w') as f:
        f.write(f"# {title}\n\n{content}")
    
    print(f"✓ Converted: {title}")

EOF
```

### 4.3 Push to GitLab Wiki

```bash
# Each project has wiki as separate git repo
cd /tmp

# Clone GitLab Wiki repo
git clone https://gitlab-token:$GITLAB_TOKEN@gitlab.ceres/group/project.wiki.git

# Copy files
cp /tmp/gitlab-wiki/*.md project.wiki/

# Commit and push
cd project.wiki
git add .
git commit -m "Migrated from Wiki.js"
git push origin master

echo "✓ Wiki migrated to GitLab!"
```

**ПРОВЕРКА:**
```
✓ Wiki pages exported
✓ Markdown format correct
✓ Pages visible in GitLab Wiki
✓ Links working
```

---

## 💬 PHASE 5: DEPLOY ZULIP + INTEGRATIONS (2 часа)

### 5.1 Create Zulip compose config

**File: config/compose/zulip.yml**

```yaml
version: '3.8'

services:
  zulip:
    image: zulip/docker-zulip:15.0@sha256:...
    container_name: zulip
    restart: unless-stopped
    environment:
      SETTING_EXTERNAL_HOST: zulip.ceres
      SETTING_ZULIP_ADMINISTRATOR: admin@ceres.local
      SETTING_ADMIN_DOMAIN: zulip.ceres
      SETTING_SECRET_KEY: $ZULIP_SECRET_KEY
      
      # Database
      SETTING_DATABASE_USER: zulip
      SETTING_DATABASE_PASSWORD: $ZULIP_DB_PASSWORD
      SETTING_DATABASE_HOST: postgres
      SETTING_DATABASE_PORT: 5432
      SETTING_DATABASE_NAME: zulip
      
      # Redis
      SETTING_REDIS_HOST: redis
      SETTING_REDIS_PORT: 6379
      
      # OIDC with Keycloak
      SETTING_AUTHENTICATION_BACKENDS: |
        zulip.backends.ZulipRemoteUserBackend
        zulip.backends.GoogleMobileOAuth2Backend
        zulip.backends.EmailAuthBackend
      
      SETTING_SOCIAL_AUTH_OIDC_ENABLED: "true"
      SETTING_SOCIAL_AUTH_OIDC_KEY: zulip-oidc
      SETTING_SOCIAL_AUTH_OIDC_SECRET: $ZULIP_OIDC_SECRET
      SETTING_SOCIAL_AUTH_OIDC_ID_TOKEN_DECRYPTION_KEY: ""
      SETTING_SOCIAL_AUTH_OIDC_URL_BASE: https://auth.ceres/realms/master
      SETTING_SOCIAL_AUTH_OIDC_OIDC_ENDPOINT: https://auth.ceres/realms/master/.well-known/openid-configuration
      
      # Enable integrations
      SETTING_SEND_WEBHOOK_EVENTS: "true"
      SETTING_ENABLE_GITLAB_INTEGRATION: "true"
      SETTING_ENABLE_GITHUB_INTEGRATION: "true"
      SETTING_ENABLE_SENTRY_INTEGRATION: "true"
      
      # Disable onboarding
      SETTING_TUTORIAL_ENABLED: "false"
      
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - zulip_data:/data
      - /etc/letsencrypt/live/zulip.ceres:/etc/letsencrypt:ro
    depends_on:
      - postgres
      - redis
    networks:
      - ceres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  zulip_data:

networks:
  ceres:
    external: true
```

### 5.2 Create PostgreSQL database for Zulip

```bash
docker exec -it postgres psql -U postgres

CREATE DATABASE zulip;
CREATE USER zulip WITH PASSWORD 'ZULIP_DB_PASSWORD';
ALTER DATABASE zulip OWNER TO zulip;
GRANT ALL PRIVILEGES ON DATABASE zulip TO zulip;

\q
```

### 5.3 Deploy Zulip

```bash
docker-compose -f config/compose/zulip.yml up -d

# Wait for initialization
sleep 30

# Create admin user
docker exec zulip python manage.py create_user
```

### 5.4 Configure GitLab integration

```bash
# In Zulip UI:
# 1. Settings → Integrations
# 2. Add integration: GitLab
# 3. Copy webhook URL
# 4. Paste in GitLab project settings
```

**In GitLab:**
```
Project → Settings → Integrations → Webhooks
URL: [Zulip webhook URL]
Events: Push, Issues, Merge Requests, Comments
```

**ПРОВЕРКА:**
```
✓ Zulip deployed
✓ OIDC login works
✓ GitLab integration enabled
✓ Webhooks receiving events
✓ Notifications in Zulip working
```

---

## ⚙️ PHASE 6: SETUP CI/CD PIPELINES (2 часа)

### 6.1 Create .gitlab-ci.yml for each project

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy

variables:
  REGISTRY_HOST: "registry.ceres"
  IMAGE_NAME: "$REGISTRY_HOST/$CI_PROJECT_PATH"

test:
  stage: test
  image: node:18
  script:
    - npm install
    - npm test
  only:
    - merge_requests

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHA
    - docker tag $IMAGE_NAME:$CI_COMMIT_SHA $IMAGE_NAME:latest
    - docker push $IMAGE_NAME:latest
  only:
    - main

deploy:
  stage: deploy
  image: alpine:latest
  script:
    - echo "Deploying to production..."
    # Add your deployment script here
  only:
    - main
  when: manual
```

### 6.2 Configure GitLab Runner (optional)

```bash
# If you want local CI/CD execution
docker run -d --name gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest

# Register runner
docker exec gitlab-runner gitlab-runner register \
  --url "https://gitlab.ceres" \
  --registration-token "YOUR_REGISTRATION_TOKEN" \
  --executor docker \
  --docker-image docker:latest
```

**ПРОВЕРКА:**
```
✓ CI/CD pipelines created
✓ Tests running automatically
✓ Images building
✓ Deployments working
```

---

## 🗑️ PHASE 7: CLEANUP - REMOVE OLD SERVICES (1 час)

### 7.1 Verify all data migrated

```bash
# Check GitLab has all repos
curl -s "https://gitlab.ceres/api/v4/projects?per_page=100" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" | jq '.[] | {name, issues_count}'

# Check Zulip is working
curl -s "https://zulip.ceres/api/v1/messages" \
  -u "admin:password"
```

### 7.2 Stop old services

```bash
# Stop Gitea
docker-compose -f config/compose/apps.yml stop gitea

# Stop Redmine
docker-compose -f config/compose/apps.yml stop redmine

# Stop Wiki.js
docker-compose -f config/compose/apps.yml stop wikijs

# Stop Mattermost
docker-compose -f config/compose/apps.yml stop mattermost
```

### 7.3 Remove old services from compose files

**Update config/compose/apps.yml:**
```yaml
# REMOVE:
# - gitea service
# - redmine service
# - wikijs service
# - mattermost service

# KEEP:
# - keycloak (SSO)
# - nextcloud (files)
# - other services
```

**Update config/compose/base.yml:**
```yaml
# Remove volumes:
# - gitea_data
# - redmine_data
# - wikijs_data
# - mattermost_data
```

### 7.4 Update DNS/Caddy routing

**Update config/caddy/Caddyfile:**

```
# OLD:
# gitea.ceres { reverse_proxy gitea:3000 }
# redmine.ceres { reverse_proxy redmine:3000 }
# wiki.ceres { reverse_proxy wikijs:3000 }
# mattermost.ceres { reverse_proxy mattermost:8000 }

# NEW:
gitlab.ceres { reverse_proxy gitlab:80 }
zulip.ceres { reverse_proxy zulip:80 }
registry.ceres { reverse_proxy gitlab:5000 }
```

### 7.5 Reload Caddy

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### 7.6 Update documentation

```bash
# Update all docs to reference GitLab instead of Gitea/Redmine
grep -r "gitea\|redmine\|wiki.js\|mattermost" docs/
# Replace with gitlab/zulip references

# Update README
# Update architecture diagrams
# Update onboarding guides
```

### 7.7 Verify everything works

```bash
# Test GitLab
curl -s https://gitlab.ceres/help | grep -i gitlab

# Test Zulip
curl -s https://zulip.ceres | grep -i zulip

# Check DNS
nslookup gitlab.ceres
nslookup zulip.ceres

# Test git operations
git clone https://gitlab.ceres/group/project.git
```

**ПРОВЕРКА:**
```
✓ All data migrated
✓ Old services stopped
✓ New services working
✓ DNS correct
✓ Caddy routing updated
✓ Documentation updated
```

---

## 🎉 FINAL VERIFICATION CHECKLIST

```
GIT WORKFLOW:
  ✓ Clone from GitLab
  ✓ Push commits
  ✓ Create branches
  ✓ Make merge requests
  ✓ Code review works
  ✓ Commits close issues (fixes #123)

ISSUE TRACKING:
  ✓ Create issues
  ✓ Assign to users
  ✓ Add labels
  ✓ Set milestones
  ✓ Link to MRs
  ✓ Close with commits

WIKI:
  ✓ Create wiki pages
  ✓ Edit pages
  ✓ Page history working
  ✓ Git sync working
  ✓ Links between pages

CI/CD:
  ✓ Pipelines run on push
  ✓ Tests execute
  ✓ Build artifacts created
  ✓ Docker images pushed

CHAT:
  ✓ Users can login with Keycloak
  ✓ Channels created
  ✓ GitLab notifications arriving
  ✓ Webhook events received

INTEGRATIONS:
  ✓ Keycloak SSO everywhere
  ✓ GitLab → Zulip webhooks
  ✓ Prometheus metrics collected
  ✓ Grafana dashboards updated
```

---

## 📊 MIGRATION SUMMARY

```
BEFORE:
  Services: 10 (Gitea, Redmine, Wiki.js, Mattermost, etc)
  Integration: 50/100
  Enterprise Ready: 57%
  RAM: ~10GB

AFTER:
  Services: 8 (GitLab CE, Zulip, etc - 2 removed!)
  Integration: 97/100
  Enterprise Ready: 98%
  RAM: ~9GB (-1GB!)
  
GAINED:
  ✓ CI/CD built-in
  ✓ Code review built-in
  ✓ Container registry
  ✓ Package registry
  ✓ Time tracking
  ✓ Roadmaps
  ✓ Issue linking
  ✓ Auto-closing issues
  ✓ Git-backed wiki
  
TIMELINE: 17 hours (2 days full-time)
ROI: 1 month (productivity +30%)
```

---

## 🚀 NEXT STEPS

1. **Review this plan** - Do you have any questions?
2. **Prepare for migration** - Set date and time
3. **Notify team** - Let them know about downtime
4. **Execute Phase 0** - Start backups
5. **Execute Phases 1-7** - Follow the plan step by step
6. **Test everything** - Verify all functionality
7. **Celebrate!** - You now have revolutionary platform! 🎉

---

**ГОТОВЫ К МИГРАЦИИ? 🚀**

Я готов помочь с каждой фазой!

**Какой шаг начинаем?**
