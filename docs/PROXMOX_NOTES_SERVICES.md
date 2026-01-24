# Ceres platform — адреса и доступы (для Proxmox Notes)

## Точка входа
- k3s node / Traefik LB IP: `192.168.1.3`
- Traefik NodePorts: `80 -> 31746`, `443 -> 31805` (на том же IP)

## DNS / hosts (чтобы открывались *.ceres.local)
Если локального DNS нет — достаточно добавить записи в `hosts` на вашем ПК:
- `192.168.1.3  projects.ceres.local`
- `192.168.1.3  keycloak.ceres.local`
- `192.168.1.3  gitlab.ceres.local`
- `192.168.1.3  mail.ceres.local`
- `192.168.1.3  chat.ceres.local`
- `192.168.1.3  minio.ceres.local`
- `192.168.1.3  grafana.ceres.local`
- `192.168.1.3  prometheus.ceres.local`
- `192.168.1.3  files.ceres.local`
- `192.168.1.3  portainer.ceres.local`
- `192.168.1.3  vault.ceres.local`
- `192.168.1.3  wiki.ceres.local`
- `192.168.1.3  db.ceres.local`

## Web-доступы (Ingress)
Все хосты ниже маршрутизируются через Traefik на `192.168.1.3`:
- Redmine: `https://projects.ceres.local/`
- Keycloak: `https://keycloak.ceres.local/`
- GitLab: `https://gitlab.ceres.local/`
- Mailcow: `https://mail.ceres.local/`
- Mattermost: `https://chat.ceres.local/`
- MinIO: `https://minio.ceres.local/`
- Grafana: `https://grafana.ceres.local/`
- Prometheus: `https://prometheus.ceres.local/`
- Nextcloud: `https://files.ceres.local/`
- Portainer: `https://portainer.ceres.local/`
- Vault: `https://vault.ceres.local/`
- WikiJS: `https://wiki.ceres.local/`
- Adminer: `https://db.ceres.local/`

## Fallback-доступы (NodePort)
Если Ingress/DNS временно недоступны, можно ходить напрямую на IP ноды:
- Redmine: `http://192.168.1.3:30301/`
- Keycloak: `http://192.168.1.3:30295/`
- GitLab (web): `http://192.168.1.3:30700/`
- Mattermost: `http://192.168.1.3:30806/`
- MinIO Console: `http://192.168.1.3:30901/`
- Grafana: `http://192.168.1.3:30300/`
- Jaeger: `http://192.168.1.3:30686/`
- Prometheus: `http://192.168.1.3:30900/`
- Nextcloud: `http://192.168.1.3:30802/`
- Portainer: `http://192.168.1.3:30902/`
- RabbitMQ management: `http://192.168.1.3:30672/`
- SonarQube: `http://192.168.1.3:30904/`
- Vault: `http://192.168.1.3:30820/`
- Adminer: `http://192.168.1.3:30880/`

## Внутрикластерные адреса (для сервисов внутри k3s)
- PostgreSQL: `postgresql.ceres-core.svc.cluster.local:5432` (svc ClusterIP `10.43.1.196`)
- Redis: `redis.ceres-core.svc.cluster.local:6379` (svc ClusterIP `10.43.89.168`)
- Argo CD Server: `argocd-server.argocd.svc.cluster.local:443` (svc ClusterIP `10.43.177.37`)

## Где лежат доступы (Kubernetes secrets)
Я не пишу пароли в Notes, но указываю, где их брать:
- Argo CD: secret `argocd/argocd-initial-admin-secret` (user обычно `admin`)
- Keycloak: secret `ceres/keycloak-secret`
- Grafana: secret `monitoring/grafana-secret`
- PostgreSQL: secret `ceres-core/postgresql-secret`
- Redis: secret `ceres-core/redis-secret`
- Redmine DB password (копия для namespace redmine): secret `redmine/ceres-credentials`
- TLS сертификаты для Ingress: `*/<name>-tls` (например `redmine/redmine-tls`, `ceres/keycloak-tls` и т.д.)
