#!/bin/bash
set -euo pipefail

echo "=== Deploying Redmine to k3s ==="

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# If deployment/redmine.yaml still contains the placeholder ghcr.io/REPO_OWNER,
# resolve repo owner from git remote and substitute on the fly.
resolve_repo_owner() {
	local url owner
	url="$(git config --get remote.origin.url || true)"
	if [ -z "$url" ]; then
		echo ""; return 0
	fi

	# https://github.com/OWNER/REPO(.git)
	# git@github.com:OWNER/REPO(.git)
	owner="$(echo "$url" | sed -nE 's#^https?://github\.com/([^/]+)/.*#\1#p')"
	if [ -z "$owner" ]; then
		owner="$(echo "$url" | sed -nE 's#^git@github\.com:([^/]+)/.*#\1#p')"
	fi
	echo "$owner"
}

OWNER="$(resolve_repo_owner)"

if grep -q 'ghcr.io/REPO_OWNER/' deployment/redmine.yaml; then
	if [ -z "$OWNER" ]; then
		echo "ERROR: deployment/redmine.yaml contains ghcr.io/REPO_OWNER but remote.origin.url is not a GitHub URL." >&2
		echo "Either change the image field in deployment/redmine.yaml or set a GitHub remote." >&2
		exit 1
	fi
	echo "Using GHCR owner: $OWNER"
	sed "s#ghcr.io/REPO_OWNER/#ghcr.io/${OWNER}/#g" deployment/redmine.yaml | kubectl apply -f -
else
	kubectl apply -f deployment/redmine.yaml
fi

echo "Waiting for Redmine rollout..."
kubectl rollout status -n redmine deployment/redmine --timeout=300s

echo "Done."
