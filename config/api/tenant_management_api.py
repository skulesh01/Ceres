"""
CERES Tenant Management REST API
Provides endpoints for tenant administration and management
"""

from flask import Flask, Blueprint, request, jsonify, g
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from functools import wraps
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import uuid

logger = logging.getLogger(__name__)

# Import tenant middleware
from config.middleware.tenant_middleware import (
    TenantMiddleware, require_tenant_context, require_role,
    require_permission, audit_log_action
)

# Initialize Flask app
app = Flask(__name__)
app.config.from_object('config.settings')

# Database
engine = create_engine(app.config['SQLALCHEMY_DATABASE_URI'])
SessionLocal = sessionmaker(bind=engine)

# Initialize tenant middleware
tenant_middleware = TenantMiddleware(
    app=app,
    keycloak_url=app.config['KEYCLOAK_URL'],
    db_session=SessionLocal()
)

# Create API blueprint
api = Blueprint('tenant_api', __name__, url_prefix='/api/v1/tenants')


# ============================================
# TENANT ENDPOINTS
# ============================================

@api.route('', methods=['POST'])
@require_role('admin')
def create_tenant():
    """
    Create new tenant (admin only)
    
    Request:
    {
        "name": "ACME Corporation",
        "domain": "acme.ceres.io",
        "owner_email": "owner@acme.com",
        "plan": "enterprise"
    }
    """
    try:
        data = request.get_json()
        
        # Validate required fields
        required = ['name', 'domain', 'owner_email']
        if not all(k in data for k in required):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Generate tenant ID from name
        tenant_id = data['name'].lower().replace(' ', '-')
        tenant_uuid = str(uuid.uuid4())
        
        # Create tenant in database
        db = SessionLocal()
        try:
            # Insert tenant
            db.execute(text("""
                INSERT INTO tenants (id, name, domain, plan, created_at)
                VALUES (:id, :name, :domain, :plan, NOW())
            """), {
                'id': tenant_uuid,
                'name': data['name'],
                'domain': data['domain'],
                'plan': data.get('plan', 'basic')
            })
            
            # Create Keycloak realm (via external service)
            from services.keycloak_service import create_realm
            keycloak_result = create_realm(tenant_id, data)
            
            if not keycloak_result:
                db.rollback()
                return jsonify({'error': 'Failed to create Keycloak realm'}), 500
            
            # Create initial admin user
            admin_user_id = str(uuid.uuid4())
            db.execute(text("""
                INSERT INTO users (id, tenant_id, email, username, is_admin, created_at)
                VALUES (:id, :tenant_id, :email, :username, true, NOW())
            """), {
                'id': admin_user_id,
                'tenant_id': tenant_uuid,
                'email': data['owner_email'],
                'username': data['owner_email'].split('@')[0]
            })
            
            # Audit log
            audit_log_action('CREATE', 'TENANT', tenant_uuid, 
                           new_data=data)
            
            db.commit()
            
            return jsonify({
                'id': tenant_uuid,
                'name': data['name'],
                'domain': data['domain'],
                'created_at': datetime.now().isoformat(),
                'status': 'active'
            }), 201
        
        finally:
            db.close()
    
    except Exception as e:
        logger.error(f"Error creating tenant: {e}")
        return jsonify({'error': str(e)}), 500


@api.route('/<tenant_id>', methods=['GET'])
@require_tenant_context
def get_tenant(tenant_id: str):
    """Get tenant details"""
    context = g.tenant_context
    
    # Verify user has access to this tenant
    if context.tenant_id != tenant_id and 'admin' not in context.roles:
        return jsonify({'error': 'Forbidden'}), 403
    
    db = SessionLocal()
    try:
        result = db.execute(text("""
            SELECT id, name, domain, plan, status, created_at, updated_at
            FROM tenants
            WHERE id = :tenant_id
        """), {'tenant_id': tenant_id}).fetchone()
        
        if not result:
            return jsonify({'error': 'Tenant not found'}), 404
        
        return jsonify({
            'id': result[0],
            'name': result[1],
            'domain': result[2],
            'plan': result[3],
            'status': result[4],
            'created_at': result[5].isoformat(),
            'updated_at': result[6].isoformat() if result[6] else None
        })
    
    finally:
        db.close()


