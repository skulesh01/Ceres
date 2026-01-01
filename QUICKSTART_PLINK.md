# 🚀 CERES - Quick Deployment Guide

## Без пароля каждый раз? ✨

Используй **plink.exe** - передаёт пароль автоматически!

### Шаг 1: Скачай plink
```powershell
Invoke-WebRequest -Uri "https://the.earth.li/~sgtatham/putty/latest/w64/plink.exe" `
    -OutFile "$HOME\plink.exe" -UseBasicParsing
```

### Шаг 2: Используй вместо ssh
```powershell
$plink = "$HOME\plink.exe"
$pass = "!r0oT3dc"
$host = "192.168.1.3"

# Вместо:  ssh root@192.168.1.3 "command"
# Используй:
& $plink -pw $pass -batch root@$host "command"
```

Пароль передаётся автоматически - **без интерактивных подсказок**! ✅

---

## Полная автоматизация

### Вариант A: Со скриптом (если gh установлен)
```powershell
# 1. Выполнить полный setup
cd "E:\Новая папка\Ceres"
.\scripts\full-setup.ps1

# 2. Запустить deploy
gh workflow run ceres-deploy.yml -R skulesh01/Ceres
```

### Вариант B: Вручную (быстрее)
```powershell
$plink = "$HOME\plink.exe"
$pass = "!r0oT3dc"

# 1. SSH ключ
ssh-keygen -t ed25519 -f "$HOME\.ssh\ceres" -N ""

# 2. Добавить pub ключ
$pub = Get-Content "$HOME\.ssh\ceres.pub" -Raw
& $plink -pw $pass -batch root@192.168.1.3 "mkdir -p ~/.ssh; echo '$pub' >> ~/.ssh/authorized_keys"

# 3. Установить Docker + k3s
& $plink -pw $pass root@192.168.1.3 "curl -fsSL https://raw.githubusercontent.com/skulesh01/Ceres/main/scripts/install.sh | bash"

# 4. Получить kubeconfig
scp -i "$HOME\.ssh\ceres" -o StrictHostKeyChecking=no root@192.168.1.3:/etc/rancher/k3s/k3s.yaml "$HOME\k3s.yaml"

# 5. Закодировать
$kube = Get-Content "$HOME\k3s.yaml" -Raw
$kubeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kube))

# 6. Добавить secrets
gh secret set DEPLOY_HOST --body "192.168.1.3" -R skulesh01/Ceres
gh secret set DEPLOY_USER --body "root" -R skulesh01/Ceres
gh secret set SSH_PRIVATE_KEY --body (Get-Content "$HOME\.ssh\ceres" -Raw) -R skulesh01/Ceres
gh secret set KUBECONFIG --body $kubeB64 -R skulesh01/Ceres

# 7. Deploy
gh workflow run ceres-deploy.yml -R skulesh01/Ceres
```

---

**Ключ:** plink избавляет от интерактивных подсказок паролей!
