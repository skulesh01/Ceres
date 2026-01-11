# GitHub Actions Setup для CERES

Инструкции по настройке автодеплоя на Kubernetes через GitHub Actions.

## Требуемые секреты

Нужно добавить в репозиторий (Settings → Secrets and variables → Actions):

| Секрет | Описание | Пример |
|--------|---------|--------|
| `DEPLOY_HOST` | IP сервера Kubernetes | `192.168.1.3` |
| `DEPLOY_USER` | SSH пользователь | `root` |
| `SSH_PRIVATE_KEY` | Приватный SSH-ключ (целиком) | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `KUBECONFIG` | kubeconfig в base64 (опционально) | output из `base64 ~/.kube/config` |

## Пошагово на Windows PowerShell

### 1. Генерируем SSH-ключ (если нет)

```powershell
# Генерируем ключ ed25519
ssh-keygen -t ed25519 -f $HOME\.ssh\ceres -N ""

# Выводим приватный ключ для секрета
$key = Get-Content $HOME\.ssh\ceres -Raw
Write-Host $key
# Скопируйте вывод
```

### 2. Добавляем публичный ключ на сервер

```powershell
# Отправляем публичный ключ на сервер
$pubKey = Get-Content $HOME\.ssh\ceres.pub
ssh root@192.168.1.3 "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
# (введите пароль)
```

### 3. Получаем kubeconfig с сервера

```powershell
# Копируем kubeconfig локально
scp root@192.168.1.3:/etc/rancher/k3s/k3s.yaml $HOME\k3s.yaml
# или для обычного k8s:
scp root@192.168.1.3:~/.kube/config $HOME\kube-config

# Кодируем в base64 (PowerShell)
$kubeconfig = Get-Content $HOME\k3s.yaml -Raw
$base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($kubeconfig))
Write-Host $base64
# Скопируйте вывод
```

### 4. Добавляем секреты в GitHub через CLI

Если установлен GitHub CLI (`gh`):

```powershell
# Авторизируемся в GitHub
gh auth login

# Переходим в директорию проекта
cd $HOME\Ceres

# Добавляем секреты (замените <значение>)
gh secret set DEPLOY_HOST --body "192.168.1.3"
gh secret set DEPLOY_USER --body "root"
gh secret set SSH_PRIVATE_KEY --body (Get-Content $HOME\.ssh\ceres -Raw)
gh secret set KUBECONFIG --body "<base64_string_из_шага_3>"
```

Или вручную через веб-интерфейс:
- Откройте https://github.com/skulesh01/Ceres/settings/secrets/actions
- Нажмите "New repository secret"
- Добавьте каждый секрет по одному

## Запуск деплоя

### Через GitHub Actions веб-интерфейс

1. Откройте репо → Actions
2. Выберите "Ceres Deploy"
3. Нажмите "Run workflow"
4. Заполните параметры:
   - Branch: `main` (по умолчанию)
   - Remote app directory: `/srv/ceres` (по умолчанию)
5. Нажмите "Run workflow"

### Через GitHub CLI

```powershell
gh workflow run ceres-deploy.yml -f branch=main -f app_dir=/srv/ceres -R skulesh01/Ceres

# Смотрим статус
gh run list -R skulesh01/Ceres

# Смотрим логи последнего запуска
gh run view -R skulesh01/Ceres --log
```

## Что происходит при деплое

1. **Checkout** — скачивает код из репозитория
2. **SSH connect** — подключается к серверу по SSH
3. **Clone/update** — клонирует или обновляет репо на сервере
4. **Bootstrap** — проверяет зависимости (git, docker, kubectl)
5. **Deploy** — применяет Kubernetes манифесты (`kubectl apply -f config/k8s/`)
6. **Smoke tests** — запускает быстрые проверки готовности
7. **Status** — выводит статус ресурсов в k8s

## Логирование и отладка

- **Логи workflow** → Actions → выберите run → смотрите вывод каждого шага
- **Логи на сервере** → `ssh root@192.168.1.3` и смотрите `/srv/ceres/logs/`
- **Статус k8s** → `kubectl get pods,svc -A`

## Что если что-то не работает

### SSH не подключается
```powershell
# Проверяем доступ
ssh -v root@192.168.1.3
# Убедитесь, что публичный ключ добавлен в ~/.ssh/authorized_keys на сервере
```

### kubectl не найден на сервере
```bash
# На сервере установите k3s
curl -sfL https://get.k3s.io | sh -
# или обычный k8s
```

### Манифесты не применяются
- Проверьте, что в `config/k8s/` есть YAML файлы
- Или используйте `docker-compose`, если манифестов нет

## Следующие шаги

1. Убедитесь, что на сервере установлены зависимости:
   ```bash
   bash /srv/ceres/scripts/install.sh
   ```

2. Заполните `.env.example` на сервере:
   ```bash
   cp /srv/ceres/.env.example /srv/ceres/.env
   nano /srv/ceres/.env
   ```

3. Запустите bootstrap вручную (опционально):
   ```bash
   bash /srv/ceres/scripts/bootstrap.sh
   ```

4. Запустите первый деплой через GitHub Actions
