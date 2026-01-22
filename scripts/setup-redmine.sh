#!/bin/bash

# CERES Redmine Setup - Build custom image with plugins

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   CERES Redmine Setup                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

#=============================================================================
# DEPLOYMENT (K3s-native)
#=============================================================================
echo -e "${BLUE}🚀 Deploying Redmine (expects image already in registry)...${NC}"
echo ""
echo -e "${YELLOW}Tip: Build/push image via CI workflow .github/workflows/redmine-image.yml${NC}"

#=============================================================================
# CREATE DATABASE
#=============================================================================
echo ""
echo -e "${BLUE}🗄️  Creating Redmine database...${NC}"

# Get PostgreSQL pod (namespace may differ)
POSTGRES_NS_AND_NAME=$(kubectl get pods --all-namespaces -l app=postgresql -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' | head -n 1)
POSTGRES_NS=$(echo "$POSTGRES_NS_AND_NAME" | awk '{print $1}')
POSTGRES_POD=$(echo "$POSTGRES_NS_AND_NAME" | awk '{print $2}')

if [ -z "$POSTGRES_NS" ] || [ -z "$POSTGRES_POD" ]; then
  echo -e "${RED}❌ PostgreSQL pod not found (label app=postgresql)${NC}"
  kubectl get pods --all-namespaces | grep -i postgres || true
  exit 1
fi

# Create database
kubectl exec -n "$POSTGRES_NS" "$POSTGRES_POD" -- psql -U postgres -c "CREATE DATABASE redmine;" 2>/dev/null || echo "Database already exists"
kubectl exec -n "$POSTGRES_NS" "$POSTGRES_POD" -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE redmine TO postgres;"

echo -e "${GREEN}✅ Database created${NC}"

#=============================================================================
# DEPLOY REDMINE
#=============================================================================
echo ""
echo -e "${BLUE}🚀 Deploying Redmine...${NC}"

./scripts/deploy-redmine.sh

echo -e "${GREEN}✅ Redmine deployed${NC}"

#=============================================================================
# WAIT FOR READY
#=============================================================================
echo ""
echo -e "${BLUE}⏳ Waiting for Redmine to be ready...${NC}"
echo -e "${YELLOW}This may take 2-3 minutes (plugins migration)${NC}"

kubectl wait --for=condition=ready pod \
    -l app=redmine \
    -n redmine \
    --timeout=300s

echo -e "${GREEN}✅ Redmine is ready!${NC}"

#=============================================================================
# CONFIGURE REDMINE
#=============================================================================
echo ""
echo -e "${BLUE}⚙️  Configuring Redmine...${NC}"

REDMINE_POD=$(kubectl get pod -n redmine -l app=redmine -o jsonpath='{.items[0].metadata.name}')

# Create admin user
echo -e "${BLUE}  Creating admin user...${NC}"
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  user = User.find_by_login('admin') || User.new
  user.login = 'admin'
  user.firstname = 'Admin'
  user.lastname = 'CERES'
  user.mail = 'admin@ceres.local'
  user.password = 'admin123'
  user.password_confirmation = 'admin123'
  user.admin = true
  user.status = 1
  user.language = 'ru'
  user.save!
  puts 'Admin user created'
" 2>/dev/null || true

# Enable plugins
echo -e "${BLUE}  Enabling plugins...${NC}"
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Enable Backlogs
  Setting.plugin_redmine_backlogs = {
    'story_trackers' => ['2'],
    'task_tracker' => '3',
    'points_burn_direction' => 'down'
  }

  puts 'Plugins configured'
" 2>/dev/null || true

# Create default project
echo -e "${BLUE}  Creating example project...${NC}"
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  project = Project.find_by_identifier('ceres-platform') || Project.new
  project.name = 'CERES Platform'
  project.identifier = 'ceres-platform'
  project.description = 'CERES DevOps Platform Development'
  project.is_public = true
  
  # Enable modules
  project.enabled_module_names = [
    'issue_tracking',
    'time_tracking',
    'news',
    'documents',
    'files',
    'wiki',
    'repository',
    'boards',
    'calendar',
    'gantt',
    'backlogs'
  ]
  
  project.save!
  puts 'Example project created'
" 2>/dev/null || true

# Create trackers for Agile
echo -e "${BLUE}  Setting up trackers...${NC}"
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # User Story
  Tracker.create!(name: 'User Story', default_status_id: 1, position: 1) unless Tracker.find_by_name('User Story')
  
  # Bug
  Tracker.find_or_create_by!(name: 'Bug') do |t|
    t.default_status_id = 1
    t.position = 2
  end
  
  # Feature
  Tracker.find_or_create_by!(name: 'Feature') do |t|
    t.default_status_id = 1
    t.position = 3
  end
  
  # Task
  Tracker.find_or_create_by!(name: 'Task') do |t|
    t.default_status_id = 1
    t.position = 4
  end
  
  puts 'Trackers configured'
" 2>/dev/null || true

echo -e "${GREEN}✅ Configuration complete${NC}"

#=============================================================================
# FINAL SUMMARY
#=============================================================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Redmine Setup Complete! ✅            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Get service info
REDMINE_IP=$(kubectl get svc -n redmine redmine -o jsonpath='{.spec.clusterIP}')
NODEPORT=$(kubectl get svc -n redmine redmine-nodeport -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "Not exposed")

echo -e "${GREEN}🎉 Redmine is ready!${NC}"
echo ""
echo -e "${CYAN}Access URLs:${NC}"
echo "  Internal: http://${REDMINE_IP}:3000"
if [ "$NODEPORT" != "Not exposed" ]; then
    echo "  External: http://YOUR_SERVER_IP:${NODEPORT}"
fi
echo "  Domain:   http://projects.ceres.local (after DNS setup)"
echo ""
echo -e "${CYAN}Credentials:${NC}"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo -e "${CYAN}✅ Enabled Plugins (public set):${NC}"
echo "  🔥 Redmine Backlogs - Full Scrum (Sprint planning, Burndown charts)"
echo "  📝 Issue Templates"
echo "  ✏️  WYSIWYG Editor"
echo "  📈 Dashboard"
echo "  📋 Clipboard Image Paste"
echo "  🎨 Theme Changer"
echo "  💬 Slack/Mattermost integration"
echo "  🔗 GitHub Hook"
echo "  📐 DrawIO"
echo "  📖 Wiki Extensions (PlantUML, Mermaid)"
echo "  📁 DMSF (Document Management)"
echo "  🖼️  Lightbox2"
echo "  🤖 Custom Workflows"
echo "  • Gitmike - GitHub-like"
echo "  • A1 Theme - Corporate"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
echo "  1. Change admin password after first login!"
echo "  2. Configure Keycloak SSO: Administration → Plugins → SAML"
echo "  3. Configure Mattermost webhook: Administration → Plugins → Slack"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  • Open Redmine and login as admin"
echo "  • Go to Project → CERES Platform → Backlogs"
echo "  • Create your first Sprint!"
echo "  • Switch to Agile Board for Kanban view"
echo ""
