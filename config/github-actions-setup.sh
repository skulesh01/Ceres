#!/bin/bash
# GitHub Actions workflow for automated deployments via ArgoCD

cat > .github/workflows/deploy.yaml <<'EOF'
name: GitOps Deploy

on:
  push:
    branches: [main]
    paths:
      - 'overlays/production/**'
      - '.github/workflows/deploy.yaml'
  workflow_dispatch:

env:
  ARGOCD_SERVER: argocd.example.com
  ARGOCD_INSECURE: true

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Validate YAML
      run: |
        sudo apt-get install -y yamllint
        yamllint overlays/production/
    
    - name: Validate Kustomize
      run: |
        curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
        ./kustomize build overlays/production > /dev/null
    
    - name: Dry-run manifests
      run: |
        ./kustomize build overlays/production | \
          kubectl apply --dry-run=client -f - || exit 1

  deploy:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    needs: validate
    steps:
    - uses: actions/checkout@v3
    
    - name: ArgoCD sync
      run: |
        argocd app sync ceres-apps \
          --server $ARGOCD_SERVER \
          --auth-token ${{ secrets.ARGOCD_TOKEN }} \
          --insecure
    
    - name: Wait for sync
      run: |
        for i in {1..60}; do
          status=$(argocd app get ceres-apps \
            --server $ARGOCD_SERVER \
            --auth-token ${{ secrets.ARGOCD_TOKEN }} \
            --insecure \
            -o json | jq -r '.status.operationState.phase')
          if [ "$status" == "Succeeded" ]; then
            echo "✓ Deployment succeeded"
            exit 0
          fi
          sleep 5
        done
        exit 1
    
    - name: Notify
      if: failure()
      run: |
        curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
          -H 'Content-Type: application/json' \
          -d '{"text":"❌ Deployment failed for ceres-apps"}'
EOF

echo "✓ GitHub Actions workflow created at .github/workflows/deploy.yaml"
