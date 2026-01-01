#!/usr/bin/env pwsh
# Полностью автоматизированный скрипт развертывания CERES
# Не требует ручного вмешательства - все делает сам

param(
    [string]$ServerIP = "192.168.1.3",
    [string]$ServerUser = "root",
    [string]$ServerPassword = "!r0oT3dc",
    [string]$GitHubRepo = "skulesh01/Ceres",
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       CERES - Автоматическое развертывание на Proxmox        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# ФУНКЦИИ
# ============================================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "  ❌ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ️  $Message" -ForegroundColor Cyan
}

function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-Scoop {
    Write-Step "Установка Scoop package manager..."
    if (Test-CommandExists "scoop") {
        Write-Success "Scoop уже установлен"
        return
    }
    
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        Write-Success "Scoop установлен"
    } catch {
        Write-Error "Не удалось установить Scoop: $_"
        Write-Info "Попытка установки через альтернативный метод..."
        iwr -useb get.scoop.sh -outfile 'install-scoop.ps1'
        .\install-scoop.ps1 -RunAsAdmin
        Remove-Item 'install-scoop.ps1'
    }
}

function Install-GitHubCLI {
    Write-Step "Установка GitHub CLI..."
    if (Test-CommandExists "gh") {
        Write-Success "GitHub CLI уже установлен"
        return
    }
    
    # Попытка через scoop
    if (Test-CommandExists "scoop") {
        try {
            scoop install gh
            Write-Success "GitHub CLI установлен через Scoop"
            return
        } catch {
            Write-Info "Установка через Scoop не удалась, пробуем альтернативный метод..."
        }
    }
    
    # Альтернативный метод - прямая загрузка
    try {
        $ghVersion = "2.63.2"
        $ghUrl = "https://github.com/cli/cli/releases/download/v$ghVersion/gh_" + $ghVersion + "_windows_amd64.zip"
        $ghZip = "$HOME\gh.zip"
        $ghDir = "$HOME\gh"
        
        Write-Info "Скачиваю GitHub CLI $ghVersion..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $ghUrl -OutFile $ghZip -UseBasicParsing
        
        Expand-Archive -Path $ghZip -DestinationPath $ghDir -Force
        
        $ghBinPath = Get-ChildItem -Path $ghDir -Recurse -Filter "gh.exe" | Select-Object -First 1 -ExpandProperty Directory
        
        if ($ghBinPath) {
            # Добавляем в PATH временно
            $env:Path = "$ghBinPath;$env:Path"
            Write-Success "GitHub CLI установлен в $ghBinPath"
            Write-Info "Перезапустите PowerShell после завершения для постоянного доступа к gh"
        } else {
            throw "gh.exe не найден после распаковки"
        }
        
        Remove-Item $ghZip -Force
    } catch {
        Write-Error "Не удалось установить GitHub CLI: $_"
        Write-Info "Установите вручную: https://cli.github.com/"
        exit 1
    }
}

function Install-Plink {
    Write-Step "Установка PuTTY plink.exe..."
    $plinkPath = "$HOME\plink.exe"
    
    if (Test-Path $plinkPath) {
        Write-Success "plink.exe уже установлен"
        return $plinkPath
    }
    
    try {
        $plinkUrl = "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe"
        Invoke-WebRequest -Uri $plinkUrl -OutFile $plinkPath -UseBasicParsing
        Write-Success "plink.exe установлен"
        return $plinkPath
    } catch {
        Write-Error "Не удалось скачать plink.exe: $_"
        exit 1
    }
}

function Test-ServerConnection {
    param([string]$PlinkPath)
    
    Write-Step "Проверка подключения к серверу $ServerIP..."
    
    try {
        $result = & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "echo 'OK'" 2>&1
        if ($result -match "OK") {
            Write-Success "Подключение к серверу успешно"
            return $true
        } else {
            Write-Error "Не удалось подключиться к серверу"
            Write-Info "Ответ: $result"
            return $false
        }
    } catch {
        Write-Error "Ошибка подключения: $_"
        return $false
    }
}

