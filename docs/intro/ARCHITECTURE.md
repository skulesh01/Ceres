# Company Infrastructure – Architecture & Deployment Documentation

## 📦 Overview
The repository **company‑infra** contains a fully open‑source, modular infrastructure that can be deployed with a single PowerShell script. All services run in Docker containers and are orchestrated by **Traefik** (reverse‑proxy) and **Keycloak** (SSO). The stack includes monitoring, CI/CD, document management, CRM, accounting, mail, virtual‑machine management, and more.

---

## 🧩 Service Map
```
┌─────────────────────────────────────────────────────────────────────┐
│                     Traefik (reverse‑proxy)                        │
│  ──────────────────────────────────────────────────────────────── │
│  │  … (other services)                                            │
│  │  ├─ nextcloud (file storage)                                   │
│  │  └─ processmaker (EDM + workflow)                             │
│  │        ↳ PostgreSQL (shared DB)                               │
│  │        ↳ Nextcloud WebDAV for document blobs                  │
│  └─────────────────────────────────────────────────────────────────┘
```

| Category | Docker Image | Role |
|---|---|---|
| **Reverse proxy / TLS** | `traefik` | Routes traffic, auto‑TLS via Let's Encrypt |
| **Database** | `postgres` | Central relational store |
| **Cache / Queue** | `redis` | Fast key‑value store |
| **Identity** | `keycloak` | OpenID Connect SSO |
| **File storage** | `nextcloud` | WebDAV‑based document repository |
| **EDM / Workflow** | `processmaker` | Configurable approval routes, document lifecycle |
| **Version control** | `gitea` | Git server + CI |
| **Project management** | `taiga` | Kanban, backlog |
| **Knowledge base** | `wikijs` | Markdown wiki |
| **CRM** | `suitecrm` | Customer relationship |
| **Accounting** | `erpnext` | Finance & invoicing |
| **Mail** | `mailcow` | SMTP/IMAP service |
| **Remote control** | `meshcentral` | Browser‑based RDP/SSH |
| **AD‑like** | `freeipa` | LDAP/Kerberos directory |
| **VM management** | `proxmox‑api` | API proxy for Proxmox VE |
| **Monitoring** | `prometheus` + `grafana` | Metrics collection & dashboards |
| **Logging** | `loki` + `promtail` | Centralised log aggregation |
| **Server metrics** | `netdata` | Real‑time system stats |
| **Backup** | `restic` | Scheduled backups to S3‑compatible storage |
| **CI/CD** | Built‑in Gitea actions | Automated pipelines |

---

## 🚀 Deployment Workflow
1. **Prerequisites** – Docker Desktop installed on Windows, Git, optional `k3d`/`kubectl` for future scaling.
2. **Clone the repo**
   ```powershell
   git clone https://github.com/your-org/company-infra.git
   cd company-infra
   ```
3. **Create `.env`** – copy `.env.example`, fill in passwords, domain, and secrets (`KEYCLOAK_CLIENT_SECRET_PM`, `NEXTCLOUD_TOKEN`).
4. **Run the one‑click script**
   ```powershell
   .\deploy.ps1
   ```
   The script runs `docker compose up -d`, creates the network, and prints URLs for each service.
5. **Initial SSO setup**
   * In Keycloak create a confidential client `processmaker` and copy the secret to `.env`.
   * Generate a Nextcloud WebDAV app‑password for ProcessMaker and add it to `.env`.
6. **Verify services** – open the URLs (e.g. `https://edm.company.local`) and log in via Keycloak.
7. **Create an approval workflow** in ProcessMaker:
   * Add a *Upload Document* task (stores file in Nextcloud).
   * Add *Approve* / *Reject* tasks and connect them with arrows.
   * Assign Keycloak groups (`doc_author`, `doc_approver`, `doc_controller`) to the tasks.
8. **Scale** – to move to Docker Swarm or k3s replace `docker compose` with `docker stack deploy` or `kubectl apply` (manifests are generated with `kompose`).

---

## 🔧 Configuration Highlights
### Traefik (reverse‑proxy)
```yaml
# traefik/traefik.yml (excerpt)
entryPoints:
  websecure:
    address: ":443"
providers:
  docker:
    exposedByDefault: false
certificatesResolvers:
  myresolver:
    acme:
      email: admin@${DOMAIN}
      storage: /letsencrypt/acme.json
      tlsChallenge: {}
```
All services expose `traefik.enable=true` and define a `Host` rule.

### Keycloak OIDC for ProcessMaker
```yaml
environment:
  OIDC_ISSUER: https://auth.${DOMAIN}/realms/company
  OIDC_CLIENT_ID: processmaker
  OIDC_CLIENT_SECRET: ${KEYCLOAK_CLIENT_SECRET_PM}
```
ProcessMaker reads the issuer URL, client ID and secret to delegate authentication.

### ProcessMaker ↔ Nextcloud (WebDAV)
```yaml
environment:
  NEXTCLOUD_URL: https://cloud.${DOMAIN}/remote.php/dav/files
  NEXTCLOUD_TOKEN: ${NEXTCLOUD_TOKEN}
```
When a document is uploaded in a workflow, ProcessMaker stores the binary in the user’s Nextcloud folder via WebDAV.

---

## 📚 Further Reading & Resources
* **ProcessMaker Community Edition** – https://github.com/processmaker/processmaker
* **Keycloak Documentation** – https://www.keycloak.org/documentation
* **Traefik v3 Docs** – https://doc.traefik.io/traefik/v3.0/
* **Nextcloud Admin Guide** – https://docs.nextcloud.com/server/latest/admin_manual/
* **Docker Compose reference** – https://docs.docker.com/compose/compose-file/

---

## 🗂️ Repository Layout
```
company-infra/
├─ .env.example                # template for environment variables
├─ docker-compose.yml          # main stack definition
├─ deploy.ps1                  # one‑click PowerShell script
├─ traefik/                    # Traefik config files
├─ keycloak/                   # realm export JSON
├─ nextcloud/                  # optional custom config
├─ processmaker/               # optional overrides
├─ docs/
│   └─ architecture.md        # ← this file
└─ README.md                  # high‑level project description
```

---

*Document generated on 2025‑11‑27.*
