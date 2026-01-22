#!/bin/bash

# CERES Custom Branding
# Apply your company's branding across all services

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       CERES Custom Branding            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Get company info
read -p "Company Name: " COMPANY_NAME
if [ -z "$COMPANY_NAME" ]; then
    COMPANY_NAME="CERES Platform"
fi

read -p "Company Domain (e.g., company.com): " COMPANY_DOMAIN
read -p "Support Email (e.g., support@company.com): " SUPPORT_EMAIL
SUPPORT_EMAIL=${SUPPORT_EMAIL:-admin@${COMPANY_DOMAIN}}

read -p "Primary Color (hex, e.g., #007bff): " PRIMARY_COLOR
PRIMARY_COLOR=${PRIMARY_COLOR:-#007bff}

read -p "Logo URL (or path to file): " LOGO_PATH

# Ask for logo upload
if [ -n "$LOGO_PATH" ] && [ -f "$LOGO_PATH" ]; then
    LOGO_FILENAME=$(basename "$LOGO_PATH")
    LOGO_BASE64=$(base64 -w 0 "$LOGO_PATH" 2>/dev/null || base64 "$LOGO_PATH")
else
    echo -e "${YELLOW}⚠️  No logo file provided, using default${NC}"
    LOGO_URL="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'%3E%3Ctext y='50' font-size='50'%3E🚀%3C/text%3E%3C/svg%3E"
fi

#=============================================================================
# KEYCLOAK THEME
#=============================================================================
echo ""
echo -e "${BLUE}🔐 Customizing Keycloak login page...${NC}"

# Create custom theme ConfigMap
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-custom-theme
  namespace: ceres
data:
  theme.properties: |
    parent=keycloak
    import=common/keycloak
    
    styles=css/custom.css
  
  custom.css: |
    .login-pf body {
      background: linear-gradient(135deg, ${PRIMARY_COLOR} 0%, #667eea 100%);
    }
    
    .card-pf {
      box-shadow: 0 10px 40px rgba(0,0,0,0.2);
      border-radius: 12px;
    }
    
    #kc-header-wrapper {
      background-color: ${PRIMARY_COLOR};
      padding: 20px;
      border-radius: 12px 12px 0 0;
    }
    
    .kc-logo-text {
      background-image: none !important;
      font-size: 24px;
      font-weight: bold;
      color: white;
    }
    
    .kc-logo-text::after {
      content: "${COMPANY_NAME}";
    }
    
    #kc-form-buttons .btn-primary {
      background-color: ${PRIMARY_COLOR};
      border-color: ${PRIMARY_COLOR};
    }
    
    #kc-form-buttons .btn-primary:hover {
      background-color: ${PRIMARY_COLOR};
      opacity: 0.9;
    }
EOF

