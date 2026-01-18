# ✅ Проверка перед развертыванием Ceres

## 📋 Быстрая проверка

### 1. Git репозиторий

Проверить:
```powershell
cd "E:\Новая папка\All_project\Ceres"
git status
```

**Если Git не инициализирован:**
```powershell
git init
git remote add origin https://github.com/skulesh01/Ceres.git
```

**Если remote не настроен:**
```powershell
git remote add origin https://github.com/skulesh01/Ceres.git
git remote -v  # Проверить
```

### 2. Ceres-Private

Проверить:
```powershell
cd "E:\Новая папка\All_project"
Test-Path "Ceres-Private"
Test-Path "Ceres-Private\credentials.json"
Test-Path "Ceres-Private\launcher.py"
```

**Если Ceres-Private отсутствует:**
- Создайте папку `Ceres-Private` рядом с `Ceres`
- Создайте `credentials.json` с паролями
- Скопируйте `launcher.py` и `deploy-to-proxmox.py`

### 3. Python

Проверить:
```powershell
python --version
# или
python3 --version
```

**Если Python не найден:**
- Установите Python 3.7+ с https://python.org
- Добавьте в PATH

### 4. Скрипты развертывания

Проверить наличие созданных скриптов:
```powershell
cd "E:\Новая папка\All_project\Ceres"
Test-Path "scripts\deploy-to-server.ps1"
Test-Path "scripts\git-auto-push.ps1"
Test-Path "scripts\deploy-and-sync.ps1"
Test-Path "scripts\check-deployment-ready.ps1"
```

## 🚀 Автоматическая проверка

Запустить скрипт проверки:
```powershell
cd "E:\Новая папка\All_project\Ceres"
.\scripts\check-deployment-ready.ps1
```

Скрипт проверит:
- ✅ Git репозиторий и remote
- ✅ Ceres-Private и credentials
- ✅ Python установлен
- ✅ Скрипты развертывания
- ✅ Docker Compose файлы
- ✅ .gitignore защищает приватные файлы
- ✅ Статус изменений в репозитории

## 📝 Результаты проверки

После запуска скрипт покажет:
- **Errors** (критичные) - требуют исправления
- **Warnings** (предупреждения) - опционально, но рекомендуется

## ✅ После успешной проверки

### Вариант 1: Развертывание + синхронизация
```powershell
.\scripts\deploy-and-sync.ps1 -DeployMode deploy -PushChanges
```

### Вариант 2: Только развертывание
```powershell
.\scripts\deploy-to-server.ps1 -Mode deploy
```

### Вариант 3: Только пуш на GitHub
```powershell
.\scripts\git-auto-push.ps1 -AutoCommit
```

## 🔧 Решение проблем

### Git репозиторий не инициализирован
```powershell
cd "E:\Новая папка\All_project\Ceres"
git init
git branch -M main  # Если нужно переименовать в main
git remote add origin https://github.com/skulesh01/Ceres.git
```

### GitHub remote не настроен
```powershell
git remote add origin https://github.com/skulesh01/Ceres.git
git remote set-url origin https://github.com/skulesh01/Ceres.git  # Изменить URL
```

### Ceres-Private не найден
- Убедитесь что папка находится рядом с Ceres:
  ```
  All_project/
  ├── Ceres/
  └── Ceres-Private/  ← должна быть здесь
  ```

### Python не найден
- Установите Python 3.7+ 
- Проверьте PATH: `$env:PATH`
- Или используйте полный путь к python.exe

---

**Следующий шаг:** Запустите `.\scripts\check-deployment-ready.ps1` для полной проверки! ✅
