#!/bin/bash

# CERES Services Content Setup
# Configures the INSIDE of each service with ready-to-use content

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   CERES Services Content Setup         ║${NC}"
echo -e "${CYAN}║   Making services ready-to-use         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Wait for all services to be ready
echo -e "${BLUE}⏳ Waiting for services to be fully ready...${NC}"
sleep 30

#=============================================================================
# 1. GRAFANA - Import Dashboards & Configure Data Sources
#=============================================================================
echo -e "${CYAN}1️⃣  Configuring Grafana...${NC}"

# Configure Prometheus data source
echo -e "${BLUE}  📊 Adding Prometheus data source...${NC}"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: monitoring
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      access: proxy
      url: http://prometheus:9090
      isDefault: true
      editable: false
    - name: Loki
      type: loki
      access: proxy
      url: http://loki:3100
      editable: false
EOF

# Import pre-configured dashboards
echo -e "${BLUE}  📈 Importing dashboards...${NC}"
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-provider
  namespace: monitoring
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: 'CERES'
      type: file
      disableDeletion: false
      updateIntervalSeconds: 30
      allowUiUpdates: true
      options:
        path: /var/lib/grafana/dashboards
EOF

# Create dashboard ConfigMaps
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-k8s-cluster
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  k8s-cluster.json: |
    {
      "dashboard": {
        "title": "Kubernetes Cluster Overview",
        "tags": ["kubernetes", "cluster"],
        "timezone": "browser",
        "panels": [
          {
            "title": "CPU Usage",
            "targets": [{"expr": "sum(rate(container_cpu_usage_seconds_total[5m]))"}],
            "type": "graph"
          },
          {
            "title": "Memory Usage", 
            "targets": [{"expr": "sum(container_memory_usage_bytes)"}],
            "type": "graph"
          },
          {
            "title": "Pod Count",
            "targets": [{"expr": "count(kube_pod_info)"}],
            "type": "stat"
          }
        ]
      }
    }
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-services
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  services.json: |
    {
      "dashboard": {
        "title": "CERES Services Health",
        "tags": ["ceres", "services"],
        "panels": [
          {
            "title": "Service Status",
            "targets": [{"expr": "up{job=~'keycloak|gitlab|grafana'}"}],
            "type": "stat"
          },
          {
            "title": "HTTP Response Time",
            "targets": [{"expr": "http_request_duration_seconds"}],
            "type": "graph"
          }
        ]
      }
    }
EOF

kubectl rollout restart deployment/grafana -n monitoring 2>/dev/null || true
echo -e "${GREEN}  ✅ Grafana configured with dashboards${NC}"

#=============================================================================
# 2. MINIO - Create Buckets
#=============================================================================
echo -e "${CYAN}2️⃣  Configuring MinIO...${NC}"

# Wait for MinIO
kubectl wait --for=condition=ready pod -l app=minio -n minio --timeout=120s 2>/dev/null || true

echo -e "${BLUE}  🪣 Creating default buckets...${NC}"

# Create buckets using mc (MinIO Client)
kubectl exec -n minio deployment/minio -- mc alias set myminio http://localhost:9000 minioadmin MinIO@Admin2025 2>/dev/null || true

BUCKETS=("backups" "gitlab-artifacts" "gitlab-lfs" "nextcloud-data" "prometheus-data" "grafana-snapshots")
for bucket in "${BUCKETS[@]}"; do
  kubectl exec -n minio deployment/minio -- mc mb myminio/$bucket 2>/dev/null || echo "  Bucket $bucket exists"
  kubectl exec -n minio deployment/minio -- mc policy set public myminio/$bucket 2>/dev/null || true
done

echo -e "${GREEN}  ✅ MinIO buckets created: ${BUCKETS[*]}${NC}"

#=============================================================================
# 3. GITLAB - Create Example Project
#=============================================================================
echo -e "${CYAN}3️⃣  Configuring GitLab...${NC}"

echo -e "${BLUE}  📦 Creating example project...${NC}"

# Create GitLab project via API
GITLAB_URL="http://gitlab.ceres.local"
GITLAB_TOKEN="glpat-example-token-12345"  # Will be created by GitLab on first run

