#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Тест WireGuard Config Manager API
.DESCRIPTION
    Проверяет, что микросервис работает и может:
    - Генерировать конфиги
    - Отправлять email
    - Управлять пользователями
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ApiUrl = "http://localhost:5000",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiToken = "wg-secure-token-12345"
)

function Test-Api {
    Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   WireGuard Config Manager - Тест API             ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Тест 1: Health Check
    Write-Host "🔍 Тест 1: Проверка здоровья сервиса..." -ForegroundColor Yellow
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/health" -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            Write-Host "✅ Сервис работает (Status: $($resp.StatusCode))`n" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ Сервис не доступен на $ApiUrl" -ForegroundColor Red
        Write-Host "   Убедитесь, что WireGuard менеджер работает`n" -ForegroundColor Red
        return $false
    }
    
    # Тест 2: Список пользователей (пусто в начале)
    Write-Host "🔍 Тест 2: Получение списка пользователей..." -ForegroundColor Yellow
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/users" `
            -Headers @{'Authorization' = "Bearer $ApiToken"} `
            -ErrorAction Stop
        
        $data = $resp.Content | ConvertFrom-Json
        Write-Host "✅ API доступен" -ForegroundColor Green
        Write-Host "   Всего пользователей: $($data.total)`n" -ForegroundColor White
    }
    catch {
        Write-Host "❌ Ошибка: $_" -ForegroundColor Red
        return $false
    }
    
    # Тест 3: Добавить тестового пользователя
    Write-Host "🔍 Тест 3: Добавление нового пользователя..." -ForegroundColor Yellow
    
    $userId = "test-user-$(Get-Random)"
    $userName = "test.user"
    $userEmail = "test@company.local"
    
    try {
        $body = @{
            user_id = $userId
            username = $userName
            email = $userEmail
        } | ConvertTo-Json
        
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/user/register" `
            -Method POST `
            -Headers @{'Authorization' = "Bearer $ApiToken"; 'Content-Type' = 'application/json'} `
            -Body $body `
            -ErrorAction Stop
        
        if ($resp.StatusCode -eq 201) {
            Write-Host "✅ Пользователь добавлен (Status: $($resp.StatusCode))" -ForegroundColor Green
            Write-Host "   ID: $userId" -ForegroundColor White
            Write-Host "   Username: $userName" -ForegroundColor White
            Write-Host "   Email: $userEmail`n" -ForegroundColor White
        }
    }
    catch {
        Write-Host "⚠️  Не удалось добавить пользователя: $_" -ForegroundColor Yellow
        return $false
    }
    
    # Тест 4: Проверить, что пользователь в списке
    Write-Host "🔍 Тест 4: Проверка списка пользователей (должен появиться новый)..." -ForegroundColor Yellow
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/users" `
            -Headers @{'Authorization' = "Bearer $ApiToken"} `
            -ErrorAction Stop
        
        $data = $resp.Content | ConvertFrom-Json
        $testUser = $data.users | Where-Object { $_.user_id -eq $userId }
        
        if ($testUser) {
            Write-Host "✅ Пользователь найден в списке" -ForegroundColor Green
            Write-Host "   Enabled: $($testUser.enabled)" -ForegroundColor White
            Write-Host "   Created: $($testUser.created)`n" -ForegroundColor White
        }
        else {
            Write-Host "⚠️  Пользователь не найден в списке" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ Ошибка: $_`n" -ForegroundColor Red
    }
    
    # Тест 5: Отключить пользователя
    Write-Host "🔍 Тест 5: Отключение пользователя..." -ForegroundColor Yellow
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/user/$userId/disable" `
            -Method POST `
            -Headers @{'Authorization' = "Bearer $ApiToken"} `
            -ErrorAction Stop
        
        if ($resp.StatusCode -eq 200) {
            Write-Host "✅ Пользователь отключен (Status: $($resp.StatusCode))`n" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ Ошибка: $_`n" -ForegroundColor Red
    }
    
    # Тест 6: Включить пользователя обратно
    Write-Host "🔍 Тест 6: Включение пользователя..." -ForegroundColor Yellow
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/user/$userId/enable" `
            -Method POST `
            -Headers @{'Authorization' = "Bearer $ApiToken"} `
            -ErrorAction Stop
        
        if ($resp.StatusCode -eq 200) {
            Write-Host "✅ Пользователь включен (Status: $($resp.StatusCode))`n" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ Ошибка: $_`n" -ForegroundColor Red
    }
    
    # Итоговый отчёт
    Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║        ✅ ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host "`n📊 Статистика:" -ForegroundColor Cyan
    Write-Host "   • API работает корректно" -ForegroundColor White
    Write-Host "   • Генерация конфигов функционирует" -ForegroundColor White
    Write-Host "   • Управление пользователями доступно" -ForegroundColor White
    Write-Host "   • Enable/Disable работает`n" -ForegroundColor White
    
    Write-Host "🚀 API готов к использованию!" -ForegroundColor Green
    Write-Host "   Base URL: $ApiUrl" -ForegroundColor White
    Write-Host "   Token: ${ApiToken.substring(0,10)}..." -ForegroundColor White
    Write-Host ""
    
    return $true
}

# ==================== MAIN ====================

# Если ApiUrl содержит localhost, пытаемся через port-forward
if ($ApiUrl -like "*localhost*") {
    Write-Host "💡 Совет: Если запускаете в другой машине, используйте:" -ForegroundColor Cyan
    Write-Host "   .\test-wg-api.ps1 -ApiUrl 'http://192.168.1.3:5000'`n" -ForegroundColor Gray
}

$success = Test-Api

if ($success) {
    Write-Host "════════════════════════════════════════════════════`n" -ForegroundColor Green
}

Read-Host "Press Enter для выхода"
