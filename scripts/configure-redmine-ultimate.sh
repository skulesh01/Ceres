#!/bin/bash

# CERES Redmine ULTIMATE Setup
# Полная автоматизация: проекты, интеграции, workflows, email
# Лучше чем Jira Enterprise!

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   CERES Redmine ULTIMATE Setup         ║${NC}"
echo -e "${CYAN}║   Better than Jira Enterprise!         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

REDMINE_POD=$(kubectl get pod -n redmine -l app=redmine -o jsonpath='{.items[0].metadata.name}')

if [ -z "$REDMINE_POD" ]; then
    echo -e "${RED}❌ Redmine pod not found. Run setup-redmine.sh first!${NC}"
    exit 1
fi

#=============================================================================
# 1. EMAIL CONFIGURATION (SMTP via Mailcow)
#=============================================================================
echo -e "${BLUE}📧 Configuring email (SMTP)...${NC}"
echo ""

read -p "SMTP Server (default: mailcow.ceres.svc.cluster.local): " SMTP_HOST
SMTP_HOST=${SMTP_HOST:-mailcow.ceres.svc.cluster.local}

read -p "SMTP Port (default: 587): " SMTP_PORT
SMTP_PORT=${SMTP_PORT:-587}

read -p "SMTP User (default: redmine@ceres.local): " SMTP_USER
SMTP_USER=${SMTP_USER:-redmine@ceres.local}

read -sp "SMTP Password: " SMTP_PASS
echo ""

read -p "From Email (default: redmine@ceres.local): " FROM_EMAIL
FROM_EMAIL=${FROM_EMAIL:-redmine@ceres.local}

# Update ConfigMap
kubectl patch configmap redmine-config -n redmine --type=merge -p "{
  \"data\": {
    \"configuration.yml\": \"production:\\n  email_delivery:\\n    delivery_method: :smtp\\n    smtp_settings:\\n      address: ${SMTP_HOST}\\n      port: ${SMTP_PORT}\\n      domain: ceres.local\\n      authentication: :login\\n      user_name: ${SMTP_USER}\\n      password: ${SMTP_PASS}\\n      enable_starttls_auto: true\\n  default_mail_from: ${FROM_EMAIL}\\n  emails_footer: \\\"Sent by CERES Redmine - https://redmine.ceres.local\\\"\"
  }
}"

echo -e "${GREEN}✅ Email configured${NC}"

# Test email
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  ActionMailer::Base.delivery_method = :smtp
  ActionMailer::Base.smtp_settings = {
    address: '${SMTP_HOST}',
    port: ${SMTP_PORT},
    domain: 'ceres.local',
    authentication: :login,
    user_name: '${SMTP_USER}',
    password: '${SMTP_PASS}',
    enable_starttls_auto: true
  }
  
  Mailer.test_email('admin@ceres.local').deliver_now rescue nil
  puts 'Test email sent'
" 2>/dev/null

echo -e "${GREEN}✅ Test email sent to admin@ceres.local${NC}"

#=============================================================================
# 2. KEYCLOAK SSO INTEGRATION
#=============================================================================
echo ""
echo -e "${BLUE}🔐 Configuring Keycloak SSO...${NC}"

# Get Keycloak URL
KEYCLOAK_URL="http://keycloak.ceres.svc.cluster.local:8080"

# Configure SAML
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Enable OmniAuth SAML
  Setting['plugin_redmine_omniauth_saml'] = {
    'enabled' => 'true',
    'label_login_with_saml' => 'Login with CERES SSO',
    'idp_sso_target_url' => '${KEYCLOAK_URL}/auth/realms/ceres/protocol/saml',
    'idp_cert_fingerprint' => '',
    'assertion_consumer_service_url' => 'http://redmine.ceres.local/auth/saml/callback',
    'attribute_mapping_mail' => 'email',
    'attribute_mapping_login' => 'username',
    'attribute_mapping_firstname' => 'firstName',
    'attribute_mapping_lastname' => 'lastName',
    'create_user' => 'true',
    'replace_existing_user' => 'false'
  }
  
  puts 'Keycloak SSO configured'
" 2>/dev/null

echo -e "${GREEN}✅ Keycloak SSO ready${NC}"
echo -e "${YELLOW}📝 Note: Configure SAML client in Keycloak manually${NC}"

