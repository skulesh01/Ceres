#Requires -RunAsAdministrator
<#
.SYNOPSIS
    CERES - Автоматический установщик для Proxmox
    
.DESCRIPTION
    Полностью автоматизированный запуск CERES платформы на Proxmox сервере.
    Для пользователей БЕЗ опыта программирования.
    
.NOTES
    Автор: CERES Team
    Версия: 2.0
    Дата: 31.12.2025
#>

# Красивый вывод
function Write-Title {
    param([string]$Text)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "➤ " -ForegroundColor Yellow -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Success {
    param([string]$Text)
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Error-Custom {
    param([string]$Text)
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $Text -ForegroundColor White
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ " -ForegroundColor Blue -NoNewline
    Write-Host $Text -ForegroundColor Gray
}

# Проверка зависимостей
function Test-Dependencies {
    Write-Step "Проверяю зависимости..."
    
    $missing = @()
    
    # Проверка PowerShell версии
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $missing += "PowerShell 5.0+"
    }
    
    # Проверка SSH клиента (встроен в Windows 10+)
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        Write-Info "Устанавливаю OpenSSH клиент..."
        Add-WindowsCapability -Online -Name OpenSSH.Client* | Out-Null
    }
    
    if ($missing.Count -gt 0) {
        Write-Error-Custom "Отсутствуют зависимости: $($missing -join ', ')"
        Write-Host ""
        Write-Host "Установите недостающие компоненты и запустите скрипт снова." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Success "Все зависимости в порядке"
}

# Главная функция
function Start-CeresDeployment {
    Clear-Host
    
    Write-Title "🚀 CERES - Автоматический установщик"
    
    Write-Host "Этот скрипт автоматически:" -ForegroundColor White
    Write-Host "  1. Упакует проект" -ForegroundColor Gray
    Write-Host "  2. Подключится к Proxmox" -ForegroundColor Gray
    Write-Host "  3. Загрузит файлы" -ForegroundColor Gray
    Write-Host "  4. Запустит установщик" -ForegroundColor Gray
    Write-Host "  5. Создаст виртуальные машины" -ForegroundColor Gray
    Write-Host "  6. Установит все сервисы" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Время установки: ~20 минут" -ForegroundColor Cyan
    Write-Host ""
    
    # Проверка зависимостей
    Test-Dependencies
    
    # Получение параметров
    Write-Host ""
    Write-Step "Настройка подключения к Proxmox"
    Write-Host ""
    
    $proxmoxIP = Read-Host "Введите IP адрес Proxmox сервера [192.168.1.3]"
    if ([string]::IsNullOrWhiteSpace($proxmoxIP)) { $proxmoxIP = "192.168.1.3" }
    
    $proxmoxUser = Read-Host "Введите пользователя Proxmox [root]"
    if ([string]::IsNullOrWhiteSpace($proxmoxUser)) { $proxmoxUser = "root" }
    
    $proxmoxPass = Read-Host "Введите пароль root" -AsSecureString
    $proxmoxPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($proxmoxPass)
    )
    
    Write-Host ""
    Write-Info "Подключение: ${proxmoxUser}@${proxmoxIP}"
    Write-Host ""
    
    $confirm = Read-Host "Начать установку? [Да/Нет]"
    if ($confirm -notmatch '^(y|yes|да|д)$') {
        Write-Host "Установка отменена." -ForegroundColor Yellow
        exit 0
    }
    
    # Создание папки для логов
    $logDir = Join-Path $PSScriptRoot "..\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir "deploy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    # Функция логирования
    function Write-Log {
        param([string]$Message)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
    
    try {
        Write-Host ""
        Write-Title "📦 Шаг 1/6: Упаковка проекта"
        Write-Log "Начало упаковки проекта"
        
        $projectRoot = Split-Path $PSScriptRoot -Parent
        $zipPath = Join-Path $env:TEMP "Ceres-deploy.zip"
        
        if (Test-Path $zipPath) {
            Remove-Item $zipPath -Force
        }
        
        Write-Step "Создаю архив..."
        
        # Исключаем ненужные папки
        $exclude = @("logs", ".git", "node_modules", "__pycache__", "*.log")
        
        Compress-Archive -Path "$projectRoot\*" -DestinationPath $zipPath -Force
        
        $zipSize = (Get-Item $zipPath).Length / 1MB
        Write-Success "Архив создан ($('{0:N2}' -f $zipSize) MB)"
        Write-Log "Архив создан: $zipPath ($zipSize MB)"
        
        Write-Host ""
        Write-Title "🔌 Шаг 2/6: Подключение к Proxmox"
        Write-Log "Подключение к Proxmox: $proxmoxIP"
        
        Write-Step "Проверяю подключение..."
        
        # Проверяем доступность хоста
        if (-not (Test-Connection -ComputerName $proxmoxIP -Count 2 -Quiet)) {
            Write-Error-Custom "Proxmox сервер не отвечает на ping"
            Write-Host ""
            Write-Host "Проверьте:" -ForegroundColor Yellow
            Write-Host "  • Правильность IP адреса" -ForegroundColor Gray
            Write-Host "  • Включен ли Proxmox сервер" -ForegroundColor Gray
            Write-Host "  • Сетевое подключение" -ForegroundColor Gray
            Write-Log "ERROR: Proxmox не отвечает на ping"
            exit 1
        }
        
        # Тест SSH подключения
        Write-Step "Проверяю SSH доступ..."
        
        # Создаем временный файл для пароля
        $passFile = Join-Path $env:TEMP "ceres_pass_$(Get-Random).txt"
        $proxmoxPassPlain | Out-File -FilePath $passFile -Encoding ASCII -NoNewline
        
        try {
            # Используем plink если есть (PuTTY), иначе встроенный SSH
            $sshResult = $null
            
            if (Get-Command plink -ErrorAction SilentlyContinue) {
                # PuTTY plink
                $sshResult = echo y | plink -ssh -pw $proxmoxPassPlain -batch ${proxmoxUser}@${proxmoxIP} "echo OK" 2>&1
            } else {
                # Встроенный OpenSSH Windows 10+
                # Отключаем проверку ключа хоста для первого подключения
                $env:TERM = "dumb"
                $sshOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o LogLevel=ERROR"
                
                # Создаем скрипт для expect-подобного поведения
                $expectScript = @"
`$password = Get-Content '$passFile'
`$process = Start-Process ssh -ArgumentList '$sshOpts ${proxmoxUser}@${proxmoxIP} "echo OK"' -NoNewWindow -PassThru -Wait -RedirectStandardInput `$input
"@
                
                # Пробуем подключиться с паролем
                try {
                    $sshResult = & ssh $sshOpts.Split() "${proxmoxUser}@${proxmoxIP}" "echo OK" 2>&1
                } catch {
                    throw "SSH connection failed"
                }
            }
            
            if ($LASTEXITCODE -ne 0 -or $sshResult -notmatch "OK") {
                throw "Authentication failed"
            }
        } catch {
            Write-Error-Custom "Не удалось подключиться к Proxmox"
            Write-Host ""
            Write-Host "Возможные причины:" -ForegroundColor Yellow
            Write-Host "  • Неверный пароль" -ForegroundColor Gray
            Write-Host "  • SSH не включен на Proxmox" -ForegroundColor Gray
            Write-Host "  • Брандмауэр блокирует SSH (порт 22)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Попробуйте:" -ForegroundColor Cyan
            Write-Host "  1. Откройте Proxmox web: https://${proxmoxIP}:8006" -ForegroundColor Gray
            Write-Host "  2. Проверьте пароль root" -ForegroundColor Gray
            Write-Host "  3. Включите SSH в настройках" -ForegroundColor Gray
            Write-Log "ERROR: SSH подключение не удалось: $_"
            
            if (Test-Path $passFile) { Remove-Item $passFile -Force }
            exit 1
        } finally {
            if (Test-Path $passFile) { Remove-Item $passFile -Force }
        }
        
        Write-Success "Подключение успешно"
        Write-Log "SSH подключение успешно"
        
        Write-Host ""
        Write-Title "📤 Шаг 3/6: Загрузка файлов"
        Write-Log "Загрузка архива на Proxmox"
        
        Write-Step "Загружаю архив на сервер..."
        
        # Создаем временный скрипт для plink/pscp с паролем
        $plinkAvailable = Get-Command plink -ErrorAction SilentlyContinue
        $pscpAvailable = Get-Command pscp -ErrorAction SilentlyContinue
        
        try {
            if ($pscpAvailable) {
                # Используем PuTTY pscp
                & pscp -pw $proxmoxPassPlain -batch $zipPath "${proxmoxUser}@${proxmoxIP}:/tmp/Ceres-deploy.zip" 2>&1 | Out-Null
                
                if ($LASTEXITCODE -ne 0) {
                    throw "pscp failed with exit code $LASTEXITCODE"
                }
            } else {
                # Используем встроенный SCP (требует интерактивного ввода пароля)
                Write-Info "Встроенный SCP требует интерактивного ввода пароля"
                Write-Host "Пароль: " -NoNewline -ForegroundColor Yellow
                Write-Host $proxmoxPassPlain -ForegroundColor Gray
                Write-Host ""
                
                $scpOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL"
                
                # Попытка с использованием temporary batch
                $batchScript = @"
@echo off
echo $proxmoxPassPlain
"@
                $batchFile = Join-Path $env:TEMP "ceres_scp_$(Get-Random).bat"
                $batchScript | Out-File -FilePath $batchFile -Encoding ASCII
                
                try {
                    cmd /c "$batchFile | scp $scpOpts $zipPath ${proxmoxUser}@${proxmoxIP}:/tmp/Ceres-deploy.zip 2>&1"
                    
                    if ($LASTEXITCODE -ne 0) {
                        throw "scp failed"
                    }
                } finally {
                    if (Test-Path $batchFile) { Remove-Item $batchFile -Force }
                }
            }
        } catch {
            Write-Error-Custom "Не удалось загрузить архив"
            Write-Host ""
            Write-Host "Альтернативный способ:" -ForegroundColor Yellow
            Write-Host "  1. Откройте Proxmox Web UI: https://${proxmoxIP}:8006" -ForegroundColor Gray
            Write-Host "  2. Зайдите в Shell" -ForegroundColor Gray
            Write-Host "  3. Загрузите файл вручную через Upload" -ForegroundColor Gray
            Write-Host "  4. Или используйте WinSCP для загрузки" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Файл для загрузки: $zipPath" -ForegroundColor Cyan
            Write-Host "Загрузите его в: /tmp/Ceres-deploy.zip" -ForegroundColor Cyan
            Write-Log "ERROR: Ошибка загрузки: $_"
            
            $manual = Read-Host "`nФайл загружен вручную? (yes/no)"
            if ($manual -ne "yes") {
                exit 1
            }
        }
        
        Write-Success "Архив загружен на сервер"
        Write-Log "Архив загружен успешно"
        
        Write-Host ""
        Write-Title "🚀 Шаг 4/6: Запуск установщика"
        Write-Log "Запуск deploy-wizard.sh"
        
        Write-Step "Распаковываю проект на сервере..."
        
        # Распаковка и запуск
        $setupScript = @"
set -e
mkdir -p /opt/Ceres
cd /opt/Ceres
unzip -o /tmp/Ceres-deploy.zip
[ -d Ceres ] && mv Ceres/* . && rmdir Ceres || true
find . -name "*.sh" -exec sed -i 's/\r$//' {} \; -exec chmod +x {} \;
echo "Проект распакован"
"@
        
        try {
            if (Get-Command plink -ErrorAction SilentlyContinue) {
                echo $setupScript | plink -ssh -pw $proxmoxPassPlain -batch ${proxmoxUser}@${proxmoxIP} "bash -s" 2>&1
            } else {
                $setupScript | ssh -o StrictHostKeyChecking=no ${proxmoxUser}@${proxmoxIP} "bash -s"
            }
        } catch {
            Write-Error-Custom "Ошибка распаковки проекта"
            Write-Log "ERROR: Ошибка распаковки: $_"
            exit 1
        }
        
        Write-Success "Проект распакован"
        Write-Log "Проект распакован"
        
        Write-Host ""
        Write-Info "Запускаю интерактивный установщик..."
        Write-Info "Следуйте инструкциям на экране"
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        Start-Sleep -Seconds 2
        
        # Запуск установщика
        $deployCmd = "cd /opt/Ceres && bash scripts/deploy-wizard.sh"
        
        Write-Info "Запускаю SSH сессию..."
        Write-Info "Нажмите Enter для ввода пароля когда запросит"
        Write-Host ""
        
        try {
            if (Get-Command plink -ErrorAction SilentlyContinue) {
                # PuTTY plink с интерактивной сессией
                & plink -ssh -pw $proxmoxPassPlain -t ${proxmoxUser}@${proxmoxIP} $deployCmd
            } else {
                # Встроенный SSH
                Write-Host "Пароль для SSH: " -NoNewline -ForegroundColor Yellow
                Write-Host $proxmoxPassPlain -ForegroundColor Gray
                Write-Host ""
                
                $sshOpts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL"
                
                # Интерактивная SSH сессия
                & ssh $sshOpts.Split() -t "${proxmoxUser}@${proxmoxIP}" $deployCmd
            }
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Установщик завершился с кодом $LASTEXITCODE"
            }
        } catch {
            Write-Error-Custom "Ошибка при запуске установщика"
            Write-Log "ERROR: Ошибка установщика: $_"
            Write-Host ""
            Write-Host "Вы можете запустить установку вручную:" -ForegroundColor Yellow
            Write-Host "  1. Подключитесь к Proxmox: ssh root@$proxmoxIP" -ForegroundColor Gray
            Write-Host "  2. Выполните: cd /opt/Ceres" -ForegroundColor Gray
            Write-Host "  3. Запустите: bash scripts/deploy-wizard.sh" -ForegroundColor Gray
            exit 1
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Title "🎉 Установка завершена!"
        Write-Log "Установка завершена успешно"
        
        Write-Host ""
        Write-Success "CERES успешно развёрнут на Proxmox!"
        Write-Host ""
        Write-Host "Следующие шаги:" -ForegroundColor Cyan
        Write-Host "  1. Добавьте записи в hosts файл (см. QUICKSTART.md)" -ForegroundColor White
        Write-Host "  2. Откройте https://nextcloud.ceres.local в браузере" -ForegroundColor White
        Write-Host "  3. Войдите: admin / admin" -ForegroundColor White
        Write-Host "  4. Смените пароли!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Документация: QUICKSTART.md" -ForegroundColor Gray
        Write-Host "Логи: $logFile" -ForegroundColor Gray
        Write-Host ""
        
    } catch {
        Write-Host ""
        Write-Title "❌ Ошибка установки"
        Write-Error-Custom $_.Exception.Message
        Write-Log "FATAL ERROR: $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Логи сохранены: $logFile" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Обратитесь за помощью с содержимым лог-файла." -ForegroundColor Cyan
        exit 1
    }
}

# Запуск
Start-CeresDeployment
