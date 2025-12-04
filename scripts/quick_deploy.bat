@echo off
setlocal enabledelayedexpansion

REM Скрипт быстрого восстановления и запуска инфраструктуры Ceres

color 0A
cls

echo.
echo ==========================================
echo   CERES Quick Deploy - Быстрое развёртывание
echo ==========================================
echo.

REM Проверить Docker
docker --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker не найден или не запущен!
    echo Пожалуйста, запустите Docker Desktop.
    pause
    exit /b 1
)

REM Перейти в папку config
cd /d F:\Ceres\config
if errorlevel 1 (
    echo [ERROR] Не удалось перейти в F:\Ceres\config
    pause
    exit /b 1
)

echo [INFO] Docker найден: 
docker --version

echo.
echo [STEP 1] Загрузка переменных окружения из .env...
if not exist .env (
    echo [WARNING] .env файл не найден!
    echo Используем .env.example
    if exist .env.example (
        copy .env.example .env
    ) else (
        echo [ERROR] .env.example тоже не найден!
        pause
        exit /b 1
    )
)
echo [OK] .env загружен

echo.
echo [STEP 2] Проверка docker-compose.yml...
if not exist docker-compose.yml (
    echo [ERROR] docker-compose.yml не найден!
    pause
    exit /b 1
)
echo [OK] docker-compose.yml найден

echo.
echo [STEP 3] Проверка существующих контейнеров...
docker compose ps -a
echo.

echo [STEP 4] Запуск инфраструктуры...
echo Это может занять 15-30 минут при первом запуске.
echo.

docker compose up -d

if errorlevel 1 (
    echo [ERROR] Ошибка при запуске docker compose!
    pause
    exit /b 1
)

echo.
echo ==========================================
echo   [OK] Инфраструктура запущена успешно!
echo ==========================================
echo.

echo [WAIT] Ожидание инициализации (30 секунд)...
timeout /t 30 /nobreak

echo.
echo [INFO] Проверка статуса контейнеров...
docker compose ps

echo.
echo ==========================================
echo   ИНФОРМАЦИЯ О ДОСТУПЕ
echo ==========================================
echo.
echo Не забудьте добавить записи в файл hosts:
echo   C:\Windows\System32\drivers\etc\hosts
echo.
echo Пример записей:
echo   127.0.0.1 Ceres.local
echo   127.0.0.1 auth.Ceres.local
echo   127.0.0.1 taiga.Ceres.local
echo.
echo Основные ссылки:
echo   Keycloak:  https://auth.Ceres.local  (admin / K3yClo@k!2025)
echo   Taiga:     https://taiga.Ceres.local
echo   ProcessMaker: https://edm.Ceres.local
echo   Nextcloud: https://cloud.Ceres.local
echo.
echo ==========================================
echo.

echo [INFO] Для просмотра логов используйте:
echo   docker compose logs -f
echo.
echo [INFO] Для остановки используйте:
echo   docker compose down
echo.

pause