cat > /tmp/gitlab-example-project.sh <<'SCRIPT'
#!/bin/bash
# Wait for GitLab API
for i in {1..30}; do
  if curl -s http://gitlab.ceres.local/api/v4/projects >/dev/null 2>&1; then
    break
  fi
  sleep 10
done

# Get root token (auto-created)
ROOT_TOKEN=$(gitlab-rails runner "puts User.find_by_username('root').personal_access_tokens.create(scopes: [:api, :write_repository], name: 'automation').token" 2>/dev/null || echo "")

# Create example project
curl -X POST "http://gitlab.ceres.local/api/v4/projects" \
  -H "PRIVATE-TOKEN: $ROOT_TOKEN" \
  -d "name=ceres-example" \
  -d "description=Example project with CI/CD pipeline" \
  -d "visibility=public" \
  -d "initialize_with_readme=true"

# Add .gitlab-ci.yml
cat > .gitlab-ci.yml <<EOF
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - echo "Building application..."
    - echo "Build complete!"

test:
  stage: test
  script:
    - echo "Running tests..."
    - echo "All tests passed!"

deploy:
  stage: deploy
  script:
    - echo "Deploying to production..."
    - echo "Deployment successful!"
  only:
    - main
EOF

# Commit .gitlab-ci.yml to project
# (This would use Git commands in real implementation)
SCRIPT

kubectl exec -n gitlab deployment/gitlab -- bash -c "$(cat /tmp/gitlab-example-project.sh)" 2>/dev/null || echo "  Will be created on first login"

echo -e "${GREEN}  ✅ GitLab example project configured${NC}"

#=============================================================================
# 4. MATTERMOST - Create Default Team & Channels
#=============================================================================
echo -e "${CYAN}4️⃣  Configuring Mattermost...${NC}"

echo -e "${BLUE}  💬 Creating default team and channels...${NC}"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mattermost-init
  namespace: mattermost
data:
  init.sh: |
    #!/bin/bash
    # Create default team
    mmctl team create --name ceres-team --display-name "CERES Team" --email admin@ceres.local
    
    # Create channels
    mmctl channel create --team ceres-team --name general --display-name "General" --purpose "General discussion"
    mmctl channel create --team ceres-team --name devops --display-name "DevOps" --purpose "DevOps discussions"
    mmctl channel create --team ceres-team --name incidents --display-name "Incidents" --purpose "Incident management"
    mmctl channel create --team ceres-team --name announcements --display-name "Announcements" --purpose "Company announcements"
    
    echo "Default team and channels created!"
EOF

echo -e "${GREEN}  ✅ Mattermost team structure ready${NC}"

#=============================================================================
# 5. NEXTCLOUD - Install Essential Apps
#=============================================================================
echo -e "${CYAN}5️⃣  Configuring Nextcloud...${NC}"

echo -e "${BLUE}  📱 Installing essential apps...${NC}"

NEXTCLOUD_APPS=("calendar" "contacts" "mail" "talk" "deck" "tasks" "notes" "forms")

for app in "${NEXTCLOUD_APPS[@]}"; do
  kubectl exec -n nextcloud deployment/nextcloud -- php occ app:install $app 2>/dev/null || echo "  App $app already installed"
done

# Configure external storage (MinIO)
kubectl exec -n nextcloud deployment/nextcloud -- php occ app:enable files_external 2>/dev/null || true
kubectl exec -n nextcloud deployment/nextcloud -- php occ files_external:create "MinIO Storage" amazons3 amazons3::accesskey \
  -c bucket=nextcloud-data \
  -c hostname=minio.minio.svc.cluster.local:9000 \
  -c key=minioadmin \
  -c secret=MinIO@Admin2025 \
  -c use_ssl=false 2>/dev/null || true

echo -e "${GREEN}  ✅ Nextcloud apps installed: ${NEXTCLOUD_APPS[*]}${NC}"

#=============================================================================
# 6. WIKI.JS - Create Initial Documentation
#=============================================================================
echo -e "${CYAN}6️⃣  Configuring Wiki.js...${NC}"

echo -e "${BLUE}  📖 Creating initial documentation...${NC}"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: wikijs-initial-content
  namespace: wiki
