#!/bin/bash
# CERES Deploy Launcher for Linux
# Проверяет Python и запускает главное приложение

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_APP="$SCRIPT_DIR/ceres-deploy.py"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=================================================="
echo "  CERES Platform - Starting Deployment Center"
echo "=================================================="
echo ""

# Проверка Python
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
        echo -e "${GREEN}[OK]${NC} Python найден: $PYTHON_VERSION"
        return 0
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
        PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')
        echo -e "${GREEN}[OK]${NC} Python найден: $PYTHON_VERSION"
        return 0
    else
        return 1
    fi
}

# Установка Python
install_python() {
    echo -e "${YELLOW}[WARN]${NC} Python не найден. Устанавливаю..."
    
    # Определяем дистрибутив Linux
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        echo "Обнаружен Debian/Ubuntu"
        sudo apt-get update
        sudo apt-get install -y python3 python3-pip
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        echo "Обнаружен RHEL/CentOS/Fedora"
        sudo yum install -y python3 python3-pip
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        echo "Обнаружен Arch Linux"
        sudo pacman -S --noconfirm python python-pip
    else
        echo -e "${RED}[ERROR]${NC} Неизвестный дистрибутив Linux"
        echo "Установите Python 3.8+ вручную: https://www.python.org/downloads/"
        exit 1
    fi
    
    # Проверяем установку
    if check_python; then
        echo -e "${GREEN}[OK]${NC} Python успешно установлен"
    else
        echo -e "${RED}[ERROR]${NC} Не удалось установить Python"
        exit 1
    fi
}

# Проверка зависимостей Python
check_python_deps() {
    echo "Проверка Python зависимостей..."
    
    $PYTHON_CMD -c "import psutil" 2>/dev/null || {
        echo "Устанавливаю psutil..."
        $PYTHON_CMD -m pip install psutil --quiet
    }
}

# Основная логика
if ! check_python; then
    install_python
fi

# Проверка зависимостей
check_python_deps

# Запуск главного приложения
echo ""
echo "Запуск CERES Deploy..."
echo ""

chmod +x "$PYTHON_APP"
exec $PYTHON_CMD "$PYTHON_APP" "$@"
