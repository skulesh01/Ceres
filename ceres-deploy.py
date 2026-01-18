#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CERES Platform - Unified Deployment Center
Единая точка входа для развертывания инфраструктуры

Работает на Linux и Windows
"""

import os
import sys
import subprocess
import platform
import shutil
from pathlib import Path

# Цвета для терминала
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

# Глобальное состояние
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
LANG = 'ru'  # По умолчанию русский

# Переводы
TRANSLATIONS = {
    'ru': {
        'welcome': 'CERES ПЛАТФОРМА - ЦЕНТР РАЗВЕРТЫВАНИЯ',
        'select_lang': 'Выберите язык / Select language',
        'main_menu': 'ГЛАВНОЕ МЕНЮ',
        'system_info': 'Информация о системе',
        'dependencies': 'Установленные зависимости',
        'deployment_method': 'Выбрать метод развертывания',
        'check_config': 'Проверить конфигурацию',
        'view_status': 'Статус развертывания',
        'help': 'Справка',
        'exit': 'Выход',
        'back': 'Назад',
        'continue': 'Продолжить',
        'yes': 'да',
        'no': 'нет',
        'os': 'ОС',
        'cpu': 'Процессор',
        'ram': 'Память',
        'disk': 'Диск',
        'installed': 'установлен',
        'not_found': 'не найден',
        'missing': 'отсутствует',
        'terraform_deploy': 'Terraform (3 ВМ на Proxmox)',
        'ansible_deploy': 'Ansible (настроить существующие ВМ)',
        'docker_deploy': 'Docker Compose (локальное тестирование)',
        'remote_deploy': 'Удаленный сервер (через SSH)',
        'k8s_deploy': 'Kubernetes (кластер K8s)',
        'confirm': 'Подтвердить',
        'cancel': 'Отменить',
    },
    'en': {
        'welcome': 'CERES PLATFORM - DEPLOYMENT CENTER',
        'select_lang': 'Select language / Выберите язык',
        'main_menu': 'MAIN MENU',
        'system_info': 'System Information',
        'dependencies': 'Installed Dependencies',
        'deployment_method': 'Select Deployment Method',
        'check_config': 'Check Configuration',
        'view_status': 'View Status',
        'help': 'Help',
        'exit': 'Exit',
        'back': 'Back',
        'continue': 'Continue',
        'yes': 'yes',
        'no': 'no',
        'os': 'OS',
        'cpu': 'CPU',
        'ram': 'RAM',
        'disk': 'Disk',
        'installed': 'installed',
        'not_found': 'not found',
        'missing': 'missing',
        'terraform_deploy': 'Terraform (3 VMs on Proxmox)',
        'ansible_deploy': 'Ansible (Configure existing VMs)',
        'docker_deploy': 'Docker Compose (Local testing)',
        'remote_deploy': 'Remote Server (SSH deployment)',
        'k8s_deploy': 'Kubernetes (K8s cluster)',
        'confirm': 'Confirm',
        'cancel': 'Cancel',
    }
}

def t(key):
    """Получить перевод"""
    return TRANSLATIONS[LANG].get(key, key)

def clear_screen():
    """Очистить экран"""
    os.system('cls' if platform.system() == 'Windows' else 'clear')

def print_header():
    """Показать заголовок"""
    clear_screen()
    print(Colors.HEADER + "╔" + "═" * 78 + "╗" + Colors.ENDC)
    print(Colors.HEADER + "║" + " " * 78 + "║" + Colors.ENDC)
    title = t('welcome')
    padding = (78 - len(title)) // 2
    print(Colors.HEADER + "║" + " " * padding + title + " " * (78 - padding - len(title)) + "║" + Colors.ENDC)
    print(Colors.HEADER + "║" + " " * 78 + "║" + Colors.ENDC)
    print(Colors.HEADER + "╚" + "═" * 78 + "╝" + Colors.ENDC)
    print()

def print_menu(title, options):
    """Показать меню"""
    print(Colors.OKCYAN + f"\n{title}\n" + Colors.ENDC)
    
    for i, option in enumerate(options, 1):
        print(f"  {i}. {option}")
    
    print(f"  0. {t('back')}")
    print()

def get_choice(max_val):
    """Получить выбор пользователя"""
    try:
        choice = int(input(f">>> "))
        if 0 <= choice <= max_val:
            return choice
        return -1
    except ValueError:
        return -1

def check_command(cmd):
    """Проверить наличие команды"""
    return shutil.which(cmd) is not None

def get_system_info():
    """Получить информацию о системе"""
    info = {
        'os': platform.system() + ' ' + platform.release(),
        'cpu': os.cpu_count(),
    }
    
    if platform.system() == 'Linux':
        try:
            with open('/proc/meminfo') as f:
                mem = f.readline().split()[1]
                info['ram'] = int(mem) // 1024 // 1024  # GB
        except:
            info['ram'] = 'N/A'
            
        try:
            df = subprocess.check_output(['df', '-h', '/']).decode()
            lines = df.split('\n')[1].split()
            info['disk_total'] = lines[1]
            info['disk_free'] = lines[3]
        except:
            info['disk_total'] = 'N/A'
            info['disk_free'] = 'N/A'
    else:
        # Windows
        import psutil
        info['ram'] = round(psutil.virtual_memory().total / 1024**3)
        disk = psutil.disk_usage('/')
        info['disk_total'] = f"{disk.total / 1024**3:.0f}GB"
        info['disk_free'] = f"{disk.free / 1024**3:.0f}GB"
    
    return info

def show_system_info():
    """Показать информацию о системе"""
    print(Colors.OKCYAN + f"\n[{t('system_info').upper()}]" + Colors.ENDC)
    
    info = get_system_info()
    
    print(f"  {t('os')}:    {info['os']}")
    print(f"  {t('cpu')}:   {info['cpu']} cores")
    print(f"  {t('ram')}:   {info['ram']} GB")
    print(f"  {t('disk')}:  {info.get('disk_total', 'N/A')} ({t('not_found')}: {info.get('disk_free', 'N/A')})")

def show_dependencies():
    """Показать установленные зависимости"""
    print(Colors.OKCYAN + f"\n[{t('dependencies').upper()}]" + Colors.ENDC)
    
    tools = [
        ('Terraform', 'terraform'),
        ('Ansible', 'ansible'),
        ('Docker', 'docker'),
        ('Python', 'python3' if platform.system() != 'Windows' else 'python'),
        ('Git', 'git'),
        ('kubectl', 'kubectl'),
    ]
    
    status = {}
    for name, cmd in tools:
        installed = check_command(cmd)
        status[name] = installed
        
        if installed:
            print(f"  {Colors.OKGREEN}[OK]{Colors.ENDC} {name}")
        else:
            print(f"  {Colors.WARNING}[  ]{Colors.ENDC} {name} ({t('not_found')})")
    
    return status

def check_configuration():
    """Проверить конфигурационные файлы"""
    print(Colors.OKCYAN + f"\n[{t('check_config').upper()}]" + Colors.ENDC)
    
    configs = [
        ('terraform.tfvars', PROJECT_ROOT / 'terraform' / 'terraform.tfvars'),
        ('.env', PROJECT_ROOT / 'config' / '.env'),
        ('ansible inventory', PROJECT_ROOT / 'ansible' / 'inventory' / 'production.yml'),
    ]
    
    all_ok = True
    for name, path in configs:
        if path.exists():
            print(f"  {Colors.OKGREEN}[OK]{Colors.ENDC} {name}")
        else:
            print(f"  {Colors.WARNING}[  ]{Colors.ENDC} {name} ({t('missing')})")
            all_ok = False
    
    return all_ok

def deploy_terraform():
    """Развертывание через Terraform"""
    print(Colors.OKCYAN + "\n[TERRAFORM DEPLOYMENT]" + Colors.ENDC)
    print("Создаст 3 ВМ на Proxmox через Terraform\n")
    
    if not check_command('terraform'):
        print(Colors.FAIL + "Terraform не установлен!" + Colors.ENDC)
        print("Установите с https://www.terraform.io/downloads")
        input(f"\n{t('continue')}...")
        return
    
    tfvars = PROJECT_ROOT / 'terraform' / 'terraform.tfvars'
    if not tfvars.exists():
        print(Colors.FAIL + "terraform.tfvars не найден!" + Colors.ENDC)
        input(f"\n{t('continue')}...")
        return
    
    print("Это развертывание:")
    print("  - Подключится к Proxmox 192.168.1.3")
    print("  - Создаст 3 ВМ (Core, Apps, Edge)")
    print("  - Установит Docker на каждую ВМ")
    print("  - Займет 10-15 минут\n")
    
    confirm = input(f"{t('confirm')}? ({t('yes')}/{t('no')}): ")
    if confirm.lower() not in ['yes', 'да', 'y', 'д']:
        return
    
    print(Colors.OKGREEN + "\nЗапуск Terraform...\n" + Colors.ENDC)
    
    # Запуск скрипта развертывания
    script = PROJECT_ROOT / 'scripts' / 'auto-deploy-terraform.ps1'
    if platform.system() == 'Windows':
        subprocess.run(['powershell', '-File', str(script)])
    else:
        # На Linux используем bash версию
        bash_script = PROJECT_ROOT / 'scripts' / 'auto-deploy-terraform.sh'
        if bash_script.exists():
            subprocess.run(['bash', str(bash_script)])
        else:
            print(Colors.WARNING + "Bash скрипт не найден, используем terraform напрямую" + Colors.ENDC)
            os.chdir(PROJECT_ROOT / 'terraform')
            subprocess.run(['terraform', 'init'])
            subprocess.run(['terraform', 'apply'])

def deploy_docker_compose():
    """Развертывание через Docker Compose"""
    print(Colors.OKCYAN + "\n[DOCKER COMPOSE DEPLOYMENT]" + Colors.ENDC)
    print("Запустит сервисы локально через Docker Compose\n")
    
    if not check_command('docker'):
        print(Colors.FAIL + "Docker не установлен!" + Colors.ENDC)
        print("Установите с https://docs.docker.com/get-docker/")
        input(f"\n{t('continue')}...")
        return
    
    print("Это развертывание:")
    print("  - Запустит все сервисы локально")
    print("  - Создаст docker volumes для данных")
    print("  - Займет 5-10 минут\n")
    
    confirm = input(f"{t('confirm')}? ({t('yes')}/{t('no')}): ")
    if confirm.lower() not in ['yes', 'да', 'y', 'д']:
        return
    
    print(Colors.OKGREEN + "\nЗапуск Docker Compose...\n" + Colors.ENDC)
    
    os.chdir(PROJECT_ROOT)
    if platform.system() == 'Windows':
        script = PROJECT_ROOT / 'scripts' / 'start.ps1'
        subprocess.run(['powershell', '-File', str(script)])
    else:
        subprocess.run(['docker-compose', '-f', 'config/compose/base.yml', 'up', '-d'])

def deployment_menu():
    """Меню выбора метода развертывания"""
    options = [
        t('terraform_deploy'),
        t('ansible_deploy'),
        t('docker_deploy'),
        t('remote_deploy'),
        t('k8s_deploy'),
    ]
    
    while True:
        print_header()
        print_menu(t('deployment_method'), options)
        
        choice = get_choice(len(options))
        
        if choice == 0:
            break
        elif choice == 1:
            deploy_terraform()
            input(f"\n{t('continue')}...")
        elif choice == 3:
            deploy_docker_compose()
            input(f"\n{t('continue')}...")
        else:
            print(Colors.WARNING + "Эта опция пока не реализована" + Colors.ENDC)
            input(f"\n{t('continue')}...")

def view_status():
    """Показать статус развертывания"""
    print(Colors.OKCYAN + "\n[DEPLOYMENT STATUS]" + Colors.ENDC)
    
    if check_command('docker'):
        print("\nDocker контейнеры:")
        subprocess.run(['docker', 'ps', '-a'])
    else:
        print(Colors.WARNING + "Docker не установлен" + Colors.ENDC)
    
    input(f"\n{t('continue')}...")

def show_help():
    """Показать справку"""
    print(Colors.OKCYAN + "\n[СПРАВКА - МЕТОДЫ РАЗВЕРТЫВАНИЯ]" + Colors.ENDC)
    
    print("""
