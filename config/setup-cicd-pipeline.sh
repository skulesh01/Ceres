#!/bin/bash
# Full GitOps CI/CD pipeline setup
# Integrates GitHub Actions + ArgoCD + Slack notifications

set -e

REPO="${1:-ceres-k8s-manifests}"
ORG="${2:-yourorg}"
SLACK_WEBHOOK="${3:-}"

echo "Setting up CI/CD pipeline for $ORG/$REPO"

# Clone repo
git clone https://github.com/$ORG/$REPO
cd $REPO

# Create GitHub Actions workflow
mkdir -p .github/workflows

cat > .github/workflows/deploy.yml <<'EOF'
name: Deploy to Kubernetes

on:
  push:
    branches: [main]
    paths:
      - 'overlays/production/**'
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Validate YAML
      run: |
        sudo apt-get install -y yamllint
        yamllint overlays/production/ || true
    
    - name: Setup Kustomize
      run: |
        curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
        sudo mv kustomize /usr/local/bin/
    
    - name: Build manifests
      run: |
        kustomize build overlays/production > manifests.yaml
    
    - name: Dry-run
      run: |
        kubectl apply --dry-run=client -f manifests.yaml || exit 1
    
    - name: Upload manifests
      uses: actions/upload-artifact@v3
      with:
        name: manifests
        path: manifests.yaml

  deploy:
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: validate
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup ArgoCD CLI
      run: |
        curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/v2.9.0/argocd-linux-amd64
        chmod +x argocd
        sudo mv argocd /usr/local/bin/
    
    - name: Trigger ArgoCD sync
      run: |
        argocd app sync ceres-apps \
          --server ${{ secrets.ARGOCD_SERVER }} \
          --auth-token ${{ secrets.ARGOCD_TOKEN }} \
          --insecure \
          --grpc-web
    
    - name: Check sync status
      run: |
        for i in {1..60}; do
          status=$(argocd app get ceres-apps \
            --server ${{ secrets.ARGOCD_SERVER }} \
            --auth-token ${{ secrets.ARGOCD_TOKEN }} \
            --insecure \
            --grpc-web \
            -o json | jq -r '.status.operationState.phase')
          if [ "$status" == "Succeeded" ]; then
            echo "✓ Deploy successful"
            exit 0
          fi
          sleep 2
        done
        exit 1
    
    - name: Slack notification
      if: always()
      uses: slackapi/slack-github-action@v1
      with:
        webhook-url: ${{ secrets.SLACK_WEBHOOK }}
        payload: |
          {
            "text": "${{ job.status == 'success' && '✅' || '❌' }} ${{ github.repository }} - ${{ github.ref }}",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Deploy ${{ job.status == 'success' && 'Succeeded' || 'Failed' }}*\nRepo: ${{ github.repository }}\nBranch: ${{ github.ref }}\nCommit: ${{ github.sha }}"
                }
              }
            ]
          }
EOF

# Create deploy action (for manual trigger)
mkdir -p .github/workflows

cat > .github/workflows/manual-deploy.yml <<'EOF'
name: Manual Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'production'
        type: choice
        options:
          - development
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to ${{ github.event.inputs.environment }}
      run: |
        echo "Deploying to ${{ github.event.inputs.environment }}"
        # Add your deployment logic here
EOF

git add .github/workflows/
git commit -m "Add GitHub Actions CI/CD pipeline"

echo "✓ GitHub Actions workflow added"
echo ""
echo "Repository secrets to set:"
echo "  - ARGOCD_SERVER: https://argocd.example.com"
echo "  - ARGOCD_TOKEN: (from 'argocd account generate-token')"
echo "  - SLACK_WEBHOOK: (from Slack app)"
echo ""
echo "Push changes:"
echo "  git push origin main"
