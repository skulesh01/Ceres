# 🚀 Автоматическая Установка и Сборка

**CERES Platform v3.0.0** поддерживает автоматическую установку всех зависимостей при развертывании на целевой системе.

---

## 📋 Методы Сборки

### 1. 🐳 Docker Build (Рекомендуется)

**Преимущества:**
- ✅ Не требует локальной установки Go
- ✅ Воспроизводимая сборка
- ✅ Изолированное окружение
- ✅ Кросс-платформенная сборка

**Использование:**

```bash
# Linux/macOS
./scripts/docker-build.sh

# Windows
.\scripts\docker-build.ps1
```

Или через Docker Compose:

```bash
docker-compose run --rm ceres-builder
```

**Результат:**
```
bin/
├── ceres-linux-amd64
├── ceres-darwin-amd64
└── ceres-windows-amd64.exe
```

---

### 2. 🔧 Автоматическая Установка Go

Если Docker недоступен, система автоматически установит Go при первом развертывании:

**Linux/macOS:**
```bash
./scripts/setup-go.sh
```

**Windows:**
```powershell
.\scripts\setup-go.ps1
```

**Что делает скрипт:**
1. ✅ Проверяет наличие Go
2. ✅ Проверяет версию Go (требуется 1.21+)
3. ✅ Скачивает Go, если отсутствует
4. ✅ Устанавливает Go в систему
5. ✅ Настраивает PATH
6. ✅ Скачивает зависимости проекта
7. ✅ Собирает CERES CLI автоматически

---

### 3. 🏗️ Makefile Targets

**С Docker (без локального Go):**
```bash
make docker-build    # Сборка в Docker
make docker-run      # Запуск в Docker
```

**С локальным Go:**
```bash
make setup-go        # Автоустановка Go
make build           # Сборка для текущей платформы
make build-all       # Сборка для всех платформ
```

---

## 🎯 Сценарии Развертывания

### Сценарий 1: Сервер с Docker

```bash
# На целевом сервере
git clone https://github.com/skulesh01/ceres.git
cd ceres

# Собрать с помощью Docker
./scripts/docker-build.sh

# Запустить
./bin/ceres-linux-amd64 --help
```

### Сценарий 2: Сервер без Docker

```bash
# На целевом сервере
git clone https://github.com/skulesh01/ceres.git
cd ceres

# Автоматически установить Go и собрать
./scripts/setup-go.sh

# Запустить
./bin/ceres --help
```

### Сценарий 3: Windows Server

```powershell
# На целевом сервере
git clone https://github.com/skulesh01/ceres.git
cd ceres

# Автоматически установить Go и собрать
.\scripts\setup-go.ps1

# Запустить
.\bin\ceres.exe --help
```

### Сценарий 4: CI/CD Pipeline

```yaml
# .github/workflows/build.yml
name: Build CERES

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build with Docker
        run: |
          docker build -t ceres:latest .
          docker create --name temp ceres:latest
          docker cp temp:/build/bin/. ./bin/
          docker rm temp
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ceres-binaries
          path: bin/*
```

---

## 🔍 Проверка Зависимостей

Система автоматически проверяет наличие всех зависимостей:

### setup-go.sh проверяет:
- ✅ Go версия 1.21+
- ✅ git
- ✅ curl

### Docker проверяет:
- ✅ Docker Engine
- ✅ docker-compose (опционально)

---

## 📦 Минимальные Требования

### Для Docker-based сборки:
- Docker 20.10+
- 2 GB RAM
- 5 GB свободного места

### Для нативной сборки:
- Go 1.21+ (устанавливается автоматически)
- 1 GB RAM
- 2 GB свободного места

### Для runtime:
- kubectl 1.25+ (для K8s операций)
- terraform 1.5+ (для инфраструктуры)
- 512 MB RAM
- 100 MB свободного места

---

## 🚀 Quick Start для Новой Системы

**С Docker:**
```bash
curl -sSL https://get.docker.com | sh
git clone https://github.com/skulesh01/ceres.git
cd ceres && ./scripts/docker-build.sh
./bin/ceres-linux-amd64 deploy --dry-run
```

**Без Docker:**
```bash
git clone https://github.com/skulesh01/ceres.git
cd ceres && ./scripts/setup-go.sh
./bin/ceres deploy --dry-run
```

---

## 🔧 Troubleshooting

### Проблема: Docker не найден

```bash
# Ubuntu/Debian
curl -sSL https://get.docker.com | sh

# RHEL/CentOS
sudo yum install docker-ce

# macOS
brew install docker
```

### Проблема: Ошибка при установке Go

```bash
# Проверить доступ к интернету
curl -I https://go.dev/dl/

# Установить вручную
wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

### Проблема: Permission denied

```bash
# Добавить права на скрипты
chmod +x scripts/*.sh

# Или через Docker (не требует прав)
./scripts/docker-build.sh
```

---

## 📊 Сравнение Методов

| Метод | Go нужен? | Docker нужен? | Время сборки | Изоляция |
|-------|-----------|---------------|--------------|----------|
| **docker-build** | ❌ | ✅ | ~3 мин | ✅ Полная |
| **setup-go.sh** | ❌ (авто) | ❌ | ~5 мин | ⚠️ Системная |
| **make build** | ✅ | ❌ | ~30 сек | ⚠️ Системная |

---

## ✅ Финальная Проверка

После сборки проверьте работоспособность:

```bash
# Проверить версию
./bin/ceres version

# Проверить help
./bin/ceres --help

# Dry-run деплой
./bin/ceres deploy --dry-run --cloud aws --environment dev

# Проверить конфигурацию
./bin/ceres config show
```

**Ожидаемый вывод:**
```
CERES Platform v3.0.0
Cloud Infrastructure Deployment Tool

Available Commands:
  deploy      Deploy CERES platform
  status      Show deployment status
  config      Manage configuration
  validate    Validate infrastructure

Use "ceres [command] --help" for more information.
```

---

**Автор**: CERES Platform Team  
**Дата**: January 2026  
**Версия**: 3.0.0
