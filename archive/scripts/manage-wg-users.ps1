#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Управление WireGuard пользователями через API
.DESCRIPTION
    Позволяет:
    - Добавить нового пользователя (отправить ему конфиг)
    - Отключить пользователя (удалить из VPN)
    - Включить пользователя обратно
    - Просмотреть список всех пользователей
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('list', 'add', 'disable', 'enable', 'download')]
    [string]$Action = 'list',
    
    [Parameter(Mandatory=$false)]
    [string]$UserId,
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Email,
    
    [Parameter(Mandatory=$false)]
    [string]$ApiUrl = "http://localhost:5000",
    
    [Parameter(Mandatory=$false)]
    [string]$ApiToken = "secure-wg-manager-token-change-me"
)

function Get-ApiHeaders {
    return @{
        'Authorization' = "Bearer $ApiToken"
        'Content-Type' = 'application/json'
    }
}

function List-Users {
    Write-Host "`n📋 Список всех пользователей VPN:" -ForegroundColor Cyan
    
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/users" `
            -Headers (Get-ApiHeaders) `
            -ErrorAction Stop
        
        $users = ($resp.Content | ConvertFrom-Json).users
        
        if ($users.Count -eq 0) {
            Write-Host "   (нет пользователей)" -ForegroundColor Gray
            return
        }
        
        Write-Host ""
        $users | ForEach-Object {
            $status = if ($_.enabled) { "✅ АКТИВЕН" } else { "❌ ОТКЛЮЧЕН" }
            Write-Host "   ID: $($_.user_id)" -ForegroundColor White
            Write-Host "   Имя: $($_.username)" -ForegroundColor White
            Write-Host "   Email: $($_.email)" -ForegroundColor White
            Write-Host "   Статус: $status" -ForegroundColor $(if ($_.enabled) { 'Green' } else { 'Red' })
            Write-Host "   Создан: $($_.created_at)" -ForegroundColor Gray
            
            if (-not $_.enabled -and $_.disabled_at) {
                Write-Host "   Отключен: $($_.disabled_at)" -ForegroundColor Gray
            }
            
            Write-Host ""
        }
        
        Write-Host "Total: $($users.Count) пользователей`n" -ForegroundColor Cyan
    }
    catch {
        Write-Host "❌ Ошибка: $_" -ForegroundColor Red
    }
}

function Add-User {
    if (-not $UserId -or -not $Username -or -not $Email) {
        Write-Host "❌ Требуются параметры: -UserId, -Username, -Email" -ForegroundColor Red
        return
    }
    
    Write-Host "`n➕ Добавление нового пользователя..." -ForegroundColor Yellow
    
    try {
        $body = @{
            user_id = $UserId
            username = $Username
            email = $Email
        } | ConvertTo-Json
        
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/user/register" `
            -Method POST `
            -Headers (Get-ApiHeaders) `
            -Body $body `
            -ErrorAction Stop
        
        $result = $resp.Content | ConvertFrom-Json
        
        Write-Host "✅ Пользователь $Username успешно добавлен!" -ForegroundColor Green
        Write-Host "   Email: $Email" -ForegroundColor White
        Write-Host "   Статус: $($result.message)" -ForegroundColor White
        Write-Host ""
    }
    catch {
        Write-Host "❌ Ошибка: $_" -ForegroundColor Red
    }
}

function Disable-User {
    if (-not $UserId) {
        Write-Host "❌ Требуется параметр: -UserId" -ForegroundColor Red
        return
    }
    
    Write-Host "`n🔒 Отключение пользователя $UserId..." -ForegroundColor Yellow
    
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/user/$UserId/disable" `
            -Method POST `
            -Headers (Get-ApiHeaders) `
            -ErrorAction Stop
        
        Write-Host "✅ Пользователь отключен из VPN!" -ForegroundColor Green
        Write-Host "   ID: $UserId" -ForegroundColor White
        Write-Host ""
    }
    catch {
        Write-Host "❌ Ошибка: $_" -ForegroundColor Red
    }
}

function Enable-User {
    if (-not $UserId) {
        Write-Host "❌ Требуется параметр: -UserId" -ForegroundColor Red
        return
    }
    
    Write-Host "`n🔓 Включение пользователя $UserId..." -ForegroundColor Yellow
    
    try {
        $resp = Invoke-WebRequest -Uri "$ApiUrl/api/v1/user/$UserId/enable" `
            -Method POST `
            -Headers (Get-ApiHeaders) `
            -ErrorAction Stop
        
        Write-Host "✅ Пользователь включен в VPN!" -ForegroundColor Green
        Write-Host "   ID: $UserId" -ForegroundColor White
        Write-Host ""
    }
    catch {
        Write-Host "❌ Ошибка: $_" -ForegroundColor Red
    }
}

function Download-Config {
    if (-not $UserId) {
        Write-Host "❌ Требуется параметр: -UserId" -ForegroundColor Red
        return
    }
    
    $configPath = "/data/wg-configs/$UserId.conf"
    
    Write-Host "`n📥 Скачивание конфига для $UserId..." -ForegroundColor Yellow
    
    try {
        # Для локального файла
        if (Test-Path $configPath) {
            $destPath = "$PSScriptRoot\wg-config-$UserId.conf"
            Copy-Item $configPath $destPath
            Write-Host "✅ Конфиг скачан: $destPath" -ForegroundColor Green
        }
        else {
            Write-Host "❌ Конфиг не найден для пользователя $UserId" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "❌ Ошибка: $_" -ForegroundColor Red
    }
}

# ==================== MAIN ====================
Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      WireGuard User Management Dashboard            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════╝" -ForegroundColor Cyan

switch ($Action) {
    'list' { List-Users }
    'add' { Add-User }
    'disable' { Disable-User }
    'enable' { Enable-User }
    'download' { Download-Config }
    default { List-Users }
}

Write-Host "`n════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Примеры использования
Write-Host "📚 ПРИМЕРЫ:" -ForegroundColor Cyan
Write-Host "  Просмотр всех пользователей:" -ForegroundColor White
Write-Host "  .\manage-wg-users.ps1 -Action list`n" -ForegroundColor Gray

Write-Host "  Добавить нового пользователя:" -ForegroundColor White
Write-Host "  .\manage-wg-users.ps1 -Action add -UserId 'abc123' -Username 'ivan.petrov' -Email 'ivan@company.local'`n" -ForegroundColor Gray

Write-Host "  Отключить пользователя:" -ForegroundColor White
Write-Host "  .\manage-wg-users.ps1 -Action disable -UserId 'abc123'`n" -ForegroundColor Gray

Write-Host "  Включить пользователя обратно:" -ForegroundColor White
Write-Host "  .\manage-wg-users.ps1 -Action enable -UserId 'abc123'`n" -ForegroundColor Gray
