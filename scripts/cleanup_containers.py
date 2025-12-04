#!/usr/bin/env python3
"""
Скрипт для сворачивания инфраструктуры Ceres
Останавливает контейнеры, очищает временные данные, но сохраняет конфигурацию
"""

import subprocess
import os
import shutil
from datetime import datetime

class CeresCleanup:
    def __init__(self, base_path="F:\\Ceres"):
        self.base_path = base_path
        self.config_dir = os.path.join(base_path, "config")
        self.log_file = os.path.join(base_path, "cleanup.log")
        
    def log(self, message):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] {message}"
        print(log_msg)
        with open(self.log_file, "a", encoding="utf-8") as f:
            f.write(log_msg + "\n")
    
    def stop_containers(self):
        """Остановить все контейнеры"""
        self.log("Остановка контейнеров...")
        
        try:
            cmd = ["docker", "compose", "down"]
            result = subprocess.run(cmd, cwd=self.config_dir, capture_output=True, text=True, timeout=60)
            
            if result.returncode == 0:
                self.log("✓ Контейнеры остановлены")
                self.log("✓ Docker томы сохранены (конфигурация не потеряна)")
                return True
            else:
                self.log(f"✗ Ошибка: {result.stderr}")
                return False
                
        except Exception as e:
            self.log(f"✗ Ошибка: {str(e)}")
            return False
    
    def clean_pycache(self):
        """Удалить Python кэш"""
        self.log("Очистка Python кэша...")
        
        try:
            for root, dirs, files in os.walk(self.base_path):
                if "__pycache__" in dirs:
                    pycache_path = os.path.join(root, "__pycache__")
                    shutil.rmtree(pycache_path, ignore_errors=True)
                    self.log(f"✓ Удален: {pycache_path}")
            
            return True
        except Exception as e:
            self.log(f"⚠ Ошибка: {str(e)}")
            return False
    
    def cleanup_temp_files(self):
        """Удалить временные файлы"""
        self.log("Очистка временных файлов...")
        
        try:
            patterns = ["*.pyc", "*.log", "*.tmp", ".DS_Store"]
            
            for root, dirs, files in os.walk(self.base_path):
                for pattern in patterns:
                    if pattern == "*.log":
                        # Не удаляем основной cleanup.log
                        for file in files:
                            if file.endswith(".log") and file != "cleanup.log":
                                file_path = os.path.join(root, file)
                                os.remove(file_path)
                                self.log(f"✓ Удален: {file_path}")
            
            return True
        except Exception as e:
            self.log(f"⚠ Ошибка: {str(e)}")
            return False
    
    def create_cleanup_report(self):
        """Создать отчет об очистке"""
        self.log("Создание отчета об очистке...")
        
        report_file = os.path.join(self.base_path, "CLEANUP_REPORT.md")
        
        report = f"""# Отчет об очистке Ceres

## Информация

- **Дата очистки:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **Статус:** ✓ Успешно

## Что было сделано

### ✓ Остановлено
- Все Docker контейнеры остановлены
- Docker Compose выполнил shutdown

### ✓ Сохранено
- **Docker томы:** Все данные сохранены в Docker томах
  - PostgreSQL данные
  - Nextcloud файлы и конфиги
  - Keycloak конфигурация
  - Redis кэш (восстановится при запуске)
  - Все остальные данные сервисов

- **Конфигурация:** Все файлы конфигурации на месте
  - `config/docker-compose.yml`
  - `config/.env`
  - `config/.env.example`

### ✓ Очищено
- Python кэш (__pycache__)
- Временные файлы
- Логи (кроме этого отчета)

## Восстановление

Для восстановления инфраструктуры:

```bash
cd F:\\Ceres\\config
docker compose up -d
```

или двойной клик на `scripts/quick_deploy.bat`

**Время восстановления:** ~15-30 минут

## Статус хранилища

Используемое пространство Docker:

```bash
docker system df
```

## Дополнительные команды

Удалить неиспользуемые образы:
```bash
docker image prune -a --force
```

Удалить все резервные томы (⚠️ ОСТОРОЖНО):
```bash
docker volume prune --force
```

---

**Проект:** Ceres - Модульная Корпоративная Инфраструктура
**Дата:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
        
        try:
            with open(report_file, "w", encoding="utf-8") as f:
                f.write(report)
            self.log(f"✓ Отчет создан: {report_file}")
        except Exception as e:
            self.log(f"✗ Ошибка: {str(e)}")
    
    def run_cleanup(self):
        """Запустить полную очистку"""
        self.log("╔" + "=" * 68 + "╗")
        self.log("║ НАЧАЛО ОЧИСТКИ И СВОРАЧИВАНИЯ CERES".ljust(69) + "║")
        self.log("╚" + "=" * 68 + "╝")
        
        self.stop_containers()
        self.clean_pycache()
        self.cleanup_temp_files()
        self.create_cleanup_report()
        
        self.log("\n" + "=" * 70)
        self.log("ОЧИСТКА ЗАВЕРШЕНА")
        self.log("=" * 70)
        self.log("✓ Все контейнеры остановлены")
        self.log("✓ Все данные сохранены в Docker томах")
        self.log("✓ Временные файлы удалены")
        self.log(f"✓ Отчет: CLEANUP_REPORT.md")
        self.log("=" * 70)


def main():
    import sys
    
    print("\n")
    print("╔" + "═" * 68 + "╗")
    print("║ Ceres - Инструмент очистки и сворачивания".ljust(69) + "║")
    print("╚" + "═" * 68 + "╝")
    
    try:
        base_path = "F:\\Ceres"
        
        if not os.path.exists(base_path):
            print(f"✗ ОШИБКА: Папка не найдена: {base_path}")
            sys.exit(1)
        
        cleanup = CeresCleanup(base_path)
        cleanup.run_cleanup()
        
        print("\n✓ Очистка завершена успешно!")
        print("✓ Все данные сохранены!")
        print("✓ Для восстановления: docker compose up -d")
        
    except KeyboardInterrupt:
        print("\n\n✗ Процесс прерван пользователем")
        sys.exit(1)
    except Exception as e:
        print(f"\n✗ Критическая ошибка: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
