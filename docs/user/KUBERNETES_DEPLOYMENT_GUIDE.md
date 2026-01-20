# CERES v3.0.0 - Kubernetes Deployment Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                  TERRAFORM (IaC)                        │
│  AWS/Azure/GCP/Proxmox Infrastructure Provisioning     │
└─────────────────────┬───────────────────────────────────┘
                      │
        ┌─────────────┴──────────────┬────────────────┐
        │                            │                │
    ┌───▼──┐                     ┌───▼──┐        ┌───▼──┐
    │ EKS  │                     │ AKS  │        │ GKE  │
    │(AWS) │                     │(Azure)        │(GCP) │
    └───┬──┘                     └───┬──┘        └───┬──┘
        │                            │                │
        └─────────────┬──────────────┴────────────────┘
                      │
        ┌─────────────▼──────────────────┐
        │   HELM CHARTS (Deployment)     │
        │  20+ services with defaults    │
        └─────────────┬──────────────────┘
                      │
        ┌─────────────▼──────────────────┐
        │    FLUX CD (GitOps)            │
        │  Automatic reconciliation      │
        └────────────────────────────────┘
```

## Phase 1: Infrastructure Setup

### 1.1 Terraform Configuration

```bash
# Structure
config/terraform/
├── versions.tf           # Provider versions & backend
├── variables.tf          # 50+ configurable variables
├── outputs.tf            # Cluster endpoints & credentials
├── main_aws.tf           # AWS infrastructure (EKS, RDS, ElastiCache)
├── main_azure.tf         # Azure infrastructure (AKS, Database, Redis)
├── main_gcp.tf           # GCP infrastructure (GKE, Cloud SQL, Memorystore)
└── terraform.tfvars      # Your custom values (git-ignored)
```

### 1.2 Deploy Infrastructure

#### AWS Deployment
```bash
cd config/terraform

# Initialize
terraform init

# Plan
terraform plan \
  -var="aws_enabled=true" \
  -var="aws_region=eu-west-1" \
  -var="aws_node_count=3" \
  -var="environment=prod"

# Apply
terraform apply -auto-approve

# Get kubeconfig
aws eks update-kubeconfig \
  --name ceres-prod \
  --region eu-west-1
```

#### Azure Deployment
```bash
# Set Azure credentials
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"

# Deploy
terraform apply \
  -var="azure_enabled=true" \
  -var="azure_location=westeurope" \
  -auto-approve

# Get kubeconfig
az aks get-credentials \
  --resource-group ceres-rg \
  --name ceres-prod
```

#### GCP Deployment
```bash
# Set GCP project
export GOOGLE_PROJECT="your-project-id"

# Deploy
terraform apply \
  -var="gcp_enabled=true" \
  -var="gcp_project_id=$GOOGLE_PROJECT" \
  -auto-approve

# Get kubeconfig
gcloud container clusters get-credentials ceres-prod \
  --region europe-west1
```

### 1.3 Verify Cluster

```bash
# Check nodes
kubectl get nodes
# Output: 3 nodes (or more) with Ready status

# Check cluster version
kubectl version --short

# Check cluster info
kubectl cluster-info
```

---

## Phase 2: Helm Chart Deployment

### 2.1 Add Helm Repositories

```bash
# Bitnami (PostgreSQL, Redis)
helm repo add bitnami https://charts.bitnami.com/bitnami

# Prometheus Community (Kube-Prometheus-Stack)
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

# Grafana
helm repo add grafana https://grafana.github.io/helm-charts

# Jetstack (Cert-Manager)
helm repo add jetstack https://charts.jetstack.io

# Ingress-Nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Update all repos
helm repo update
```

### 2.2 Customize Values

Create `helm/ceres/values-prod.yaml`:

```yaml
global:
  domain: your-domain.com
  environment: production

postgresql:
  auth:
    password: YOUR_SECURE_PASSWORD
  primary:
    persistence:
      size: 200Gi  # Adjust for your needs

redis:
  auth:
    password: YOUR_SECURE_PASSWORD

keycloak:
  auth:
    adminPassword: YOUR_SECURE_PASSWORD

gitlab:
  initialRootPassword: YOUR_SECURE_PASSWORD

# ... other services
```

### 2.3 Deploy CERES Helm Chart

```bash
# Create namespace
kubectl create namespace ceres