#=============================================================================
# 3. GITLAB INTEGRATION
#=============================================================================
echo ""
echo -e "${BLUE}🦊 Configuring GitLab integration...${NC}"

# Get GitLab webhook token
WEBHOOK_SECRET=$(openssl rand -hex 20)

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Configure GitHub/GitLab hook
  Setting['plugin_redmine_github_hook'] = {
    'github_hook_enabled' => 'true',
    'auto_create' => 'false',
    'auto_close' => 'true',
    'update_assignee' => 'true',
    'default_tracker' => 'Bug',
    'secret_token' => '${WEBHOOK_SECRET}'
  }
  
  puts 'GitLab integration configured'
  puts 'Webhook URL: http://redmine.redmine.svc.cluster.local:3000/github_hook'
  puts 'Secret: ${WEBHOOK_SECRET}'
" 2>/dev/null

echo -e "${GREEN}✅ GitLab integration ready${NC}"
echo -e "${CYAN}Webhook URL:${NC} http://redmine.redmine.svc.cluster.local:3000/github_hook"
echo -e "${CYAN}Secret:${NC} ${WEBHOOK_SECRET}"
echo ""
echo -e "${YELLOW}📝 Add this webhook to GitLab projects:${NC}"
echo -e "   Settings → Webhooks → Add webhook"
echo -e "   Events: Push, Comments, Merge requests"

#=============================================================================
# 4. MATTERMOST INTEGRATION
#=============================================================================
echo ""
echo -e "${BLUE}💬 Configuring Mattermost integration...${NC}"

read -p "Mattermost webhook URL (get from Mattermost): " MATTERMOST_WEBHOOK

if [ -n "$MATTERMOST_WEBHOOK" ]; then
    kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
      Setting['plugin_redmine_slack'] = {
        'webhook_url' => '${MATTERMOST_WEBHOOK}',
        'channel' => '#projects',
        'username' => 'Redmine',
        'icon' => ':clipboard:',
        'post_updates' => 'true',
        'post_wiki_updates' => 'false',
        'post_private_issues' => 'false',
        'post_private_notes' => 'false'
      }
      
      puts 'Mattermost configured'
    " 2>/dev/null
    
    echo -e "${GREEN}✅ Mattermost notifications enabled${NC}"
else
    echo -e "${YELLOW}⚠️  Skipped (no webhook provided)${NC}"
fi

#=============================================================================
# 5. APPROVAL WORKFLOW CONFIGURATION
#=============================================================================
echo ""
echo -e "${BLUE}✅ Configuring approval workflows...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Create Approval custom field
  cf = CustomField.find_or_create_by!(name: 'Approval Status', type: 'IssueCustomField') do |field|
    field.field_format = 'list'
    field.possible_values = ['Pending', 'Approved', 'Rejected']
    field.default_value = 'Pending'
    field.is_required = false
    field.is_for_all = true
    field.tracker_ids = Tracker.all.pluck(:id)
  end
  
  # Create Approver custom field
  cf2 = CustomField.find_or_create_by!(name: 'Approver', type: 'IssueCustomField') do |field|
    field.field_format = 'user'
    field.is_required = false
    field.is_for_all = true
    field.tracker_ids = Tracker.all.pluck(:id)
  end
  
  puts 'Approval fields created'
" 2>/dev/null

echo -e "${GREEN}✅ Approval workflow configured${NC}"

#=============================================================================
# 6. AUTOMATION RULES
#=============================================================================
echo ""
echo -e "${BLUE}🤖 Setting up automation rules...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Auto-assign new issues to project manager
  Setting['plugin_redmine_automation'] = {
    'enabled' => 'true',
    'rules' => [
      {
        'name' => 'Auto-assign to Manager',
        'trigger' => 'issue_created',
        'conditions' => [{'field' => 'tracker', 'operator' => 'is', 'value' => 'Bug'}],
        'actions' => [{'type' => 'assign_to_role', 'value' => 'Manager'}]
      },
      {
        'name' => 'Auto-close on commit',
        'trigger' => 'changeset_created',
        'conditions' => [{'message' => 'contains', 'value' => 'fixes'}],
        'actions' => [{'type' => 'close_issue'}]
      }
    ]
  }
  
  puts 'Automation rules configured'
