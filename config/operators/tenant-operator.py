#!/usr/bin/env python3
"""
CERES Tenant Operator - Kubernetes Operator for automated tenant provisioning
Manages CeresTenant resources: automatic namespace, keycloak realm, database schema creation
v2.9.0 - Production-ready operator with reconciliation and status tracking
"""

import os
import sys
import logging
import json
import time
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List
from dataclasses import dataclass

import kopf
import kubernetes
from kubernetes import client, config, watch
from kubernetes.client.rest import ApiException
import yaml
import requests
from jinja2 import Template

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('ceres-tenant-operator')


@dataclass
class TenantConfig:
    """Tenant configuration container"""
    tenant_id: str
    name: str
    display_name: str
    namespace: str
    admin_username: str
    admin_email: str
    plan: str
    keycloak_realm: str


class KeycloakManager:
    """Manage Keycloak realm and users for tenants"""
    
    def __init__(self, keycloak_url: str, admin_username: str, admin_password: str):
        self.url = keycloak_url
        self.username = admin_username
        self.password = admin_password
        self.token = None
        self.authenticate()
    
    def authenticate(self):
        """Get admin access token from Keycloak"""
        token_url = f"{self.url}/realms/master/protocol/openid-connect/token"
        data = {
            'client_id': 'admin-cli',
            'username': self.username,
            'password': self.password,
            'grant_type': 'password'
        }
        
        try:
            response = requests.post(token_url, data=data, timeout=10)
            response.raise_for_status()
            self.token = response.json()['access_token']
            logger.info("✓ Keycloak authentication successful")
        except requests.RequestException as e:
            logger.error(f"✗ Keycloak authentication failed: {e}")
            raise
    
    def get_headers(self) -> Dict[str, str]:
        """Get authorization headers"""
        return {
            'Authorization': f'Bearer {self.token}',
            'Content-Type': 'application/json'
        }
    
    def create_realm(self, realm_name: str, tenant_config: TenantConfig) -> bool:
        """Create Keycloak realm for tenant"""
        realm_data = {
            'realm': realm_name,
            'displayName': tenant_config.display_name,
            'enabled': True,
            'loginTheme': 'ceres',
            'accountTheme': 'ceres',
            'adminTheme': 'keycloak',
            'emailTheme': 'ceres',
            'rememberMe': True,
            'userManagedAccessAllowed': False,
            'resetPasswordAllowed': True,
            'verifyEmail': True,
            'expiredActionTokenDuration': 900,
            'smtpServer': {
                'host': 'smtp.ceres.io',
                'from': f'noreply@{tenant_config.tenant_id}.ceres.io',
                'auth': True,
                'ssl': True,
                'port': '465'
            }
        }
        
        try:
            url = f"{self.url}/admin/realms"
            response = requests.post(
                url,
                headers=self.get_headers(),
                json=realm_data,
                timeout=10
            )
            
            if response.status_code in [201, 204]:
                logger.info(f"✓ Keycloak realm '{realm_name}' created")
                return True
            else:
                logger.error(f"✗ Failed to create realm: {response.text}")
                return False
        except requests.RequestException as e:
            logger.error(f"✗ Keycloak realm creation failed: {e}")
            return False
    
    def create_user(self, realm_name: str, username: str, email: str, 
                   temp_password: str, first_name: str = "", last_name: str = "") -> bool:
        """Create user in Keycloak realm"""
        user_data = {
            'username': username,
            'email': email,
            'firstName': first_name,
            'lastName': last_name,
            'enabled': True,
            'emailVerified': False,
            'credentials': [
                {
                    'type': 'password',
                    'value': temp_password,
                    'temporary': True
                }
            ]
        }
        
        try:
            url = f"{self.url}/admin/realms/{realm_name}/users"
            response = requests.post(
                url,
                headers=self.get_headers(),
                json=user_data,
                timeout=10
            )
            
            if response.status_code == 201:
                logger.info(f"✓ User '{username}' created in realm '{realm_name}'")
                return True
            else:
                logger.error(f"✗ Failed to create user: {response.text}")
                return False
        except requests.RequestException as e:
            logger.error(f"✗ User creation failed: {e}")
            return False
    
    def create_client(self, realm_name: str, client_name: str, redirect_uris: List[str]) -> Dict:
        """Create OAuth2 client for tenant application"""
        client_data = {
            'clientId': client_name,
            'name': client_name,
            'enabled': True,
            'clientAuthenticatorType': 'client-secret',
            'redirectUris': redirect_uris,
            'webOrigins': [uri.split('/')[2] for uri in redirect_uris],
            'standardFlowEnabled': True,
            'implicitFlowEnabled': False,
            'directAccessGrantsEnabled': True,
            'serviceAccountsEnabled': True,
            'authorizationServicesEnabled': False,
            'publicClient': False
        }
        
        try:
            url = f"{self.url}/admin/realms/{realm_name}/clients"
            response = requests.post(
                url,
                headers=self.get_headers(),
                json=client_data,
                timeout=10
            )
            
            if response.status_code == 201:
                client = response.json()
                logger.info(f"✓ OAuth2 client '{client_name}' created")
                return client
            else:
                logger.error(f"✗ Failed to create client: {response.text}")
                return {}
        except requests.RequestException as e:
            logger.error(f"✗ Client creation failed: {e}")
            return {}