1. TERRAFORM (Рекомендуется для продакшена)
   - Создает 3 ВМ на Proxmox
   - Требует доступ к серверу Proxmox
   - Время: 30-45 минут
   - Результат: Полный 3-узловой кластер

2. DOCKER COMPOSE (Для локального тестирования)
   - Запускает все сервисы локально
   - Требует установленный Docker
   - Время: 5-10 минут
   - Результат: Локальный экземпляр CERES

ВКЛЮЧЕННЫЕ СЕРВИСЫ (20+):
  Core: PostgreSQL, Redis, Keycloak
  Apps: GitLab CE, Zulip, Nextcloud, Mayan EDMS
  Office: OnlyOffice, Collabora
  Monitoring: Prometheus, Grafana, Alertmanager
  Network: Caddy, WireGuard, Mailu
""")
    
    input(f"\n{t('continue')}...")

def select_language():
    """Выбор языка"""
    global LANG
    
    clear_screen()
    print(Colors.HEADER + "\n╔" + "═" * 78 + "╗" + Colors.ENDC)
    print(Colors.HEADER + "║" + " " * 20 + "SELECT LANGUAGE / ВЫБЕРИТЕ ЯЗЫК" + " " * 27 + "║" + Colors.ENDC)
    print(Colors.HEADER + "╚" + "═" * 78 + "╝\n" + Colors.ENDC)
    
    print("  1. English")
    print("  2. Русский")
    print()
    
    choice = input(">>> ")
    
    if choice == '1':
        LANG = 'en'
    elif choice == '2':
        LANG = 'ru'

def main_menu():
    """Главное меню"""
    options = [
        t('system_info'),
        t('deployment_method'),
        t('check_config'),
        t('view_status'),
        t('help'),
    ]
    
    while True:
        print_header()
        show_system_info()
        show_dependencies()
        check_configuration()
        
        print_menu(t('main_menu'), options)
        
        choice = get_choice(len(options))
        
        if choice == 0:
            print(Colors.OKGREEN + "\nДо свидания!" + Colors.ENDC)
            sys.exit(0)
        elif choice == 1:
            # Уже показано выше
            input(f"\n{t('continue')}...")
        elif choice == 2:
            deployment_menu()
        elif choice == 3:
            print_header()
            check_configuration()
            input(f"\n{t('continue')}...")
        elif choice == 4:
            print_header()
            view_status()
        elif choice == 5:
            print_header()
            show_help()

def main():
    """Главная функция"""
    # Выбор языка при первом запуске
    select_language()
    
    # Главное меню
    main_menu()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print(Colors.OKGREEN + "\n\nПрервано пользователем. До свидания!" + Colors.ENDC)
        sys.exit(0)
