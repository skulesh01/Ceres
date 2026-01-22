# 📧 Email Workflows & Approval System

Complete guide to email integration and document approval workflows in CERES Redmine.

---

## 📋 Table of Contents

1. [Email Configuration](#email-configuration)
2. [Notification Types](#notification-types)
3. [Approval Workflows](#approval-workflows)
4. [Email Templates](#email-templates)
5. [Best Practices](#best-practices)

---

## 📧 Email Configuration

### Automatic Setup (Recommended)

```bash
./scripts/configure-redmine-ultimate.sh
```

The script will prompt for:
- SMTP server (default: Mailcow)
- SMTP port (default: 587)
- Authentication credentials
- From email address

### Manual Configuration

If you need to configure manually:

1. Edit ConfigMap:
```bash
kubectl edit configmap redmine-config -n redmine
```

2. Add SMTP settings:
```yaml
production:
  email_delivery:
    delivery_method: :smtp
    smtp_settings:
      address: mailcow.ceres.svc.cluster.local
      port: 587
      domain: ceres.local
      authentication: :login
      user_name: redmine@ceres.local
      password: YOUR_PASSWORD
      enable_starttls_auto: true
  default_mail_from: redmine@ceres.local
  emails_footer: "Sent by CERES Redmine - https://redmine.ceres.local"
```

3. Restart Redmine:
```bash
kubectl rollout restart deployment/redmine -n redmine
```

---

## 🔔 Notification Types

CERES Redmine sends 13 types of email notifications:

### Issue Events

| Event | When Triggered | Recipients |
|-------|----------------|------------|
| **Issue Added** | New issue created | Project members, Watchers |
| **Issue Updated** | Any field changed | Assignee, Author, Watchers |
| **Issue Note Added** | Comment added | Assignee, Author, Watchers, Mentioned users |
| **Issue Status Updated** | Status changed | Assignee, Author, Watchers |
| **Issue Assigned** | Assignee changed | New assignee, Old assignee, Author |
| **Issue Priority Updated** | Priority changed | Assignee, Author, Watchers |

### Content Events

| Event | When Triggered | Recipients |
|-------|----------------|------------|
| **News Added** | News article published | All project members |
| **News Comment Added** | Comment on news | News author, Commenters |
| **Document Added** | Document uploaded | All project members |
| **File Added** | File attached | All project members |

### Collaboration Events

| Event | When Triggered | Recipients |
|-------|----------------|------------|
| **Message Posted** | Forum message | Forum watchers |
| **Wiki Content Added** | Wiki page created | Wiki watchers |
| **Wiki Content Updated** | Wiki page edited | Wiki watchers |

---

## ✅ Approval Workflows

### What is Document Approval?

CERES Redmine includes **redmine_approval** plugin for multi-level document approval workflows.

**Use Cases:**
- Contract approval (Legal → Finance → Executive)
- Invoice approval (Creator → Accountant → CFO)
- Technical document review (Engineer → Team Lead → Manager)
- Change request approval (Developer → QA → Product Owner)

### How It Works

1. **Document Upload** (via DMSF plugin)
2. **Approval Request** (assign approvers)
3. **Email Notification** (approvers receive email)
4. **Review & Approve/Reject** (approvers act via email or web)
5. **Status Update** (automatic email to requester)
6. **Final Notification** (all stakeholders notified)

### Example Workflow: Invoice Approval

#### Step 1: Create Approval Issue

```
Project: Accounting
Tracker: Approval
Subject: Invoice #12345 - Office Supplies
Description: Approve invoice for $1,234.56
Attachments: invoice_12345.pdf (via DMSF)

Custom Fields:
- Approval Status: Pending
- Approver: john.doe@ceres.local (Accountant)
```

#### Step 2: Email Sent to Approver

**Subject:** `[Redmine] Approval Request: Invoice #12345 - Office Supplies`

**Body:**
```
You have a new approval request:

Project: Accounting
Issue #123: Invoice #12345 - Office Supplies
Amount: $1,234.56
Requester: jane.smith@ceres.local
Document: invoice_12345.pdf

Review document: https://redmine.ceres.local/issues/123
Download: https://redmine.ceres.local/dmsf/files/456

Actions:
✅ Approve: https://redmine.ceres.local/issues/123/approve
❌ Reject: https://redmine.ceres.local/issues/123/reject

---
Sent by CERES Redmine - https://redmine.ceres.local
```

#### Step 3: Approver Takes Action

Clicks "Approve" → Status changes to "Approved" → Email sent:

**To:** Requester (jane.smith@ceres.local)
**Subject:** `[Redmine] Approved: Invoice #12345 - Office Supplies`

**Body:**
```
Your approval request has been APPROVED:

Issue #123: Invoice #12345 - Office Supplies
Approved by: John Doe (Accountant)
Approval date: 2024-01-15 14:32

Next steps: Forward to CFO for final approval

View issue: https://redmine.ceres.local/issues/123
```

#### Step 4: Multi-Level Approval

For 3-level approval (Accountant → CFO → Executive):

1. **Level 1:** Accountant approves → Status: "L1 Approved"
2. **Level 2:** CFO receives email → Approves → Status: "L2 Approved"
3. **Level 3:** Executive receives email → Approves → Status: "Final Approved"
4. **Final:** All stakeholders notified

---

## 📝 Email Templates

### Custom Email Templates

Located in: `public/themes/YOUR_THEME/emails/`

#### 1. Approval Request Template

**File:** `approval_request.html.erb`

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; }
    .header { background: #0066cc; color: white; padding: 20px; }
    .content { padding: 20px; }
    .button { background: #28a745; color: white; padding: 10px 20px; text-decoration: none; }
    .button-reject { background: #dc3545; }
  </style>
</head>
<body>
  <div class="header">
    <h2>🔔 Approval Request</h2>
  </div>
  <div class="content">
    <p>Hello <%= @approver.name %>,</p>
    
    <p>You have a new approval request:</p>
    
    <table>
      <tr><td><strong>Project:</strong></td><td><%= @issue.project.name %></td></tr>
      <tr><td><strong>Subject:</strong></td><td><%= @issue.subject %></td></tr>
      <tr><td><strong>Requester:</strong></td><td><%= @issue.author.name %></td></tr>
      <tr><td><strong>Date:</strong></td><td><%= @issue.created_on.strftime("%Y-%m-%d %H:%M") %></td></tr>
    </table>
    
    <p><%= @issue.description %></p>
    
    <p>
      <a href="<%= @issue_url %>/approve" class="button">✅ Approve</a>
      <a href="<%= @issue_url %>/reject" class="button button-reject">❌ Reject</a>
    </p>
    
    <p><a href="<%= @issue_url %>">View full details</a></p>
  </div>
</body>
</html>
```

#### 2. Issue Assigned Template

**File:** `issue_assigned.html.erb`

```html
<!DOCTYPE html>
<html>
<body>
  <h2>📌 Issue Assigned to You</h2>
  
  <p>Hi <%= @user.name %>,</p>
  
  <p>A new issue has been assigned to you:</p>
  
  <table>
    <tr><td><strong>Project:</strong></td><td><%= @issue.project.name %></td></tr>
    <tr><td><strong>Tracker:</strong></td><td><%= @issue.tracker.name %></td></tr>
    <tr><td><strong>Subject:</strong></td><td><%= @issue.subject %></td></tr>
    <tr><td><strong>Priority:</strong></td><td><%= @issue.priority.name %></td></tr>
    <tr><td><strong>Due date:</strong></td><td><%= @issue.due_date %></td></tr>
  </table>
  
  <p><strong>Description:</strong></p>
  <p><%= @issue.description %></p>
  
  <p><a href="<%= @issue_url %>">View Issue #<%= @issue.id %></a></p>
</body>
</html>
```

#### 3. Mention Notification Template

**File:** `mention.html.erb`

```html
<!DOCTYPE html>
<html>
<body>
  <h2>💬 You were mentioned</h2>
  
  <p>Hi <%= @user.name %>,</p>
  
  <p><strong><%= @author.name %></strong> mentioned you in <%= @issue.tracker.name %> #<%= @issue.id %>:</p>
  
  <blockquote>
    <%= @mention_text %>
  </blockquote>
  
  <p><a href="<%= @issue_url %>#note-<%= @journal.id %>">View comment</a></p>
</body>
</html>
```

---

## 📬 Email Workflows Examples

### Workflow 1: Bug Report → QA → Developer

1. **Reporter** creates bug → Email sent to QA team
2. **QA** confirms bug → Assigns to Developer → Email sent to Developer
3. **Developer** fixes bug → Changes status to "Fixed" → Email sent to QA
4. **QA** tests → Closes issue → Email sent to Reporter (bug fixed)

**Email Recipients at Each Step:**
- Step 1: QA Team (role-based)
- Step 2: Assigned developer
- Step 3: QA Team, Reporter (watchers)
- Step 4: Reporter, Developer, Watchers

### Workflow 2: Feature Request → Product Owner → Dev Team

1. **User** requests feature → Email to Product Owner
2. **PO** approves → Adds to backlog → Email to Scrum Master
3. **SM** adds to sprint → Email to Dev Team
4. **Developer** implements → Email to PO (review)
5. **PO** accepts → Email to User (feature shipped)

### Workflow 3: Document Approval Chain

1. **Creator** uploads document → Email to Team Lead
2. **Team Lead** reviews → Approves → Email to Manager
3. **Manager** reviews → Approves → Email to Director
4. **Director** final approval → Email to all stakeholders

---

## 🎯 Best Practices

### 1. Email Notification Settings

**Per-User Settings:**
- Administration → Users → [User] → Email notifications
- Options:
  - `All events`: Get every notification (not recommended)
  - `Only assigned/watched`: Smart filtering (recommended)
  - `Only assigned`: Minimal notifications
  - `No events`: Disable emails (use Mattermost instead)

**Recommended Settings:**
- **Developers:** Only assigned/watched
- **Managers:** All events on managed projects
- **Stakeholders:** Only project-level events (news, documents)

### 2. Reduce Email Noise

**Use Watchers Wisely:**
- Don't add entire team as watchers
- Only add people who NEED updates
- Use @mentions for specific people

**Batch Notifications:**
- Administration → Settings → Email notifications
- Enable "Combine multiple notifications"
- Digest emails (daily summary instead of per-event)

### 3. Email Templates Customization

**Add Company Branding:**
```bash
./scripts/apply-branding.sh
```

This applies:
- Company logo in emails
- Custom colors
- Footer with company info

**Manual Customization:**
- Copy email templates from Redmine core
- Modify HTML/CSS
- Place in theme folder
- Test with test emails

### 4. Approval Workflow Best Practices

**Document Naming:**
- Use consistent naming: `[Type] Subject - YYYY-MM-DD`
- Example: `[Contract] NDA - Acme Corp - 2024-01-15`

**Approval Deadlines:**
- Set due dates on approval issues
- Enable deadline reminders (Administration → Settings)
- Escalate overdue approvals

**Audit Trail:**
- All approvals logged in issue history
- Email notifications archived
- DMSF tracks document versions

### 5. Integration with Mattermost

**Dual Notifications:**
- Email for formal approvals
- Mattermost for quick updates

**Configuration:**
```bash
# In configure-redmine-ultimate.sh
# Enable both email and Mattermost
```

**Use Cases:**
- **Email:** Approvals, formal notifications, external users
- **Mattermost:** Quick updates, team discussions, internal only

---

## 🔧 Troubleshooting

### Email Not Sending

**Check SMTP Settings:**
```bash
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails console

# In Rails console:
ActionMailer::Base.smtp_settings
# Should show your SMTP config
```

**Test Email:**
```bash
kubectl exec -n redmine $REDMINE_POD -- bundle exec rails runner "
  Mailer.test_email('your.email@ceres.local').deliver_now
"
```

**Check Logs:**
```bash
kubectl logs -n redmine deployment/redmine | grep -i mail
```

### Emails in Spam

**Solutions:**
1. Configure SPF record for your domain
2. Configure DKIM in Mailcow
3. Use proper From address (not noreply@)
4. Add your server IP to SPF record

**Mailcow Configuration:**
- Login to Mailcow
- Configuration → Configuration → Options
- Enable DKIM signing
- Add SPF record to DNS

### Approval Plugin Not Working

**Verify Plugin Installed:**
```bash
kubectl exec -n redmine $REDMINE_POD -- ls plugins/

# Should see:
# redmine_approval
```

**Check Plugin Enabled:**
- Administration → Plugins
- Should show "Redmine Approval" plugin

**Migrate Database:**
```bash
kubectl exec -n redmine $REDMINE_POD -- bundle exec rake redmine:plugins:migrate
```

---

## 📊 Metrics & Analytics

### Email Notification Metrics

Track email effectiveness:
- Open rate (via tracking pixels)
- Click rate (via UTM parameters)
- Response time (approval → action)

**Enable Tracking:**
- Administration → Settings → Email notifications
- Check "Add tracking to emails"

### Approval Workflow Metrics

- Average approval time
- Bottlenecks (which approver delays most)
- Rejection rate
- Overdue approvals

**Reports:**
- Administration → Reports
- Custom SQL queries via plugin

---

## 🚀 Advanced: Automation Rules for Email

### Auto-escalate Overdue Approvals

```ruby
# In redmine_automation plugin
Rule: "Escalate Overdue Approvals"
Trigger: Daily schedule
Condition: Issue.tracker == "Approval" AND Issue.due_date < Today
Action: Send email to Manager + Update priority to "High"
```

### Auto-assign by Email Subject

```ruby
# Auto-assign emails sent to redmine@ceres.local
Rule: "Auto-assign Support Tickets"
Trigger: Email received
Condition: Email.to == "support@ceres.local"
Action: Create issue, Assign to role "Support"
```

### Auto-close Approved Documents

```ruby
# Close issue when all approvals complete
Rule: "Auto-close Approved"
Trigger: Custom field changed
Condition: Approval_Status == "Final Approved"
Action: Close issue, Send email to creator
```

---

## 📚 Resources

- [Redmine Email Configuration](https://www.redmine.org/projects/redmine/wiki/EmailConfiguration)
- [redmine_approval Plugin](https://github.com/haru/redmine_approval)
- [DMSF Plugin (Document Management)](https://github.com/danmunn/redmine_dmsf)
- [Email Notification Settings](https://www.redmine.org/projects/redmine/wiki/RedmineSettings#Email-notifications)

---

**Need help?** Check [REDMINE_GUIDE.md](REDMINE_GUIDE.md) or open an issue.

**Better than Jira Enterprise?** ✅ Yes! Email workflows included for FREE.
