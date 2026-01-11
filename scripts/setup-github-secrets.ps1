# Скрипт для настройки GitHub Actions секретов
# Запускайте после установки GitHub CLI и аутентификации

Write-Host "=== Настройка GitHub Actions секретов ===" -ForegroundColor Cyan

# Проверка установки gh
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI не установлен" -ForegroundColor Red
    Write-Host "Установите вручную: https://cli.github.com/" -ForegroundColor Yellow
    Write-Host "Или через scoop: scoop install gh" -ForegroundColor Yellow
    exit 1
}

# Проверка аутентификации
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ GitHub CLI не аутентифицирован" -ForegroundColor Red
    Write-Host "Выполните: gh auth login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ GitHub CLI установлен и аутентифицирован" -ForegroundColor Green

# Чтение данных
$kubeconfig = Get-Content "$HOME\k3s.yaml" -Raw
$kubeconfigB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeconfig))

$sshKey = Get-Content "$HOME\.ssh\ceres" -Raw
$deployHost = "192.168.1.3"
$deployUser = "root"
$deployPassword = $env:DEPLOY_SERVER_PASSWORD

# Установка секретов
Write-Host "`nУстановка секретов в репозиторий skulesh01/Ceres..." -ForegroundColor Cyan

Write-Host "1. KUBECONFIG..." -NoNewline
echo $kubeconfigB64 | gh secret set KUBECONFIG -R skulesh01/Ceres
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌" -ForegroundColor Red
}

Write-Host "2. SSH_PRIVATE_KEY..." -NoNewline
echo $sshKey | gh secret set SSH_PRIVATE_KEY -R skulesh01/Ceres
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌" -ForegroundColor Red
}

Write-Host "3. DEPLOY_HOST..." -NoNewline
echo $deployHost | gh secret set DEPLOY_HOST -R skulesh01/Ceres
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌" -ForegroundColor Red
}

Write-Host "4. DEPLOY_USER..." -NoNewline
echo $deployUser | gh secret set DEPLOY_USER -R skulesh01/Ceres
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌" -ForegroundColor Red
}

Write-Host "5. DEPLOY_PASSWORD..." -NoNewline
echo $deployPassword | gh secret set DEPLOY_PASSWORD -R skulesh01/Ceres
if ($LASTEXITCODE -eq 0) {
    Write-Host " ✅" -ForegroundColor Green
} else {
    Write-Host " ❌" -ForegroundColor Red
}

Write-Host "`n=== Секреты настроены ===" -ForegroundColor Green
Write-Host "Теперь можно запустить деплоймент:" -ForegroundColor Cyan
Write-Host "  gh workflow run deploy.yml -R skulesh01/Ceres" -ForegroundColor Yellow
