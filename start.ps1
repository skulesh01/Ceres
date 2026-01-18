param([int]$Method = 0)
if ($Method -eq 0) { Write-Host "Choose: 1=Docker, 2=Kubernetes"; exit }
if ($Method -eq 1) { docker-compose -f config/compose/core.yml up -d; docker-compose -f config/compose/apps.yml up -d; docker ps }
if ($Method -eq 2) { Write-Host "Use: terraform apply && ansible-playbook" }