@api.route('/<tenant_id>', methods=['PUT'])
@require_tenant_context
@require_role('admin')
def update_tenant(tenant_id: str):
    """Update tenant settings"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    data = request.get_json()
    
    db = SessionLocal()
    try:
        # Update only allowed fields
        update_fields = {}
        for field in ['name', 'domain', 'plan']:
            if field in data:
                update_fields[field] = data[field]
        
        if update_fields:
            set_clause = ', '.join([f"{k} = :{k}" for k in update_fields.keys()])
            update_fields['tenant_id'] = tenant_id
            update_fields['updated_at'] = 'NOW()'
            
            db.execute(text(f"""
                UPDATE tenants
                SET {set_clause}, updated_at = NOW()
                WHERE id = :tenant_id
            """), update_fields)
            
            # Audit
            audit_log_action('UPDATE', 'TENANT', tenant_id, new_data=data)
        
        db.commit()
        return jsonify({'status': 'updated'}), 200
    
    except Exception as e:
        logger.error(f"Error updating tenant: {e}")
        db.rollback()
        return jsonify({'error': str(e)}), 500
    
    finally:
        db.close()


# ============================================
# TENANT MEMBERS ENDPOINTS
# ============================================

@api.route('/<tenant_id>/members', methods=['GET'])
@require_tenant_context
@require_role('admin')
def list_members(tenant_id: str):
    """List tenant members"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    db = SessionLocal()
    try:
        # RLS will automatically filter to tenant
        results = db.execute(text("""
            SELECT u.id, u.email, u.username, u.is_active, u.created_at,
                   ARRAY_AGG(r.name) as roles
            FROM users u
            LEFT JOIN user_roles ur ON u.id = ur.user_id AND ur.tenant_id = :tenant_id
            LEFT JOIN roles r ON ur.role_id = r.id
            WHERE u.tenant_id = :tenant_id
            GROUP BY u.id, u.email, u.username, u.is_active, u.created_at
            ORDER BY u.created_at DESC
        """), {'tenant_id': tenant_id}).fetchall()
        
        members = [{
            'id': r[0],
            'email': r[1],
            'username': r[2],
            'is_active': r[3],
            'created_at': r[4].isoformat(),
            'roles': r[5] or []
        } for r in results]
        
        return jsonify({'members': members}), 200
    
    finally:
        db.close()


@api.route('/<tenant_id>/members', methods=['POST'])
@require_tenant_context
@require_role('admin')
def invite_member(tenant_id: str):
    """Invite new member to tenant"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    data = request.get_json()
    email = data.get('email')
    role = data.get('role', 'user')
    
    if not email:
        return jsonify({'error': 'Email required'}), 400
    
    db = SessionLocal()
    try:
        # Create invitation record
        invitation_id = str(uuid.uuid4())
        db.execute(text("""
            INSERT INTO invitations (id, tenant_id, email, role, expires_at)
            VALUES (:id, :tenant_id, :email, :role, NOW() + INTERVAL '7 days')
        """), {
            'id': invitation_id,
            'tenant_id': tenant_id,
            'email': email,
            'role': role
        })
        
        # Send invitation email (external service)
        from services.email_service import send_invitation
        send_invitation(email, tenant_id, invitation_id)
        
        # Audit
        audit_log_action('INVITE', 'USER', email, 
                       new_data={'role': role})
        
        db.commit()
        return jsonify({'status': 'invited', 'invitation_id': invitation_id}), 201
    
    except Exception as e:
        logger.error(f"Error inviting member: {e}")
        db.rollback()
        return jsonify({'error': str(e)}), 500
    
    finally:
        db.close()


@api.route('/<tenant_id>/members/<member_id>', methods=['DELETE'])
@require_tenant_context
@require_role('admin')
def remove_member(tenant_id: str, member_id: str):
    """Remove member from tenant"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    db = SessionLocal()
    try:
        # Delete user roles
        db.execute(text("""
            DELETE FROM user_roles
            WHERE user_id = :member_id AND tenant_id = :tenant_id
        """), {'member_id': member_id, 'tenant_id': tenant_id})
        
        # Audit
        audit_log_action('REMOVE', 'USER', member_id)
        
        db.commit()
        return jsonify({'status': 'removed'}), 200
    
    finally:
        db.close()


# ============================================
# TENANT SETTINGS ENDPOINTS
# ============================================

@api.route('/<tenant_id>/settings', methods=['GET'])
@require_tenant_context
@require_role('admin')
def get_tenant_settings(tenant_id: str):
    """Get tenant settings"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    db = SessionLocal()
    try:
        result = db.execute(text("""
            SELECT settings
            FROM tenant_settings
            WHERE tenant_id = :tenant_id
        """), {'tenant_id': tenant_id}).fetchone()
        
        settings = json.loads(result[0]) if result else {}
        
        return jsonify(settings), 200
    
    finally:
        db.close()


@api.route('/<tenant_id>/settings', methods=['PUT'])
@require_tenant_context
@require_role('admin')
def update_tenant_settings(tenant_id: str):
    """Update tenant settings"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    data = request.get_json()
    
    db = SessionLocal()
    try:
        db.execute(text("""
            INSERT INTO tenant_settings (tenant_id, settings)
            VALUES (:tenant_id, :settings)
            ON CONFLICT (tenant_id) DO UPDATE
            SET settings = :settings
        """), {
            'tenant_id': tenant_id,
            'settings': json.dumps(data)
        })
        
        # Audit
        audit_log_action('UPDATE', 'SETTINGS', tenant_id, new_data=data)
        
        db.commit()
        return jsonify({'status': 'updated'}), 200
    
    finally:
        db.close()