# Install
helm install ceres ./helm/ceres \
  -n ceres \
  -f helm/ceres/values-prod.yaml

# Wait for deployment
kubectl wait --for=condition=ready pod \
  -l app=postgresql \
  -n ceres \
  --timeout=300s

kubectl wait --for=condition=ready pod \
  -l app=redis \
  -n ceres \
  --timeout=300s

# Verify deployment
helm list -n ceres
kubectl get pods -n ceres
```

---

## Phase 3: Flux CD GitOps Setup

### 3.1 Install Flux

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Check installation
flux version

# Pre-flight check
flux check --pre
```

### 3.2 Bootstrap Flux (GitHub)

```bash
# Generate GitHub token: https://github.com/settings/tokens
export GITHUB_TOKEN=your_token
export GITHUB_USER=your_username
export GITHUB_REPO=Ceres

# Bootstrap Flux
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repo=$GITHUB_REPO \
  --path=config/flux \
  --personal \
  --private=false
```

### 3.3 Bootstrap Flux (GitLab)

```bash
# Generate GitLab token
export GITLAB_TOKEN=your_token
export GITLAB_HOST=gitlab.com
export GITLAB_USER=your_username
export GITLAB_REPO=ceres

# Bootstrap Flux
flux bootstrap gitlab \
  --owner=$GITLAB_USER \
  --repository=$GITLAB_REPO \
  --hostname=$GITLAB_HOST \
  --path=config/flux \
  --personal
```

### 3.4 Verify Flux Installation

```bash
# Check Flux namespace
kubectl get ns flux-system

# Check Flux components
kubectl get deployment -n flux-system

# Reconcile sources
flux reconcile source git
flux reconcile source helm

# Check HelmReleases
kubectl get helmrelease -n ceres

# View Flux logs
flux logs --all-namespaces --follow
```

---

## Phase 4: Network & TLS Setup

### 4.1 Install Cert-Manager

```bash
# Create namespace
kubectl create namespace cert-manager

# Install Cert-Manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --set installCRDs=true
```

### 4.2 Create ClusterIssuer

```bash
kubectl apply -f config/kubernetes/cert-issuer.yaml
```

### 4.3 Install Ingress-Nginx

```bash
kubectl create namespace ingress-nginx

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx
```

### 4.4 Apply Ingress Configuration

```bash
kubectl apply -f config/kubernetes/ingress.yaml

# Verify
kubectl get ingress -n ceres
kubectl describe ingress ceres-ingress -n ceres
```

### 4.5 Get LoadBalancer IP

```bash
kubectl get svc -n ingress-nginx

# AWS: Note the EXTERNAL-IP (it's an ELB address)
# Azure: Note the EXTERNAL-IP (it's an Azure LB address)
# GCP: Note the EXTERNAL-IP (it's a GCP LB address)

# Create DNS records pointing to this IP
```

---

## Phase 5: Verification & Access

### 5.1 Check All Pods

```bash
# All services
kubectl get pods -n ceres

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# postgresql-0                  1/1     Running   0          5m
# redis-0                        1/1     Running   0          5m
# keycloak-0                    1/1     Running   0          3m
# gitlab-0                      1/1     Running   0          2m
# nextcloud-0                   1/1     Running   0          2m
# mattermost-0                  1/1     Running   0          2m
# ...
```

### 5.2 Check Services

```bash
kubectl get svc -n ceres

# All services should have ClusterIP or LoadBalancer assigned
```

### 5.3 Access Services

Once Ingress is ready and DNS is configured:

- **Keycloak**: https://keycloak.your-domain.com
- **GitLab**: https://gitlab.your-domain.com
- **Nextcloud**: https://nextcloud.your-domain.com
- **Mattermost**: https://mattermost.your-domain.com
- **Redmine**: https://redmine.your-domain.com
- **Wiki.js**: https://wiki.your-domain.com
- **Grafana**: https://grafana.your-domain.com
- **Prometheus**: https://prometheus.your-domain.com
- **Alertmanager**: https://alertmanager.your-domain.com
- **Zulip**: https://zulip.your-domain.com
- **Mayan**: https://mayan.your-domain.com
- **OnlyOffice**: https://office.your-domain.com

### 5.4 Get Initial Credentials

