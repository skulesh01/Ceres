#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CERES Auto-Deploy Script
Полная автоматизация развертывания через Terraform + Ansible + Docker
"""

import os
import sys
import subprocess
import shutil
import time
from pathlib import Path

# Цвета
class C:
    G = '\033[92m'  # Green
    Y = '\033[93m'  # Yellow
    R = '\033[91m'  # Red
    C = '\033[96m'  # Cyan
    E = '\033[0m'   # End

PROJECT_ROOT = Path(__file__).parent.parent
TERRAFORM_DIR = PROJECT_ROOT / 'terraform'
ANSIBLE_DIR = PROJECT_ROOT / 'ansible'

def log(msg, color=C.C):
    """Вывод сообщения"""
    print(f"{color}{msg}{C.E}")

def check_tool(name, cmd):
    """Проверить наличие инструмента"""
    if shutil.which(cmd):
        log(f"[OK] {name} found", C.G)
        return True
    else:
        log(f"[  ] {name} not found", C.Y)
        return False

def install_terraform():
    """Установить Terraform"""
    log("\n>>> Installing Terraform...", C.C)
    
    system = os.uname().sysname.lower()
    
    if system == 'linux':
        # Linux
        log("Detected Linux", C.C)
        subprocess.run([
            'bash', '-c',
            '''
            wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install -y terraform
            '''
        ])
    else:
        log("Please install Terraform manually from https://www.terraform.io/downloads", C.R)
        return False
    
    return check_tool("Terraform", "terraform")

def install_ansible():
    """Установить Ansible"""
    log("\n>>> Installing Ansible...", C.C)
    
    if not shutil.which('python3'):
        log("Python3 required for Ansible!", C.R)
        return False
    
    subprocess.run(['python3', '-m', 'pip', 'install', 'ansible', '--quiet'])
    return check_tool("Ansible", "ansible")

def check_dependencies():
    """Проверить все зависимости"""
    log("\n=== STAGE 1: Checking Dependencies ===\n", C.C)
    
    deps = {
        'Terraform': 'terraform',
        'Ansible': 'ansible',
        'Git': 'git',
    }
    
    missing = []
    for name, cmd in deps.items():
        if not check_tool(name, cmd):
            missing.append((name, cmd))
    
    # Устанавливаем отсутствующие
    if missing:
        log("\nInstalling missing dependencies...", C.Y)
        
        for name, cmd in missing:
            if name == 'Terraform':
                if not install_terraform():
                    log(f"Failed to install {name}", C.R)
                    return False
            elif name == 'Ansible':
                if not install_ansible():
                    log(f"Failed to install {name}", C.R)
                    return False
            else:
                log(f"Please install {name} manually", C.R)
                return False
    
    return True

def check_config():
    """Проверить конфигурационные файлы"""
    log("\n=== STAGE 2: Checking Configuration ===\n", C.C)
    
    configs = [
        ('terraform.tfvars', TERRAFORM_DIR / 'terraform.tfvars'),
        ('.env', PROJECT_ROOT / 'config' / '.env'),
        ('ansible inventory', ANSIBLE_DIR / 'inventory' / 'production.yml'),
    ]
    
    all_ok = True
    for name, path in configs:
        if path.exists():
            log(f"[OK] {name} found", C.G)
        else:
            log(f"[ERROR] {name} missing at {path}", C.R)
            all_ok = False
    
    return all_ok

def deploy_terraform():
    """Развернуть инфраструктуру через Terraform"""
    log("\n=== STAGE 3: Creating Infrastructure (Terraform) ===\n", C.C)
    
    os.chdir(TERRAFORM_DIR)
    
    # Инициализация
    log("Initializing Terraform...", C.C)
    result = subprocess.run(['terraform', 'init'])
    if result.returncode != 0:
        log("Terraform init failed!", C.R)
        return False
    
    log("[OK] Terraform initialized", C.G)
    
    # План
    log("\nPlanning infrastructure...", C.C)
    result = subprocess.run(['terraform', 'plan', '-out=tfplan'])
    if result.returncode != 0:
        log("Terraform plan failed!", C.R)
        return False
    
    log("[OK] Plan created", C.G)
    
    # Подтверждение
    print()
    confirm = input("Apply this plan? (yes/no): ")
    if confirm.lower() not in ['yes', 'да', 'y', 'д']:
        log("Aborted by user", C.Y)
        return False
    
    # Применение
    log("\nApplying plan (creating 3 VMs)...", C.C)
    log("This may take 10-15 minutes...", C.Y)
    
    result = subprocess.run(['terraform', 'apply', 'tfplan'])
    if result.returncode != 0:
        log("Terraform apply failed!", C.R)
        return False
    
    log("[OK] Infrastructure created!", C.G)
    
    # Вывод IP адресов
    try:
        core_ip = subprocess.check_output(['terraform', 'output', '-raw', 'core_ip']).decode().strip()
        apps_ip = subprocess.check_output(['terraform', 'output', '-raw', 'apps_ip']).decode().strip()
        edge_ip = subprocess.check_output(['terraform', 'output', '-raw', 'edge_ip']).decode().strip()
        
        log(f"\nVM IP addresses:", C.C)
        log(f"  Core: {core_ip}", C.G)
        log(f"  Apps: {apps_ip}", C.G)
        log(f"  Edge: {edge_ip}", C.G)
    except:
        pass
    
    os.chdir(PROJECT_ROOT)
    return True

def deploy_ansible():
    """Настроить ВМ через Ansible"""
    log("\n=== STAGE 4: Configuring VMs (Ansible) ===\n", C.C)
    
    inventory = ANSIBLE_DIR / 'inventory' / 'production.yml'
    playbook = ANSIBLE_DIR / 'playbooks' / 'deploy-ceres.yml'
    
    if not playbook.exists():
        log(f"Playbook not found: {playbook}", C.R)
        return False
    
    log("Running Ansible playbook...", C.C)
    log("This may take 20-30 minutes...", C.Y)
    
    result = subprocess.run([
        'ansible-playbook',
        '-i', str(inventory),
        str(playbook),
        '-v'
    ])
    
    if result.returncode != 0:
        log("Ansible playbook failed!", C.R)
        return False
    
    log("[OK] VMs configured!", C.G)
    return True

def deploy_services():
    """Запустить сервисы через Docker Compose"""
    log("\n=== STAGE 5: Starting Services (Docker Compose) ===\n", C.C)
    
    start_script = PROJECT_ROOT / 'scripts' / 'start.py'
    
    if start_script.exists():
        log("Running services startup script...", C.C)
        result = subprocess.run(['python3', str(start_script)])
        
        if result.returncode != 0:
            log("Failed to start services!", C.R)
            return False
        
        log("[OK] All services started!", C.G)
    else:
        log("start.py not found, skipping service startup", C.Y)
    
    return True

def show_summary():
    """Показать итоги развертывания"""
    log("\n" + "=" * 80, C.G)
    log("                    DEPLOYMENT COMPLETED", C.G)
    log("=" * 80 + "\n", C.G)
    
    print("""
