#!/usr/bin/env python3
"""
CERES Webhook Server - Validation and Mutation Webhooks for CRDs
v2.9.0 - Provides CRD validation, mutation, and conversion
"""

import json
import logging
import base64
from datetime import datetime
from typing import Dict, Any, List

import kopf
from flask import Flask, request, jsonify
import jsonschema

logger = logging.getLogger('ceres-webhook')
app = Flask(__name__)


# =====================================================
# Validation Webhooks
# =====================================================

class TenantValidator:
    """Validate CeresTenant resources"""
    
    @staticmethod
    def validate_tenant_id(tenant_id: str) -> List[str]:
        """Validate tenant ID format"""
        errors = []
        if not tenant_id:
            errors.append("tenantId is required")
        elif not all(c.isalnum() or c == '-' for c in tenant_id):
            errors.append("tenantId must contain only alphanumeric characters and hyphens")
        elif len(tenant_id) < 3 or len(tenant_id) > 32:
            errors.append("tenantId must be between 3 and 32 characters")
        return errors
    
    @staticmethod
    def validate_email(email: str) -> List[str]:
        """Validate email format"""
        errors = []
        if '@' not in email or '.' not in email:
            errors.append(f"Invalid email format: {email}")
        return errors
    
    @staticmethod
    def validate_plan(plan: str) -> List[str]:
        """Validate subscription plan"""
        errors = []
        valid_plans = ["free", "starter", "professional", "enterprise"]
        if plan not in valid_plans:
            errors.append(f"Plan must be one of: {', '.join(valid_plans)}")
        return errors
    
    @classmethod
    def validate(cls, body: Dict[str, Any]) -> Dict[str, Any]:
        """Full validation of CeresTenant"""
        spec = body.get('spec', {})
        errors = []
        
        # Validate tenant ID
        tenant_id = spec.get('tenantId')
        errors.extend(cls.validate_tenant_id(tenant_id or ''))
        
        # Validate admin email
        admin = spec.get('admin', {})
        if admin:
            email = admin.get('email')
            if email:
                errors.extend(cls.validate_email(email))
        
        # Validate plan
        plan = spec.get('plan', 'starter')
        errors.extend(cls.validate_plan(plan))
        
        return {
            'valid': len(errors) == 0,
            'errors': errors
        }


class DatabaseValidator:
    """Validate CeresDatabase resources"""
    
    @staticmethod
    def validate_engine(engine: str) -> List[str]:
        """Validate database engine"""
        errors = []
        valid_engines = ["postgresql", "mysql", "mongodb"]
        if engine not in valid_engines:
            errors.append(f"Engine must be one of: {', '.join(valid_engines)}")
        return errors
    
    @staticmethod
    def validate_version(version: str) -> List[str]:
        """Validate database version format"""
        errors = []
        parts = version.split('.')
        if len(parts) < 2:
            errors.append("Version must be in format MAJOR.MINOR or MAJOR.MINOR.PATCH")
        try:
            for part in parts[:2]:
                int(part)
        except ValueError:
            errors.append("Version numbers must be numeric")
        return errors
    
    @staticmethod
    def validate_storage_size(size: str) -> List[str]:
        """Validate storage size format"""
        errors = []
        if not size or not size[-2:].isalpha():
            errors.append("Storage size must end with unit (e.g., 10Gi, 100Gi)")
        try:
            int(size[:-2])
        except ValueError:
            errors.append("Storage size must be numeric with unit")
        return errors
    
    @classmethod
    def validate(cls, body: Dict[str, Any]) -> Dict[str, Any]:
        """Full validation of CeresDatabase"""
        spec = body.get('spec', {})
        errors = []
        
        # Validate engine
        engine = spec.get('engine')
        if engine:
            errors.extend(cls.validate_engine(engine))
        
        # Validate version
        version = spec.get('version')
        if version:
            errors.extend(cls.validate_version(version))
        
        # Validate storage
        storage = spec.get('storage', {})
        if storage:
            size = storage.get('size')
            if size:
                errors.extend(cls.validate_storage_size(size))
        
        # Validate replicas
        replicas = spec.get('replicas', 1)
        if replicas < 1 or replicas > 10:
            errors.append("Replicas must be between 1 and 10")
        
        return {
            'valid': len(errors) == 0,
            'errors': errors
        }


@app.route('/validate/cerestenant', methods=['POST'])
def validate_tenant():
    """Webhook for validating CeresTenant resources"""
    admission_review = request.get_json()
    
    try:
        uid = admission_review['request']['uid']
        resource = admission_review['request']['object']
        
        validation = TenantValidator.validate(resource)
        
        response = {
            'apiVersion': 'admission.k8s.io/v1',
            'kind': 'AdmissionReview',
            'response': {
                'uid': uid,
                'allowed': validation['valid'],
                'status': {
                    'message': '; '.join(validation['errors']) if validation['errors'] else 'Valid'
                }
            }
        }
        
        return jsonify(response), 200
    
    except Exception as e:
        logger.error(f"Validation error: {e}")
        return jsonify({'error': str(e)}), 400