class DatabaseManager:
    """Manage PostgreSQL database for tenants"""
    
    def __init__(self, host: str, port: int, admin_user: str, admin_password: str):
        self.host = host
        self.port = port
        self.admin_user = admin_user
        self.admin_password = admin_password
    
    def execute_sql(self, sql: str, database: str = 'postgres') -> bool:
        """Execute SQL query as admin"""
        import psycopg2
        
        try:
            conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                user=self.admin_user,
                password=self.admin_password,
                database=database
            )
            cursor = conn.cursor()
            cursor.execute(sql)
            conn.commit()
            cursor.close()
            conn.close()
            logger.info(f"✓ SQL executed successfully")
            return True
        except Exception as e:
            logger.error(f"✗ SQL execution failed: {e}")
            return False
    
    def create_tenant_schema(self, tenant_id: str) -> bool:
        """Create database schema for tenant"""
        schema_name = f"tenant_{tenant_id.replace('-', '_')}"
        
        sql_commands = [
            f"CREATE SCHEMA IF NOT EXISTS {schema_name};",
            f"GRANT ALL PRIVILEGES ON SCHEMA {schema_name} TO ceres_app;",
            f"SET search_path TO {schema_name}, public;",
            
            # Create tenant metadata table
            f"""
            CREATE TABLE IF NOT EXISTS {schema_name}.tenant_config (
                id SERIAL PRIMARY KEY,
                tenant_id VARCHAR(32) UNIQUE NOT NULL,
                display_name VARCHAR(255) NOT NULL,
                plan VARCHAR(32) DEFAULT 'starter',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                active BOOLEAN DEFAULT true
            );
            """,
            
            # Create RLS policy
            f"""
            ALTER TABLE {schema_name}.tenant_config ENABLE ROW LEVEL SECURITY;
            CREATE POLICY tenant_isolation ON {schema_name}.tenant_config
            USING (tenant_id = current_setting('app.tenant_id')::text);
            """,
        ]
        
        for sql in sql_commands:
            if not self.execute_sql(sql):
                return False
        
        logger.info(f"✓ Database schema '{schema_name}' created for tenant '{tenant_id}'")
        return True
    
    def create_tenant_user(self, tenant_id: str, username: str, password: str) -> bool:
        """Create dedicated database user for tenant"""
        schema_name = f"tenant_{tenant_id.replace('-', '_')}"
        db_user = f"tenant_{tenant_id.replace('-', '_')}"
        
        sql = f"""
        CREATE USER {db_user} WITH PASSWORD '{password}';
        GRANT USAGE ON SCHEMA {schema_name} TO {db_user};
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA {schema_name} TO {db_user};
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA {schema_name} TO {db_user};
        """
        
        return self.execute_sql(sql)


class NamespaceManager:
    """Manage Kubernetes namespaces for tenants"""
    
    def __init__(self):
        self.v1 = client.CoreV1Api()
    
    def create_namespace(self, namespace: str, tenant_id: str) -> bool:
        """Create Kubernetes namespace for tenant"""
        ns_manifest = {
            'apiVersion': 'v1',
            'kind': 'Namespace',
            'metadata': {
                'name': namespace,
                'labels': {
                    'tenant-id': tenant_id,
                    'managed-by': 'ceres-tenant-operator'
                },
                'annotations': {
                    'ceres.io/tenant-id': tenant_id,
                    'pod-security.kubernetes.io/enforce': 'baseline'
                }
            }
        }
        
        try:
            self.v1.create_namespace(ns_manifest)
            logger.info(f"✓ Namespace '{namespace}' created for tenant '{tenant_id}'")
            return True
        except ApiException as e:
            if e.status == 409:
                logger.warning(f"⚠ Namespace '{namespace}' already exists")
                return True
            logger.error(f"✗ Failed to create namespace: {e}")
            return False
    
    def create_tenant_rbac(self, namespace: str, tenant_id: str) -> bool:
        """Create RBAC resources for tenant isolation"""
        rbac_manifest = f"""
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tenant-admin
  namespace: {namespace}
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-admin-binding
  namespace: {namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: tenant-admin
subjects:
- kind: ServiceAccount
  name: tenant-admin
  namespace: {namespace}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tenant-admin
  namespace: {namespace}
  labels:
    tenant-id: {tenant_id}
"""
        try:
            yaml_list = yaml.safe_load_all(rbac_manifest)
            for item in yaml_list:
                if item:
                    kubernetes.utils.create_from_yaml_dict(
                        api_client=client.api_client.ApiClient(),
                        data=item,
                        namespace=namespace
                    )
            logger.info(f"✓ RBAC configured for namespace '{namespace}'")
            return True
        except Exception as e:
            logger.error(f"✗ Failed to create RBAC: {e}")
            return False


# =====================================================
# Kopf Operator Handlers
# =====================================================

@kopf.on.event('ceres.io', 'v1alpha1', 'cerestenants',
               labels={'managed-by': 'ceres-tenant-operator'})
