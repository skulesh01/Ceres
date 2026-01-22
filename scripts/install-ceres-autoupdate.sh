#!/bin/bash
set -euo pipefail

# Installs a simple systemd timer on the server so it auto-updates from git
# and reapplies manifests (GitOps-lite). Recommended for single-node setups.

SERVICE_NAME="ceres-autoupdate"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root" >&2
  exit 1
fi

cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<'EOF'
[Unit]
Description=Ceres auto-update (git pull + kubectl apply)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=/root/Ceres
ExecStart=/bin/bash -lc 'git fetch --all && git reset --hard origin/main && ./scripts/deploy-redmine.sh'
EOF

cat > "/etc/systemd/system/${SERVICE_NAME}.timer" <<'EOF'
[Unit]
Description=Run Ceres auto-update every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.timer"

echo "Installed and started: ${SERVICE_NAME}.timer"
