# CERES - Service Access (auto-generated)

Generated: 2026-01-24 18:38:23

## Entry point
- Traefik LoadBalancer IP: 192.168.1.3
- k3s node InternalIP: 192.168.1.3

## Ingress (recommended)
- https://chat.ceres.local/  (ns=mattermost, ingress=mattermost)
- https://db.ceres.local/  (ns=adminer, ingress=adminer)
- https://files.ceres.local/  (ns=nextcloud, ingress=nextcloud)
- https://gitlab.ceres.local/  (ns=gitlab, ingress=gitlab)
- https://grafana.ceres.local/  (ns=monitoring, ingress=grafana)
- https://keycloak.ceres.local/  (ns=ceres, ingress=keycloak)
- https://mail.ceres.local/  (ns=mailcow, ingress=mailcow)
- https://minio.ceres.local/  (ns=minio, ingress=minio)
- https://portainer.ceres.local/  (ns=portainer, ingress=portainer)
- https://projects.ceres.local/  (ns=redmine, ingress=redmine)
- https://prometheus.ceres.local/  (ns=monitoring, ingress=prometheus)
- https://vault.ceres.local/  (ns=vault, ingress=vault)
- https://wiki.ceres.local/  (ns=wiki, ingress=wikijs)

## NodePort (fallback)
- adminer/adminer-nodeport: http://192.168.1.3:30880/ (svcPort=8080/TCP)
- ceres/keycloak-nodeport: http://192.168.1.3:30295/ (svcPort=8080/TCP)
- gitlab/gitlab-nodeport: http://192.168.1.3:30700/ (svcPort=80/TCP)
- kube-system/traefik (type=LoadBalancer): http://192.168.1.3:31746/ (svcPort=80/TCP)
- kube-system/traefik (type=LoadBalancer): https://192.168.1.3:31805/ (svcPort=443/TCP)
- mattermost/mattermost-nodeport: http://192.168.1.3:30806/ (svcPort=8065/TCP)
- minio/minio-nodeport: http://192.168.1.3:30901/ (svcPort=9001/TCP)
- monitoring/grafana-nodeport: http://192.168.1.3:30300/ (svcPort=3000/TCP)
- monitoring/jaeger-nodeport: http://192.168.1.3:30686/ (svcPort=16686/TCP)
- monitoring/prometheus-nodeport: http://192.168.1.3:30900/ (svcPort=9090/TCP)
- nextcloud/nextcloud-nodeport: http://192.168.1.3:30802/ (svcPort=80/TCP)
- portainer/portainer-nodeport: http://192.168.1.3:30902/ (svcPort=9000/TCP)
- rabbitmq/rabbitmq-nodeport: http://192.168.1.3:30672/ (svcPort=15672/TCP)
- redmine/redmine-nodeport: http://192.168.1.3:30301/ (svcPort=3000/TCP)
- sonarqube/sonarqube-nodeport: http://192.168.1.3:30904/ (svcPort=9000/TCP)
- vault/vault-nodeport: http://192.168.1.3:30820/ (svcPort=8200/TCP)

## Credentials (where to find)
Don't paste passwords here; reference Kubernetes secrets:
- argocd/argocd-initial-admin-secret
- ceres-core/postgresql-secret
- ceres-core/redis-secret
- redmine/ceres-credentials
