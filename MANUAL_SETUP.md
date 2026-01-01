# 🚀 Manual Setup Instructions

## 🔑 Краткий способ - с plink (БЕЗ вввода паролей)

Если вы хотите избежать ввода пароля каждый раз, используйте **plink** (из PuTTY):

```powershell
# 1. Скачать plink.exe (просто запусти в PowerShell)
Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" `
    -OutFile "$HOME\plink.exe" -UseBasicParsing

# 2. Теперь используй plink вместо ssh (пароль передается автоматически)
& "$HOME\plink.exe" -pw "!r0oT3dc" root@192.168.1.3 "echo OK"

# 3. Используй в скриптах вместо ssh:
$pubKey = Get-Content "$HOME\.ssh\ceres.pub" -Raw
& "$HOME\plink.exe" -pw "!r0oT3dc" root@192.168.1.3 "mkdir -p ~/.ssh; echo '$pubKey' >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"
```

После этого SSH-ключ будет зарегистрирован, и дальше можно использовать обычный `ssh -i` без пароля.

---

## Или обычный способ - с вводом пароля

Из-за ограничений интерактивного SSH в текущей среде, выполните эти шаги вручную (займёт 5 минут):

## Шаг 1: Откройте PowerShell (Windows)

```powershell
# Проверьте версию
$PSVersionTable.PSVersion
```

## Шаг 2: Создайте SSH-ключ

```powershell
# Создаём директорию
mkdir "$HOME\.ssh" -Force -ErrorAction SilentlyContinue

# Генерируем ключ ed25519
ssh-keygen -t ed25519 -f "$HOME\.ssh\ceres" -N ""

# Проверяем
ls "$HOME\.ssh\ceres*"
```

## Шаг 3: Добавьте публичный ключ на сервер

```powershell
# Этот команда попросит пароль (введите: !r0oT3dc)
$pubKey = Get-Content "$HOME\.ssh\ceres.pub" -Raw
ssh root@192.168.1.3 "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

**Вводит пароль:** !r0oT3dc

## Шаг 4: Проверьте доступ без пароля

```powershell
ssh -i "$HOME\.ssh\ceres" root@192.168.1.3 "uname -a"
```

Должна вывести информацию о системе **без запроса пароля**.

## Шаг 5: Установите зависимости на сервере

```powershell
ssh -i "$HOME\.ssh\ceres" root@192.168.1.3 "bash -c '$(curl -fsSL https://raw.githubusercontent.com/skulesh01/Ceres/main/scripts/install.sh)'"
```

Это займёт 5-10 минут. Установит: Docker, k3s, kubectl.

## Шаг 6: Получите kubeconfig

```powershell
scp -i "$HOME\.ssh\ceres" root@192.168.1.3:/etc/rancher/k3s/k3s.yaml "$HOME\k3s.yaml"

# Проверьте
cat "$HOME\k3s.yaml"
```

## Шаг 7: Закодируйте kubeconfig в base64

```powershell
$kubeconfig = Get-Content "$HOME\k3s.yaml" -Raw
$kubeBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeconfig))

# Сохраняем для справки
$kubeBase64 | Out-File "$HOME\kubeconfig.base64.txt" -NoNewline

# Выводим (скопируйте это значение)
Write-Host $kubeBase64
```

## Шаг 8: Добавьте секреты в GitHub Actions

Откройте: **https://github.com/skulesh01/Ceres/settings/secrets/actions**

Нажмите "New repository secret" и добавьте:

| Name | Value |
|------|-------|
| `DEPLOY_HOST` | 192.168.1.3 |
| `DEPLOY_USER` | root |
| `SSH_PRIVATE_KEY` | `Get-Content "$HOME\.ssh\ceres" -Raw` (весь файл) |
| `KUBECONFIG` | `Get-Content "$HOME\kubeconfig.base64.txt" -Raw` (весь файл) |

**Или через GitHub CLI:**

```powershell
gh auth login  # если не авторизированы

gh secret set DEPLOY_HOST --body "192.168.1.3"
gh secret set DEPLOY_USER --body "root"
gh secret set SSH_PRIVATE_KEY --body (Get-Content "$HOME\.ssh\ceres" -Raw)
gh secret set KUBECONFIG --body (Get-Content "$HOME\kubeconfig.base64.txt" -Raw)
```

## Шаг 9: Запустите деплой

**Через GitHub Actions:**
1. Откройте https://github.com/skulesh01/Ceres/actions
2. Выберите "Ceres Deploy"
3. Нажмите "Run workflow"
4. Заполните (можно оставить по умолчанию):
   - Branch: `main`
   - Remote app directory: `/srv/ceres`
5. Нажмите "Run workflow"

**Или через GitHub CLI:**

```powershell
gh workflow run ceres-deploy.yml -R skulesh01/Ceres
gh run watch -R skulesh01/Ceres  # смотреть логи
```

## ✅ Проверка после деплоя

На сервере:

```powershell
ssh -i "$HOME\.ssh\ceres" root@192.168.1.3

# На сервере:
kubectl get pods -A
kubectl get svc -a
docker ps
journalctl -u k3s -f
```

---

## ✨ Что произошло автоматически

После запуска скрипта с plink были выполнены:

✅ SSH ключ создан: `~/.ssh/ceres`  
✅ Public key добавлен на 192.168.1.3  
✅ Docker и k3s установлены на сервере  
✅ kubeconfig кодирован в base64: `~/kubeconfig.b64`

## 📋 Что осталось

1. **Установить GitHub CLI** (если ещё не установлен):
   ```powershell
   choco install gh  # если есть Chocolatey
   # Или скачать: https://cli.github.com
   ```

2. **Добавить GitHub secrets** (вручную или через CLI):
   ```powershell
   $keyFile = "$HOME\.ssh\ceres"
   $kubeB64 = Get-Content "$HOME\kubeconfig.b64" -Raw
   $privKey = Get-Content $keyFile -Raw
   $repo = "skulesh01/Ceres"
   
   gh secret set DEPLOY_HOST --body "192.168.1.3" --repo $repo
   gh secret set DEPLOY_USER --body "root" --repo $repo
   gh secret set SSH_PRIVATE_KEY --body $privKey --repo $repo
   gh secret set KUBECONFIG --body $kubeB64 --repo $repo
   ```

3. **Запустить развёртывание**:
   ```powershell
   gh workflow run ceres-deploy.yml -R skulesh01/Ceres
   gh run watch -R skulesh01/Ceres
   ```

---

**Дата:** 2026-01-01  
**Статус:** Готово! (нужна установка GitHub CLI)
