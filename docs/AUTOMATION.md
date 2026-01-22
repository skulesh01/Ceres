# Automation (native)

This repo is designed to be operated in a Kubernetes-native way:

- **CI builds/pushes images** (no `docker build` on servers)
- **k3s deploys from a registry** (pulls images by tag)
- **GitOps/CI applies manifests** (no manual `kubectl apply` drift)

## Redmine image

Workflow: `.github/workflows/redmine-image.yml`

- Builds `docker/redmine/Dockerfile`
- Pushes to GHCR:
  - `ghcr.io/<owner>/ceres-redmine:5.1-plugins`
  - `ghcr.io/<owner>/ceres-redmine:<CERES_VERSION>`

## Deploy Redmine

Script: `scripts/deploy-redmine.sh`

- Applies `deployment/redmine.yaml`
- If the manifest contains `ghcr.io/REPO_OWNER/...`, it resolves `<owner>` from `git remote.origin.url` and substitutes automatically.

## GitOps-lite auto-update (single server)

Script: `scripts/install-ceres-autoupdate.sh`

- Installs a systemd timer that runs:
  - `git reset --hard origin/main`
  - `./scripts/deploy-redmine.sh`

This keeps a single-node setup updated without manual work.

## Recommended next step: GitOps (Argo CD / Flux)

For production, prefer GitOps controllers:

- Drift correction
- Rollback
- Audit trail
- Environment separation (dev/stage/prod)

This repo intentionally keeps manifests compatible with GitOps tools.

## Argo CD (quick bootstrap)

On the server:

- `./scripts/bootstrap-gitops.sh`
- Access Argo CD: `https://<SERVER_IP>:30090`

After GitOps is enabled, disable the legacy systemd updater:

- `./scripts/disable-ceres-autoupdate.sh`