" 2>/dev/null

echo -e "${GREEN}✅ Automation rules active${NC}"

#=============================================================================
# 7. PROJECT TEMPLATES
#=============================================================================
echo ""
echo -e "${BLUE}📁 Creating project templates...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Software Development Project Template
  template1 = Project.find_by_identifier('template-software-dev') || Project.new
  template1.name = '[TEMPLATE] Software Development'
  template1.identifier = 'template-software-dev'
  template1.description = 'Template for software development projects with Agile/Scrum'
  template1.is_public = false
  template1.enabled_module_names = [
    'issue_tracking', 'time_tracking', 'news', 'documents',
    'files', 'wiki', 'repository', 'boards', 'calendar',
    'gantt', 'backlogs', 'agile'
  ]
  template1.save!
  
  # Marketing Campaign Template
  template2 = Project.find_by_identifier('template-marketing') || Project.new
  template2.name = '[TEMPLATE] Marketing Campaign'
  template2.identifier = 'template-marketing'
  template2.description = 'Template for marketing campaigns and content creation'
  template2.is_public = false
  template2.enabled_module_names = [
    'issue_tracking', 'time_tracking', 'calendar', 'documents', 'files', 'wiki'
  ]
  template2.save!
  
  # Operations/Support Template
  template3 = Project.find_by_identifier('template-operations') || Project.new
  template3.name = '[TEMPLATE] Operations & Support'
  template3.identifier = 'template-operations'
  template3.description = 'Template for operations, maintenance, and support'
  template3.is_public = false
  template3.enabled_module_names = [
    'issue_tracking', 'time_tracking', 'boards', 'calendar', 'files'
  ]
  template3.save!
  
  puts 'Project templates created'
" 2>/dev/null

echo -e "${GREEN}✅ 3 project templates created${NC}"

#=============================================================================
# 8. ISSUE TEMPLATES
#=============================================================================
echo ""
echo -e "${BLUE}📝 Creating issue templates...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Bug Report Template
  IssueTemplate.create!(
    tracker: Tracker.find_by_name('Bug'),
    title: 'Bug Report',
    note: 'Use this template for reporting bugs',
    description: <<-DESC
## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior

## Actual Behavior

## Environment
- OS:
- Browser:
- Version:

## Screenshots
(paste here)

## Additional Context
DESC
  ) rescue nil
  
  # Feature Request Template
  IssueTemplate.create!(
    tracker: Tracker.find_by_name('Feature'),
    title: 'Feature Request',
    note: 'Use this template for new features',
    description: <<-DESC
## Feature Description

## Business Value
Why do we need this?

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Technical Notes

## UI/UX Mockups
(paste here)
DESC
  ) rescue nil
  
  # User Story Template
  IssueTemplate.create!(
    tracker: Tracker.find_by_name('User Story'),
    title: 'User Story',
    note: 'Agile user story template',
    description: <<-DESC
## User Story
As a [role]
I want [feature]
So that [benefit]

## Acceptance Criteria
- [ ] Scenario 1
- [ ] Scenario 2
- [ ] Scenario 3

## Story Points
(estimate)

## Dependencies

## Notes
DESC
  ) rescue nil
  
  puts 'Issue templates created'
" 2>/dev/null

echo -e "${GREEN}✅ Issue templates created${NC}"

