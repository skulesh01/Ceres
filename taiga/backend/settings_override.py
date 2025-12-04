# settings_override.py – Taiga backend custom settings
# This file is imported by the base Taiga settings via the environment variable
# TAIGA_BACKEND_SETTINGS_MODULE=taiga.settings_override

from .settings import *  # импортировать все базовые настройки

# -------------------------------------------------------------------
# LDAP authentication (via FreeIPA)
# -------------------------------------------------------------------
import ldap
import django_auth_ldap.config as ldap_config

AUTH_LDAP_SERVER_URI = os.getenv('LDAP_URL', 'ldap://freeipa.company.local')
AUTH_LDAP_BIND_DN = os.getenv('LDAP_BIND_DN', 'uid=admin,cn=users,cn=accounts,dc=company,dc=local')
AUTH_LDAP_BIND_PASSWORD = os.getenv('LDAP_BIND_PASSWORD', 'FreeIPAAdmin123')

AUTH_LDAP_USER_SEARCH = ldap_config.LDAPSearch(
    "ou=users,dc=company,dc=local",
    ldap.SCOPE_SUBTREE,
    "(uid=%(user)s)"
)

AUTHENTICATION_BACKENDS = (
    'django_auth_ldap.backend.LDAPBackend',
    'taiga.auth.backends.EmailBackend',
)

# -------------------------------------------------------------------
# Slack notifications (optional)
# -------------------------------------------------------------------
SLACK_WEBHOOK_URL = os.getenv('SLACK_WEBHOOK_URL', '')
if SLACK_WEBHOOK_URL:
    INSTALLED_APPS += ('taiga_contrib_slack',)
    # basic configuration – the plugin reads the webhook URL from env
    TAIGA_SLACK_WEBHOOK_URL = SLACK_WEBHOOK_URL

# -------------------------------------------------------------------
# Time‑Tracking plugin (taiga-contrib-time-tracking)
# -------------------------------------------------------------------
INSTALLED_APPS += ('taiga_contrib_time_tracking',)
# Enable time‑tracking globally
TAIGA_TIME_TRACKING_ENABLED = True

# -------------------------------------------------------------------
# Miscellaneous tweaks – keep things lightweight for demo
# -------------------------------------------------------------------
DEBUG = False
ALLOWED_HOSTS = ['*']  # Traefik will handle proper host validation

# Ensure the secret key is set via env (required by Django)
SECRET_KEY = os.getenv('TAIGA_SECRET_KEY', 'replace‑this‑with‑a‑strong‑random‑value')
