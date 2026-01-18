# Настройка GitHub Actions секретов

## Что нужно сделать

Для автоматического деплоймента CERES на k3s кластер нужно настроить GitHub Actions секреты.

## Шаг 1: Установить GitHub CLI

### Через Scoop (рекомендуется)
```powershell
scoop install gh
```

### Или скачать вручную
Скачайте установщик с https://cli.github.com/ и установите.

## Шаг 2: Аутентифицироваться в GitHub

```powershell
gh auth login
```

Следуйте инструкциям:
1. Выберите `GitHub.com`
2. Выберите `HTTPS`
3. Выберите `Login with a web browser`
4. Скопируйте код и откройте браузер
5. Введите код и подтвердите доступ

## Шаг 3: Запустить скрипт настройки секретов

```powershell
.\scripts\setup-github-secrets.ps1
```

Скрипт установит следующие секреты:
- **KUBECONFIG** - конфигурация для доступа к k3s кластеру (base64)
- **SSH_PRIVATE_KEY** - приватный SSH ключ для доступа к серверу
- **DEPLOY_HOST** - IP адрес сервера (192.168.1.3)
- **DEPLOY_USER** - пользователь для SSH (root)
- **DEPLOY_PASSWORD** - пароль для SSH (<DEPLOY_PASSWORD>)

## Шаг 4: Запустить деплоймент

После настройки секретов можно запустить GitHub Actions workflow:

```powershell
gh workflow run deploy.yml -R skulesh01/Ceres
```

Или вручную через веб-интерфейс:
1. Откройте https://github.com/skulesh01/Ceres/actions
2. Выберите workflow "Deploy CERES"
3. Нажмите "Run workflow"
4. Выберите ветку (обычно `main`)
5. Нажмите "Run workflow"

## Проверка результата

Проверить статус деплоймента:
```powershell
gh run watch -R skulesh01/Ceres
```

Или через веб-интерфейс:
https://github.com/skulesh01/Ceres/actions

## Ручная настройка секретов (альтернатива)

Если не хотите использовать скрипт, можно настроить секреты вручную:

1. Откройте https://github.com/skulesh01/Ceres/settings/secrets/actions
2. Нажмите "New repository secret"
3. Добавьте каждый секрет:

### KUBECONFIG
```powershell
$kube = Get-Content "$HOME\k3s.yaml" -Raw
$kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kube))
echo $kubeB64 | clip
```
Вставьте из буфера обмена.

### SSH_PRIVATE_KEY
```powershell
Get-Content "$HOME\.ssh\ceres" -Raw | clip
```
Вставьте из буфера обмена.

### DEPLOY_HOST
```
192.168.1.3
```

### DEPLOY_USER
```
root
```

### DEPLOY_PASSWORD
```
<DEPLOY_PASSWORD>
```

## Что дальше?

После настройки секретов и запуска деплоймента:
1. GitHub Actions установит все сервисы CERES на k3s
2. Сервисы будут доступны по адресам:
   - Keycloak: https://auth.ceres.local
   - Wiki.js: https://wiki.ceres.local
   - Grafana: https://grafana.ceres.local
   - И другие...

3. Не забудьте добавить записи в hosts на клиентском ПК:
   ```
   192.168.1.3 auth.ceres.local wiki.ceres.local grafana.ceres.local
   ```
