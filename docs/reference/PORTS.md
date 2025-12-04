# Порты сервисов (внутренние/внешние)

Это приблизительный список портов, указанных в `docker-compose.yml`:

- Traefik: 80, 443 (внешне)
- PostgreSQL: 5432 (обычно доступ внутри сети)
- Redis: 6379 (внутри)
- Keycloak: 8080/8443 (через Traefik доступ по https)
- Nextcloud: 80/443 (через Traefik)
- Grafana: 3000 (через Traefik)
- Prometheus: 9090 (может быть локально)
- Gitea: 3000 (через Traefik)

Если вы меняете порты, обновите `docker-compose.yml` и Traefik метки (labels).
