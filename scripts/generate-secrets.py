#!/usr/bin/env python3
"""
Generate secure secrets for .env file
Replaces all CHANGE_ME values with secure random strings
"""

import os
import secrets
import string
import re
from pathlib import Path

def generate_secret(length=32):
    """Generate a secure random string"""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def generate_jwt_secret():
    """Generate JWT secret (64 chars)"""
    return secrets.token_urlsafe(48)

def generate_api_key():
    """Generate API key format"""
    return f"glpat-{generate_secret(20)}"

def generate_webhook_key():
    """Generate webhook key"""
    return secrets.token_hex(32)

def update_env_file():
    """Update config/.env with generated secrets"""
    env_example = Path("config/.env.example")
    env_file = Path("config/.env")
    
    if not env_example.exists():
        print("❌ config/.env.example not found!")
        return
    
    # Read template
    with open(env_example, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace CHANGE_ME values
    replacements = {
        'POSTGRES_PASSWORD': generate_secret(32),
        'WG_HOST': '192.168.1.100',  # Default, user should change
        'WG_EASY_PASSWORD': generate_secret(16),
        'KEYCLOAK_ADMIN_PASSWORD': generate_secret(24),
        
        # GitLab
        'GITLAB_ROOT_PASSWORD': generate_secret(24),
        'GITLAB_DB_PASSWORD': generate_secret(32),
        'GITLAB_SMTP_PASSWORD': generate_secret(24),
        'GITLAB_OIDC_SECRET': generate_secret(48),
        'GITLAB_API_TOKEN': generate_api_key(),
        'GITLAB_PROMETHEUS_TOKEN': generate_secret(32),
        
        # Zulip
        'ZULIP_DB_PASSWORD': generate_secret(32),
        'ZULIP_ADMIN_PASSWORD': generate_secret(24),
        'ZULIP_SMTP_PASSWORD': generate_secret(24),
        'ZULIP_OIDC_SECRET': generate_secret(48),
        'ZULIP_SECRET_KEY': generate_jwt_secret(),
        'ZULIP_WEBHOOK_KEY': generate_webhook_key(),
        'ZULIP_BOT_API_KEY': generate_api_key(),
        
        # OIDC
        'NEXTCLOUD_OIDC_SECRET': generate_secret(48),
        'GRAFANA_OIDC_SECRET': generate_secret(48),
        'PORTAINER_OIDC_SECRET': generate_secret(48),
        'MAYAN_OIDC_SECRET': generate_secret(48),
        'UPTIME_OIDC_SECRET': generate_secret(48),
    }
    
    # Replace only CHANGE_ME values
    for key, value in replacements.items():
        pattern = f'{key}=CHANGE_ME'
        if pattern in content:
            content = content.replace(pattern, f'{key}={value}')
            print(f"✅ Generated {key}")
    
    # Write to .env
    with open(env_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n✅ Generated config/.env with secure secrets!")
    print(f"⚠️  Review and update WG_HOST, SMTP_* values manually")

if __name__ == '__main__':
    update_env_file()
