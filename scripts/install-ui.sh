#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-/opt/ceres/Ceres}"
CERES_ROOT="${CERES_ROOT:-$REPO_DIR}"

HOST_IP="${CERES_UI_HOST_IP:-192.168.1.3}"
MAIL_FROM="${CERES_MAIL_FROM:-admin@ceres.local}"
VPN_ENDPOINT="${CERES_UI_VPN_ENDPOINT:-${CERES_VPN_ENDPOINT:-192.168.1.3}}"
VPN_PORT="${CERES_UI_VPN_PORT:-51820}"

SMTP_HOST="${CERES_SMTP_HOST:-}"
SMTP_PORT="${CERES_SMTP_PORT:-}"
SMTP_USER="${CERES_SMTP_USER:-}"
SMTP_PASS="${CERES_SMTP_PASS:-}"
SMTP_STARTTLS="${CERES_SMTP_STARTTLS:-}"
SMTP_TLS="${CERES_SMTP_TLS:-}"

BASIC_USER="${CERES_UI_BASIC_USER:-admin}"
BASIC_PASS="${CERES_UI_BASIC_PASS:-}"

# systemd services often run with HOME=/, which breaks kubectl's default kubeconfig discovery.
HOME_DIR="${HOME_DIR:-/root}"
KUBECONFIG_PATH="${KUBECONFIG:-}"
if [ -z "${KUBECONFIG_PATH}" ]; then
  if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
  elif [ -f "${HOME_DIR}/.kube/config" ]; then
    KUBECONFIG_PATH="${HOME_DIR}/.kube/config"
  fi
fi

mkdir -p "${REPO_DIR}"

# Keep a stable path for systemd units and k8s Endpoints manifests.
# If the repo lives elsewhere (e.g. /root/Ceres), make /opt/ceres/Ceres point to it.
if [ "${REPO_DIR}" != "/opt/ceres/Ceres" ]; then
  mkdir -p /opt/ceres
  ln -sfn "${REPO_DIR}" /opt/ceres/Ceres
fi

if ! command -v go >/dev/null 2>&1; then
  if [ -x "/usr/local/go/bin/go" ]; then
    export PATH="$PATH:/usr/local/go/bin"
  fi
fi

if ! command -v go >/dev/null 2>&1; then
  echo "[CERES UI] Go not found; running scripts/setup-go.sh" >&2
  (cd "${REPO_DIR}" && bash ./scripts/setup-go.sh) || true
fi

if ! command -v go >/dev/null 2>&1; then
  echo "[CERES UI] Go still not available. Install Go and rerun." >&2
  exit 1
fi

if [ ! -d "${REPO_DIR}/.git" ]; then
  echo "[CERES UI] repo not found at ${REPO_DIR} (.git missing)" >&2
  exit 1
fi

cd "${REPO_DIR}"
export CERES_ROOT

mkdir -p bin

echo "[CERES UI] building binaries..."
go build -o bin/ceres ./cmd/ceres
go build -o bin/ceres-ui ./cmd/ceres-ui
go build -o bin/ceres-mail-ui ./cmd/ceres-mail-ui

if [ -z "${BASIC_PASS}" ]; then
  if command -v openssl >/dev/null 2>&1; then
    BASIC_PASS="$(openssl rand -hex 16)"
  else
    BASIC_PASS="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-32)"
  fi
fi

mkdir -p /etc/ceres
chmod 700 /etc/ceres

cat > /etc/ceres/console-ui.env <<EOF
HOME=${HOME_DIR}
${KUBECONFIG_PATH:+KUBECONFIG=${KUBECONFIG_PATH}}
CERES_CONSOLE_LISTEN=:8091
CERES_UI_BASIC_USER=${BASIC_USER}
CERES_UI_BASIC_PASS=${BASIC_PASS}
CERES_ROOT=${CERES_ROOT}
CERES_UI_CLOUD=${CERES_UI_CLOUD:-k3s}
CERES_UI_ENV=${CERES_UI_ENV:-prod}
CERES_UI_NAMESPACE=${CERES_UI_NAMESPACE:-ceres}
CERES_UI_VPN_ENDPOINT=${VPN_ENDPOINT}
CERES_UI_VPN_PORT=${VPN_PORT}
CERES_MAIL_FROM=${MAIL_FROM}
${SMTP_HOST:+CERES_SMTP_HOST=${SMTP_HOST}}
${SMTP_PORT:+CERES_SMTP_PORT=${SMTP_PORT}}
${SMTP_USER:+CERES_SMTP_USER=${SMTP_USER}}
${SMTP_PASS:+CERES_SMTP_PASS=${SMTP_PASS}}
${SMTP_STARTTLS:+CERES_SMTP_STARTTLS=${SMTP_STARTTLS}}
${SMTP_TLS:+CERES_SMTP_TLS=${SMTP_TLS}}
EOF

cat > /etc/ceres/mail-ui.env <<EOF
HOME=${HOME_DIR}
${KUBECONFIG_PATH:+KUBECONFIG=${KUBECONFIG_PATH}}
CERES_UI_LISTEN=:8090
CERES_UI_BASIC_USER=${BASIC_USER}
CERES_UI_BASIC_PASS=${BASIC_PASS}
CERES_UI_VPN_ENDPOINT=${VPN_ENDPOINT}
CERES_UI_VPN_PORT=${VPN_PORT}
CERES_MAIL_FROM=${MAIL_FROM}
${SMTP_HOST:+CERES_SMTP_HOST=${SMTP_HOST}}
${SMTP_PORT:+CERES_SMTP_PORT=${SMTP_PORT}}
${SMTP_USER:+CERES_SMTP_USER=${SMTP_USER}}
${SMTP_PASS:+CERES_SMTP_PASS=${SMTP_PASS}}
${SMTP_STARTTLS:+CERES_SMTP_STARTTLS=${SMTP_STARTTLS}}
${SMTP_TLS:+CERES_SMTP_TLS=${SMTP_TLS}}
EOF

chmod 600 /etc/ceres/console-ui.env /etc/ceres/mail-ui.env

install -m 0644 "${REPO_DIR}/scripts/ceres-console-ui.service" /etc/systemd/system/ceres-console-ui.service
install -m 0644 "${REPO_DIR}/scripts/ceres-mail-ui.service" /etc/systemd/system/ceres-mail-ui.service
if [ -f "${REPO_DIR}/scripts/ceres-update-and-deploy.service" ]; then
  install -m 0644 "${REPO_DIR}/scripts/ceres-update-and-deploy.service" /etc/systemd/system/ceres-update-and-deploy.service
fi

systemctl daemon-reload
systemctl enable --now ceres-console-ui.service
systemctl enable --now ceres-mail-ui.service

systemctl restart ceres-console-ui.service || true
systemctl restart ceres-mail-ui.service || true

cat > /root/ceres-ui-credentials.txt <<EOF
CERES Console UI: https://ui.ceres.local
CERES Mail UI:    https://mail-ui.ceres.local
User: ${BASIC_USER}
Pass: ${BASIC_PASS}

Host IP for k8s Endpoints (manifests): ${HOST_IP}
EOF
chmod 600 /root/ceres-ui-credentials.txt

echo "[CERES UI] installed. Credentials saved to /root/ceres-ui-credentials.txt"
