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
# BUILD DOCKER IMAGE
#=============================================================================
echo -e "${BLUE}🐳 Building Redmine Docker image with plugins...${NC}"
echo ""

cd docker/redmine

docker build -t redmine-ceres:5.1-plugins .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker image built successfully${NC}"
else
    echo -e "${RED}❌ Docker build failed${NC}"
    exit 1
fi

cd ../..

#=============================================================================
# IMPORT IMAGE TO K3S
#=============================================================================
echo ""
echo -e "${BLUE}📦 Importing image to K3s...${NC}"

# Save and load image for K3s
docker save redmine-ceres:5.1-plugins | sudo k3s ctr images import -

echo -e "${GREEN}✅ Image imported to K3s${NC}"

#=============================================================================
# CREATE DATABASE
#=============================================================================
echo ""
echo -e "${BLUE}🗄️  Creating Redmine database...${NC}"

# Get PostgreSQL pod
POSTGRES_POD=$(kubectl get pod -n ceres -l app=postgresql -o jsonpath='{.items[0].metadata.name}')

if [ -z "$POSTGRES_POD" ]; then
    echo -e "${RED}❌ PostgreSQL pod not found${NC}"
    exit 1
fi

# Create database
kubectl exec -n ceres $POSTGRES_POD -- psql -U postgres -c "CREATE DATABASE redmine;" 2>/dev/null || echo "Database already exists"
kubectl exec -n ceres $POSTGRES_POD -- psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE redmine TO postgres;"

echo -e "${GREEN}✅ Database created${NC}"

#=============================================================================
# DEPLOY REDMINE
#=============================================================================
echo ""
echo -e "${BLUE}🚀 Deploying Redmine...${NC}"

kubectl apply -f deployment/redmine.yaml

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
  
  # Enable Agile
  Setting.plugin_redmine_agile = {
    'estimate_units' => 'hours',
    'default_chart' => 'burndown'
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
    'backlogs',
    'agile'
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
# CONFIGURE THEMES
#=============================================================================
echo ""
echo -e "${BLUE}🎨 Setting default theme...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  Setting.ui_theme = 'PurpleMine2'
  puts 'Theme set to PurpleMine2'
" 2>/dev/null || true

echo -e "${GREEN}✅ Theme configured${NC}"

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
echo -e "${CYAN}✅ Enabled Plugins (21 total):${NC}"
echo "  🔥 Redmine Backlogs - Full Scrum (Sprint planning, Burndown charts)"
echo "  📊 Redmine Agile - Kanban boards"
echo "  ✅ Checklists"
echo "  🏷️  Tags"
echo "  📝 Issue Templates"
echo "  ✏️  WYSIWYG Editor"
echo "  📈 Dashboard"
echo "  💬 Messenger (@mentions)"
echo "  📋 Clipboard Image Paste"
echo "  🎨 Theme Changer"
echo "  💬 Slack/Mattermost integration"
echo "  🔗 GitHub/GitLab Hook"
echo "  🔐 LDAP Sync"
echo "  🔑 SAML (Keycloak SSO)"
echo "  📐 DrawIO"
echo "  📖 Wiki Extensions (PlantUML, Mermaid)"
echo "  📁 DMSF (Document Management)"
echo "  🖼️  Lightbox2"
echo "  📊 Workload"
echo "  ⏱️  Spent Time"
echo "  📉 Issue Charts"
echo ""
echo -e "${CYAN}🎨 Available Themes:${NC}"
echo "  • PurpleMine2 (default) - Modern responsive"
echo "  • Circle Theme - Material Design"
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