@app.route('/validate/ceresdatabase', methods=['POST'])
def validate_database():
    """Webhook for validating CeresDatabase resources"""
    admission_review = request.get_json()
    
    try:
        uid = admission_review['request']['uid']
        resource = admission_review['request']['object']
        
        validation = DatabaseValidator.validate(resource)
        
        response = {
            'apiVersion': 'admission.k8s.io/v1',
            'kind': 'AdmissionReview',
            'response': {
                'uid': uid,
                'allowed': validation['valid'],
                'status': {
                    'message': '; '.join(validation['errors']) if validation['errors'] else 'Valid'
                }
            }
        }
        
        return jsonify(response), 200
    
    except Exception as e:
        logger.error(f"Validation error: {e}")
        return jsonify({'error': str(e)}), 400


# =====================================================
# Mutation Webhooks
# =====================================================

class TenantMutator:
    """Mutate CeresTenant resources with defaults"""
    
    @staticmethod
    def mutate(obj: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Generate JSON patches for tenant mutation"""
        patches = []
        spec = obj.get('spec', {})
        
        # Set default namespace if not provided
        if 'namespace' not in spec or not spec['namespace']:
            tenant_id = spec.get('tenantId', 'default')
            patches.append({
                'op': 'add',
                'path': '/spec/namespace',
                'value': f'tenant-{tenant_id}'
            })
        
        # Set default plan
        if 'plan' not in spec:
            patches.append({
                'op': 'add',
                'path': '/spec/plan',
                'value': 'starter'
            })
        
        # Set default keycloak realm
        if 'keycloak' not in spec or 'realmName' not in spec.get('keycloak', {}):
            tenant_id = spec.get('tenantId')
            patches.append({
                'op': 'add',
                'path': '/spec/keycloak/realmName',
                'value': tenant_id
            })
        
        # Add labels
        metadata = obj.get('metadata', {})
        labels = metadata.get('labels', {})
        if 'app.ceres.io/tenant' not in labels:
            tenant_id = spec.get('tenantId')
            patches.append({
                'op': 'add',
                'path': f'/metadata/labels/app.ceres.io~1tenant',
                'value': tenant_id
            })
        
        # Add managed-by label
        if 'app.kubernetes.io/managed-by' not in labels:
            patches.append({
                'op': 'add',
                'path': '/metadata/labels/app.kubernetes.io~1managed-by',
                'value': 'ceres-tenant-operator'
            })
        
        return patches


@app.route('/mutate/cerestenant', methods=['POST'])
def mutate_tenant():
    """Webhook for mutating CeresTenant resources"""
    admission_review = request.get_json()
    
    try:
        uid = admission_review['request']['uid']
        obj = admission_review['request']['object']
        
        patches = TenantMutator.mutate(obj)
        
        # Encode patches in base64
        patch_bytes = json.dumps(patches).encode('utf-8')
        patch_b64 = base64.b64encode(patch_bytes).decode('utf-8')
        
        response = {
            'apiVersion': 'admission.k8s.io/v1',
            'kind': 'AdmissionReview',
            'response': {
                'uid': uid,
                'allowed': True,
                'patchType': 'JSONPatch',
                'patch': patch_b64
            }
        }
        
        return jsonify(response), 200
    
    except Exception as e:
        logger.error(f"Mutation error: {e}")
        return jsonify({'error': str(e)}), 400


# =====================================================
# Conversion Webhooks
# =====================================================

@app.route('/convert', methods=['POST'])
def convert_crd():
    """Handle CRD version conversion (e.g., v1alpha1 -> v1beta1)"""
    conversion_review = request.get_json()
    
    try:
        uid = conversion_review['request']['uid']
        objects = conversion_review['request']['objects']
        desired_api_version = conversion_review['request']['desiredAPIVersion']
        
        converted_objects = []
        
        for obj in objects:
            converted_obj = obj.copy()
            converted_obj['apiVersion'] = desired_api_version
            converted_objects.append(converted_obj)
        
        response = {
            'apiVersion': 'apiextensions.k8s.io/v1',
            'kind': 'ConversionReview',
            'response': {
                'uid': uid,
                'result': {
                    'status': 'Success'
                },
                'convertedObjects': converted_objects
            }
        }
        
        return jsonify(response), 200
    
    except Exception as e:
        logger.error(f"Conversion error: {e}")
        return jsonify({'error': str(e)}), 400


# =====================================================
# Health checks
# =====================================================

@app.route('/health', methods=['GET'])
def health():
    """Liveness probe"""
    return jsonify({'status': 'healthy'}), 200


@app.route('/ready', methods=['GET'])
def readiness():
    """Readiness probe"""
    return jsonify({'status': 'ready'}), 200


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    app.run(host='0.0.0.0', port=8443, ssl_context=('certs/tls.crt', 'certs/tls.key'))