# ============================================
# TENANT USAGE & BILLING ENDPOINTS
# ============================================

@api.route('/<tenant_id>/usage', methods=['GET'])
@require_tenant_context
@require_role('admin')
def get_tenant_usage(tenant_id: str):
    """Get tenant resource usage"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    db = SessionLocal()
    try:
        # Get usage statistics
        result = db.execute(text("""
            SELECT 
                COUNT(DISTINCT u.id) as user_count,
                COUNT(DISTINCT p.id) as project_count,
                COALESCE(SUM(f.size), 0) / (1024*1024) as storage_mb,
                MAX(u.last_login) as last_activity
            FROM tenants t
            LEFT JOIN users u ON u.tenant_id = t.id
            LEFT JOIN projects p ON p.tenant_id = t.id
            LEFT JOIN files f ON f.tenant_id = t.id
            WHERE t.id = :tenant_id
        """), {'tenant_id': tenant_id}).fetchone()
        
        return jsonify({
            'users': result[0],
            'projects': result[1],
            'storage_mb': float(result[2]),
            'last_activity': result[3].isoformat() if result[3] else None
        }), 200
    
    finally:
        db.close()


@api.route('/<tenant_id>/billing', methods=['GET'])
@require_tenant_context
@require_role('admin')
def get_tenant_billing(tenant_id: str):
    """Get tenant billing information"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    db = SessionLocal()
    try:
        result = db.execute(text("""
            SELECT plan, monthly_cost, annual_cost, status
            FROM tenant_billing
            WHERE tenant_id = :tenant_id
        """), {'tenant_id': tenant_id}).fetchone()
        
        if not result:
            return jsonify({'error': 'No billing info'}), 404
        
        return jsonify({
            'plan': result[0],
            'monthly_cost': float(result[1]),
            'annual_cost': float(result[2]),
            'status': result[3]
        }), 200
    
    finally:
        db.close()


# ============================================
# TENANT AUDIT LOG ENDPOINTS
# ============================================

@api.route('/<tenant_id>/audit-log', methods=['GET'])
@require_tenant_context
@require_role('admin')
def get_audit_log(tenant_id: str):
    """Get tenant audit log"""
    context = g.tenant_context
    
    if context.tenant_id != tenant_id:
        return jsonify({'error': 'Forbidden'}), 403
    
    # Get query parameters
    limit = request.args.get('limit', 100, type=int)
    offset = request.args.get('offset', 0, type=int)
    
    db = SessionLocal()
    try:
        results = db.execute(text("""
            SELECT id, action, resource_type, resource_id, user_id, 
                   old_data, new_data, timestamp
            FROM audit_log
            WHERE tenant_id = :tenant_id
            ORDER BY timestamp DESC
            LIMIT :limit OFFSET :offset
        """), {
            'tenant_id': tenant_id,
            'limit': limit,
            'offset': offset
        }).fetchall()
        
        logs = [{
            'id': r[0],
            'action': r[1],
            'resource_type': r[2],
            'resource_id': r[3],
            'user_id': r[4],
            'old_data': json.loads(r[5]) if r[5] else None,
            'new_data': json.loads(r[6]) if r[6] else None,
            'timestamp': r[7].isoformat()
        } for r in results]
        
        return jsonify({'logs': logs}), 200
    
    finally:
        db.close()


# ============================================
# ERROR HANDLERS
# ============================================

@app.errorhandler(400)
def bad_request(error):
    return jsonify({'error': 'Bad Request', 'message': str(error.description)}), 400

@app.errorhandler(401)
def unauthorized(error):
    return jsonify({'error': 'Unauthorized', 'message': str(error.description)}), 401

@app.errorhandler(403)
def forbidden(error):
    return jsonify({'error': 'Forbidden', 'message': str(error.description)}), 403

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not Found', 'message': str(error.description)}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal error: {error}")
    return jsonify({'error': 'Internal Server Error'}), 500


# ============================================
# INITIALIZATION
# ============================================

if __name__ == '__main__':
    # Register blueprint
    app.register_blueprint(api)
    
    # Run development server
    app.run(host='0.0.0.0', port=5000, debug=True)