CREATED:
  • 3 VMs on Proxmox (Core, Apps, Edge)
  • Docker installed on all VMs
  • All dependencies configured

STARTED:
  • PostgreSQL + Redis (storage)
  • Keycloak (SSO/OIDC)
  • GitLab CE (Git + CI/CD)
  • Zulip (chat)
  • Nextcloud (files)
  • Prometheus + Grafana (monitoring)
  • 20+ additional services

ACCESS:
  • auth.ceres           → Keycloak
  • gitlab.ceres         → GitLab CE
  • zulip.ceres          → Zulip
  • nextcloud.ceres      → Nextcloud
  • grafana.ceres        → Grafana

NEXT STEPS:
  1. Verify access to services via browser
  2. Configure DNS (if needed)
  3. Add users through Keycloak
  4. Configure SMTP for notifications
""")

def main():
    """Главная функция"""
    log("\n" + "=" * 80, C.C)
    log("          CERES AUTOMATED DEPLOYMENT ON PROXMOX", C.C)
    log("=" * 80, C.C)
    
    print("""
  Infrastructure:  Proxmox 192.168.1.3
  Cluster:         3 VMs (Core, Apps, Edge)
  Services:        20+ (PostgreSQL, Redis, GitLab, Zulip, etc)
  Stages:          Terraform → Ansible → Docker Compose
""")
    
    start_time = time.time()
    
    # Этап 1: Зависимости
    if not check_dependencies():
        log("\nDependency check failed!", C.R)
        return 1
    
    # Этап 2: Конфигурация
    if not check_config():
        log("\nConfiguration check failed!", C.R)
        return 1
    
    # Этап 3: Terraform
    if not deploy_terraform():
        log("\nTerraform deployment failed!", C.R)
        return 1
    
    # Этап 4: Ansible
    if not deploy_ansible():
        log("\nAnsible deployment failed!", C.R)
        return 1
    
    # Этап 5: Сервисы
    if not deploy_services():
        log("\nService deployment failed!", C.R)
        return 1
    
    # Итоги
    elapsed = int(time.time() - start_time)
    minutes = elapsed // 60
    seconds = elapsed % 60
    
    show_summary()
    
    log(f"\nTotal time: {minutes}m {seconds}s", C.G)
    
    return 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        log("\n\nInterrupted by user. Goodbye!", C.Y)
        sys.exit(1)
