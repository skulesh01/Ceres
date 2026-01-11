# Deployment & Bootstrap Scripts

Скрипты для полной автоинициализации и деплоя CERES на сервер.

## Скрипты

### bootstrap.sh
Главный скрипт инициализации. Проверяет зависимости, инициализирует окружение, валидирует структуру проекта.

```bash
./scripts/bootstrap.sh
```

### check-dependencies.sh
Проверяет наличие необходимых инструментов: git, curl, wget, docker/podman, kubectl (опционально).

```bash
./scripts/check-dependencies.sh
```

### init-environment.sh
Инициализирует окружение: создаёт директории, выставляет права, создаёт `.env.example`.

```bash
./scripts/init-environment.sh
```

### deploy.sh
Главный оркестратор деплоя. Выполняет проверку, инициализацию, сборку и развёртывание.

```bash
# Проверить зависимости
./scripts/deploy.sh check

# Инициализировать
./scripts/deploy.sh init

# Валидировать k8s-манифесты
./scripts/deploy.sh build

# Развернуть в k8s
./scripts/deploy.sh deploy

# Smoke-тесты
./scripts/deploy.sh smoke

# Всё по порядку
./scripts/deploy.sh all
```

## Переменные окружения

Скопируйте `.env.example` в `.env` и заполните:

```bash
cp .env.example .env
# отредактируйте .env
source .env
./scripts/deploy.sh all
```

Обязательные переменные:
- `REMOTE_HOST` — IP сервера
- `REMOTE_USER` — пользователь SSH
- `SSH_KEY_PATH` — путь к приватному ключу
- `K8S_MANIFEST_PATH` — путь к манифестам на сервере

Опциональные:
- `REMOTE_PORT` — порт SSH (по умолчанию 22)
- `REMOTE_KUBECONFIG` — путь к kubeconfig на сервере
- `GH_REPO` — owner/repo для GitHub Actions
- `TENANT_NAME`, `TENANT_DOMAIN` — для автопровижена арендатора

## Полный процесс первого развёртывания

1. На сервере:
   ```bash
   curl -sfL https://get.k3s.io | sh -
   ```

2. На вашей машине:
   ```bash
   # Скопируйте kubeconfig с сервера
   scp $DEPLOY_SERVER_USER@$DEPLOY_SERVER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/ceres.yaml
   
   # Подготовьте переменные
   cp .env.example .env
   # отредактируйте .env
   
   # Полный деплой
   ./scripts/deploy.sh all
   ```

3. Проверка:
   ```bash
   kubectl get pods
   kubectl get services
   ```

## Логирование

Логи сохраняются в `./logs/`:
- `bootstrap.log` — логи инициализации
- `deploy.log` — логи деплоя
- `smoke.log` — логи тестов
