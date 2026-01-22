# 🚀 CERES Redmine - Full-Featured Project Management

**Redmine 5.1 with 21+ plugins pre-installed**

---

## 📦 What's Included

### 🔥 Agile/Scrum Features

| Plugin | Description | Use Case |
|--------|-------------|----------|
| **Redmine Backlogs** | Full Scrum implementation | Sprint planning, Burndown charts, Story points, Velocity tracking |
| **Redmine Agile FREE** | Kanban boards | Drag & drop tasks, Swim lanes, WIP limits, Quick filters |
| **Issue Charts** | Analytics & graphs | Burndown, Velocity, Lead time, Cycle time |
| **Workload** | Team capacity planning | Resource allocation, Team load visualization |

### 📝 Task Management

| Plugin | Description |
|--------|-------------|
| **Checklists** | Subtask checklists in issues |
| **Tags** | Tag issues and projects |
| **Issue Templates** | Pre-defined templates (Bug, Feature, Support) |
| **Dashboard** | Customizable project dashboard |

### 💬 Communication

| Plugin | Description |
|--------|-------------|
| **Messenger** | @mentions in comments, notifications |
| **Slack** | Mattermost/Slack webhook integration |
| **Clipboard Image Paste** | Paste screenshots directly |

### 🔗 Integrations

| Plugin | Description |
|--------|-------------|
| **GitHub Hook** | Auto-update from GitLab commits |
| **LDAP Sync** | Keycloak user sync |
| **SAML** | Keycloak SSO |

### 📚 Documentation

| Plugin | Description |
|--------|-------------|
| **Wiki Extensions** | PlantUML, Mermaid diagrams |
| **DrawIO** | Visual diagrams in wiki |
| **DMSF** | Document Management System |
| **WYSIWYG Editor** | Visual text editor |

### 🎨 Themes

- **PurpleMine2** (default) - Modern responsive theme
- **Circle Theme** - Material Design
- **Gitmike** - GitHub-inspired
- **A1 Theme** - Corporate style

---

## 🚀 Quick Start

### 1. Build & Deploy

```bash
# Build Docker image with plugins
./scripts/setup-redmine.sh
```

**What it does:**
1. Builds custom Docker image with 21 plugins
2. Imports to K3s
3. Creates PostgreSQL database
4. Deploys Redmine
5. Configures plugins
6. Creates admin user
7. Sets up example project

**Time:** ~5-7 minutes

### 2. Access Redmine

```
URL: http://YOUR_SERVER_IP:30310
or:  http://projects.ceres.local

Login: admin
Password: admin123
```

### 3. First Steps

1. **Change admin password** (My account → Change password)
2. **Enable Agile modules**:
   - Go to project → Settings → Modules
   - Check: ✅ Backlogs, ✅ Agile
3. **Configure Backlogs**:
   - Administration → Plugins → Redmine Backlogs → Configure
   - Story trackers: User Story, Feature
   - Task tracker: Task
4. **Create first Sprint**:
   - Project → Backlogs → New Sprint
   - Add User Stories to Sprint
   - Start Sprint!

---

## 📊 How to Use

### Scrum Mode (Redmine Backlogs)

**Sprint Planning:**
```
1. Project → Backlogs
2. Create Sprint (2 weeks)
3. Drag User Stories from Product Backlog to Sprint
4. Estimate Story Points
5. Start Sprint
```

**Daily Standup:**
```
1. Project → Backlogs → Taskboard
2. View current sprint tasks
3. Move tasks: To Do → In Progress → Done
4. Update remaining hours
```

**Sprint Review:**
```
1. Project → Backlogs → Charts
2. View Burndown chart
3. Check Velocity
4. Close Sprint
5. Move incomplete stories to next sprint
```

### Kanban Mode (Redmine Agile)

**Setup Board:**
```
1. Project → Agile
2. Configure columns: To Do, In Progress, Review, Done
3. Set WIP limits (optional)
4. Choose swim lanes (By Assignee, By Priority)
```

**Work with Board:**
```
1. Drag & drop tasks between columns
2. Quick edit (click on task)
3. Filter by assignee/priority/version
4. Color coding by priority
```

### Time Tracking

**Log time:**
```
1. Issue → Log time
or
2. Use timer (redmine_spent_time plugin)
   - Click "Start" on issue
   - Work on task
   - Click "Stop"
   - Time auto-logged
```

**View reports:**
```
1. Project → Spent time
2. Filter by user/date/activity
3. Export to Excel/PDF
```

---

## 🔗 Integrations Setup

### GitLab Integration

**Webhook setup:**
```bash
# In GitLab project:
Settings → Webhooks

URL: http://redmine.redmine.svc.cluster.local:3000/github_hook
Secret: <redmine_secret>

Triggers:
✅ Push events
✅ Comments
✅ Merge requests
```

