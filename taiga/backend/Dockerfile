# Dockerfile for Taiga backend with useful plugins (LDAP, Slack, Time‑Tracking)
# Base image from official Taiga backend
FROM taigaio/taiga-back:latest

# Install extra Python dependencies for plugins
RUN pip install --no-cache-dir \
    django-auth-ldap \
    taiga-contrib-slack \
    taiga-contrib-time-tracking

# Copy our settings override (adds LDAP, Slack, Time‑Tracking)
COPY settings_override.py /taiga/settings_override.py

# Tell Taiga to use the override module
ENV TAIGA_BACKEND_SETTINGS_MODULE=taiga.settings_override

# Expose the default port (8000) – already exposed by base image
EXPOSE 8000

# Entry point stays the same (provided by base image)