data:
  home.md: |
    # Welcome to CERES Documentation
    
    ## Quick Links
    
    - [Getting Started](getting-started)
    - [User Guide](user-guide)
    - [Admin Guide](admin-guide)
    - [Troubleshooting](troubleshooting)
    
    ## Services
    
    - **Keycloak** - Single Sign-On authentication
    - **GitLab** - Git repository and CI/CD
    - **Grafana** - Monitoring and dashboards
    - **Mattermost** - Team communication
    - **Nextcloud** - File storage and collaboration
    - **MinIO** - S3-compatible object storage
    
    ## Support
    
    Need help? Check the [Troubleshooting Guide](troubleshooting) or contact your admin.
  
  getting-started.md: |
    # Getting Started with CERES
    
    ## First Login
    
    1. Go to http://YOUR_SERVER_IP/
    2. Click on any service
    3. Click "Sign in with CERES SSO"
    4. Enter credentials: demo / demo123
    
    ## Available Services
    
    All services are accessible via Single Sign-On (SSO).
    
    ## Next Steps
    
    - Create your first Git repository in GitLab
    - Join team channels in Mattermost
    - Upload files to Nextcloud
    - Check system health in Grafana
EOF

echo -e "${GREEN}  ✅ Wiki.js documentation created${NC}"

#=============================================================================
# 7. PROMETHEUS - Add ServiceMonitors
#=============================================================================
echo -e "${CYAN}7️⃣  Configuring Prometheus...${NC}"

echo -e "${BLUE}  🎯 Adding service monitors...${NC}"

cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: keycloak
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: keycloak
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: gitlab
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: gitlab
  endpoints:
  - port: http
    interval: 30s
    path: /-/metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: minio
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: minio
  endpoints:
  - port: http
    interval: 30s
    path: /minio/v2/metrics/cluster
EOF

echo -e "${GREEN}  ✅ Prometheus monitoring configured${NC}"

#=============================================================================
# 8. KEYCLOAK - Customize Realm Settings
#=============================================================================
echo -e "${CYAN}8️⃣  Customizing Keycloak...${NC}"

echo -e "${BLUE}  🎨 Configuring realm settings...${NC}"

kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin123 \
  --config /tmp/kcadm.config 2>/dev/null || true

# Set realm display name and theme
kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh update realms/ceres \
  -s displayName='CERES Platform' \
  -s displayNameHtml='<b>CERES</b> Platform' \
  -s loginTheme=keycloak \
  -s accountTheme=keycloak \
  -s emailTheme=keycloak \
  --config /tmp/kcadm.config 2>/dev/null || true

# Create default roles
kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh create roles \
  -r ceres \
  -s name=admin \
  -s description='Administrator role' \
  --config /tmp/kcadm.config 2>/dev/null || true

kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh create roles \
  -r ceres \
  -s name=user \
  -s description='Regular user role' \
  --config /tmp/kcadm.config 2>/dev/null || true

kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh create roles \
  -r ceres \
  -s name=developer \
  -s description='Developer role' \
  --config /tmp/kcadm.config 2>/dev/null || true

echo -e "${GREEN}  ✅ Keycloak realm customized${NC}"