```bash
# Get Keycloak admin credentials
kubectl get secret -n ceres ceres-secrets \
  -o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' | base64 -d

# Get PostgreSQL password
kubectl get secret -n ceres ceres-secrets \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

# Get GitLab root password
kubectl get secret -n ceres ceres-secrets \
  -o jsonpath='{.data.GITLAB_ROOT_PASSWORD}' | base64 -d
```

---

## Post-Deployment

### Backup Configuration

```bash
# Install Velero (backup tool)
wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz

# Configure S3 backend
velero backup-location create default \
  --provider aws \
  --bucket ceres-backups \
  --secret-file ./credentials-velero

# Enable daily backups
velero schedule create daily \
  --schedule="0 2 * * *" \
  --include-namespaces ceres
```

### Monitoring

```bash
# View Prometheus targets
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090

# View Grafana dashboards
kubectl port-forward -n ceres svc/grafana 3000:3000
# Open http://localhost:3000 (default: admin/changeme)
```

### Logs

```bash
# View logs for specific pod
kubectl logs -n ceres postgresql-0

# View logs with follow
kubectl logs -n ceres postgresql-0 -f

# View logs using Loki (if integrated with Grafana)
# Open Loki datasource in Grafana
```

### Scaling

```bash
# Scale PostgreSQL (if using StatefulSet)
kubectl scale statefulset postgresql -n ceres --replicas=3

# Scale Nextcloud replicas
kubectl scale deployment nextcloud -n ceres --replicas=3

# Scale Mattermost replicas
kubectl scale deployment mattermost -n ceres --replicas=3
```

---

## Troubleshooting

### Pod won't start

```bash
# Check pod status
kubectl describe pod postgresql-0 -n ceres

# Check logs
kubectl logs postgresql-0 -n ceres

# Check events
kubectl get events -n ceres --sort-by='.lastTimestamp'
```

### Storage issues

```bash
# Check PVCs
kubectl get pvc -n ceres

# Check PV status
kubectl get pv

# Check storage classes
kubectl get storageclass
```

### Network issues

```bash
# Check DNS resolution inside pod
kubectl run -it --rm debug --image=alpine --restart=Never -- nslookup postgresql.ceres.svc.cluster.local

# Test connectivity
kubectl exec -it postgresql-0 -n ceres -- telnet redis 6379
```

### Flux sync issues

```bash
# Check git repository status
kubectl get gitrepository -n flux-system

# Check helm repository status
kubectl get helmrepository -n flux-system

# Manually reconcile
flux reconcile source git ceres
flux reconcile kustomization ceres
```

---

## Cost Optimization

### AWS
- Use Spot instances for worker nodes (50% savings)
- Configure Karpenter for auto-scaling
- Use RDS automated backups instead of snapshots

### Azure
- Use Azure Spot VMs for worker nodes
- Enable reserved instances for stable workloads
- Use Azure Backup for managed backups

### GCP
- Use Committed Use Discounts (CUD)
- Configure Workload Identity for pod-to-GCP service authentication
- Use Container Registry instead of external registries

---

## Security Best Practices

### Network Policies
```bash
# Apply network policies to restrict pod-to-pod communication
kubectl apply -f config/kubernetes/network-policies.yaml
```

### RBAC
```bash
# Create limited service accounts for each application
kubectl apply -f config/kubernetes/rbac.yaml
```

### Pod Security
```bash
# Apply Pod Security Standards
kubectl label namespace ceres \
  pod-security.kubernetes.io/enforce=restricted
```

### Secrets Management
```bash
# Use external secrets (AWS Secrets Manager / Azure Key Vault)
# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system
```

---

## Maintenance

### Updates
```bash
# Update Helm charts
helm repo update
helm upgrade ceres ./helm/ceres -n ceres

# Update Flux
flux install --export | kubectl apply -f -
```

### Cleanup
```bash
# Remove old PVCs
kubectl delete pvc --all -n ceres

# Remove old backups
velero delete schedule daily
```

---

## Advanced Topics

- [Multi-cluster setup with Hub-Spoke architecture](./docs/multi-cluster.md)
- [Custom Helm Charts for your applications](./docs/custom-helm-charts.md)
- [GitLab CI integration with Flux](./docs/gitlab-ci-flux.md)
- [Disaster Recovery Plan](./docs/disaster-recovery.md)