**Commit syntax:**
```bash
git commit -m "refs #123 - Fixed bug"
# Auto-updates issue #123

git commit -m "fixes #123 - Completed feature"
# Auto-closes issue #123
```

### Mattermost Integration

**In Redmine:**
```
Administration → Plugins → Redmine Slack → Configure

Webhook URL: http://mattermost:8065/hooks/xxx
Channel: #projects
Events:
✅ Issue created
✅ Issue updated
✅ Issue closed
```

**Notifications:**
```
New issue → #projects
Status changed → Assigned user DM
Comments → Mentioned users
```

### Keycloak SSO

**SAML setup:**
```
Administration → Plugins → OmniAuth SAML → Configure

IdP SSO URL: http://keycloak.ceres.local/auth/realms/ceres/protocol/saml
IdP Cert: <paste certificate>
Attribute mapping:
  - email → mail
  - first_name → firstname
  - last_name → lastname
```

---

## 🎨 Customization

### Change Theme

**Global (all users):**
```
Administration → Settings → Display
Default theme: PurpleMine2
```

**Per user:**
```
My account → Settings
Theme: Choose from dropdown
```

### Custom Fields

**Create custom field:**
```
Administration → Custom fields → New custom field
Type: Issue
Format: List, Text, Date, etc.
Trackers: Select which trackers use this field
```

**Example: Priority custom field**
```
Name: Business Priority
Format: List
Values: P0-Critical, P1-High, P2-Medium, P3-Low
Trackers: Feature, Bug
```

### Issue Templates

**Create template:**
```
Administration → Issue templates → New
Name: Bug Report Template
Tracker: Bug
Content:
## Steps to Reproduce
1. 
2. 
3. 

## Expected Result

## Actual Result

## Environment
- OS:
- Browser:
- Version:
```

---

## 🔧 Advanced Configuration

### Database Backup

```bash
# Backup Redmine database
kubectl exec -n ceres postgresql-xxx -- pg_dump -U postgres redmine > redmine_backup.sql

# Restore
kubectl exec -i -n ceres postgresql-xxx -- psql -U postgres redmine < redmine_backup.sql
```

### Performance Tuning

**Increase resources:**
```yaml
# deployment/redmine.yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

**Enable caching:**
```ruby
# config/additional_environment.rb
config.cache_store = :memory_store
config.action_controller.perform_caching = true
```

### Plugin Installation (manual)

```bash
# SSH to pod
kubectl exec -it -n redmine redmine-xxx -- bash

# Go to plugins dir
cd /usr/src/redmine/plugins

# Clone plugin
git clone https://github.com/author/plugin_name.git

# Install dependencies
bundle install

# Migrate
bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# Restart
kubectl rollout restart deployment/redmine -n redmine
```

---

## 📚 Best Practices

### Project Structure

```
Company Projects
├── CERES Platform
│   ├── Backend API
│   ├── Frontend
│   └── Infrastructure
├── Marketing
│   ├── Website
│   └── Campaigns
└── Operations
    ├── Support
    └── Maintenance
```

### Workflow

**Example workflow:**
```
New → Assigned → In Progress → Review → Testing → Closed
```

**Transitions:**
- New → Assigned (auto-assign to team member)
- In Progress → Review (requires code review)
- Review → Testing (QA team)
- Testing → Closed (passed tests)

### Roles & Permissions

**Manager:**
- Create/edit/delete issues
- Manage versions/sprints
- View all projects

**Developer:**
- Create/edit own issues
- Log time
- Comment

**Reporter:**
- Create issues
- Comment
- View only

---

## 🐛 Troubleshooting

### Plugins not loading

```bash
# Re-run migrations
kubectl exec -n redmine redmine-xxx -- bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# Restart
kubectl rollout restart deployment/redmine -n redmine
```

### Database connection error

```bash
# Check PostgreSQL
kubectl get pods -n ceres | grep postgresql

# Check credentials
kubectl exec -n redmine redmine-xxx -- env | grep REDMINE_DB
```

### Slow performance

```bash
# Check resources
kubectl top pod -n redmine

# Increase limits (see Performance Tuning)

# Clear cache
kubectl exec -n redmine redmine-xxx -- bundle exec rake tmp:cache:clear
```

---

## 📞 Support

**Documentation:**
- Official: https://www.redmine.org/guide
- Backlogs: https://github.com/backlogs/redmine_backlogs/wiki
- Agile: https://github.com/redmineup/redmine_agile

**Issues?**
- CERES: https://github.com/skulesh01/Ceres/issues
- Redmine: https://www.redmine.org/projects/redmine/issues

---

**Enjoy your fully-featured Project Management! 🚀**

*21 plugins, 4 themes, Scrum + Kanban, SSO ready*