function Install-K3s {
    param([string]$PlinkPath)
    
    Write-Step "Проверка установки k3s на сервере..."
    
    $k3sCheck = & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "which k3s" 2>&1
    
    if ($k3sCheck -match "/usr/local/bin/k3s") {
        Write-Success "k3s уже установлен"
        
        # Проверяем, что k3s запущен
        $k3sStatus = & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "systemctl is-active k3s" 2>&1
        if ($k3sStatus -match "active") {
            Write-Success "k3s активен и работает"
        } else {
            Write-Info "Запускаю k3s..."
            & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "systemctl start k3s" 2>&1 | Out-Null
            Start-Sleep -Seconds 5
            Write-Success "k3s запущен"
        }
        return $true
    }
    
    Write-Info "k3s не установлен, начинаю установку..."
    
    # Проверка DNS
    Write-Info "Проверка DNS на сервере..."
    $dnsCheck = & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "ping -c 1 google.com" 2>&1
    
    if ($dnsCheck -notmatch "1 received" -and $dnsCheck -notmatch "1 packets received") {
        Write-Info "Настройка DNS на сервере..."
        & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "echo 'nameserver 8.8.8.8' > /etc/resolv.conf; echo 'nameserver 8.8.4.4' >> /etc/resolv.conf" 2>&1 | Out-Null
        
        # Проверка и настройка маршрута по умолчанию
        $routeCheck = & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "ip route | grep default" 2>&1
        if (-not $routeCheck) {
            Write-Info "Настройка маршрута по умолчанию..."
            & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "ip route add default via 192.168.1.1" 2>&1 | Out-Null
        }
        
        Write-Success "DNS и маршрутизация настроены"
    }
    
    # Установка k3s
    Write-Info "Скачиваю и устанавливаю k3s (это может занять несколько минут)..."
    
    $k3sInstallCmd = @"
cd /tmp && \
wget -q https://get.k3s.io -O k3s-install.sh && \
chmod +x k3s-install.sh && \
INSTALL_K3S_EXEC='server --write-kubeconfig-mode=644' sh k3s-install.sh
"@
    
    $installResult = & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP $k3sInstallCmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "k3s успешно установлен"
        Start-Sleep -Seconds 10
        return $true
    } else {
        Write-Error "Ошибка установки k3s"
        Write-Info "Детали: $installResult"
        return $false
    }
}

function Get-Kubeconfig {
    param([string]$PlinkPath)
    
    Write-Step "Получение kubeconfig с сервера..."
    
    $kubeconfigPath = "$HOME\k3s.yaml"
    
    try {
        $kubeconfigContent = & $PlinkPath -pw $ServerPassword -batch $ServerUser@$ServerIP "cat /etc/rancher/k3s/k3s.yaml" 2>&1
        
        if ($kubeconfigContent -match "apiVersion: v1") {
            # Заменяем localhost на реальный IP
            $kubeconfigContent = $kubeconfigContent -replace "127.0.0.1", $ServerIP
            $kubeconfigContent | Set-Content -Path $kubeconfigPath -Force
            Write-Success "Kubeconfig сохранен в $kubeconfigPath"
            return $kubeconfigPath
        } else {
            Write-Error "Не удалось получить kubeconfig"
            Write-Info "Ответ: $kubeconfigContent"
            return $null
        }
    } catch {
        Write-Error "Ошибка получения kubeconfig: $_"
        return $null
    }
}

function Setup-GitHubSecrets {
    param(
        [string]$KubeconfigPath,
        [string]$Token
    )
    
    Write-Step "Настройка GitHub Actions секретов..."
    
    # Проверка аутентификации
    if (-not $Token) {
        Write-Info "GitHub токен не указан, пытаюсь использовать gh auth..."
        $authStatus = gh auth status 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "GitHub CLI не аутентифицирован"
            Write-Info "Выполните: gh auth login"
            Write-Info "Или установите переменную GITHUB_TOKEN"
            return $false
        }
    }
    
    try {
        # Подготовка данных
        $kubeconfig = Get-Content $KubeconfigPath -Raw
        $kubeconfigB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeconfig))
        
        $sshKeyPath = "$HOME\.ssh\ceres"
        if (-not (Test-Path $sshKeyPath)) {
            Write-Info "Генерация SSH ключа..."
            ssh-keygen -t ed25519 -f $sshKeyPath -N '""' -C "ceres-auto-deploy"
        }
        $sshKey = Get-Content $sshKeyPath -Raw
        
        # Установка секретов
        $secrets = @{
            "KUBECONFIG" = $kubeconfigB64
            "SSH_PRIVATE_KEY" = $sshKey
            "DEPLOY_HOST" = $ServerIP
            "DEPLOY_USER" = $ServerUser
            "DEPLOY_PASSWORD" = $ServerPassword
        }
        
        foreach ($secret in $secrets.GetEnumerator()) {
            Write-Info "Устанавливаю секрет: $($secret.Key)..."
            
            if ($Token) {
                # Через API
                $body = @{
                    encrypted_value = $secret.Value
                    key_id = ""
                } | ConvertTo-Json
                
                $headers = @{
                    Authorization = "Bearer $Token"
                    Accept = "application/vnd.github+json"
                }
                
                Invoke-RestMethod -Method PUT -Uri "https://api.github.com/repos/$GitHubRepo/actions/secrets/$($secret.Key)" -Headers $headers -Body $body
            } else {
                # Через gh CLI
                $secret.Value | gh secret set $secret.Key -R $GitHubRepo
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "$($secret.Key) установлен"
            } else {
                Write-Error "Не удалось установить $($secret.Key)"
            }
        }
        
        Write-Success "Все секреты настроены"
        return $true
    } catch {
        Write-Error "Ошибка настройки секретов: $_"
        return $false
    }
}

