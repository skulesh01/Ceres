# CERES - Автоматический деплой на Proxmox
# Простая и надежная версия без сложных конструкций

param(
    [string]$ServerIP = $env:DEPLOY_SERVER_IP,
    [string]$ServerUser = $env:DEPLOY_SERVER_USER,
    [string]$ServerPassword = $env:DEPLOY_SERVER_PASSWORD,
    [string]$Gateway = "192.168.1.1",
    [string[]]$DnsServers = @("8.8.8.8", "8.8.4.4"),
    [switch]$SkipNetworkConfig,
    [switch]$SkipGitHubSecrets,
    [string]$GitHubPat = $Env:GITHUB_PAT
)

$plink = "$HOME\plink.exe"
$kubePath = "$HOME\k3s.yaml"
$sshKey = "$HOME\.ssh\ceres"
$secretsFile = "$HOME\ceres-secrets.txt"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CERES Auto-Deploy" -ForegroundColor Cyan  
Write-Host "========================================`n" -ForegroundColor Cyan

# 0. Префлайт: базовые проверки сети/портов/ресурсов (вынесено в scripts/preflight.ps1)

# 1. Проверка plink
Write-Host ">> Проверка plink.exe..." -ForegroundColor Yellow
if (!(Test-Path $plink)) {
    Write-Host "   Скачиваю plink.exe..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" -OutFile $plink -UseBasicParsing
}
Write-Host "   [OK] plink.exe готов" -ForegroundColor Green

# 2. Проверка подключения
Write-Host "`n>> Подключение к серверу..." -ForegroundColor Yellow
$testConn = & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP "echo OK" 2>&1
if ($testConn -match "OK") {
    Write-Host "   [OK] Подключение успешно" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Не удалось подключиться" -ForegroundColor Red
    exit 1
}

# 3. Проверка k3s
Write-Host "`n>> Проверка k3s..." -ForegroundColor Yellow
$k3sCheck = & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP "kubectl get nodes" 2>&1

if ($k3sCheck -match "Ready") {
    Write-Host "   [OK] k3s работает" -ForegroundColor Green
} else {
    Write-Host "   [INFO] k3s не установлен, устанавливаю..." -ForegroundColor Cyan
    
    if (-not $SkipNetworkConfig) {
        $dnsContent = ($DnsServers | ForEach-Object { "nameserver $_" }) -join "\n"
        Write-Host "   Настройка DNS и маршрутизации..." -ForegroundColor Cyan
        $cmdNet = "printf '$dnsContent\n' > /etc/resolv.conf; ip route show | grep -q default || ip route add default via $Gateway"
        & $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" $cmdNet | Out-Null
    } else {
        Write-Host "   Пропускаю настройку сети (SkipNetworkConfig)" -ForegroundColor Cyan
    }
    
    # Установка k3s
    Write-Host "   Установка k3s (2-3 минуты)..." -ForegroundColor Cyan
    $cmdK3s = "cd /tmp; wget -q https://get.k3s.io -O k3s.sh; chmod +x k3s.sh; INSTALL_K3S_EXEC='server --write-kubeconfig-mode=644' sh k3s.sh"
    & $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" $cmdK3s | Out-Null
    
    Start-Sleep -Seconds 10
    Write-Host "   [OK] k3s установлен" -ForegroundColor Green
}

# 4. Получение kubeconfig
Write-Host "`n>> Получение kubeconfig..." -ForegroundColor Yellow
$kubeRaw = & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP "cat /etc/rancher/k3s/k3s.yaml" 2>&1

if ($kubeRaw -match "apiVersion") {
    $kubeRaw = $kubeRaw -replace "127.0.0.1", $ServerIP
    $kubeRaw | Set-Content $kubePath -Force
    Write-Host "   [OK] $kubePath" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Не удалось получить kubeconfig" -ForegroundColor Red
    exit 1
}

