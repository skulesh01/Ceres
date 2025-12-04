# URL сервисов Ceres

Ниже — список URL-адресов, используемых по умолчанию для локального развёртывания (через hosts). При изменении домена обновите `config/.env`.

| Сервис | URL |
|---|---|
| Traefik Dashboard | https://traefik.Ceres.local |
| Keycloak (SSO) | https://auth.Ceres.local |
| Nextcloud | https://cloud.Ceres.local |
| Taiga | https://taiga.Ceres.local |
| ProcessMaker | https://edm.Ceres.local |
| ERPNext | https://erp.Ceres.local |
| SuiteCRM | https://crm.Ceres.local |
| Gitea | https://git.Ceres.local |
| Mailcow | https://mail.Ceres.local |
| MeshCentral | https://mesh.Ceres.local |
| Grafana | https://grafana.Ceres.local |
| Prometheus | http://localhost:9090 (внутренний) |
| FreeIPA | https://ipa.Ceres.local |

# Примечание
Для локального тестирования добавьте записи в `C:\Windows\System32\drivers\etc\hosts` (от администратора):
```
127.0.0.1 Ceres.local
127.0.0.1 auth.Ceres.local
127.0.0.1 taiga.Ceres.local
127.0.0.1 cloud.Ceres.local
127.0.0.1 erp.Ceres.local
127.0.0.1 crm.Ceres.local
127.0.0.1 git.Ceres.local
127.0.0.1 mail.Ceres.local
127.0.0.1 mesh.Ceres.local
127.0.0.1 grafana.Ceres.local
127.0.0.1 traefik.Ceres.local
127.0.0.1 ipa.Ceres.local
127.0.0.1 edm.Ceres.local
```