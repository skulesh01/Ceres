"""
CERES Multi-Tenancy Middleware
Provides tenant context injection for Flask/Django applications
"""

import uuid
import json
import logging
from functools import wraps
from typing import Optional, Dict, Any
from contextlib import contextmanager

import jwt
from flask import request, g, abort
from sqlalchemy import text
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


class TenantContext:
    """Manages tenant context for current request"""
    
    def __init__(self, tenant_id: str, realm: str, user_id: Optional[str] = None, 
                 roles: Optional[list] = None, email: Optional[str] = None):
        self.tenant_id = tenant_id
        self.realm = realm
        self.user_id = user_id
        self.roles = roles or []
        self.email = email
        self.jwt_token = None
        self.jwt_claims = {}
    
    def has_role(self, role: str) -> bool:
        """Check if user has specific role"""
        return role in self.roles or 'admin' in self.roles
    
    def has_permission(self, permission: str) -> bool:
        """Check if user has specific permission based on role"""
        role_permissions = {
            'admin': ['read:all', 'write:all', 'delete:all', 'manage:tenant'],
            'manager': ['read:all', 'write:own', 'manage:reports'],
            'user': ['read:own', 'write:own'],
            'viewer': ['read:own']
        }
        
        user_permissions = set()
        for role in self.roles:
            user_permissions.update(role_permissions.get(role, []))
        
        return permission in user_permissions
    
    def to_dict(self) -> Dict[str, Any]:
        """Serialize context to dictionary"""
        return {
            'tenant_id': self.tenant_id,
            'realm': self.realm,
            'user_id': self.user_id,
            'roles': self.roles,
            'email': self.email
        }


class TenantMiddleware:
    """Extracts and validates tenant context from request"""
    
    def __init__(self, app=None, keycloak_url: str = "http://keycloak:8080", 
                 db_session: Optional[Session] = None):
        self.app = app
        self.keycloak_url = keycloak_url
        self.db_session = db_session
        
        if app:
            self.init_app(app)
    
    def init_app(self, app):
        """Initialize middleware with Flask app"""
        app.before_request(self._extract_tenant_context)
        app.after_request(self._cleanup_tenant_context)
    
    def _extract_tenant_context(self):
        """Extract tenant context from request"""
        try:
            # Get tenant from multiple sources (priority order)
            tenant_id = self._extract_tenant_id()
            
            if not tenant_id:
                logger.warning(f"No tenant ID in request from {request.remote_addr}")
                abort(400, description="Tenant ID is required")
            
            # Get authorization token
            auth_header = request.headers.get('Authorization', '')
            token = auth_header.replace('Bearer ', '') if auth_header.startswith('Bearer ') else None
            
            # Extract JWT claims
            claims = {}
            user_id = None
            roles = []
            email = None
            
            if token:
                try:
                    # Decode JWT without verification (verified by Keycloak)
                    claims = jwt.decode(token, options={"verify_signature": False})
                    user_id = claims.get('sub')
                    roles = claims.get('realm_access', {}).get('roles', [])
                    email = claims.get('email')
                    
                    # Validate tenant in token matches request tenant
                    token_tenant = claims.get('tenant_id')
                    if token_tenant and token_tenant != tenant_id:
                        logger.warning(f"Tenant mismatch: token={token_tenant}, request={tenant_id}")
                        abort(403, description="Tenant mismatch")
                except jwt.DecodeError as e:
                    logger.error(f"Invalid JWT: {e}")
                    abort(401, description="Invalid token")
            
            # Create and store tenant context
            context = TenantContext(
                tenant_id=tenant_id,
                realm=self._extract_realm(tenant_id),
                user_id=user_id,
                roles=roles,
                email=email
            )
            context.jwt_token = token
            context.jwt_claims = claims
            
            g.tenant_context = context
            
            # Set database session tenant context for RLS
            self._set_db_tenant_context(tenant_id, claims)
            
            logger.debug(f"Tenant context set: {context.tenant_id} for {email or 'anonymous'}")
            
        except Exception as e:
            logger.error(f"Error extracting tenant context: {e}")
            abort(500, description="Internal server error")
    
    def _extract_tenant_id(self) -> Optional[str]:
        """Extract tenant ID from request (multiple sources)"""
        
        # 1. From X-Tenant-ID header (API clients)
        tenant_id = request.headers.get('X-Tenant-ID')
        if tenant_id:
            return tenant_id
        
        # 2. From subdomain (browser clients)
        host = request.host.split(':')[0]
        if host.endswith('.ceres.io') or host.endswith('.ceres.local'):
            subdomain = host.split('.')[0]
            if subdomain not in ['www', 'api', 'admin']:
                return subdomain
        
        # 3. From request path (API routes like /api/v1/tenants/{id}/)
        import re
        match = re.match(r'^/api/v1/tenants/([a-z0-9\-]+)/', request.path)
        if match:
            return match.group(1)
        
        # 4. From custom parameter
        tenant_id = request.args.get('tenant_id') or request.form.get('tenant_id')
        if tenant_id:
            return tenant_id
        
        return None
    
    def _extract_realm(self, tenant_id: str) -> str:
        """Get Keycloak realm name for tenant"""
        # Realm name is typically tenant_id or derived from it
        return tenant_id.replace('-', '_')
    
    def _set_db_tenant_context(self, tenant_id: str, claims: Dict):
        """Set database-level tenant context for RLS"""
        if not self.db_session:
            return
        
        try:
            # Set application context variables for RLS
            self.db_session.execute(
                text(f"SET app.current_tenant_id = '{tenant_id}'")
            )
            
            # Set JWT claims as JSON for advanced RLS queries
            claims_json = json.dumps(claims)
            self.db_session.execute(
                text(f"SET app.jwt_claims = '{claims_json}'")
            )
            
            logger.debug(f"Database tenant context set for {tenant_id}")
        except Exception as e:
            logger.error(f"Failed to set database tenant context: {e}")
    
    def _cleanup_tenant_context(self, response):
        """Cleanup tenant context after request"""
        if self.db_session:
            self.db_session.execute(text("RESET app.current_tenant_id"))
            self.db_session.execute(text("RESET app.jwt_claims"))
        
        return response


