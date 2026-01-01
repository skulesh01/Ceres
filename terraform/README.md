# CERES Terraform Configuration

Автоматическое создание инфраструктуры Proxmox для CERES платформы.

## 📋 Требования

- Terraform >= 1.5
- Proxmox VE 7.0+
- Cloud-init шаблон VM (Debian 12 рекомендуется)

## 🚀 Быстрый старт

### 1. Подготовка Proxmox шаблона

```bash
# На Proxmox сервере создайте cloud-init шаблон:
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
qm create 9000 --name debian-12-cloud --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 debian-12-generic-amd64.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

### 2. Настройка переменных

```bash
# Скопируйте пример файла переменных
cp terraform.tfvars.example terraform.tfvars

# Отредактируйте terraform.tfvars с вашими значениями
nano terraform.tfvars
```

### 3. Создание инфраструктуры

```bash
# Инициализация Terraform
terraform init

# Проверка плана
terraform plan

# Применение конфигурации
terraform apply

# Автоматическое применение без подтверждения
terraform apply -auto-approve
```

### 4. Получение информации

```bash
# Показать outputs (IP адреса, SSH команды)
terraform output

# Показать SSH команды для подключения
terraform output ssh_connection_core
terraform output ssh_connection_apps
terraform output ssh_connection_edge
```

## 📦 Созданные ресурсы

Terraform создаст 3 виртуальные машины:

| VM | Hostname | Default IP | CPU | RAM | Disk | Services |
|----|----------|-----------|-----|-----|------|----------|
| Core | ceres-core-prod | 192.168.1.10 | 4 | 8GB | 50GB | PostgreSQL, Redis, Keycloak |
| Apps | ceres-apps-prod | 192.168.1.11 | 4 | 8GB | 80GB | Nextcloud, Gitea, Mattermost, Redmine, Wiki.js |
| Edge | ceres-edge-prod | 192.168.1.12 | 2 | 4GB | 40GB | Caddy, Prometheus, Grafana, Portainer |

## 🔧 Настройка окружений

### Development

```bash
terraform workspace new dev
terraform apply -var="environment=dev" -var="core_vm_ip=192.168.1.20"
```

### Staging

```bash
terraform workspace new staging
terraform apply -var="environment=staging" -var="core_vm_ip=192.168.1.30"
```

### Production

```bash
terraform workspace new prod
terraform apply -var="environment=prod"
```

## 🔐 Безопасность

### Использование переменных окружения

```bash
# Вместо хранения паролей в terraform.tfvars
export TF_VAR_proxmox_password="your-password"
export TF_VAR_ssh_password="your-ssh-password"

terraform apply
```

### Использование Vault для секретов

```bash
# Установите Vault provider
terraform init

# Используйте secrets из Vault
proxmox_password = data.vault_generic_secret.proxmox.data["password"]
```

## 🔄 Обновление инфраструктуры

```bash
# Изменить ресурсы VM (например, увеличить RAM)
terraform apply -var="core_vm_memory=16384"

# Terraform покажет план изменений перед применением
```

## 🗑️ Удаление инфраструктуры

```bash
# Удалить все созданные ресурсы
terraform destroy

# Удалить без подтверждения
terraform destroy -auto-approve
```

## 📊 State Management

### Local State (по умолчанию)

```bash
# State хранится в terraform.tfstate локально
# НЕ коммитьте этот файл в Git!
```

### Remote State (рекомендуется для команды)

```hcl
# В main.tf раскомментируйте backend "s3"
terraform {
  backend "s3" {
    bucket = "ceres-terraform-state"
    key    = "proxmox/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## 🔍 Troubleshooting

### Ошибка подключения к Proxmox API

```bash
# Проверьте доступность API
curl -k https://192.168.1.3:8006/api2/json/version

# Проверьте учетные данные
pveum user list
```

### VM не создается

```bash
# Проверьте наличие шаблона
qm list | grep template

# Проверьте доступное место на storage
pvesm status
```

### Cloud-init не применяется

```bash
# На созданной VM проверьте cloud-init
ssh ceres@192.168.1.10
cloud-init status
```

## 🔗 Интеграция с Ansible

После создания VMs с помощью Terraform, используйте Ansible для развертывания CERES:

```bash
# Получите IP адреса из Terraform
terraform output -json > ../ansible/inventory/terraform-outputs.json

# Запустите Ansible playbook
cd ../ansible
ansible-playbook -i inventory/production.yml deploy.yml
```

## 📚 Дополнительная документация

- [Terraform Proxmox Provider](https://github.com/Telmate/terraform-provider-proxmox)
- [Proxmox Cloud-Init](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [CERES GitOps Guide](../docs/GITOPS_GUIDE.md)
