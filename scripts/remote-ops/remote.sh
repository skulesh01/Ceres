#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}" || true
ARG1="${2:-}" || true
ARG2="${3:-}" || true

REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-}"
REMOTE_PORT="${REMOTE_PORT:-22}"
SSH_KEY_PATH="${SSH_KEY_PATH:-}"
REMOTE_KUBECONFIG="${REMOTE_KUBECONFIG:-~/.kube/config}"

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <cmd|git-pull|upload|download|kubectl-apply> <arg1> [arg2]" >&2
  exit 1
fi

if [[ -z "$REMOTE_HOST" || -z "$REMOTE_USER" ]]; then
  echo "REMOTE_HOST and REMOTE_USER must be set (env or exported)." >&2
  exit 1
fi

ssh_opts=("-p" "$REMOTE_PORT" "-o" "StrictHostKeyChecking=accept-new")
if [[ -n "$SSH_KEY_PATH" ]]; then
  ssh_opts+=("-i" "$SSH_KEY_PATH")
fi

case "$ACTION" in
  cmd)
    if [[ -z "$ARG1" ]]; then
      echo "cmd requires a command to run" >&2
      exit 1
    fi
    ssh "${ssh_opts[@]}" "$REMOTE_USER@$REMOTE_HOST" "$ARG1"
    ;;
  git-pull)
    if [[ -z "$ARG1" ]]; then
      echo "git-pull requires a remote path" >&2
      exit 1
    fi
    ssh "${ssh_opts[@]}" "$REMOTE_USER@$REMOTE_HOST" "cd $ARG1 && git pull --ff-only"
    ;;
  upload)
    if [[ -z "$ARG1" || -z "$ARG2" ]]; then
      echo "upload requires <local_path> <remote_path>" >&2
      exit 1
    fi
    scp "${ssh_opts[@]}" "$ARG1" "$REMOTE_USER@$REMOTE_HOST:$ARG2"
    ;;
  download)
    if [[ -z "$ARG1" || -z "$ARG2" ]]; then
      echo "download requires <remote_path> <local_path>" >&2
      exit 1
    fi
    scp "${ssh_opts[@]}" "$REMOTE_USER@$REMOTE_HOST:$ARG1" "$ARG2"
    ;;
  kubectl-apply)
    if [[ -z "$ARG1" ]]; then
      echo "kubectl-apply requires <manifests_path>" >&2
      exit 1
    fi
    ssh "${ssh_opts[@]}" "$REMOTE_USER@$REMOTE_HOST" "KUBECONFIG=$REMOTE_KUBECONFIG kubectl apply -f $ARG1"
    ;;
  *)
    echo "Unsupported action: $ACTION" >&2
    exit 1
    ;;
esac
