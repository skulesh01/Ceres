# CERES Cross-Platform Support Guide

## Поддерживаемые платформы

CERES работает на:
- ✅ **Windows 10/11** (PowerShell 5.1+)
- ✅ **Linux** (PowerShell Core 7.0+, CentOS/Ubuntu/Debian)
- ✅ **macOS** (PowerShell Core 7.0+, Intel/Apple Silicon)

## Установка PowerShell Core

### Windows 10/11
PowerShell 5.1 встроенный, но рекомендуется PowerShell Core 7+:
```powershell
winget install Microsoft.PowerShell
# или через Chocolatey:
choco install powershell-core
```

### Ubuntu/Debian
```bash
# Добавить репозиторий Microsoft
wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
apt-get update

# Установить PowerShell
apt-get install -y powershell
```

### CentOS/RHEL
```bash
yum install -y powershell
```

### macOS
```bash
# Через Homebrew (рекомендуется)
brew install powershell

# Или загрузить напрямую
# https://github.com/PowerShell/PowerShell/releases
```

## Проверка установки

```powershell
powershell --version
pwsh --version

# Проверить ОС
$PSVersionTable
```

## Кроссплатформенные функции

### Platform.ps1 модуль

Используйте встроенный модуль для кроссплатформенного кода:

```powershell
. ./scripts/_lib/Platform.ps1

# Получить информацию о платформе
$platform = Get-PlatformInfo
Write-Host "OS: $($platform.OS)"
Write-Host "Is Windows: $($platform.IsWindows)"
Write-Host "Is Linux: $($platform.IsLinux)"

# Получить ресурсы (работает везде)
$cpu = Get-CPUCores
$ram = Get-MemoryGB
$disk = Get-DiskSpaceGB

# Проверить Docker и Kubectl
if (Test-DockerAvailable) {
    Write-Host "Docker: OK"
}
```

### Получение системных ресурсов

```powershell
# ПРАВИЛЬНО (кроссплатформенно):
$cpu = Get-CPUCores                    # Работает везде
$ram = Get-MemoryGB                    # Работает везде
$disk = Get-DiskSpaceGB                # Работает везде

# НЕПРАВИЛЬНО (только Windows):
$cpu = (Get-CimInstance Win32_Processor).NumberOfLogicalProcessors  # ❌ Не работает на Linux
$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory   # ❌ Не работает на Linux
```

## Примеры кроссплатформенного кода

### Чтение файла (кроссплатформенно)

```powershell
# ПРАВИЛЬНО - работает везде:
$content = Get-Content $filePath -Raw
$json = $content | ConvertFrom-Json

# НЕПРАВИЛЬНО - Windows only:
$registry = Get-ItemProperty HKLM:\Software\...  # ❌ Не работает на Linux
```

### Переменные окружения

```powershell
# ПРАВИЛЬНО:
$env:MY_VAR = "value"      # Работает везде
Write-Host $env:MY_VAR      # Работает везде

# НЕПРАВИЛЬНО:
$env:SYSTEMROOT             # ❌ Windows only
$env:PATH                   # Работает везде, но разный формат (: vs ;)
```

### Пути файлов

```powershell
# ПРАВИЛЬНО (используйте Join-Path):
$path = Join-Path $root "config" "profiles"  # Автоматически добавляет \ или /

# НЕПРАВИЛЬНО (hardcoded backslash):
$path = "$root\config\profiles"              # ❌ Не работает на Linux
$path = "C:\Ceres\config"                    # ❌ Не работает на Linux/Mac
```

### Запуск команд OS

```powershell
# ПРАВИЛЬНО - использование встроенного модуля:
Invoke-OSCommand `
    -WindowsCmd 'Get-Volume C:' `
    -UnixCmd 'df /dev/root'

# Или явная проверка:
if ($PSVersionTable.Platform -eq "Win32NT") {
    Get-Volume C:
} else {
    df /
}
```

## Тестирование на разных платформах

### Локальное тестирование на Windows

