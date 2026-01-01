#!/usr/bin/env bash
set -euo pipefail

MANIFEST_PATH="${1:-${K8S_MANIFEST_PATH:-}}"
KUBECONFIG_PATH="${REMOTE_KUBECONFIG:-~/.kube/config}"

if [[ -z "$MANIFEST_PATH" ]]; then
  echo "Usage: $0 <manifest_path> (or set K8S_MANIFEST_PATH)" >&2
  exit 1
fi

if [[ ! -d "$MANIFEST_PATH" && ! -f "$MANIFEST_PATH" ]]; then
  echo "Manifest path not found: $MANIFEST_PATH" >&2
  exit 1
fi

echo "Applying manifests from $MANIFEST_PATH"
KUBECONFIG="$KUBECONFIG_PATH" kubectl apply -f "$MANIFEST_PATH"