# Update Keycloak realm settings
KEYCLOAK_POD=$(kubectl get pod -n ceres -l app=keycloak -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n ceres ${KEYCLOAK_POD} -- /opt/keycloak/bin/kcadm.sh config credentials \
    --server http://localhost:8080 \
    --realm master \
    --user admin \
    --password admin123 2>/dev/null || true

kubectl exec -n ceres ${KEYCLOAK_POD} -- /opt/keycloak/bin/kcadm.sh update realms/ceres \
    -s displayName="${COMPANY_NAME}" \
    -s displayNameHtml="<strong>${COMPANY_NAME}</strong>" \
    -s loginTheme=custom \
    -s accountTheme=custom \
    -s adminTheme=custom \
    -s emailTheme=custom 2>/dev/null || true

echo -e "${GREEN}✅ Keycloak theme customized${NC}"

#=============================================================================
# GRAFANA BRANDING
#=============================================================================
echo ""
echo -e "${BLUE}📊 Customizing Grafana...${NC}"

# Update Grafana config
kubectl get configmap grafana-config -n monitoring -o yaml | \
sed "s/app_name = Grafana/app_name = ${COMPANY_NAME} Analytics/" | \
sed "s/org_name = Main Org./org_name = ${COMPANY_NAME}/" | \
kubectl apply -f -

# Custom CSS
cat <<EOF | kubectl create configmap grafana-custom-css -n monitoring --from-literal=custom.css="
.sidemenu__logo {
  background-image: url('${LOGO_URL}') !important;
}

.page-header__brand-text {
  display: none;
}

.login-branding {
  background-color: ${PRIMARY_COLOR} !important;
}

.btn-primary {
  background-color: ${PRIMARY_COLOR} !important;
  border-color: ${PRIMARY_COLOR} !important;
}

.navbar {
  background: linear-gradient(90deg, ${PRIMARY_COLOR} 0%, #667eea 100%);
}
" -o yaml --dry-run=client | kubectl apply -f -
EOF

# Restart Grafana
kubectl rollout restart deployment/grafana -n monitoring 2>/dev/null || true

echo -e "${GREEN}✅ Grafana branding applied${NC}"

#=============================================================================
# GITLAB BRANDING
#=============================================================================
echo ""
echo -e "${BLUE}🦊 Customizing GitLab...${NC}"

# Update GitLab configuration
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitlab-branding
  namespace: gitlab
data:
  gitlab.rb: |
    gitlab_rails['gitlab_default_theme'] = 2
    gitlab_rails['gravatar_enabled'] = true
    
    # Custom logo
    gitlab_rails['gitlab_email_from'] = '${SUPPORT_EMAIL}'
    gitlab_rails['gitlab_email_display_name'] = '${COMPANY_NAME} GitLab'
    gitlab_rails['gitlab_email_reply_to'] = '${SUPPORT_EMAIL}'
    
    # Sign-in page
    gitlab_rails['extra_sign_in_text'] = '${COMPANY_NAME} - Git Repository & CI/CD'
    
    # Help page
    gitlab_rails['help_page_text'] = 'Contact ${SUPPORT_EMAIL} for support'
    gitlab_rails['help_page_support_url'] = 'https://${COMPANY_DOMAIN}/support'
EOF

echo -e "${GREEN}✅ GitLab branding configured${NC}"

#=============================================================================
# MATTERMOST BRANDING
#=============================================================================
echo ""
echo -e "${BLUE}💬 Customizing Mattermost...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mattermost-branding
  namespace: mattermost
data:
  config.json: |
    {
      "TeamSettings": {
        "SiteName": "${COMPANY_NAME} Chat",
        "CustomBrandText": "${COMPANY_NAME}"
      },
      "EmailSettings": {
        "FeedbackName": "${COMPANY_NAME}",
        "FeedbackEmail": "${SUPPORT_EMAIL}",
        "ReplyToAddress": "${SUPPORT_EMAIL}"
      },
      "SupportSettings": {
        "SupportEmail": "${SUPPORT_EMAIL}",
        "AboutLink": "https://${COMPANY_DOMAIN}/about",
        "HelpLink": "https://${COMPANY_DOMAIN}/help",
        "PrivacyPolicyLink": "https://${COMPANY_DOMAIN}/privacy",
        "TermsOfServiceLink": "https://${COMPANY_DOMAIN}/terms"
      }
    }
EOF

echo -e "${GREEN}✅ Mattermost branding configured${NC}"

#=============================================================================
# NEXTCLOUD BRANDING
#=============================================================================
echo ""
echo -e "${BLUE}📁 Customizing Nextcloud...${NC}"

NEXTCLOUD_POD=$(kubectl get pod -n nextcloud -l app=nextcloud -o jsonpath='{.items[0].metadata.name}')

# Set theming via occ
kubectl exec -n nextcloud ${NEXTCLOUD_POD} -- php occ config:system:set \
    theme --value="${COMPANY_NAME}" 2>/dev/null || true

kubectl exec -n nextcloud ${NEXTCLOUD_POD} -- php occ config:app:set \
    theming name --value="${COMPANY_NAME}" 2>/dev/null || true

kubectl exec -n nextcloud ${NEXTCLOUD_POD} -- php occ config:app:set \
    theming url --value="https://${COMPANY_DOMAIN}" 2>/dev/null || true

kubectl exec -n nextcloud ${NEXTCLOUD_POD} -- php occ config:app:set \
    theming slogan --value="Secure File Storage" 2>/dev/null || true

kubectl exec -n nextcloud ${NEXTCLOUD_POD} -- php occ config:app:set \
    theming color --value="${PRIMARY_COLOR}" 2>/dev/null || true

echo -e "${GREEN}✅ Nextcloud theming applied${NC}"

#=============================================================================
# LANDING PAGE BRANDING
#=============================================================================
echo ""
echo -e "${BLUE}🌐 Customizing landing page...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: landing-page
  namespace: ceres
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>${COMPANY_NAME} - Platform</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                background: linear-gradient(135deg, ${PRIMARY_COLOR} 0%, #667eea 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            .container {
                max-width: 1200px;
                width: 100%;
            }
            .header {
                text-align: center;
                color: white;
                margin-bottom: 40px;
            }
            .logo {
                font-size: 64px;
                margin-bottom: 20px;
            }
            h1 {
                font-size: 48px;
                margin-bottom: 10px;
                text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
            }
            .tagline {
                font-size: 20px;
                opacity: 0.9;
            }
            .services {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
                gap: 20px;
            }
            .service-card {
                background: white;
                border-radius: 12px;
                padding: 30px;
                text-align: center;
                transition: transform 0.3s, box-shadow 0.3s;
                cursor: pointer;
                text-decoration: none;
                color: inherit;
            }
            .service-card:hover {
                transform: translateY(-5px);
                box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            }
            .service-icon {
                font-size: 48px;
                margin-bottom: 15px;
            }
            .service-name {
                font-size: 24px;
                font-weight: bold;
                margin-bottom: 10px;
                color: ${PRIMARY_COLOR};
            }
            .service-desc {
                color: #666;
                font-size: 14px;
            }
            .footer {
                text-align: center;
                color: white;
                margin-top: 40px;
                opacity: 0.8;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">🚀</div>
                <h1>${COMPANY_NAME}</h1>
                <p class="tagline">Your Complete DevOps Platform</p>
            </div>
            
            <div class="services">
                <a href="https://keycloak.${COMPANY_DOMAIN}" class="service-card">
                    <div class="service-icon">🔐</div>
                    <div class="service-name">Authentication</div>
                    <div class="service-desc">Single Sign-On & Identity Management</div>
                </a>
                
                <a href="https://gitlab.${COMPANY_DOMAIN}" class="service-card">
                    <div class="service-icon">🦊</div>
                    <div class="service-name">GitLab</div>
                    <div class="service-desc">Git Repository & CI/CD Pipelines</div>
                </a>
                
                <a href="https://grafana.${COMPANY_DOMAIN}" class="service-card">
                    <div class="service-icon">📊</div>
                    <div class="service-name">Grafana</div>
                    <div class="service-desc">Metrics & Monitoring Dashboards</div>
                </a>
                
                <a href="https://chat.${COMPANY_DOMAIN}" class="service-card">
                    <div class="service-icon">💬</div>
                    <div class="service-name">Chat</div>
                    <div class="service-desc">Team Communication</div>
                </a>
                
                <a href="https://files.${COMPANY_DOMAIN}" class="service-card">
                    <div class="service-icon">📁</div>
                    <div class="service-name">Files</div>
                    <div class="service-desc">Secure Cloud Storage</div>
                </a>
                
                <a href="https://wiki.${COMPANY_DOMAIN}" class="service-card">
                    <div class="service-icon">📖</div>
                    <div class="service-name">Wiki</div>
                    <div class="service-desc">Documentation & Knowledge Base</div>
                </a>
                
                <a href="https://minio.${COMPANY_DOMAIN}" class="service-card">
                    <div class="service-icon">🪣</div>
                    <div class="service-name">Storage</div>
                    <div class="service-desc">S3-Compatible Object Storage</div>
                </a>
            </div>
            
            <div class="footer">
                <p>© 2025 ${COMPANY_NAME}. All rights reserved.</p>
                <p>Support: ${SUPPORT_EMAIL}</p>
            </div>
        </div>
    </body>
    </html>
EOF

# Update deployment
kubectl rollout restart deployment/landing-page -n ceres 2>/dev/null || true

echo -e "${GREEN}✅ Landing page customized${NC}"

#=============================================================================
# EMAIL TEMPLATES
#=============================================================================
echo ""
echo -e "${BLUE}📧 Customizing email templates...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: email-templates
  namespace: ceres
data:
  welcome-email.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; background-color: #f4f4f4; }
            .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; }
            .header { background: ${PRIMARY_COLOR}; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; }
            .button { background: ${PRIMARY_COLOR}; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; }
            .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>${COMPANY_NAME}</h1>
            </div>
            <div class="content">
                <h2>Welcome to ${COMPANY_NAME}!</h2>
                <p>Your account has been created successfully.</p>
                <p>You now have access to our complete DevOps platform:</p>
                <ul>
                    <li>GitLab - Git Repository & CI/CD</li>
                    <li>Grafana - Monitoring Dashboards</li>
                    <li>Mattermost - Team Chat</li>
                    <li>Nextcloud - File Storage</li>
                    <li>And more...</li>
                </ul>
                <p style="text-align: center; margin-top: 30px;">
                    <a href="https://${COMPANY_DOMAIN}" class="button">Access Platform</a>
                </p>
            </div>
            <div class="footer">
                <p>© 2025 ${COMPANY_NAME}</p>
                <p>Questions? Contact ${SUPPORT_EMAIL}</p>
            </div>
        </div>
    </body>
    </html>
  
  password-reset.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; background-color: #f4f4f4; }
            .container { max-width: 600px; margin: 0 auto; background: white; padding: 20px; }
            .header { background: ${PRIMARY_COLOR}; color: white; padding: 20px; text-align: center; }
            .content { padding: 20px; }
            .button { background: ${PRIMARY_COLOR}; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; display: inline-block; }
            .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>${COMPANY_NAME}</h1>
            </div>
            <div class="content">
                <h2>Password Reset Request</h2>
                <p>We received a request to reset your password.</p>
                <p>Click the button below to create a new password:</p>
                <p style="text-align: center; margin: 30px 0;">
                    <a href="{{RESET_LINK}}" class="button">Reset Password</a>
                </p>
                <p style="color: #666; font-size: 14px;">If you didn't request this, please ignore this email.</p>
            </div>
            <div class="footer">
                <p>© 2025 ${COMPANY_NAME}</p>
                <p>Questions? Contact ${SUPPORT_EMAIL}</p>
            </div>
        </div>
    </body>
    </html>
EOF

echo -e "${GREEN}✅ Email templates customized${NC}"

#=============================================================================
# FINAL SUMMARY
#=============================================================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Custom Branding Applied! ✅           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🎨 Branding Configuration:${NC}"
echo "  Company: ${COMPANY_NAME}"
echo "  Domain: ${COMPANY_DOMAIN}"
echo "  Support: ${SUPPORT_EMAIL}"
echo "  Color: ${PRIMARY_COLOR}"
echo ""
echo -e "${CYAN}✅ Customized Services:${NC}"
echo "  🔐 Keycloak - Custom login theme"
echo "  📊 Grafana - Custom dashboard branding"
echo "  🦊 GitLab - Email and sign-in customization"
echo "  💬 Mattermost - Team and email settings"
echo "  📁 Nextcloud - Theme and colors"
echo "  🌐 Landing Page - Full company branding"
echo "  📧 Email Templates - Welcome and password reset"
echo ""
echo -e "${YELLOW}🔄 Services are restarting to apply changes...${NC}"
echo ""
echo -e "${GREEN}Preview your branded platform at: https://${COMPANY_DOMAIN}${NC}"