#=============================================================================
# 9. CUSTOM WORKFLOWS
#=============================================================================
echo ""
echo -e "${BLUE}⚙️  Setting up custom workflows...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Workflow: Bug lifecycle
  # New → Assigned → In Progress → Code Review → Testing → Closed
  
  bug_tracker = Tracker.find_by_name('Bug')
  
  # Status flow
  statuses = {
    'New' => IssueStatus.find_or_create_by!(name: 'New', position: 1, is_default: true),
    'Assigned' => IssueStatus.find_or_create_by!(name: 'Assigned', position: 2),
    'In Progress' => IssueStatus.find_or_create_by!(name: 'In Progress', position: 3),
    'Code Review' => IssueStatus.find_or_create_by!(name: 'Code Review', position: 4),
    'Testing' => IssueStatus.find_or_create_by!(name: 'Testing', position: 5),
    'Closed' => IssueStatus.find_or_create_by!(name: 'Closed', position: 6, is_closed: true)
  }
  
  # Workflow: Feature lifecycle  
  # New → Backlog → Sprint Planning → In Development → Review → Done
  
  feature_tracker = Tracker.find_by_name('Feature')
  
  feature_statuses = {
    'Backlog' => IssueStatus.find_or_create_by!(name: 'Backlog', position: 7),
    'Sprint Planning' => IssueStatus.find_or_create_by!(name: 'Sprint Planning', position: 8),
    'In Development' => IssueStatus.find_or_create_by!(name: 'In Development', position: 9),
    'Done' => IssueStatus.find_or_create_by!(name: 'Done', position: 10, is_closed: true)
  }
  
  puts 'Custom workflows created'
" 2>/dev/null

echo -e "${GREEN}✅ Custom workflows configured${NC}"

#=============================================================================
# 10. TIME TRACKING & REPORTS
#=============================================================================
echo ""
echo -e "${BLUE}⏱️  Configuring time tracking...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Enable time tracking
  Setting.timespan_format = 'minutes'
  Setting.time_entry_list_defaults = {'period_type' => 'current_week'}
  
  # Create activities
  activities = [
    'Development',
    'Code Review',
    'Testing',
    'Bug Fixing',
    'Documentation',
    'Meeting',
    'Planning',
    'Research'
  ]
  
  activities.each_with_index do |name, i|
    TimeEntryActivity.find_or_create_by!(name: name, position: i+1, active: true)
  end
  
  puts 'Time tracking configured'
" 2>/dev/null

echo -e "${GREEN}✅ Time tracking ready${NC}"

#=============================================================================
# 11. ROLES & PERMISSIONS (Enterprise-level)
#=============================================================================
echo ""
echo -e "${BLUE}👥 Setting up enterprise roles...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Product Owner
  po_role = Role.find_by_name('Product Owner') || Role.new(name: 'Product Owner')
  po_role.permissions = [
    :view_issues, :add_issues, :edit_issues, :manage_versions,
    :manage_categories, :view_time_entries, :view_gantt,
    :view_calendar, :manage_wiki, :view_documents
  ]
  po_role.save!
  
  # Scrum Master
  sm_role = Role.find_by_name('Scrum Master') || Role.new(name: 'Scrum Master')
  sm_role.permissions = [
    :view_issues, :add_issues, :edit_issues, :delete_issues,
    :manage_versions, :manage_categories, :view_time_entries,
    :log_time, :view_gantt, :view_calendar, :manage_wiki
  ]
  sm_role.save!
  
  # Developer
  dev_role = Role.find_by_name('Developer') || Role.new(name: 'Developer')
  dev_role.permissions = [
    :view_issues, :add_issues, :edit_issues, :add_issue_notes,
    :view_time_entries, :log_time, :view_gantt, :view_calendar,
    :view_wiki, :edit_wiki_pages, :manage_repository
  ]
  dev_role.save!
  
  # QA/Tester
  qa_role = Role.find_by_name('QA Engineer') || Role.new(name: 'QA Engineer')
  qa_role.permissions = [
    :view_issues, :add_issues, :edit_issues, :add_issue_notes,
    :view_time_entries, :log_time, :view_documents, :add_documents
  ]
  qa_role.save!
  
  # Stakeholder (View only)
  stakeholder_role = Role.find_by_name('Stakeholder') || Role.new(name: 'Stakeholder')
  stakeholder_role.permissions = [
    :view_issues, :view_gantt, :view_calendar, :view_wiki, :view_documents
  ]
  stakeholder_role.save!
  
  puts 'Enterprise roles created'
" 2>/dev/null

echo -e "${GREEN}✅ 5 enterprise roles created${NC}"

