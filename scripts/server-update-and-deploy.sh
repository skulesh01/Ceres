#!/usr/bin/env bash
set -euo pipefail

# Load instance-wide configuration (SMTP, mail mode, etc) if present.
# This keeps updates reproducible and removes the need to manually export env vars.
if [ -f "/etc/ceres/ceres.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "/etc/ceres/ceres.env"
  set +a
fi

REPO_URL="${REPO_URL:-https://github.com/skulesh01/Ceres.git}"
REPO_DIR="${REPO_DIR:-/root/Ceres}"

echo "[CERES] update+deploy"
echo "  repo: ${REPO_URL}"
echo "  dir:  ${REPO_DIR}"

if [ ! -d "${REPO_DIR}/.git" ]; then
  echo "[CERES] cloning repo..."
  mkdir -p "${REPO_DIR}"
  git clone "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"

echo "[CERES] pulling latest..."
git fetch --all --prune
# Default: pull current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull --ff-only origin "${BRANCH}"

echo "[CERES] running deploy (reconcile)..."
# Make path resolution deterministic
export CERES_ROOT="${REPO_DIR}"

echo "[CERES] bootstrapping Kubernetes secrets (if needed)..."
if [ -f "./scripts/bootstrap-secrets.sh" ]; then
  bash ./scripts/bootstrap-secrets.sh
else
  echo "[CERES] missing scripts/bootstrap-secrets.sh" >&2
  exit 1
fi

echo "[CERES] ensuring console/mail UI services..."
if [ -f "./scripts/install-ui.sh" ]; then
  # Ensure default layout matches systemd units
  export REPO_DIR="${REPO_DIR}"
  export CERES_ROOT="${REPO_DIR}"
  bash ./scripts/install-ui.sh || echo "[CERES] UI install skipped/failed (non-fatal)"
fi

if [ -x "./bin/ceres" ]; then
  ./bin/ceres deploy --cloud proxmox --environment prod --namespace ceres
else
  # Fallback: run from source (requires Go on server)
  if command -v go >/dev/null 2>&1; then
    go run ./cmd/ceres/main.go deploy --cloud proxmox --environment prod --namespace ceres
  elif [ -x "/usr/local/go/bin/go" ]; then
    /usr/local/go/bin/go run ./cmd/ceres/main.go deploy --cloud proxmox --environment prod --namespace ceres
  else
    echo "Go not found and ./bin/ceres отсутствует. Установи Go или положи собранный бинарь в ./bin/ceres" >&2
    exit 1
  fi
fi

# Optional: configure Keycloak SMTP if external SMTP is provided.
# This is safe for both internal/external mail setups; it will no-op if vars are missing.
if [ -f "./scripts/configure-keycloak-smtp.sh" ] && [ -n "${CERES_SMTP_HOST:-}" ]; then
  bash ./scripts/configure-keycloak-smtp.sh || echo "[CERES] Keycloak SMTP config skipped/failed (non-fatal)" >&2
fi

# Optional: update Proxmox Notes/Description with current service URLs.
# This helps keep Proxmox inventory in sync after domain changes.
maybe_bool() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y) return 0 ;;
    0|false|FALSE|no|NO|n|N|"") return 1 ;;
    *) return 1 ;;
  esac
}

CERES_PROXMOX_NOTES_APPLY="${CERES_PROXMOX_NOTES_APPLY:-false}"
CERES_PROXMOX_NOTES_UPDATE="${CERES_PROXMOX_NOTES_UPDATE:-auto}"

if maybe_bool "${CERES_PROXMOX_NOTES_APPLY}"; then
  if [ -f "./deployment/gitops/proxmox-notes-updater.yaml" ]; then
    echo "[CERES] applying Proxmox notes updater resources (optional)..."
    kubectl apply -f ./deployment/gitops/proxmox-notes-updater.yaml || echo "[CERES] Proxmox notes updater apply failed (non-fatal)" >&2
  else
    echo "[CERES] ./deployment/gitops/proxmox-notes-updater.yaml not found; skipping apply" >&2
  fi
fi

run_proxmox_notes_update=false
case "${CERES_PROXMOX_NOTES_UPDATE}" in
  auto)
    # Auto: run only if resources appear to be configured.
    run_proxmox_notes_update=true
    ;;
  true|TRUE|1|yes|YES)
    run_proxmox_notes_update=true
    ;;
  false|FALSE|0|no|NO|"")
    run_proxmox_notes_update=false
    ;;
  *)
    echo "[CERES] Unknown CERES_PROXMOX_NOTES_UPDATE='${CERES_PROXMOX_NOTES_UPDATE}', expected auto|true|false; skipping" >&2
    run_proxmox_notes_update=false
    ;;
esac

if [ "${run_proxmox_notes_update}" = true ]; then
  if kubectl -n ceres-management get cronjob proxmox-notes-updater >/dev/null 2>&1; then
    # Check whether token secret looks configured; avoid noisy failures in auto mode.
    token_b64=$(kubectl -n ceres-management get secret proxmox-notes-updater -o jsonpath='{.data.api_token_secret}' 2>/dev/null || true)
    token=""
    if [ -n "${token_b64}" ]; then
      token=$(echo "${token_b64}" | base64 -d 2>/dev/null || true)
    fi

    if [ "${CERES_PROXMOX_NOTES_UPDATE}" = "auto" ] && { [ -z "${token}" ] || [ "${token}" = "CHANGE_ME" ]; }; then
      echo "[CERES] Proxmox notes updater detected but not configured (api_token_secret missing/CHANGE_ME); skipping" >&2
    else
      job="proxmox-notes-updater-manual-$(date +%Y%m%d%H%M%S)"
      echo "[CERES] running Proxmox notes update job: ${job}"
      kubectl -n ceres-management create job --from=cronjob/proxmox-notes-updater "${job}" >/dev/null 2>&1 || true
      if kubectl -n ceres-management wait --for=condition=complete "job/${job}" --timeout=180s >/dev/null 2>&1; then
        echo "[CERES] Proxmox notes updated"
      else
        echo "[CERES] Proxmox notes update did not complete in time (non-fatal); logs:" >&2
        kubectl -n ceres-management logs "job/${job}" 2>/dev/null || true
      fi
    fi
  else
    echo "[CERES] Proxmox notes updater CronJob not found; skipping" >&2
  fi
fi

echo "[CERES] done"