```powershell
# Запустить на Windows
powershell -File scripts/ceres.ps1 analyze resources
```

### Тестирование в Docker контейнере

```bash
# Прямо на Linux/Mac:
docker run -it mcr.microsoft.com/powershell:latest pwsh

# Внутри контейнера:
pwsh -File scripts/ceres.ps1 analyze resources
```

### Тестирование на реальной машине

```bash
# На Linux/Mac сервере:
git clone https://github.com/yourorg/Ceres.git
cd Ceres

pwsh -File scripts/ceres.ps1 analyze resources
```

## Известные различия между платформами

### Пути файлов
| Платформа | Разделитель | Пример |
|-----------|------------|--------|
| Windows | `\` | `C:\Users\Name` |
| Linux | `/` | `/home/user` |
| macOS | `/` | `/Users/name` |

**Решение:** Всегда используйте `Join-Path`

### Переменные окружения
| Платформа | Разделитель PATH |
|-----------|---------|
| Windows | `;` |
| Linux/Mac | `:` |

**Решение:** PowerShell автоматически преобразует при использовании `$env:PATH`

### Получение памяти
| Платформа | Способ | Файл/Команда |
|-----------|--------|------------|
| Windows | WMI | `Get-CimInstance` |
| Linux | /proc | `/proc/meminfo` |
| macOS | sysctl | `vm_stat` или `sysctl hw.memsize` |

**Решение:** Используйте функцию `Get-MemoryGB` из Platform.ps1

## Проблемы и решения

### ❌ "Get-CimInstance not available on Linux"

```powershell
# НЕПРАВИЛЬНО:
$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory

# ПРАВИЛЬНО:
$ram = Get-MemoryGB
```

### ❌ "Cannot find path C:\Users\..."

```powershell
# НЕПРАВИЛЬНО:
$home = "C:\Users\MyName"

# ПРАВИЛЬНО:
$home = $HOME              # Или
$home = $env:USERPROFILE   # На Windows
```

### ❌ "Docker command not found"

```powershell
# Проверить наличие Docker:
if (Test-DockerAvailable) {
    docker ps
} else {
    Write-Error "Docker is not installed or not running"
}
```

### ❌ "Permission denied on /proc/meminfo"

Это нормально - некоторые файлы требуют sudo на Linux. Функции обработают это:

```powershell
$ram = Get-MemoryGB  # Обработает ошибку и вернет значение по умолчанию
```

## Как добавить поддержку новой платформы

1. Добавьте функцию проверки в Platform.ps1:
```powershell
function Get-IsMyPlatform {
    return $PSVersionTable.OS -like "*MyOS*"
}
```

2. Используйте её в модулях:
```powershell
if (Get-IsMyPlatform) {
    # Специфический код для этой платформы
}
```

## CI/CD тестирование кроссплатформенности

GitHub Actions workflow проверяет на всех платформах:

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    pwsh-version: ['7.0', '7.1', '7.2', '7.3']

steps:
  - name: Test on ${{ matrix.os }}
    run: pwsh -File scripts/ceres.ps1 analyze resources
```

## Дополнительные ресурсы

- [PowerShell Core на GitHub](https://github.com/PowerShell/PowerShell)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Cross-platform scripting guide](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)
- [$PSVersionTable reference](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables?view=powershell-7.2#psversiontable)

## Контрольный список для разработчиков

При добавлении новой функции проверьте:

- [ ] Не используется `Get-CimInstance Win32_*`
- [ ] Не используется прямой путь с `\` или `C:\`
- [ ] Используется `Join-Path` для путей
- [ ] Используется $HOME вместо hardcoded пути
- [ ] Проверены оба пути в if-else для Windows/Linux
- [ ] Тестировано на Windows PowerShell 5.1
- [ ] Тестировано на PowerShell Core (pwsh)
- [ ] Тестировано на Linux
- [ ] Документация обновлена

---

**Вопросы?** Проверьте [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) или создайте issue.
