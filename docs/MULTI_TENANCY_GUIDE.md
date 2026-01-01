# CERES Multi-Tenancy Architecture Guide

**Version:** 2.6.0 | **Last Updated:** January 2026

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Components](#components)
4. [Isolation Model](#isolation-model)
5. [Tenant Provisioning](#tenant-provisioning)
6. [Application Integration](#application-integration)
7. [API Reference](#api-reference)
8. [Security Considerations](#security-considerations)
9. [Monitoring & Operations](#monitoring--operations)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## Overview

CERES v2.6.0 introduces comprehensive multi-tenancy support, enabling a single CERES deployment to serve multiple customers with complete data isolation and tenant-specific customization.

### Key Capabilities

- **Complete Data Isolation:** Database, application, and network level
- **One Deployment, Many Customers:** Simplified operations and cost reduction
- **Tenant Self-Service:** Onboarding and management via API
- **Enterprise SLA:** Per-tenant monitoring, billing, and audit logs
- **Zero Downtime:** Multi-tenant operations don't affect others

### Multi-Tenancy Levels

```
Level 1 - Network Routing:  Nginx detects tenant from domain/header
Level 2 - Authentication:   Keycloak realms isolate user credentials
Level 3 - Database:         PostgreSQL RLS enforces data isolation
Level 4 - Application:      Middleware ensures tenant context
Level 5 - Audit:            All changes logged per tenant
```

---

## Architecture

```
Internet
   ↓
┌─────────────────────────────────────────┐
│      Nginx Tenant Router                │
│  - Detects tenant from:                 │
│    • Subdomain (acme.ceres.io)         │
│    • Header (X-Tenant-ID)              │
│    • Path (/api/v1/tenants/{id})       │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  Keycloak Authentication                │
│  - Separate realm per tenant            │
│  - SSO within tenant                    │
│  - JWT includes tenant_id claim         │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  Application (Flask/Django)             │
│  - TenantMiddleware extracts context    │
│  - Sets app.current_tenant_id variable  │
│  - All queries filtered by tenant       │
└──────────────┬──────────────────────────┘
               ↓
┌─────────────────────────────────────────┐
│  PostgreSQL Row-Level Security (RLS)    │
│  - Policies enforce tenant filtering    │
│  - No cross-tenant data access possible │
│  - Audit table logs all changes         │
└─────────────────────────────────────────┘
```

---

## Components

### 1. Nginx Tenant Router

Detects tenant from multiple sources and routes requests accordingly.

**Tenant Detection (Priority Order):**

```
1. X-Tenant-ID Header (highest priority for APIs)
2. Subdomain (acme.ceres.io for browser clients)
3. Request path (/api/v1/tenants/{id}/)
4. Query parameter (?tenant_id=...)
```

**Key Features:**

- Rate limiting per tenant
- SSL/TLS termination
- Health checks for backends
- Logging with tenant context

### 2. Keycloak Realm Isolation

Each tenant gets dedicated Keycloak realm with:

- **Separate User Database:** Users cannot see other realms
- **Realm Roles:** `admin`, `manager`, `user`, `viewer`
- **Client Applications:** Separate web and API clients per tenant
- **Identity Providers:** Google, GitHub with tenant-specific config
- **Password Policies:** Enforced at realm level

### 3. PostgreSQL Row-Level Security (RLS)

Database-level data isolation using PostgreSQL RLS policies.

**RLS Policies Per Table:**

```sql
-- Users see only their own record (or admins see all)
SELECT * FROM users WHERE id = CURRENT_USER_ID OR user_is_admin()

-- Organizations visible only to tenant members
SELECT * FROM organizations WHERE tenant_id = get_current_tenant_id()

-- Files visible based on project access
SELECT * FROM files WHERE project_id IN (
  SELECT id FROM projects
  WHERE owner_id = CURRENT_USER_ID
    OR is_public = true
)
```

**Enforcement:**

- RLS enabled on all tables with tenant data
- Audit log tables immutable (no RLS)
- Each row contains `tenant_id` for filtering
- Policies check `get_current_tenant_id()` function

### 4. Application Middleware

Flask middleware extracts and validates tenant context.

```python
@app.before_request
def extract_tenant_context():
    tenant_id = extract_from_header_or_subdomain()
    claims = validate_jwt_token()
    
    if claims['tenant_id'] != tenant_id:
        abort(403)  # Tenant mismatch
    
    g.tenant_context = TenantContext(
        tenant_id=tenant_id,
        user_id=claims['sub'],
        roles=claims['roles']
    )
    
    # Set database context for RLS
    db.execute("SET app.current_tenant_id = $1", tenant_id)
```

### 5. Tenant Management API

REST API for tenant administration:

```
POST   /api/v1/tenants               - Create tenant (admin)
GET    /api/v1/tenants/{id}          - Get tenant info
PUT    /api/v1/tenants/{id}          - Update tenant settings
GET    /api/v1/tenants/{id}/members  - List members
POST   /api/v1/tenants/{id}/members  - Invite member
DELETE /api/v1/tenants/{id}/members/{mid} - Remove member
GET    /api/v1/tenants/{id}/usage    - Get usage statistics
GET    /api/v1/tenants/{id}/billing  - Get billing info
GET    /api/v1/tenants/{id}/audit-log - Get audit logs
```

---

## Isolation Model

### Network Isolation

```
Tenant A (acme.ceres.io)    → Nginx router → Extract tenant=acme
Tenant B (xyz.ceres.io)     → Nginx router → Extract tenant=xyz

Each request includes tenant context throughout stack
```

### Authentication Isolation

```
Keycloak Master Realm
├── acme realm
│   ├── Users: admin@acme.com, alice@acme.com
│   ├── Roles: admin, manager, user
│   └── Clients: acme-webapp, acme-api
├── xyz realm
│   ├── Users: admin@xyz.com, bob@xyz.com
│   ├── Roles: admin, user
│   └── Clients: xyz-webapp, xyz-api
```

### Database Isolation

```sql
-- Tenant A data
INSERT INTO users (id, tenant_id, email) VALUES (uuid1, tenant_a_id, 'alice@acme.com')
INSERT INTO projects (id, tenant_id, name) VALUES (uuid2, tenant_a_id, 'ACME Project')
INSERT INTO files (id, tenant_id, project_id, name) VALUES (uuid3, tenant_a_id, uuid2, 'doc.pdf')

-- RLS Policy enforces:
SELECT * FROM users   -- Only shows tenant_a users
SELECT * FROM files   -- Only shows tenant_a files

-- Tenant B data is completely invisible
```

### Application Isolation

```python
# Request from alice@acme.com
g.tenant_context = TenantContext(
    tenant_id='acme-corp',
    user_id='uuid1',
    roles=['admin']
)

# All database queries automatically filtered
db.execute("SELECT * FROM projects")
# SQL becomes: SELECT * FROM projects WHERE tenant_id = 'acme-corp'

# Cross-tenant access impossible
db.execute("SELECT * FROM tenants WHERE id = 'xyz-corp'")
# Returns nothing (RLS blocks it)
```

---

## Tenant Provisioning

### Quick Provisioning

```bash
./scripts/provision-tenant.sh \
    "acme-corp" \
    "ACME Corporation" \
    "acme.ceres.io" \
    "owner@acme.com"
```

**What Happens:**

1. **Keycloak Realm Created**
   - Realm name: acme-corp
   - Web app client: acme-corp-webapp
   - API client: acme-corp-api
   - Default password policy

2. **PostgreSQL Schema Initialized**
   - Tenant record created
   - Admin user created
   - RLS policies active
   - Service account generated

3. **DNS Configured**
   - Domain added to /etc/hosts (dev)
   - Or DNS A record (production)

4. **Credentials Generated**
   - Admin email: owner@acme.com
   - Temporary password
   - API service account ID & secret

### Manual Provisioning Steps

**Step 1: Create Keycloak Realm**

```bash
# Get admin token
TOKEN=$(curl -s -X POST \
  http://keycloak:8080/auth/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli&grant_type=client_credentials&client_secret=secret" \
  | jq -r '.access_token')

# Create realm
curl -X POST \
  http://keycloak:8080/auth/admin/realms \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @realm-template.json
```

**Step 2: Create Tenant in Database**

```sql
INSERT INTO tenants (id, name, domain, created_at)
VALUES (gen_random_uuid(), 'ACME Corp', 'acme.ceres.io', NOW());

-- Create tenant-specific role
CREATE ROLE tenant_acme_corp LOGIN PASSWORD 'secure_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public 
  TO tenant_acme_corp;
```

**Step 3: Create Admin User**

```sql
INSERT INTO users (id, tenant_id, email, username, is_admin)
VALUES (
  gen_random_uuid(),
  (SELECT id FROM tenants WHERE domain = 'acme.ceres.io'),
  'owner@acme.com',
  'owner',
  true
);
```

**Step 4: Configure DNS**

```bash
# Development
echo "127.0.0.1 acme.ceres.io" >> /etc/hosts

# Production
# Add DNS A record: acme.ceres.io → Load Balancer IP
```

---

## Application Integration

### Flask Integration

```python
from flask import Flask, g
from config.middleware.tenant_middleware import TenantMiddleware

app = Flask(__name__)

# Initialize tenant middleware
TenantMiddleware(app, keycloak_url='http://keycloak:8080')

@app.route('/api/projects')
@require_tenant_context
def list_projects():
    # Automatically filtered to current tenant
    projects = db.session.execute("""
        SELECT * FROM projects
    """).fetchall()
    # RLS ensures only tenant's projects visible
    return jsonify([p.to_dict() for p in projects])

@app.route('/api/tenants/<tenant_id>/members')
@require_role('admin')
def list_members(tenant_id):
    # Verify user is in this tenant
    if g.tenant_context.tenant_id != tenant_id:
        abort(403)
    
    members = db.session.execute("""
        SELECT * FROM users WHERE tenant_id = :tenant_id
    """, {'tenant_id': tenant_id}).fetchall()
    
    return jsonify([m.to_dict() for m in members])
```

### Django Integration

```python
# middleware.py
from django.utils.deprecation import MiddlewareMixin
from django.contrib.auth.models import AnonymousUser

class TenantMiddleware(MiddlewareMixin):
    def process_request(self, request):
        # Extract tenant ID
        tenant_id = self.extract_tenant_id(request)
        
        # Validate JWT
        user = self.get_user_from_jwt(request)
        
        # Store in request
        request.tenant_id = tenant_id
        request.user = user
        
        # Set database context for RLS
        connection.set_isolation_level(None)
        with connection.cursor() as cursor:
            cursor.execute(f"SET app.current_tenant_id = '{tenant_id}'")

# settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'ceres',
        'USER': 'postgres',
        'PASSWORD': 'password',
        'HOST': 'postgres-1',
        'PORT': 5432,
    }
}

MIDDLEWARE = [
    'myapp.middleware.TenantMiddleware',
    ...
]

# models.py
class TenantModel(models.Model):
    tenant_id = models.UUIDField()
    
    class Meta:
        abstract = True
    
    def save(self, *args, **kwargs):
        self.tenant_id = self.request.tenant_id
        super().save(*args, **kwargs)
```

### Query Examples

**Python (SQLAlchemy)**

```python
from sqlalchemy import text

# RLS automatically filters
projects = db.session.execute(
    text("SELECT * FROM projects")
).fetchall()
# Only returns projects for current tenant due to RLS

# Cross-tenant query impossible
other_tenant_data = db.session.execute(
    text("SELECT * FROM projects WHERE tenant_id = 'other-tenant'")
).fetchall()
# Returns empty (RLS blocks it)
```

**Node.js (Express + pg)**

```javascript
const { TenantMiddleware } = require('./middleware');
const { Pool } = require('pg');

const pool = new Pool();

// Use tenant middleware
app.use(TenantMiddleware);

// RLS automatically enforced
app.get('/api/projects', async (req, res) => {
    const client = await pool.connect();
    try {
        // Set tenant context
        await client.query(`SET app.current_tenant_id = '${req.tenant_id}'`);
        
        // Query returns only tenant's data
        const result = await client.query('SELECT * FROM projects');
        res.json(result.rows);
    } finally {
        client.release();
    }
});
```

---

## API Reference

### Create Tenant

```
POST /api/v1/tenants
Authorization: Bearer <admin_token>

Request:
{
    "name": "ACME Corporation",
    "domain": "acme.ceres.io",
    "owner_email": "owner@acme.com",
    "plan": "enterprise"
}

Response (201 Created):
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "ACME Corporation",
    "domain": "acme.ceres.io",
    "created_at": "2026-01-01T00:00:00Z",
    "status": "active"
}
```

### Get Tenant Info

```
GET /api/v1/tenants/{id}
Authorization: Bearer <tenant_token>

Response (200 OK):
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "ACME Corporation",
    "domain": "acme.ceres.io",
    "plan": "enterprise",
    "status": "active",
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-02T00:00:00Z"
}
```

### List Members

```
GET /api/v1/tenants/{id}/members
Authorization: Bearer <tenant_admin_token>

Response (200 OK):
{
    "members": [
        {
            "id": "user-uuid-1",
            "email": "owner@acme.com",
            "username": "owner",
            "is_active": true,
            "created_at": "2026-01-01T00:00:00Z",
            "roles": ["admin"]
        },
        {
            "id": "user-uuid-2",
            "email": "user@acme.com",
            "username": "user",
            "is_active": true,
            "created_at": "2026-01-02T00:00:00Z",
            "roles": ["user"]
        }
    ]
}
```

### Invite Member

```
POST /api/v1/tenants/{id}/members
Authorization: Bearer <tenant_admin_token>

Request:
{
    "email": "newuser@acme.com",
    "role": "user"
}

Response (201 Created):
{
    "status": "invited",
    "invitation_id": "inv-uuid",
    "email": "newuser@acme.com"
}
```

### Get Usage Statistics

```
GET /api/v1/tenants/{id}/usage
Authorization: Bearer <tenant_admin_token>

Response (200 OK):
{
    "users": 25,
    "projects": 12,
    "storage_mb": 5234.5,
    "last_activity": "2026-01-02T10:30:00Z"
}
```

### Get Audit Log

```
GET /api/v1/tenants/{id}/audit-log?limit=50&offset=0
Authorization: Bearer <tenant_admin_token>

Response (200 OK):
{
    "logs": [
        {
            "id": "log-uuid",
            "action": "CREATE",
            "resource_type": "PROJECT",
            "resource_id": "proj-uuid",
            "user_id": "user-uuid",
            "old_data": null,
            "new_data": { "name": "New Project", "status": "active" },
            "timestamp": "2026-01-02T10:30:00Z"
        }
    ]
}
```

---

## Security Considerations

### Cross-Tenant Access Prevention

**Layer 1: Network**
- Nginx validates tenant ID matches domain/header
- Invalid combinations rejected at edge

**Layer 2: JWT Validation**
- Token must include tenant_id claim
- Token tenant_id must match request tenant

**Layer 3: Application Context**
- Middleware validates tenant context set
- All queries scoped by current tenant

**Layer 4: Database RLS**
- PostgreSQL policies block cross-tenant queries
- Even superuser queries filtered if RLS enforced

**Layer 5: Audit**
- All access attempts logged with tenant context
- Anomalies detected via cross-tenant access queries

### Data Residency

For regulatory compliance (GDPR, CCPA):

```sql
-- Store tenant location information
ALTER TABLE tenants ADD COLUMN data_region VARCHAR(2);

-- EU-specific queries must use EU database
-- Implement geo-routing in Nginx:
location ~ ^/eu/ {
    proxy_pass http://postgres-eu:5432;  # EU database
}

-- Non-EU queries use default database
location ~ ^/api/ {
    proxy_pass http://postgres-default:5432;  # Default region
}
```

### Encryption

```
At Rest:
- PostgreSQL with pgcrypto extension
- Sensitive fields encrypted with tenant-specific keys

In Transit:
- TLS 1.3 for all communication
- mTLS between services

Keys:
- Master key in HashiCorp Vault
- Per-tenant keys derived from master
- Tenant-specific key rotation policies
```

---

## Monitoring & Operations

### Tenant-Level Metrics

```prometheus
# Tenant-specific usage
ceres_tenant_user_count{tenant_id="acme-corp"} 25
ceres_tenant_storage_mb{tenant_id="acme-corp"} 5234
ceres_tenant_api_requests{tenant_id="acme-corp"} 125000

# Tenant-specific errors
ceres_tenant_errors_total{tenant_id="acme-corp", code="500"} 5
ceres_tenant_rls_violations{tenant_id="acme-corp"} 0

# Cross-tenant detection
ceres_cross_tenant_access_attempts 0
```

### Health Checks

```bash
# Check tenant realm in Keycloak
curl http://keycloak:8080/auth/realms/acme-corp/.well-known/openid-configuration

# Verify RLS is enforced
psql -c "SELECT verify_tenant_isolation();"

# Check cross-tenant access attempts
psql -c "SELECT * FROM detect_cross_tenant_access();"

# Test tenant isolation
psql -c "SET app.current_tenant_id = 'acme-corp'; SELECT * FROM users;"
# Should only show acme-corp users
```

### Alerting Rules

```yaml
- alert: TenantCrossTenantAccessAttempt
  expr: ceres_cross_tenant_access_attempts > 0
  for: 1m
  annotations:
    summary: "Cross-tenant access attempt detected"
    description: "Potential security breach in tenant {{ $labels.tenant_id }}"

- alert: TenantRLSViolation
  expr: ceres_tenant_rls_violations > 0
  for: 1m
  annotations:
    summary: "RLS violation detected in {{ $labels.tenant_id }}"

- alert: TenantQuotaExceeded
  expr: ceres_tenant_storage_mb > ceres_tenant_storage_quota_mb
  for: 5m
  annotations:
    summary: "Tenant {{ $labels.tenant_id }} exceeded storage quota"
```

---

## Troubleshooting

### Cross-Tenant Data Leak

**Symptom:** User sees data from another tenant

**Diagnosis:**

```sql
-- Check what the user can access
SET app.current_tenant_id = 'acme-corp';
SELECT * FROM users;  -- Should only show acme-corp users

-- Verify RLS policies
SELECT tablename, policyname FROM pg_policies 
WHERE schemaname = 'public';

-- Check for disabled RLS
SELECT relname, relrowsecurity FROM pg_class 
WHERE relname = 'users';
-- relrowsecurity should be 't' (true)
```

**Fix:**

```sql
-- Re-enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Re-apply policies
CREATE POLICY users_isolation ON users
  FOR SELECT USING (tenant_id = get_current_tenant_id());
```

### Tenant Context Not Set

**Symptom:** Queries return empty results despite data existing

**Diagnosis:**

```python
# Add logging to middleware
print(f"Tenant context: {g.tenant_context}")
print(f"Tenant ID: {g.tenant_context.tenant_id}")

# Check database context
db.execute("SELECT current_setting('app.current_tenant_id')")
# Should return the tenant ID
```

**Fix:**

```python
# Verify middleware is registered
app.before_request(extract_tenant_context)

# Check that tenant ID extraction works
tenant_id = extract_from_header_or_subdomain()
if not tenant_id:
    abort(400, "Tenant ID required")
```

### JWT Tenant Mismatch

**Symptom:** 403 Forbidden, "Tenant mismatch"

**Diagnosis:**

```python
# Decode JWT to check claims
import jwt
token = "eyJ..."
claims = jwt.decode(token, options={"verify_signature": False})
print(claims['tenant_id'])  # Should match request tenant_id
```

**Fix:**

- Regenerate JWT token from Keycloak
- Verify token includes tenant_id claim
- Check Keycloak realm is configured with tenant_id mapper

---

## Best Practices

### 1. Always Include Tenant Context

```python
@app.before_request
def ensure_tenant_context():
    if request.path.startswith('/auth'):
        return  # Skip auth endpoints
    
    if not g.tenant_context:
        abort(400, "Tenant context required")
```

### 2. Separate Read and Write Operations

```python
# For multi-tenant scaling, consider:
# - Read replicas: One per tenant or shared
# - Write primary: Tenant-aware routing
# - Backup: Tenant-specific backup policies
```

### 3. Implement Soft Deletes

```sql
ALTER TABLE users ADD COLUMN deleted_at TIMESTAMP;

-- RLS policy includes soft delete check
CREATE POLICY users_not_deleted ON users
  FOR SELECT USING (deleted_at IS NULL);
```

### 4. Regular Isolation Audits

```bash
# Monthly verification
./scripts/verify-tenant-isolation.sh

# Check for any RLS-disabled tables
psql -c "SELECT relname FROM pg_class WHERE relrowsecurity = 'f';"

# Verify all tables have tenant_id column
psql -c "SELECT tablename FROM pg_tables 
         WHERE schemaname = 'public' 
         AND tablename NOT LIKE 'pg_%';"
```

### 5. Quota Management

```sql
-- Enforce storage quota
CREATE TRIGGER enforce_storage_quota
BEFORE INSERT ON files
FOR EACH ROW
EXECUTE FUNCTION check_tenant_quota();

-- Track usage
CREATE TABLE tenant_usage (
    tenant_id UUID,
    metric_name VARCHAR(50),
    metric_value NUMERIC,
    recorded_at TIMESTAMP
);
```

### 6. Data Retention Policies

```sql
-- Soft delete with retention
DELETE FROM audit_log
WHERE tenant_id = $1
AND changed_at < NOW() - INTERVAL '90 days'
AND (SELECT retention_days FROM tenant_settings 
     WHERE id = $1) < 90;
```

---

## Summary

CERES Multi-Tenancy v2.6.0 provides:

✅ **Complete Data Isolation** - Network, app, and database levels
✅ **Enterprise Features** - Per-tenant billing, audit, monitoring
✅ **Zero Complexity** - Single deployment for all tenants
✅ **Transparent Scaling** - Add tenants without downtime
✅ **Regulatory Compliance** - Data residency, audit trails, encryption

With v2.6.0, CERES supports true SaaS deployments for enterprise customers.
