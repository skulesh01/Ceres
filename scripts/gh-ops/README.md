# GH Ops Helper

Набор утилит для работы с GitHub Actions через `gh` (GitHub CLI). Ничего не хранит, использует переменные окружения.

## Требования
- Установлен `gh` и выполнен `gh auth login` с доступом к репозиторию.
- Переменные окружения:
  - `GH_REPO` — `owner/repo` (пример: `acme/ceres`).

## Возможности
- Запуск workflow с вводом параметров.
- Просмотр статуса последнего запуска.
- Установка секрета в репозитории.

## Примеры
```bash
# Запустить workflow по имени файла (manual dispatch), с вводом параметров
GH_REPO=acme/ceres ./gh-actions.sh run .github/workflows/ceres-deploy.yml env="prod"

# Показать последний запуск
GH_REPO=acme/ceres ./gh-actions.sh last .github/workflows/ceres-deploy.yml

# Установить секрет
GH_REPO=acme/ceres ./gh-actions.sh secret DEPLOY_HOST 192.168.1.3
```
