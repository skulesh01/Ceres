@echo off
:: CERES - One-Click Launcher
:: Просто запустите этот файл двойным кликом!

chcp 65001 >nul 2>&1
color 0B

echo.
echo ════════════════════════════════════════════════════════════
echo   🚀 CERES - Панель управления
echo ════════════════════════════════════════════════════════════
echo.
echo   Что можно делать:
echo.
echo     1. Установить CERES на Proxmox
echo     2. Настроить доступ к сервисам
echo     3. Первая настройка после установки
echo     4. Проверить статус
echo     5. Создать резервную копию
echo     6. И многое другое...
echo.
echo   Сейчас откроется интерактивное меню!
echo.
echo ════════════════════════════════════════════════════════════
echo.
echo   Нужна помощь? Откройте FAQ.md или НАЧАЛО.md
echo.
pause

:: Проверка наличия MENU.ps1
if exist "%~dp0MENU.ps1" (
    :: Запуск главного меню
    powershell -Command "Start-Process powershell -ArgumentList '-NoExit -ExecutionPolicy Bypass -File ""%~dp0MENU.ps1""' -Verb RunAs"
) else (
    :: Fallback на старый LAUNCH
    echo MENU.ps1 не найден, запускаю установщик...
    powershell -Command "Start-Process powershell -ArgumentList '-NoExit -ExecutionPolicy Bypass -File ""%~dp0scripts\LAUNCH.ps1""' -Verb RunAs"
)