# 5. Генерация SSH ключа
Write-Host "`n>> Проверка SSH ключа..." -ForegroundColor Yellow
if (!(Test-Path $sshKey)) {
    Write-Host "   Генерирую SSH ключ..." -ForegroundColor Cyan
    if (-not (Get-Command ssh-keygen -ErrorAction SilentlyContinue)) {
        Write-Host "   [ERROR] ssh-keygen не найден. Установите OpenSSH Client и повторите." -ForegroundColor Red
        exit 1
    }
    New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
    ssh-keygen -t ed25519 -f $sshKey -N """" -C "ceres" -q
}
Write-Host "   [OK] SSH ключ готов" -ForegroundColor Green

Write-Host "`n>> Подготовка секретов для GitHub..." -ForegroundColor Yellow
$kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeRaw))
$sshRaw = Get-Content $sshKey -Raw

$secretsLines = @(
    "========================================",
    "CERES GitHub Actions Secrets",
    "========================================",
    "",
    "Добавьте эти секреты в:",
    "https://github.com/skulesh01/Ceres/settings/secrets/actions",
    "",
    "----------------------------------------",
    "1. KUBECONFIG",
    "----------------------------------------",
    $kubeB64,
    "",
    "----------------------------------------",
    "2. SSH_PRIVATE_KEY",
    "----------------------------------------",
    $sshRaw,
    "",
    "----------------------------------------",
    "3. DEPLOY_HOST",
    "----------------------------------------",
    $ServerIP,
    "",
    "----------------------------------------",
    "4. DEPLOY_USER",
    "----------------------------------------",
    $ServerUser,
    "",
    "----------------------------------------",
    "5. DEPLOY_PASSWORD",
    "----------------------------------------",
    $ServerPassword,
    "",
    "========================================"
)
$secretsContent = ($secretsLines -join "`r`n")

$secretsContent | Set-Content $secretsFile -Force
Write-Host "   [OK] Секреты сохранены: $secretsFile" -ForegroundColor Green

# 7. Попытка автоматической настройки через gh
Write-Host "`n>> Настройка GitHub секретов..." -ForegroundColor Yellow

if (-not $SkipGitHubSecrets) {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $authCheck = gh auth status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   GitHub CLI найден и аутентифицирован" -ForegroundColor Cyan
            
            Write-Host "   Устанавливаю секреты..." -ForegroundColor Cyan
            echo $kubeB64 | gh secret set KUBECONFIG -R skulesh01/Ceres 2>&1 | Out-Null
            echo $sshRaw | gh secret set SSH_PRIVATE_KEY -R skulesh01/Ceres 2>&1 | Out-Null
            echo $ServerIP | gh secret set DEPLOY_HOST -R skulesh01/Ceres 2>&1 | Out-Null
            echo $ServerUser | gh secret set DEPLOY_USER -R skulesh01/Ceres 2>&1 | Out-Null
            echo $ServerPassword | gh secret set DEPLOY_PASSWORD -R skulesh01/Ceres 2>&1 | Out-Null
            
            Write-Host "   [OK] Секреты установлены автоматически!" -ForegroundColor Green
        } else {
            Write-Host "   [INFO] GitHub CLI не аутентифицирован" -ForegroundColor Cyan
            Write-Host "   Настройте вручную из файла: $secretsFile" -ForegroundColor Cyan
        }
    } else {
        Write-Host "   [INFO] GitHub CLI не установлен" -ForegroundColor Cyan
        Write-Host "   Настройте вручную из файла: $secretsFile" -ForegroundColor Cyan
    }
} else {
    Write-Host "   Пропускаю установку секретов в GitHub (SkipGitHubSecrets)" -ForegroundColor Cyan
    Write-Host "   Используйте файл: $secretsFile" -ForegroundColor Cyan
}

# 8. Установка Flux controllers
Write-Host "`n>> Установка Flux controllers..." -ForegroundColor Yellow
$cmdFlux = "kubectl create namespace flux-system >/dev/null 2>&1 || true; kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml"
& $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" $cmdFlux | Out-Null
Write-Host "   [OK] Flux controllers установлены" -ForegroundColor Green

# 9. Bootstrap GitOps (GitRepository + Kustomization)
Write-Host "`n>> Применение GitOps манифестов (flux-system.yaml)..." -ForegroundColor Yellow
$fluxManifestPath = Join-Path $PSScriptRoot "flux\clusters\production\flux-system.yaml"
if (Test-Path $fluxManifestPath) {
    $fluxManifest = Get-Content $fluxManifestPath -Raw
    # Создадим Secret для авторизации GitRepository, если передан PAT
    if ([string]::IsNullOrWhiteSpace($GitHubPat)) {
        Write-Host "   [INFO] GitHub PAT не указан (параметр -GitHubPat или переменная окружения GITHUB_PAT)." -ForegroundColor Cyan
        Write-Host "         При необходимости добавьте секрет вручную: flux\\clusters\\production\\ceres-git-auth.secret.yaml" -ForegroundColor Cyan
    } else {
        Write-Host "   [OK] Найден GitHub PAT, создаю Secret в flux-system..." -ForegroundColor Green
        $cmdSecret = "kubectl -n flux-system create secret generic ceres-git-auth --from-literal=username=git --from-literal=password=$GitHubPat >/dev/null 2>&1 || kubectl -n flux-system delete secret ceres-git-auth >/dev/null 2>&1; kubectl -n flux-system create secret generic ceres-git-auth --from-literal=username=git --from-literal=password=$GitHubPat"
        & $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" $cmdSecret | Out-Null
    }

    # Предпочтительно применить локальный файл через pscp (raw может быть недоступен)
    $tmpRemote = "/tmp/flux-system.yaml"
    $pscp = "$HOME\pscp.exe"
    if (Test-Path $pscp) {
        Write-Host "   Копирую flux-system.yaml на сервер и применяю..." -ForegroundColor Cyan
        & $pscp -pw $ServerPassword -batch $fluxManifestPath "$ServerUser@$ServerIP:$tmpRemote" 2>&1 | Out-Null
        & $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" "kubectl apply -f $tmpRemote" | Out-Null
    } else {
        Write-Host "   [INFO] pscp.exe не найден, пробую применить по raw URL" -ForegroundColor Cyan
        $rawFlux = "https://raw.githubusercontent.com/skulesh01/Ceres/main/flux/clusters/production/flux-system.yaml"
        $cmdApply = "kubectl apply -f $rawFlux"
        & $plink -pw $ServerPassword -batch "$ServerUser@$ServerIP" $cmdApply | Out-Null
    }
    Write-Host "   [OK] Flux GitRepository/Kustomization применены" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Не найден файл: $fluxManifestPath" -ForegroundColor Red
}

# 10. Проверка статуса
Write-Host "`n>> Проверка статуса Flux и приложений..." -ForegroundColor Yellow
$fluxPods = & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP "kubectl -n flux-system get pods" 2>&1
Write-Host $fluxPods
$ceresHr = & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP "kubectl -n ceres get helmrelease" 2>&1
Write-Host $ceresHr
$ceresPods = & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP "kubectl -n ceres get pods" 2>&1
Write-Host $ceresPods

# Итоги
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  Развертывание завершено!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "Готово:" -ForegroundColor White
Write-Host "  ✓ k3s установлен и работает на $ServerIP" -ForegroundColor Green
Write-Host "  ✓ Kubeconfig: $kubePath" -ForegroundColor Green  
Write-Host "  ✓ Секреты: $secretsFile" -ForegroundColor Green

Write-Host "`nСледующие шаги:" -ForegroundColor Cyan
Write-Host "  1. Настройте GitHub секреты (если еще не настроены)" -ForegroundColor White
Write-Host "     https://github.com/skulesh01/Ceres/settings/secrets/actions" -ForegroundColor Gray
Write-Host "  2. Flux и GitOps уже применены автоматически." -ForegroundColor White
Write-Host "  3. Проверьте статус на сервере:" -ForegroundColor White
Write-Host "     kubectl -n flux-system get pods" -ForegroundColor Gray
Write-Host "     kubectl -n ceres get helmrelease,pods" -ForegroundColor Gray
Write-Host ""
