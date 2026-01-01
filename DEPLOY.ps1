# CERES - Автоматический деплой на Proxmox
# Простая и надежная версия без сложных конструкций

param(
    [string]$ServerIP = "192.168.1.3",
    [string]$ServerUser = "root",
    [string]$ServerPassword = "!r0oT3dc"
)

$plink = "$HOME\plink.exe"
$kubePath = "$HOME\k3s.yaml"
$sshKey = "$HOME\.ssh\ceres"
$secretsFile = "$HOME\ceres-secrets.txt"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CERES Auto-Deploy" -ForegroundColor Cyan  
Write-Host "========================================`n" -ForegroundColor Cyan

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
    
    # Настройка сети
    Write-Host "   Настройка DNS и маршрутизации..." -ForegroundColor Cyan
    & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP @"
echo 'nameserver 8.8.8.8' > /etc/resolv.conf && \
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf && \
ip route show | grep -q default || ip route add default via 192.168.1.1
"@ 2>&1 | Out-Null
    
    # Установка k3s
    Write-Host "   Установка k3s (2-3 минуты)..." -ForegroundColor Cyan
    & $plink -pw $ServerPassword -batch $ServerUser@$ServerIP @"
cd /tmp && \
wget -q https://get.k3s.io -O k3s.sh && \
chmod +x k3s.sh && \
INSTALL_K3S_EXEC='server --write-kubeconfig-mode=644' sh k3s.sh
"@ 2>&1 | Out-Null
    
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
    New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
    ssh-keygen -t ed25519 -f $sshKey -N """" -C "ceres" -q
}
Write-Host "   [OK] SSH ключ готов" -ForegroundColor Green

# 6. Подготовка секретов
Write-Host "`n>> Подготовка секретов для GitHub..." -ForegroundColor Yellow
$kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeRaw))
$sshRaw = Get-Content $sshKey -Raw

$secretsContent = @"
========================================
CERES GitHub Actions Secrets
========================================

Добавьте эти секреты в:
https://github.com/skulesh01/Ceres/settings/secrets/actions

----------------------------------------
1. KUBECONFIG
----------------------------------------
$kubeB64

----------------------------------------
2. SSH_PRIVATE_KEY
----------------------------------------
$sshRaw

----------------------------------------
3. DEPLOY_HOST
----------------------------------------
$ServerIP

----------------------------------------
4. DEPLOY_USER
----------------------------------------
$ServerUser

----------------------------------------
5. DEPLOY_PASSWORD
----------------------------------------
$ServerPassword

========================================
"@

$secretsContent | Set-Content $secretsFile -Force
Write-Host "   [OK] Секреты сохранены: $secretsFile" -ForegroundColor Green

# 7. Попытка автоматической настройки через gh
Write-Host "`n>> Настройка GitHub секретов..." -ForegroundColor Yellow

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
Write-Host "  2. Запустите деплоймент:" -ForegroundColor White
Write-Host "     gh workflow run deploy.yml -R skulesh01/Ceres" -ForegroundColor Gray
Write-Host "     или https://github.com/skulesh01/Ceres/actions" -ForegroundColor Gray
Write-Host ""
