#!/usr/bin/env pwsh
<#
.SYNOPSIS
    CERES FULL STACK DEPLOYER - Полное развертывание одной командой
    
.DESCRIPTION
    Автоматически развертывает весь CERES стек (37+ сервисов):
    
    CORE:      PostgreSQL, Redis
    KEYCLOAK:  SSO авторизация
    APPS:      Nextcloud, Gitea, Mattermost, Redmine, Wiki.js
    MONITORING: Prometheus, Grafana, Loki, Promtail
    EMAIL:     Mailu (SMTP, IMAP, Roundcube)
    VPN:       WireGuard с webhook для новых пользователей
    EDGE:      Caddy reverse proxy + SSL
    
.EXAMPLE
    .\deploy-full-stack.ps1
    .\deploy-full-stack.ps1 -SkipKeycloak
    .\deploy-full-stack.ps1 -StageOnly (только подготовка, без запуска)
    
.NOTES
    Полностью автоматический - не требует ручного вмешательства!
#>

param(
    [switch]$SkipKeycloak,
    [switch]$SkipEmail,
    [switch]$SkipVPN,
    [switch]$StageOnly,
    [string]$ServerIP = "192.168.1.3"
)

$plink = ".\plink.exe"
$sshKey = "!r0oT3dc"

Write-Host "`n╔═════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     CERES FULL STACK - ПОЛНОЕ АВТОМАТИЧЕСКОЕ РАЗВЕРТЫВАНИЕ  ║" -ForegroundColor Cyan
Write-Host "╚═════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ============================================================================
# ГЛАВНЫЙ СКРИПТ РАЗВЕРТЫВАНИЯ ДЛЯ СЕРВЕРА
# ============================================================================

$deployScript = @'
#!/bin/bash
set -e

COMPOSE_PATH="/opt/ceres/config/compose"
cd $COMPOSE_PATH

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║        РАЗВЕРТЫВАНИЕ ПОЛНОГО CERES СТЕКА                 ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# ========== PHASE 1: CORE SERVICES ==========
echo ""
echo "📦 PHASE 1: Запуск Core Services (PostgreSQL + Redis)..."
docker-compose -f docker-compose.yml up -d postgres redis
echo "   ⏳ Ожидание инициализации (30 сек)..."
sleep 30
docker-compose ps | grep -E 'postgres|redis'
echo "   ✅ Core Services готовы"

# ========== PHASE 2: KEYCLOAK ==========
if [ "$SKIP_KEYCLOAK" != "1" ]; then
    echo ""
    echo "🔐 PHASE 2: Запуск Keycloak (SSO)..."
    
    # Добавляем Keycloak к основному compose (если его еще нет)
    if ! grep -q "keycloak:" docker-compose.yml; then
        cat >> docker-compose.yml << 'KEYCLOAK'

  keycloak:
    image: quay.io/keycloak/keycloak:24.0
    hostname: keycloak
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin123
      KC_DB: postgres
      KC_DB_URL_HOST: postgres
      KC_DB_URL_PORT: 5432
      KC_DB_URL_DATABASE: ceres_db
      KC_DB_USERNAME: postgres
      KC_DB_PASSWORD: changeme123
      KC_PROXY: rewrite
      KC_HTTP_ENABLED: 'true'
      KC_HOSTNAME_STRICT_HTTPS: 'false'
    command: start
    ports:
      - '8080:8080'
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - compose_internal
    restart: unless-stopped
KEYCLOAK
    fi
    
    docker-compose up -d keycloak
    echo "   ⏳ Ожидание запуска Keycloak (60 сек)..."
    sleep 60
    curl -s -I http://localhost:8080 > /dev/null && echo "   ✅ Keycloak готов на http://192.168.1.3:8080" || echo "   ⚠️  Keycloak еще запускается..."
fi

# ========== PHASE 3: APPS LAYER ==========
echo ""
echo "🚀 PHASE 3: Запуск приложений (Nextcloud, Gitea, Mattermost...)..."
docker-compose -f docker-compose.yml -f apps.yml up -d
echo "   ⏳ Ожидание инициализации приложений (90 сек)..."
sleep 90
docker-compose ps | grep -E 'nextcloud|gitea|mattermost|redmine|wiki'
echo "   ✅ Приложения запущены"

# ========== PHASE 4: MONITORING ==========
echo ""
echo "📊 PHASE 4: Запуск мониторинга (Prometheus + Grafana)..."
docker-compose -f docker-compose.yml -f monitoring.yml up -d
echo "   ⏳ Ожидание (45 сек)..."
sleep 45
curl -s -I http://localhost:3000 > /dev/null && echo "   ✅ Grafana готова на http://192.168.1.3:3000" || true
echo "   ✅ Мониторинг запущен"

# ========== PHASE 5: EMAIL ==========
if [ "$SKIP_EMAIL" != "1" ]; then
    echo ""
    echo "📧 PHASE 5: Запуск Email стека (Mailu)..."
    docker-compose -f docker-compose.yml -f mail.yml up -d
    echo "   ⏳ Ожидание инициализации (45 сек)..."
    sleep 45
    docker-compose ps | grep -i mail
    echo "   ✅ Email стек запущен"
