# CERES Remote Deployment via SSH
# Автоматический деплой на удаленный сервер через SSH

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerHost,
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "root",
    
    [Parameter(Mandatory=$false)]
    [string]$SSHKey = "$env:USERPROFILE\.ssh\id_rsa.ppk",
    
    [Parameter(Mandatory=$false)]
    [string]$Domain = "ceres.local",
    
    [Parameter(Mandatory=$false)]
    [switch]$FullDeploy,
    
    [Parameter(Mandatory=$false)]
    [switch]$CheckOnly
)

# ==========================================
# Проверка plink
# ==========================================
Write-Host "🔍 Проверка plink..." -ForegroundColor Cyan

$plinkPath = "plink.exe"
try {
    $null = Get-Command plink -ErrorAction Stop
} catch {
    Write-Host "❌ plink не найден!" -ForegroundColor Red
    Write-Host "Установите PuTTY: https://www.putty.org/" -ForegroundColor Yellow
    Write-Host "Или добавьте plink.exe в PATH" -ForegroundColor Yellow
    exit 1
}

# ==========================================
# Функция выполнения SSH команд
# ==========================================
function Invoke-SSHCommand {
    param(
        [string]$Command,
        [string]$Description = "Выполнение команды"
    )
    
    Write-Host "→ $Description" -ForegroundColor Yellow
    
    $sshArgs = @(
        "-ssh"
        "-batch"  # Не запрашивать пароль
        "-i", $SSHKey
        "$Username@$ServerHost"
        $Command
    )
    
    $result = & plink $sshArgs 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ OK" -ForegroundColor Green
        return $result
    } else {
        Write-Host "❌ FAILED" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        return $null
    }
}

# ==========================================
# Проверка подключения
# ==========================================
Write-Host ""
Write-Host "🔌 Проверка SSH подключения к $ServerHost..." -ForegroundColor Cyan

