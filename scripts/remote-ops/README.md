# Remote Ops Helper

Лёгкие скрипты для удалённого выполнения команд по SSH, `git pull`, копирования файлов и применения манифестов k8s. Ничего не хранит внутри себя, все доступы задаются переменными окружения или параметрами.

## Предварительно
- На сервере должен работать SSH.
- На вашей машине должен быть установлен ssh-клиент (OpenSSH) и добавлен ваш публичный ключ на сервер (в `~/.ssh/authorized_keys`).
- Рекомендуемые переменные окружения (можно задать в shell или GitHub Actions секретах):
  - `REMOTE_HOST` — адрес сервера
  - `REMOTE_USER` — пользователь (например, `root`)
  - `REMOTE_PORT` — порт SSH (по умолчанию 22)
  - `SSH_KEY_PATH` — путь до приватного ключа (если не зададите, будет использоваться агент или дефолтный ключ)
  - `REMOTE_KUBECONFIG` — путь к kubeconfig на сервере (по умолчанию `~/.kube/config`)

## Примеры
### PowerShell (Windows)
```powershell
# Выполнить команду
./remote.ps1 -Action cmd -Argument "uname -a"

# git pull в каталоге /srv/ceres
./remote.ps1 -Action git-pull -Argument "/srv/ceres"

# загрузить файл на сервер
./remote.ps1 -Action upload -Argument "C:\\tmp\\cfg.yml" -Argument2 "/srv/ceres/cfg.yml"

# применить манифесты k8s на сервере
./remote.ps1 -Action kubectl-apply -Argument "/srv/ceres/k8s"
```

### Bash (Linux/macOS/WSL)
```bash
# Выполнить команду
./remote.sh cmd "uname -a"

# git pull в каталоге /srv/ceres
./remote.sh git-pull /srv/ceres

# загрузить файл на сервер
./remote.sh upload ./local.yml /srv/ceres/local.yml

# применить манифесты k8s на сервере
./remote.sh kubectl-apply /srv/ceres/k8s
```

## Параметры безопасности
- Не храните пароли/ключи в файлах репозитория. Используйте переменные окружения или секреты CI.
- Если нужен пароль, можно временно задать `SSH_ASKPASS` или использовать ssh-agent, но лучше ключи.
