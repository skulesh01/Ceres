# Решенные проблемы и уроки

Этот документ описывает проблемы, с которыми мы столкнулись при автоматизации развертывания CERES, и как они были решены.

## Проблема 1: SSH пароли в автоматизации

### Проблема
OpenSSH на Windows не поддерживает передачу пароля в параметрах командной строки. Любая попытка использовать `ssh` или `scp` приводила к интерактивному запросу пароля, что блокировало автоматизацию.

### Попытки решения
1. ❌ `ssh -p password` - такого параметра не существует
2. ❌ `sshpass` - не работает на Windows
3. ❌ PowerShell heredoc с паролем - синтаксические ошибки
4. ❌ SSH ключи без пароля - требуют предварительной настройки на сервере

### Решение
**PuTTY plink.exe** - утилита из пакета PuTTY, поддерживающая передачу пароля:

```powershell
$plink = "$HOME\plink.exe"
Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" -OutFile $plink

# Использование
& $plink -pw "password" -batch user@host "command"
```

Параметры:
- `-pw` - передача пароля
- `-batch` - неинтерактивный режим (не запрашивать подтверждения)

## Проблема 2: VM без доступа в интернет

### Проблема
Proxmox VM (192.168.1.3) не имела доступа в интернет. При попытке установить k3s:
```
Could not resolve host: get.k3s.io
```

### Диагностика
```bash
ping google.com  # network unreachable
ping 8.8.8.8     # timeout
cat /etc/resolv.conf  # nameserver 192.168.1.1 (недоступен)
ip route show    # default route отсутствует
```

### Причины
1. Proxmox не настраивает NAT автоматически для VM
2. DNS сервер указан на Proxmox host (192.168.1.1), но недоступен из VM
3. Отсутствует маршрут по умолчанию

### Решение
```bash
# 1. Настройка публичного DNS (Google)
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf

# 2. Добавление маршрута по умолчанию через Proxmox host
ip route add default via 192.168.1.1

# 3. Проверка
ping 8.8.8.8      # OK
ping google.com   # OK
```

### Долгосрочное решение
Для постоянной настройки добавить в `/etc/network/interfaces`:
```
auto eth0
iface eth0 inet static
    address 192.168.1.3
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8 8.8.4.4
```

## Проблема 3: curl vs wget

### Проблема
После настройки DNS команда `curl` все равно не работала:
```bash
curl https://get.k3s.io  # DNS resolution failed
```

### Причина
Разные HTTP клиенты используют разные библиотеки для DNS и TLS. В Debian minimal могут отсутствовать нужные библиотеки для curl.

### Решение
Использовать `wget` вместо `curl`:
```bash
wget https://get.k3s.io -O /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
sh /tmp/k3s-install.sh
```

`wget` оказался более надежным в минимальных окружениях.

## Проблема 4: PowerShell строковая интерполяция

### Проблема
PowerShell неправильно обрабатывает переменные в строках с `${}` синтаксисом:
```powershell
$url = "https://github.com/cli/cli/releases/download/v$ghVersion/gh_${ghVersion}_windows_amd64.zip"
# Ошибка: Unexpected token '}'
```

### Причина
`${variable}` - это специальный синтаксис PowerShell для разыменования переменных. Когда в строке есть `${ghVersion}`, PowerShell пытается найти переменную с этим именем, но путается из-за подчеркивания после.

### Решение
Использовать конкатенацию строк вместо интерполяции:
```powershell
$url = "https://github.com/cli/cli/releases/download/v$ghVersion/gh_" + $ghVersion + "_windows_amd64.zip"
```

Или экранировать специальные символы:
```powershell
$url = "https://github.com/cli/cli/releases/download/v$ghVersion/gh_$($ghVersion)_windows_amd64.zip"
```

## Проблема 5: GitHub CLI аутентификация

### Проблема
GitHub API требует аутентификации для управления секретами. Попытка использовать API напрямую без токена:
```powershell
Invoke-RestMethod -Uri "https://api.github.com/repos/.../secrets/..." 
# 401 Unauthorized
```

### Решение
Использовать GitHub CLI (`gh`) вместо прямого API:

```powershell
# Установка
scoop install gh
# или
# скачать с https://cli.github.com/

# Аутентификация (один раз)
gh auth login

# Использование
echo $secretValue | gh secret set SECRET_NAME -R owner/repo
```

Преимущества `gh`:
- Автоматическая аутентификация
- Правильная кодировка секретов (требуется шифрование с публичным ключом репозитория)
- Простой синтаксис

## Проблема 6: Kubeconfig localhost

### Проблема
Kubeconfig от k3s по умолчанию использует `127.0.0.1`:
```yaml
server: https://127.0.0.1:6443
```

Это работает только на самом сервере, но не с клиентской машины.

### Решение
Заменить localhost на реальный IP сервера:
```powershell
$kubeconfig = Get-Content $kubePath -Raw
$kubeconfig = $kubeconfig -replace "127.0.0.1", $ServerIP
$kubeconfig | Set-Content $kubePath -Force
```

## Общие уроки

### 1. Автоматизация для Windows
- Используйте PuTTY tools (plink, pscp) для SSH с паролями
- PowerShell heredoc работает плохо - используйте однострочные команды
- Избегайте `${var}` синтаксиса в строках - используйте конкатенацию
- Тестируйте скрипты пошагово, не пишите все сразу

### 2. Proxmox networking
- VM не имеют интернета по умолчанию
- Нужно явно настроить DNS (8.8.8.8) и gateway
- Тестируйте connectivity перед установкой софта

### 3. k3s установка
- Проверяйте сетевой доступ до установки
- wget надежнее curl в minimal окружениях
- k3s создает kubeconfig с localhost - нужна замена IP

### 4. GitHub Actions секреты
- Используйте `gh` CLI вместо прямого API
- Секреты должны быть в base64 (kubeconfig)
- Сохраняйте копию секретов локально для восстановления

## Финальный рабочий процесс

```powershell
# 1. Скачать plink.exe
Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" -OutFile "$HOME\plink.exe"

# 2. Настроить сеть на VM
& "$HOME\plink.exe" -pw "password" -batch root@192.168.1.3 @"
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
ip route add default via 192.168.1.1
"@

# 3. Установить k3s
& "$HOME\plink.exe" -pw "password" -batch root@192.168.1.3 @"
wget https://get.k3s.io -O /tmp/k3s.sh
chmod +x /tmp/k3s.sh
INSTALL_K3S_EXEC='server --write-kubeconfig-mode=644' sh /tmp/k3s.sh
"@

# 4. Получить kubeconfig
$kubeconfig = & "$HOME\plink.exe" -pw "password" -batch root@192.168.1.3 "cat /etc/rancher/k3s/k3s.yaml"
$kubeconfig = $kubeconfig -replace "127.0.0.1", "192.168.1.3"
$kubeconfig | Set-Content "$HOME\k3s.yaml"

# 5. Настроить GitHub секреты
$kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeconfig))
echo $kubeB64 | gh secret set KUBECONFIG -R owner/repo
```

Этот процесс полностью автоматизирован в скрипте `DEPLOY.ps1`.
