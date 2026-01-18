#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CERES Private - Deployment Launcher
Главная точка входа для развертывания
"""

import sys
import json
from pathlib import Path

# Загружаем credentials
CREDS_FILE = Path(__file__).parent / 'credentials.json'
creds = json.loads(CREDS_FILE.read_text())

print("=" * 80)
print("              CERES PRIVATE — ЗАПУСК РАЗВЕРТЫВАНИЯ")
print("=" * 80)
print("\nВнимание: здесь реальные учётные данные и пароли!")
print("Убедитесь, что эта папка НЕ в Git.\n")

print("Доступные действия:\n")
print("  1. Полное развертывание на Proxmox (45–75 мин)")
print("  2. Настроить SSH-ключи (доступ без пароля)")
print("  3. Показать все учётные данные")
print("  4. Тест подключения к Proxmox")
print("  0. Выход\n")

choice_raw = input("Выберите действие: ").strip()
# Допускать ввод вида "1. ..." или "1) ..." и пр.
if choice_raw.startswith('1'):
    choice = '1'
elif choice_raw.startswith('2'):
    choice = '2'
elif choice_raw.startswith('3'):
    choice = '3'
elif choice_raw.startswith('4'):
    choice = '4'
elif choice_raw.startswith('0'):
    choice = '0'
else:
    choice = choice_raw

if choice == '1':
    print("\nЗапускаю полное развертывание…")
    # Запускаем соседний скрипт как процесс (надёжно для имён с дефисами)
    import subprocess
    from pathlib import Path
    base = Path(__file__).parent
    candidates = [
        'deploy_to_proxmox.py',
        'deploy-to-proxmox.py',
        'remote-deploy.py'
    ]
    for name in candidates:
        p = base / name
        if p.exists():
            code = subprocess.call([sys.executable, str(p)])
            sys.exit(code)
    print("[ОШИБКА] Не найден скрипт развертывания рядом с launcher.py")
    sys.exit(1)
    
elif choice == '2':
    print("\nНастраиваю SSH-ключи…")
    import subprocess
    from pathlib import Path
    base = Path(__file__).parent
    candidates = [
        'setup_ssh.py',
        'setup-ssh.py',
        'setup-ssh.ps1'
    ]
    for name in candidates:
        p = base / name
        if p.exists():
            if p.suffix == '.ps1':
                code = subprocess.call(['pwsh', '-File', str(p)])
            else:
                code = subprocess.call([sys.executable, str(p)])
            sys.exit(code)
    print("[ОШИБКА] Не найден скрипт настройки SSH рядом с launcher.py")
    sys.exit(1)
    
elif choice == '3':
    print("\n" + "=" * 80)
    print("                    ВСЕ УЧЁТНЫЕ ДАННЫЕ")
    print("=" * 80 + "\n")

    print("PROXMOX:")
    print(f"  Хост:     {creds['proxmox']['host']}")
    print(f"  Пользователь:     {creds['proxmox']['user']}")
    print(f"  Пароль: {creds['proxmox']['password']}\n")

    print("Виртуальные машины:")
    for vm_name, vm_data in creds.get('vms', {}).items():
        ip = vm_data.get('ip', 'N/A')
        ssh_user = vm_data.get('ssh_user', 'root')
        ssh_pass = vm_data.get('ssh_password', '***')
        print(f"  {vm_name.upper()}: {ip} (ssh: {ssh_user}/{ssh_pass})")

    print("\nСервисы:")
    for svc_name, svc_data in creds.get('services', {}).items():
        admin_user = svc_data.get('admin_user')
        admin_pass = svc_data.get('admin_password')
        url = svc_data.get('url', 'N/A')
        if admin_user and admin_pass:
            print(f"  {svc_name}: {url} ({admin_user}/{admin_pass})")

    print("\n" + "=" * 80)
    input("\nНажмите Enter, чтобы продолжить…")
    
elif choice == '4':
    print("\nТест подключения…")
    try:
        import paramiko
    except ImportError:
        print("Устанавливаю paramiko…")
        import subprocess
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'paramiko', '--quiet'])
        import paramiko
    
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(
            creds['proxmox']['host'],
            username=creds['ssh']['user'],
            password=creds['ssh']['password'],
            timeout=5
        )
        print(f"[OK] Подключение установлено: {creds['proxmox']['host']}")
        
        stdin, stdout, stderr = ssh.exec_command('pveversion')
        version = stdout.read().decode().strip()
        print(f"[OK] Версия Proxmox: {version}")
        
        ssh.close()
    except Exception as e:
        print(f"[ОШИБКА] Подключение не удалось: {e}")

    input("\nНажмите Enter, чтобы продолжить…")
    
elif choice == '0':
    print("До свидания!")
    sys.exit(0)
    
else:
    print("Недопустимый выбор!")
    sys.exit(1)