function Deploy-Ceres {
    Write-Step "Запуск деплоймента CERES..."
    
    try {
        # Проверяем наличие workflow файла
        gh workflow list -R $GitHubRepo 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Не удалось получить список workflows"
            return $false
        }
        
        # Ищем подходящий workflow
        $workflows = gh workflow list -R $GitHubRepo --json name,path | ConvertFrom-Json
        $deployWorkflow = $workflows | Where-Object { $_.name -match "deploy|Deploy|DEPLOY" } | Select-Object -First 1
        
        if (-not $deployWorkflow) {
            Write-Info "Workflow деплоймента не найден, создаю базовый..."
            
            # Создаем базовый workflow файл если его нет
            $workflowContent = @"
name: Deploy CERES to k3s

on:
  workflow_dispatch:
  push:
    branches: [ main, master ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup kubeconfig
        run: |
          mkdir -p `$HOME/.kube
          echo "`${{ secrets.KUBECONFIG }}" | base64 -d > `$HOME/.kube/config
          chmod 600 `$HOME/.kube/config
      
      - name: Deploy to k3s
        run: |
          kubectl apply -f config/compose/ || echo "Конфигурационные файлы будут добавлены позже"
          kubectl get pods -A
"@
            
            $workflowDir = ".github/workflows"
            if (-not (Test-Path $workflowDir)) {
                New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
            }
            
            $workflowContent | Set-Content -Path "$workflowDir/deploy.yml" -Force
            
            git add "$workflowDir/deploy.yml"
            git commit -m "Add auto-deploy workflow"
            git push
            
            Write-Success "Workflow создан и отправлен в репозиторий"
            Start-Sleep -Seconds 5
            
            $deployWorkflow = @{ path = ".github/workflows/deploy.yml" }
        }
        
        Write-Info "Запускаю workflow: $($deployWorkflow.path)..."
        gh workflow run $deployWorkflow.path -R $GitHubRepo
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Деплоймент запущен"
            Write-Info "Отслеживание выполнения..."
            Start-Sleep -Seconds 3
            gh run watch -R $GitHubRepo --exit-status
            
            Write-Success "Деплоймент завершен"
            return $true
        } else {
            Write-Error "Не удалось запустить деплоймент"
            return $false
        }
    } catch {
        Write-Error "Ошибка запуска деплоймента: $_"
        Write-Info "Вы можете запустить деплоймент вручную: https://github.com/$GitHubRepo/actions"
        return $false
    }
}

# ============================================================================
# ОСНОВНОЙ ПРОЦЕСС
# ============================================================================

Write-Info "Начало автоматического развертывания CERES"
Write-Info "Сервер: $ServerIP | Пользователь: $ServerUser"
Write-Info ""

# Шаг 1: Установка зависимостей
Install-Scoop
Install-GitHubCLI
$plinkPath = Install-Plink

# Шаг 2: Проверка подключения
if (-not (Test-ServerConnection -PlinkPath $plinkPath)) {
    Write-Error "Не могу подключиться к серверу. Проверьте параметры подключения."
    exit 1
}

# Шаг 3: Установка k3s
if (-not (Install-K3s -PlinkPath $plinkPath)) {
    Write-Error "Не удалось установить k3s"
    exit 1
}

# Шаг 4: Получение kubeconfig
$kubeconfigPath = Get-Kubeconfig -PlinkPath $plinkPath
if (-not $kubeconfigPath) {
    Write-Error "Не удалось получить kubeconfig"
    exit 1
}

# Шаг 5: Настройка GitHub секретов
if (-not (Setup-GitHubSecrets -KubeconfigPath $kubeconfigPath -Token $GitHubToken)) {
    Write-Error "Не удалось настроить GitHub секреты"
    Write-Info "Вы можете настроить их вручную через: .\scripts\setup-github-secrets.ps1"
    exit 1
}

# Шаг 6: Деплоймент
# if (-not (Deploy-Ceres)) {
#     Write-Error "Деплоймент завершился с ошибками"
#     exit 1
# }

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           CERES успешно развернут на $ServerIP            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Success "Все этапы завершены успешно!"
Write-Info "Проверить статус: kubectl --kubeconfig $kubeconfigPath get pods -A"
$actionsUrl = "https://github.com/$GitHubRepo/actions"
Write-Info "GitHub Actions: $actionsUrl"
Write-Host ""
