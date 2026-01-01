#!/bin/bash
# Create sealed secrets for production credentials

NAMESPACE="ceres"

# Check if kubeseal installed
if ! command -v kubeseal &> /dev/null; then
    echo "Installing kubeseal..."
    wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
    tar xzf kubeseal-0.24.0-linux-amd64.tar.gz
    sudo install -m 755 kubeseal /usr/local/bin/kubeseal
fi

# Function to create sealed secret
seal_secret() {
    local name=$1
    local key=$2
    local value=$3
    
    kubectl create secret generic $name \
        --from-literal=$key="$value" \
        -n $NAMESPACE \
        --dry-run=client \
        -o yaml | kubeseal -o yaml > ${name}-sealed.yaml
    
    echo "✓ Created sealed secret: ${name}-sealed.yaml"
}

# Create secrets (replace with actual values)
seal_secret "postgres-credentials" "password" "your-secure-password-here"
seal_secret "keycloak-credentials" "admin-password" "your-keycloak-admin-password"
seal_secret "github-credentials" "token" "your-github-token"
seal_secret "slack-webhook" "url" "https://hooks.slack.com/services/..."

echo ""
echo "Next steps:"
echo "1. Review the sealed secrets"
echo "2. Commit them to Git: git add *-sealed.yaml && git commit -m 'Add sealed secrets'"
echo "3. Apply to cluster: kubectl apply -f *-sealed.yaml"