def log_tenant_event(event, **kwargs):
    """Log all tenant events"""
    logger.info(f"Event: {event['type']} - {event['object']['metadata']['name']}")


@kopf.on.create('ceres.io', 'v1alpha1', 'cerestenants')
def create_tenant(spec, status, namespace, name, patch, **kwargs):
    """Handle CeresTenant creation"""
    logger.info(f"🚀 Creating tenant: {name}")
    
    tenant_id = spec.get('tenantId')
    tenant_namespace = spec.get('namespace', f'tenant-{tenant_id}')
    keycloak_realm = spec.get('keycloak', {}).get('realmName', tenant_id)
    admin_username = spec.get('admin', {}).get('username')
    admin_email = spec.get('admin', {}).get('email')
    
    # Step 1: Create Kubernetes namespace
    ns_mgr = NamespaceManager()
    if not ns_mgr.create_namespace(tenant_namespace, tenant_id):
        patch.status['phase'] = 'Failed'
        patch.status['conditions'] = [{
            'type': 'NamespaceCreated',
            'status': 'False',
            'reason': 'NamespaceCreationFailed',
            'message': f'Failed to create namespace {tenant_namespace}',
            'lastTransitionTime': datetime.now().isoformat()
        }]
        return
    
    # Step 2: Create Keycloak realm
    try:
        keycloak_url = os.getenv('KEYCLOAK_URL', 'http://keycloak:8080')
        keycloak_admin = os.getenv('KEYCLOAK_ADMIN', 'admin')
        keycloak_password = os.getenv('KEYCLOAK_ADMIN_PASSWORD', '')
        
        kc_mgr = KeycloakManager(keycloak_url, keycloak_admin, keycloak_password)
        tenant_config = TenantConfig(
            tenant_id=tenant_id,
            name=spec.get('name'),
            display_name=spec.get('displayName'),
            namespace=tenant_namespace,
            admin_username=admin_username,
            admin_email=admin_email,
            plan=spec.get('plan', 'starter'),
            keycloak_realm=keycloak_realm
        )
        
        if not kc_mgr.create_realm(keycloak_realm, tenant_config):
            raise Exception("Failed to create Keycloak realm")
        
        # Create admin user
        if not kc_mgr.create_user(
            keycloak_realm,
            admin_username,
            admin_email,
            "ChangeMe123!",  # Temporary password
            spec.get('admin', {}).get('firstName', ''),
            spec.get('admin', {}).get('lastName', '')
        ):
            raise Exception("Failed to create admin user")
        
    except Exception as e:
        logger.error(f"✗ Keycloak setup failed: {e}")
        patch.status['phase'] = 'Failed'
        return
    
    # Step 3: Create database schema
    try:
        db_host = os.getenv('DB_HOST', 'postgres')
        db_port = int(os.getenv('DB_PORT', 5432))
        db_admin = os.getenv('DB_ADMIN_USER', 'postgres')
        db_password = os.getenv('DB_ADMIN_PASSWORD', '')
        
        db_mgr = DatabaseManager(db_host, db_port, db_admin, db_password)
        if not db_mgr.create_tenant_schema(tenant_id):
            raise Exception("Failed to create database schema")
    
    except Exception as e:
        logger.error(f"✗ Database setup failed: {e}")
        patch.status['phase'] = 'Failed'
        return
    
    # Update status
    patch.status['phase'] = 'Active'
    patch.status['provisioned'] = datetime.now().isoformat()
    patch.status['namespace'] = tenant_namespace
    patch.status['keycloakRealm'] = keycloak_realm
    patch.status['conditions'] = [
        {
            'type': 'Ready',
            'status': 'True',
            'reason': 'TenantProvisioned',
            'message': f'Tenant {tenant_id} provisioned successfully',
            'lastTransitionTime': datetime.now().isoformat()
        }
    ]
    
    logger.info(f"✓ Tenant '{tenant_id}' provisioned successfully")


@kopf.on.update('ceres.io', 'v1alpha1', 'cerestenants')
def update_tenant(spec, status, patch, **kwargs):
    """Handle CeresTenant updates"""
    logger.info(f"🔄 Updating tenant: {spec.get('tenantId')}")
    patch.status['lastUpdated'] = datetime.now().isoformat()


@kopf.on.delete('ceres.io', 'v1alpha1', 'cerestenants')
def delete_tenant(spec, **kwargs):
    """Handle CeresTenant deletion"""
    tenant_id = spec.get('tenantId')
    logger.info(f"🗑️  Deleting tenant: {tenant_id}")
    # Cleanup logic here


def main():
    """Main operator entry point"""
    logger.info("🔷 CERES Tenant Operator started")
    logger.info(f"  Version: 2.9.0")
    logger.info(f"  Kubernetes: {config.KUBERNETES_VERSION}")
    
    # Load Kubernetes config
    try:
        config.load_incluster_config()
        logger.info("✓ Using in-cluster configuration")
    except:
        config.load_kube_config()
        logger.info("✓ Using local kubeconfig")
    
    # Start operator
    kopf.run(loglevel=logging.INFO)


if __name__ == '__main__':
    main()