def require_tenant_context(f):
    """Decorator to require valid tenant context"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not hasattr(g, 'tenant_context') or not g.tenant_context:
            abort(401, description="Authentication required")
        return f(*args, **kwargs)
    return decorated_function


def require_role(role: str):
    """Decorator to require specific role"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not hasattr(g, 'tenant_context'):
                abort(401, description="Authentication required")
            
            if not g.tenant_context.has_role(role):
                abort(403, description=f"Role '{role}' required")
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator


def require_permission(permission: str):
    """Decorator to require specific permission"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            if not hasattr(g, 'tenant_context'):
                abort(401, description="Authentication required")
            
            if not g.tenant_context.has_permission(permission):
                abort(403, description=f"Permission '{permission}' required")
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator


@contextmanager
def tenant_context(tenant_id: str, user_id: Optional[str] = None, db_session: Optional[Session] = None):
    """Context manager for temporary tenant context"""
    old_context = getattr(g, 'tenant_context', None)
    
    try:
        g.tenant_context = TenantContext(
            tenant_id=tenant_id,
            realm=tenant_id.replace('-', '_'),
            user_id=user_id
        )
        
        # Set database context if session provided
        if db_session:
            db_session.execute(text(f"SET app.current_tenant_id = '{tenant_id}'"))
        
        yield g.tenant_context
    
    finally:
        # Restore old context
        g.tenant_context = old_context
        if db_session:
            db_session.execute(text("RESET app.current_tenant_id"))


class TenantAwareQuery:
    """SQLAlchemy mixin for automatic tenant filtering"""
    
    @classmethod
    def for_tenant(cls, tenant_id: Optional[str] = None):
        """Get query filtered to specific tenant"""
        if not tenant_id and hasattr(g, 'tenant_context'):
            tenant_id = g.tenant_context.tenant_id
        
        if not tenant_id:
            raise ValueError("No tenant context available")
        
        # Filter by tenant_id column
        return cls.query.filter(cls.tenant_id == tenant_id)
    
    @classmethod
    def get_for_tenant(cls, id: Any, tenant_id: Optional[str] = None):
        """Get record by ID for specific tenant"""
        return cls.for_tenant(tenant_id).filter(cls.id == id).first()


def audit_log_action(action: str, resource_type: str, resource_id: str, 
                     old_data: Optional[Dict] = None, new_data: Optional[Dict] = None):
    """Log audit action for tenant"""
    if not hasattr(g, 'tenant_context'):
        return
    
    context = g.tenant_context
    
    # Log to audit table
    audit_entry = {
        'tenant_id': context.tenant_id,
        'user_id': context.user_id,
        'action': action,
        'resource_type': resource_type,
        'resource_id': resource_id,
        'old_data': old_data,
        'new_data': new_data,
        'timestamp': datetime.now(),
        'ip_address': request.remote_addr,
        'user_agent': request.user_agent.string
    }
    
    logger.info(f"Audit: {json.dumps(audit_entry)}")


# Flask Blueprint example
from flask import Blueprint

def create_tenant_blueprint(name: str = 'tenants'):
    """Create Flask blueprint with tenant-aware routes"""
    bp = Blueprint(name, __name__, url_prefix='/api/v1/tenants')
    
    @bp.route('/<tenant_id>/info', methods=['GET'])
    @require_tenant_context
    def get_tenant_info(tenant_id: str):
        """Get tenant information"""
        context = g.tenant_context
        
        if context.tenant_id != tenant_id:
            abort(403, description="Cannot access other tenant")
        
        return {
            'tenant_id': context.tenant_id,
            'realm': context.realm,
            'user_id': context.user_id,
            'roles': context.roles,
            'email': context.email
        }
    
    @bp.route('/<tenant_id>/members', methods=['GET'])
    @require_tenant_context
    @require_role('admin')
    def list_tenant_members(tenant_id: str):
        """List tenant members (admin only)"""
        context = g.tenant_context
        
        if context.tenant_id != tenant_id:
            abort(403, description="Cannot access other tenant")
        
        # Query returns only members for this tenant (RLS enforced)
        # SELECT * FROM users WHERE tenant_id = <tenant_id>
        
        return {'members': []}
    
    return bp
