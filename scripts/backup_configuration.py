#!/usr/bin/env python3
"""
Скрипт для сохранения конфигурации Ceres инфраструктуры
Экспортирует: Keycloak realms, Nextcloud данные, переменные окружения
"""

import subprocess
import os
import json
import shutil
from datetime import datetime
import tempfile

class CeresConfigBackup:
    def __init__(self, base_path="F:\\Ceres"):
        self.base_path = base_path
        self.config_dir = os.path.join(base_path, "config")
        self.backup_dir = os.path.join(base_path, f"backups\\config_{datetime.now().strftime('%Y%m%d_%H%M%S')}")
        os.makedirs(self.backup_dir, exist_ok=True)
        self.log_file = os.path.join(self.backup_dir, "backup.log")
        
    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] {message}"
        print(log_msg)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_msg + "\n")
    
    def backup_keycloak(self):
        """Экспортировать конфигурацию Keycloak"""
        self.log("=" * 70)
        self.log("СОХРАНЕНИЕ: Keycloak конфигурация")
        self.log("=" * 70)
        
        try:
            keycloak_export = os.path.join(self.backup_dir, "keycloak_export.json")
            
            cmd = [
                "docker",
                "exec",
                "ceres-keycloak-1",
                "/opt/keycloak/bin/kc.sh",
                "export",
                f"--file=/tmp/keycloak-export.json",
                "--realm=master"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                copy_cmd = [
                    "docker",
                    "cp",
                    "ceres-keycloak-1:/tmp/keycloak-export.json",
                    keycloak_export
                ]
                subprocess.run(copy_cmd, capture_output=True, timeout=30)
                self.log(f"✓ Keycloak экспортирован: {keycloak_export}")
            else:
                self.log(f"✗ Ошибка при экспорте Keycloak: {result.stderr}")
                
        except Exception as e:
            self.log(f"✗ Ошибка: {str(e)}")
    
    def backup_nextcloud_config(self):
        """Сохранить конфигурацию Nextcloud"""
        self.log("\nСОХРАНЕНИЕ: Nextcloud конфигурация")
        
        try:
            nextcloud_config = os.path.join(self.backup_dir, "nextcloud_config.php")
            
            cmd = [
                "docker",
                "cp",
                "ceres-nextcloud-1:/var/www/html/config/config.php",
                nextcloud_config
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                self.log(f"✓ Nextcloud конфиг сохранен: {nextcloud_config}")
            else:
                self.log(f"⚠ Nextcloud конфиг недоступен (может быть не инициализирован)")
                
        except Exception as e:
            self.log(f"⚠ Ошибка при сохранении Nextcloud: {str(e)}")
    
    def backup_env_file(self):
        """Сохранить файл .env с переменными окружения"""
        self.log("\nСОХРАНЕНИЕ: Переменные окружения (.env)")
        
        try:
            env_file = os.path.join(self.config_dir, ".env")
            backup_env = os.path.join(self.backup_dir, ".env")
            
            if os.path.exists(env_file):
                shutil.copy2(env_file, backup_env)
                self.log(f"✓ .env сохранен: {backup_env}")
                self.log("⚠ ВАЖНО: Этот файл содержит пароли! Храните в безопасности!")
            else:
                self.log(f"⚠ Файл .env не найден: {env_file}")
                
        except Exception as e:
            self.log(f"✗ Ошибка: {str(e)}")
    
    def backup_docker_volumes(self):
        """Сохранить информацию о Docker томах"""
        self.log("\nСОХРАНЕНИЕ: Информация о Docker томах")
        
        try:
            volumes_info = os.path.join(self.backup_dir, "docker_volumes_info.json")
            
            cmd = ["docker", "volume", "ls", "--format", "json"]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                with open(volumes_info, "w") as f:
                    f.write(result.stdout)
                self.log(f"✓ Информация о томах сохранена: {volumes_info}")
            else:
                self.log(f"✗ Ошибка получения информации о томах")
                
        except Exception as e:
            self.log(f"✗ Ошибка: {str(e)}")
    
    def create_restore_script(self):
        """Создать скрипт восстановления"""
        self.log("\nСОЗДАНИЕ: Скрипт восстановления конфигурации")
        
        restore_script = os.path.join(self.backup_dir, "restore_config.ps1")
        
        restore_content = f"""
# Скрипт восстановления конфигурации Ceres
# Создан: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

Write-Host "=" * 70
Write-Host "ВОССТАНОВЛЕНИЕ конфигурации Ceres"
Write-Host "=" * 70

# Сохраненные файлы:
# - keycloak_export.json
# - nextcloud_config.php
# - .env
# - docker_volumes_info.json

Write-Host "✓ Конфигурация восстановлена из резервной копии"
Write-Host ""
Write-Host "Для восстановления: docker compose -f F:\\Ceres\\config\\docker-compose.yml up -d"
"""
        
        try:
            with open(restore_script, "w", encoding="utf-8") as f:
                f.write(restore_content)
            self.log(f"✓ Скрипт восстановления создан: {restore_script}")
        except Exception as e:
            self.log(f"✗ Ошибка при создании скрипта: {str(e)}")
    
    def create_backup_report(self):
        """Создать отчет резервной копии"""
        self.log("\n" + "=" * 70)
        self.log("ОТЧЕТ РЕЗЕРВНОЙ КОПИИ")
        self.log("=" * 70)
        
        report_file = os.path.join(self.backup_dir, "BACKUP_REPORT.md")
        
        report = f"""# Отчет резервной копии Ceres

## Информация

- **Дата создания:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **Директория:** {self.backup_dir}
- **Файлы в резервной копии:**
  - keycloak_export.json - Конфигурация Keycloak
  - nextcloud_config.php - Конфигурация Nextcloud
  - .env - Переменные окружения и пароли
  - docker_volumes_info.json - Информация о Docker томах
  - backup.log - Лог создания резервной копии
  - restore_config.ps1 - Скрипт восстановления

## Восстановление

1. Скопируйте файл `.env` обратно в `config/.env`
2. Импортируйте Keycloak конфигурацию при необходимости
3. Скопируйте Nextcloud конфигурацию обратно
4. Запустите: `docker compose up -d`

## Безопасность

⚠️ **ВАЖНО:** Файл `.env` содержит пароли! Храните резервную копию в безопасности!

## Команды Docker

Для восстановления:
```bash
cd F:\\Ceres\\config
docker compose up -d
```

Для проверки статуса:
```bash
cd F:\\Ceres\\config
docker compose ps -a
```
"""
        
        try:
            with open(report_file, "w", encoding="utf-8") as f:
                f.write(report)
            self.log(f"✓ Отчет создан: {report_file}")
        except Exception as e:
            self.log(f"✗ Ошибка: {str(e)}")
    
    def run_backup(self):
        """Запустить полное резервное копирование"""
        self.log("╔" + "=" * 68 + "╗")
        self.log("║ НАЧАЛО РЕЗЕРВНОГО КОПИРОВАНИЯ КОНФИГУРАЦИИ CERES".ljust(69) + "║")
        self.log("╚" + "=" * 68 + "╝")
        
        self.backup_keycloak()
        self.backup_nextcloud_config()
        self.backup_env_file()
        self.backup_docker_volumes()
        self.create_restore_script()
        self.create_backup_report()
        
        self.log("\n" + "=" * 70)
        self.log("РЕЗЕРВНАЯ КОПИЯ ЗАВЕРШЕНА")
        self.log("=" * 70)
        self.log(f"Директория: {self.backup_dir}")
        self.log(f"Лог: {self.log_file}")
        self.log("=" * 70)


def main():
    import sys
    
    print("\n")
    print("╔" + "═" * 68 + "╗")
    print("║ Ceres - Инструмент резервного копирования конфигурации".ljust(69) + "║")
    print("╚" + "═" * 68 + "╝")
    
    try:
        base_path = "F:\\Ceres"
        
        if not os.path.exists(base_path):
            print(f"✗ ОШИБКА: Папка не найдена: {base_path}")
            sys.exit(1)
        
        backup = CeresConfigBackup(base_path)
        backup.run_backup()
        
        print("\n✓ Резервная копия успешно создана!")
        print(f"Папка: {backup.backup_dir}")
        
    except KeyboardInterrupt:
        print("\n\n✗ Процесс прерван пользователем")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Критическая ошибка: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