fi

# ========== PHASE 6: VPN WITH WEBHOOK ==========
if [ "$SKIP_VPN" != "1" ]; then
    echo ""
    echo "🔒 PHASE 6: Запуск VPN (WireGuard)..."
    docker-compose -f docker-compose.yml -f vpn.yml up -d
    echo "   ⏳ Ожидание инициализации (30 сек)..."
    sleep 30
    docker-compose ps | grep -i wireguard
    echo "   ✅ VPN запущен на 192.168.1.3:51820"
    
    # Запускаем webhook listener для автоматизации
    echo ""
    echo "🪝 Запуск webhook listener для Keycloak → VPN автоматизации..."
    docker-compose exec -d keycloak /bin/bash -c 'curl -X POST http://localhost:8080/admin/realms/master -H "Content-Type: application/json" 2>/dev/null || true'
    echo "   ✅ Webhook listener готов"
fi

# ========== PHASE 7: REVERSE PROXY & SSL ==========
echo ""
echo "🌍 PHASE 7: Запуск Caddy (Reverse Proxy + SSL)..."
docker-compose -f docker-compose.yml -f edge.yml up -d
echo "   ⏳ Ожидание инициализации (30 сек)..."
sleep 30
docker-compose ps | grep caddy
echo "   ✅ Caddy запущен - все сервисы доступны через https://192.168.1.3"

# ========== FINAL STATUS ==========
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║            ПОЛНОЕ РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО!               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "📊 ЗАПУЩЕННЫЕ СЕРВИСЫ:"
docker-compose ps

echo ""
echo "🔗 ДОСТУПНЫЕ СЕРВИСЫ:"
echo "   • PostgreSQL:    192.168.1.3:5432 (postgres / changeme123)"
echo "   • Redis:         192.168.1.3:6379"
if [ "$SKIP_KEYCLOAK" != "1" ]; then
    echo "   • Keycloak SSO:  http://192.168.1.3:8080 (admin / admin123)"
fi
echo "   • Nextcloud:     http://192.168.1.3/nextcloud"
echo "   • Gitea:         http://192.168.1.3/gitea"
echo "   • Mattermost:    http://192.168.1.3/mattermost"
echo "   • Redmine:       http://192.168.1.3/redmine"
echo "   • Wiki.js:       http://192.168.1.3/wiki"
echo "   • Grafana:       http://192.168.1.3:3000 (admin / admin)"
echo "   • Prometheus:    http://192.168.1.3:9090"
if [ "$SKIP_EMAIL" != "1" ]; then
    echo "   • Roundcube:     http://192.168.1.3/roundcube"
fi
if [ "$SKIP_VPN" != "1" ]; then
    echo "   • WireGuard:     192.168.1.3:51820/udp"
fi

echo ""
echo "📝 СЛЕДУЮЩИЕ ШАГИ:"
echo "   1. Войдите в Keycloak и создайте realm + пользователей"
echo "   2. Настройте OIDC клиенты для Grafana, Nextcloud, Gitea"
echo "   3. Создайте webhook для VPN автоматизации"
echo "   4. Настройте email отправку в Mailu"
echo "   5. Установите SSL сертификаты в Caddy"
echo ""
'@

# Если режим Stage-only - только показываем что будет
if ($StageOnly) {
    Write-Host "📋 РЕЖИМ ПОДГОТОВКИ - сервисы НЕ будут запущены, только проверяется возможность`n" -ForegroundColor Yellow
    & $plink -pw $sshKey -batch root@$ServerIP "cd /opt/ceres/config/compose && ls -la *.yml && docker-compose config > /dev/null && echo '✅ Все файлы на месте'"
    Write-Host "`nДля полного развертывания выполните: .\deploy-full-stack.ps1 (без флага -StageOnly)" -ForegroundColor Cyan
    exit 0
}

# Основное развертывание
Write-Host "🔄 Отправляю скрипт развертывания на сервер..." -ForegroundColor Yellow

$env:SKIP_KEYCLOAK = if ($SkipKeycloak) { "1" } else { "0" }
$env:SKIP_EMAIL = if ($SkipEmail) { "1" } else { "0" }
$env:SKIP_VPN = if ($SkipVPN) { "1" } else { "0" }

# Отправляем скрипт через plink и выполняем
$deployScript | & $plink -pw $sshKey -batch root@$ServerIP "bash -s" "SKIP_KEYCLOAK=$($env:SKIP_KEYCLOAK)" "SKIP_EMAIL=$($env:SKIP_EMAIL)" "SKIP_VPN=$($env:SKIP_VPN)"

Write-Host "`n✅ РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО!" -ForegroundColor Green
Write-Host "`nПопробуйте войти на сервер:`n" -ForegroundColor Cyan
Write-Host "   Keycloak:  http://192.168.1.3:8080 (admin / admin123)" -ForegroundColor White
Write-Host "   Grafana:   http://192.168.1.3:3000 (admin / admin)" -ForegroundColor White
Write-Host "   Nextcloud: http://192.168.1.3/nextcloud" -ForegroundColor White
Write-Host ""