$result = Invoke-SSHCommand -Command "echo 'SSH OK'" -Description "Тест подключения"
if (-not $result) {
    Write-Host "❌ Не могу подключиться к серверу!" -ForegroundColor Red
    Write-Host "Проверьте:" -ForegroundColor Yellow
    Write-Host "  1. Сервер включен" -ForegroundColor Yellow
    Write-Host "  2. SSH доступен на порту 22" -ForegroundColor Yellow
    Write-Host "  3. SSH ключ корректный: $SSHKey" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ SSH подключение работает!" -ForegroundColor Green

# ==========================================
# Проверка системы (если только check)
# ==========================================
if ($CheckOnly) {
    Write-Host ""
    Write-Host "📊 Проверка системы..." -ForegroundColor Cyan
    
    # Проверка OS
    Write-Host "→ OS:" -ForegroundColor Yellow
    Invoke-SSHCommand -Command "cat /etc/os-release | grep PRETTY_NAME" | Write-Host
    
    # Проверка ресурсов
    Write-Host "→ CPU:" -ForegroundColor Yellow
    Invoke-SSHCommand -Command "nproc" | Write-Host
    
    Write-Host "→ RAM:" -ForegroundColor Yellow
    Invoke-SSHCommand -Command "free -h | grep Mem" | Write-Host
    
    Write-Host "→ Disk:" -ForegroundColor Yellow
    Invoke-SSHCommand -Command "df -h /" | Write-Host
    
    # Проверка Docker
    Write-Host "→ Docker:" -ForegroundColor Yellow
    $dockerVersion = Invoke-SSHCommand -Command "docker --version 2>/dev/null || echo 'Not installed'"
    Write-Host $dockerVersion
    
    Write-Host ""
    Write-Host "✅ Проверка завершена" -ForegroundColor Green
    exit 0
}

# ==========================================
# Полный деплой
# ==========================================
if ($FullDeploy) {
    Write-Host ""
    Write-Host "🚀 НАЧИНАЮ ПОЛНЫЙ ДЕПЛОЙ..." -ForegroundColor Magenta
    Write-Host ""
    
    # Шаг 1: Обновление системы
    Write-Host "📦 Шаг 1/10: Обновление системы..." -ForegroundColor Cyan
    Invoke-SSHCommand -Command "apt update && apt upgrade -y" -Description "apt update && upgrade"
    
    # Шаг 2: Установка Docker
    Write-Host ""
    Write-Host "🐳 Шаг 2/10: Установка Docker..." -ForegroundColor Cyan
    $dockerCheck = Invoke-SSHCommand -Command "docker --version 2>/dev/null"
    if (-not $dockerCheck) {
        Write-Host "Docker не установлен, устанавливаю..." -ForegroundColor Yellow
        Invoke-SSHCommand -Command "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh" -Description "Установка Docker"
        Invoke-SSHCommand -Command "systemctl enable docker && systemctl start docker" -Description "Запуск Docker"
    } else {
        Write-Host "Docker уже установлен: $dockerCheck" -ForegroundColor Green
    }
    
    # Шаг 3: Установка Docker Compose
    Write-Host ""
    Write-Host "🔧 Шаг 3/10: Установка Docker Compose..." -ForegroundColor Cyan
    Invoke-SSHCommand -Command @"
curl -L 'https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64' -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
"@ -Description "Установка Docker Compose"
    
    # Шаг 4: Установка Git
    Write-Host ""
    Write-Host "📥 Шаг 4/10: Установка Git..." -ForegroundColor Cyan
    Invoke-SSHCommand -Command "apt install -y git vim curl wget htop python3-pip" -Description "Установка пакетов"
    
    # Шаг 5: Клонирование проекта
    Write-Host ""
    Write-Host "📂 Шаг 5/10: Клонирование CERES..." -ForegroundColor Cyan
    Invoke-SSHCommand -Command "cd /opt && rm -rf Ceres && git clone https://github.com/skulesh01/Ceres.git" -Description "Git clone"
    
    # Шаг 6: Генерация .env
    Write-Host ""
    Write-Host "⚙️ Шаг 6/10: Генерация конфигурации..." -ForegroundColor Cyan
    
    # Генерируем случайные пароли
    $postgresPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    $keycloakPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    $gitlabPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    $grafanaPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    
    Invoke-SSHCommand -Command @"
cd /opt/Ceres && cp config/.env.example config/.env && \
sed -i 's/DOMAIN=ceres/DOMAIN=$Domain/g' config/.env && \
sed -i 's/POSTGRES_PASSWORD=CHANGE_ME/POSTGRES_PASSWORD=$postgresPassword/g' config/.env && \
sed -i 's/KEYCLOAK_ADMIN_PASSWORD=CHANGE_ME/KEYCLOAK_ADMIN_PASSWORD=$keycloakPassword/g' config/.env && \
sed -i 's/GITLAB_ROOT_PASSWORD=CHANGE_ME/GITLAB_ROOT_PASSWORD=$gitlabPassword/g' config/.env && \
sed -i 's/GRAFANA_ADMIN_PASSWORD=CHANGE_ME/GRAFANA_ADMIN_PASSWORD=$grafanaPassword/g' config/.env
"@ -Description "Конфигурация .env"
    
    Write-Host ""
    Write-Host "🔑 СОХРАНИТЕ ЭТИ ПАРОЛИ:" -ForegroundColor Yellow
    Write-Host "  PostgreSQL: $postgresPassword" -ForegroundColor Cyan
    Write-Host "  Keycloak:   $keycloakPassword" -ForegroundColor Cyan
    Write-Host "  GitLab:     $gitlabPassword" -ForegroundColor Cyan
    Write-Host "  Grafana:    $grafanaPassword" -ForegroundColor Cyan
    Write-Host ""
    
    # Шаг 7: Настройка firewall
    Write-Host ""
    Write-Host "🔥 Шаг 7/10: Настройка firewall..." -ForegroundColor Cyan
    Invoke-SSHCommand -Command @"
ufw allow 22/tcp && \
ufw allow 80/tcp && \
ufw allow 443/tcp && \
ufw allow 51820/udp && \
echo 'y' | ufw enable
"@ -Description "Настройка UFW"
    
    # Шаг 8: Создание Docker network
    Write-Host ""
    Write-Host "🌐 Шаг 8/10: Создание Docker network..." -ForegroundColor Cyan
    Invoke-SSHCommand -Command "docker network create ceres_net 2>/dev/null || true" -Description "Docker network"
    
    # Шаг 9: Запуск сервисов
    Write-Host ""
    Write-Host "🚀 Шаг 9/10: Запуск сервисов..." -ForegroundColor Cyan
    Write-Host "Это займёт 10-15 минут..." -ForegroundColor Yellow
    
    Invoke-SSHCommand -Command @"
cd /opt/Ceres && \
docker-compose -f config/compose/base.yml up -d && \
docker-compose -f config/compose/core.yml up -d && \
sleep 30 && \
docker-compose -f config/compose/gitlab.yml up -d && \
docker-compose -f config/compose/zulip.yml up -d && \
docker-compose -f config/compose/apps.yml up -d && \
docker-compose -f config/compose/monitoring.yml up -d && \
docker-compose -f config/compose/monitoring-exporters.yml up -d && \
docker-compose -f config/compose/ops.yml up -d && \
docker-compose -f config/compose/edge.yml up -d
"@ -Description "Запуск всех сервисов"
    
    # Шаг 10: Проверка
    Write-Host ""
    Write-Host "✅ Шаг 10/10: Проверка сервисов..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
    
    $containers = Invoke-SSHCommand -Command "docker ps --format '{{.Names}}: {{.Status}}'"
    Write-Host $containers
    
    # Итоговая информация
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "   ✅ ДЕПЛОЙ ЗАВЕРШЁН!" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Доступные сервисы:" -ForegroundColor Cyan
    Write-Host "   https://auth.$Domain - Keycloak" -ForegroundColor White
    Write-Host "   https://gitlab.$Domain - GitLab CE" -ForegroundColor White
    Write-Host "   https://zulip.$Domain - Zulip" -ForegroundColor White
    Write-Host "   https://nextcloud.$Domain - Nextcloud" -ForegroundColor White
    Write-Host "   https://grafana.$Domain - Grafana" -ForegroundColor White
    Write-Host ""
    Write-Host "🔑 Пароли сохранены выше (прокрутите вверх)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 Следующие шаги:" -ForegroundColor Cyan
    Write-Host "   1. Настройте DNS: *.$Domain -> $ServerHost" -ForegroundColor White
    Write-Host "   2. Дождитесь инициализации (5-10 мин)" -ForegroundColor White
    Write-Host "   3. Откройте https://auth.$Domain" -ForegroundColor White
    Write-Host ""
    
    exit 0
}

# ==========================================
# Если не указаны параметры
# ==========================================
Write-Host ""
Write-Host "❓ Что делать?" -ForegroundColor Yellow
Write-Host ""
Write-Host "Используйте параметры:" -ForegroundColor Cyan
Write-Host "  -CheckOnly       - Только проверка системы" -ForegroundColor White
Write-Host "  -FullDeploy      - Полный автоматический деплой" -ForegroundColor White
Write-Host ""
Write-Host "Примеры:" -ForegroundColor Cyan
Write-Host "  .\scripts\remote-deploy.ps1 -ServerHost 192.168.1.100 -CheckOnly" -ForegroundColor White
Write-Host "  .\scripts\remote-deploy.ps1 -ServerHost 192.168.1.100 -FullDeploy -Domain ceres.example.com" -ForegroundColor White
Write-Host ""
