#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <run|last|secret> ..." >&2
  exit 1
fi

CMD=$1; shift
REPO="${GH_REPO:-}"
if [[ -z "$REPO" ]]; then
  echo "GH_REPO must be set (owner/repo)." >&2
  exit 1
fi

case "$CMD" in
  run)
    WF="${1:-}"; shift || true
    if [[ -z "$WF" ]]; then
      echo "run requires <workflow_file> [key=value ...]" >&2
      exit 1
    fi
    gh workflow run "$WF" "${@}" --repo "$REPO"
    ;;
  last)
    WF="${1:-}"; shift || true
    if [[ -z "$WF" ]]; then
      echo "last requires <workflow_file>" >&2
      exit 1
    fi
    gh run list --workflow "$WF" --limit 1 --repo "$REPO"
    ;;
  secret)
    KEY="${1:-}"; VAL="${2:-}"; shift 2 || true
    if [[ -z "$KEY" || -z "$VAL" ]]; then
      echo "secret requires <name> <value>" >&2
      exit 1
    fi
    gh secret set "$KEY" --body "$VAL" --repo "$REPO"
    ;;
  *)
    echo "Unknown command: $CMD" >&2
    exit 1
    ;;
 esac