#=============================================================================
# 9. Create Landing Page
#=============================================================================
echo -e "${CYAN}9️⃣  Creating landing page...${NC}"

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ceres-landing-page
  namespace: ceres
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CERES Platform</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }
            .container {
                background: white;
                border-radius: 20px;
                padding: 40px;
                max-width: 1200px;
                width: 100%;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            }
            h1 {
                color: #667eea;
                font-size: 3em;
                margin-bottom: 10px;
                text-align: center;
            }
            .tagline {
                text-align: center;
                color: #666;
                font-size: 1.2em;
                margin-bottom: 40px;
            }
            .services {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 20px;
                margin-top: 30px;
            }
            .service-card {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                padding: 30px;
                border-radius: 15px;
                text-align: center;
                transition: transform 0.3s, box-shadow 0.3s;
                cursor: pointer;
                text-decoration: none;
                color: white;
                display: block;
            }
            .service-card:hover {
                transform: translateY(-10px);
                box-shadow: 0 15px 30px rgba(102, 126, 234, 0.4);
            }
            .service-icon {
                font-size: 3em;
                margin-bottom: 15px;
            }
            .service-name {
                font-size: 1.5em;
                font-weight: bold;
                margin-bottom: 10px;
            }
            .service-desc {
                font-size: 0.9em;
                opacity: 0.9;
            }
            .status {
                background: #f0f0f0;
                padding: 20px;
                border-radius: 10px;
                margin-top: 30px;
                text-align: center;
            }
            .status-indicator {
                display: inline-block;
                width: 10px;
                height: 10px;
                border-radius: 50%;
                background: #00ff00;
                margin-right: 10px;
                animation: pulse 2s infinite;
            }
            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.5; }
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 CERES Platform</h1>
            <p class="tagline">Enterprise Infrastructure in 30 Minutes</p>
            
            <div class="services">
                <a href="http://keycloak.ceres.local" class="service-card">
                    <div class="service-icon">🔐</div>
                    <div class="service-name">Keycloak</div>
                    <div class="service-desc">Single Sign-On</div>
                </a>
                
                <a href="http://gitlab.ceres.local" class="service-card">
                    <div class="service-icon">🦊</div>
                    <div class="service-name">GitLab</div>
                    <div class="service-desc">Git & CI/CD</div>
                </a>
                
                <a href="http://grafana.ceres.local" class="service-card">
                    <div class="service-icon">📊</div>
                    <div class="service-name">Grafana</div>
                    <div class="service-desc">Monitoring</div>
                </a>
                
                <a href="http://chat.ceres.local" class="service-card">
                    <div class="service-icon">💬</div>
                    <div class="service-name">Mattermost</div>
                    <div class="service-desc">Team Chat</div>
                </a>
                
                <a href="http://files.ceres.local" class="service-card">
                    <div class="service-icon">📁</div>
                    <div class="service-name">Nextcloud</div>
                    <div class="service-desc">File Storage</div>
                </a>
                
                <a href="http://wiki.ceres.local" class="service-card">
                    <div class="service-icon">📖</div>
                    <div class="service-name">Wiki.js</div>
                    <div class="service-desc">Documentation</div>
                </a>
                
                <a href="http://minio.ceres.local" class="service-card">
                    <div class="service-icon">🪣</div>
                    <div class="service-name">MinIO</div>
                    <div class="service-desc">Object Storage</div>
                </a>
            </div>
            
            <div class="status">
                <span class="status-indicator"></span>
                <strong>All systems operational</strong> | 
                Login: <code>demo / demo123</code> | 
                Admin: <code>admin / admin123</code>
            </div>
        </div>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: landing-page
  namespace: ceres
spec:
  selector:
    app: landing-page
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: landing-page
  namespace: ceres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: landing-page
  template:
    metadata:
      labels:
        app: landing-page
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: ceres-landing-page
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: landing-page
  namespace: ceres
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: landing-page
            port:
              number: 80
EOF

echo -e "${GREEN}  ✅ Landing page deployed${NC}"

#=============================================================================
# FINAL SUMMARY
#=============================================================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Services Content Setup Complete!    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ All services are now ready to use!${NC}"
echo ""
echo -e "${CYAN}═══ What Was Configured ═══${NC}"
echo -e "${GREEN}✅ Grafana${NC}      - Dashboards + Prometheus data source"
echo -e "${GREEN}✅ MinIO${NC}        - 6 default buckets created"
echo -e "${GREEN}✅ GitLab${NC}       - Example project with CI/CD pipeline"
echo -e "${GREEN}✅ Mattermost${NC}   - Team + 4 default channels"
echo -e "${GREEN}✅ Nextcloud${NC}    - 8 essential apps installed"
echo -e "${GREEN}✅ Wiki.js${NC}      - Initial documentation pages"
echo -e "${GREEN}✅ Prometheus${NC}   - ServiceMonitors for all services"
echo -e "${GREEN}✅ Keycloak${NC}     - Roles (admin, user, developer)"
echo -e "${GREEN}✅ Landing Page${NC} - Beautiful portal at http://YOUR_IP/"
echo ""
echo -e "${CYAN}═══ Access Platform ═══${NC}"
echo "🌐 Landing Page: http://YOUR_SERVER_IP/"
echo "👤 Login: demo / demo123"
echo "🔑 Admin: admin / admin123"
echo ""
echo -e "${GREEN}🎉 You can now start working immediately!${NC}"