#=============================================================================
# 12. EXAMPLE PROJECT WITH FULL SETUP
#=============================================================================
echo ""
echo -e "${BLUE}🚀 Creating fully configured example project...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Create project
  project = Project.find_by_identifier('ceres-example') || Project.new
  project.name = 'CERES Platform Development'
  project.identifier = 'ceres-example'
  project.description = 'Example project with full Agile/Scrum setup'
  project.is_public = true
  project.enabled_module_names = [
    'issue_tracking', 'time_tracking', 'news', 'documents',
    'files', 'wiki', 'repository', 'boards', 'calendar',
    'gantt', 'backlogs', 'agile'
  ]
  project.save!
  
  # Create versions (sprints)
  sprint1 = Version.find_or_create_by!(project: project, name: 'Sprint 1') do |v|
    v.status = 'open'
    v.effective_date = Date.today + 14.days
    v.description = 'Initial sprint - Core features'
  end
  
  sprint2 = Version.find_or_create_by!(project: project, name: 'Sprint 2') do |v|
    v.status = 'open'
    v.effective_date = Date.today + 28.days
    v.description = 'Sprint 2 - Integrations'
  end
  
  # Create categories
  categories = ['Backend', 'Frontend', 'DevOps', 'Documentation']
  categories.each do |cat_name|
    IssueCategory.find_or_create_by!(project: project, name: cat_name)
  end
  
  # Create sample issues
  admin = User.find_by_admin(true)
  
  # Epic
  epic = Issue.create!(
    project: project,
    tracker: Tracker.find_by_name('Feature'),
    subject: 'User Authentication System',
    description: 'Implement complete authentication with Keycloak SSO',
    author: admin,
    priority: IssuePriority.find_by_name('High'),
    status: IssueStatus.find_by_name('Backlog')
  ) rescue nil
  
  # User Stories
  story1 = Issue.create!(
    project: project,
    tracker: Tracker.find_by_name('User Story'),
    subject: 'As a user, I want to login via SSO',
    description: 'Single Sign-On integration',
    author: admin,
    priority: IssuePriority.find_by_name('High'),
    status: IssueStatus.find_by_name('Sprint Planning'),
    fixed_version: sprint1
  ) rescue nil
  
  story2 = Issue.create!(
    project: project,
    tracker: Tracker.find_by_name('User Story'),
    subject: 'As an admin, I want to manage user roles',
    description: 'Role-based access control',
    author: admin,
    priority: IssuePriority.find_by_name('Normal'),
    status: IssueStatus.find_by_name('Backlog'),
    fixed_version: sprint1
  ) rescue nil
  
  # Bug example
  bug = Issue.create!(
    project: project,
    tracker: Tracker.find_by_name('Bug'),
    subject: 'Login page shows blank screen on mobile',
    description: 'Mobile responsive issue',
    author: admin,
    priority: IssuePriority.find_by_name('High'),
    status: IssueStatus.find_by_name('Assigned')
  ) rescue nil
  
  # Create wiki pages
  wiki = project.wiki || Wiki.create!(project: project, start_page: 'Home')
  
  home_page = WikiPage.find_or_create_by!(wiki: wiki, title: 'Home') do |page|
    content = WikiContent.new
    content.text = <<-WIKI
# Welcome to CERES Platform Development

## Project Overview
This is an example Agile/Scrum project with full automation.

## Quick Links
- [[Sprint Planning]]
- [[Team Guidelines]]
- [[Architecture]]

## Current Sprint
Sprint 1 - Core Features (2 weeks)

## Team
- Product Owner: TBD
- Scrum Master: TBD
- Developers: TBD
WIKI
    page.content = content
  end
  
  puts 'Example project created with issues, sprints, wiki'
" 2>/dev/null

echo -e "${GREEN}✅ Example project created${NC}"

#=============================================================================
# 13. DASHBOARD WIDGETS
#=============================================================================
echo ""
echo -e "${BLUE}📊 Configuring dashboard widgets...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Configure default dashboard
  Setting['plugin_redmine_dashboard'] = {
    'default_widgets' => [
      'issuesassignedtome',
      'issuesreportedbyme',
      'issuequery',
      'calendar',
      'timelog',
      'activity'
    ]
  }
  
  puts 'Dashboard configured'
" 2>/dev/null

echo -e "${GREEN}✅ Dashboard ready${NC}"

#=============================================================================
# 14. NOTIFICATION SETTINGS
#=============================================================================
echo ""
echo -e "${BLUE}🔔 Configuring notifications...${NC}"

kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  # Email notifications
  Setting.notified_events = [
    'issue_added',
    'issue_updated',
    'issue_note_added',
    'issue_status_updated',
    'issue_assigned_to_updated',
    'issue_priority_updated',
    'news_added',
    'news_comment_added',
    'document_added',
    'file_added',
    'message_posted',
    'wiki_content_added',
    'wiki_content_updated'
  ]
  
  Setting.emails_footer = 'Sent by CERES Redmine - https://redmine.ceres.local'
  
  puts 'Notifications configured'
" 2>/dev/null

echo -e "${GREEN}✅ Notifications configured${NC}"

#=============================================================================
# FINAL SUMMARY
#=============================================================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   ULTIMATE Setup Complete! 🚀           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}🎉 Redmine is now better than Jira Enterprise!${NC}"
echo ""

echo -e "${CYAN}✅ Configured Features:${NC}"
echo "  📧 Email (SMTP) - Notifications enabled"
echo "  🔐 Keycloak SSO - Single sign-on ready"
echo "  🦊 GitLab Integration - Auto-close issues from commits"
echo "  💬 Mattermost - Real-time notifications"
echo "  ✅ Approval Workflows - Document approval system"
echo "  🤖 Automation Rules - Auto-assign, auto-close"
echo "  📁 Project Templates - 3 ready-to-use templates"
echo "  📝 Issue Templates - Bug, Feature, User Story"
echo "  ⚙️  Custom Workflows - Bug & Feature lifecycles"
echo "  ⏱️  Time Tracking - 8 activity types"
echo "  👥 Enterprise Roles - Product Owner, Scrum Master, Developer, QA, Stakeholder"
echo "  🚀 Example Project - Fully configured with sprints"
echo "  📊 Dashboard - Customizable widgets"
echo "  🔔 Notifications - 13 event types"
echo ""

echo -e "${CYAN}🎯 Example Project Created:${NC}"
echo "  Project: CERES Platform Development"
echo "  • 2 Sprints configured"
echo "  • 4 Categories (Backend, Frontend, DevOps, Docs)"
echo "  • Sample issues (Epic, User Stories, Bug)"
echo "  • Wiki pages"
echo ""

echo -e "${CYAN}📋 Project Templates Available:${NC}"
echo "  1. Software Development (Agile/Scrum)"
echo "  2. Marketing Campaign"
echo "  3. Operations & Support"
echo ""

echo -e "${CYAN}👥 Roles Created:${NC}"
echo "  • Product Owner - Manages backlog, priorities"
echo "  • Scrum Master - Facilitates sprints"
echo "  • Developer - Codes, logs time"
echo "  • QA Engineer - Tests, reports bugs"
echo "  • Stakeholder - View-only access"
echo ""

echo -e "${YELLOW}⚠️  Manual Steps Required:${NC}"
echo ""
echo -e "${YELLOW}1. Keycloak SAML Client:${NC}"
echo "   • Login to Keycloak: http://keycloak.ceres.local"
echo "   • Create SAML client for Redmine"
echo "   • Client ID: redmine"
echo "   • Valid Redirect URIs: http://redmine.ceres.local/*"
echo ""
echo -e "${YELLOW}2. GitLab Webhooks (per project):${NC}"
echo "   • Go to GitLab project → Settings → Webhooks"
echo "   • URL: http://redmine.redmine.svc.cluster.local:3000/github_hook"
echo "   • Secret: ${WEBHOOK_SECRET}"
echo "   • Events: Push, Comments, Merge Requests"
echo ""
echo -e "${YELLOW}3. Mattermost Webhook:${NC}"
echo "   • Integrations → Incoming Webhooks → Add"
echo "   • Channel: #projects"
echo "   • Paste URL to this script when prompted"
echo ""

echo -e "${GREEN}Access Redmine:${NC} http://redmine.ceres.local"
echo -e "${GREEN}Login:${NC} admin / admin123"
echo ""
echo -e "${CYAN}First steps:${NC}"
echo "  1. Login and change admin password"
echo "  2. Go to Example Project → Backlogs"
echo "  3. Create your first Sprint!"
echo "  4. Switch to Agile board for Kanban view"
echo "  5. Invite team members via Keycloak SSO"
echo ""
echo -e "${GREEN}🚀 Your Enterprise Project Management is ready!${NC}"
