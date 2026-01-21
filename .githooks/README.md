# Git Hooks для CERES

Этот каталог содержит Git хуки для автоматической проверки версионирования.

## Установка

```bash
# Настроить Git для использования этих хуков
git config core.hooksPath .githooks

# Сделать хуки исполняемыми (Linux/Mac)
chmod +x .githooks/*
```

## Хуки

### pre-commit
Проверяет перед каждым коммитом:
- ✅ Совпадение версии в `VERSION` и `cmd/ceres/main.go`
- ✅ Формат версии (semantic versioning: X.Y.Z)
- ⚠️ Наличие версии в сообщении коммита

## Отключение хуков

```bash
# Временно пропустить хук
git commit --no-verify -m "..."

# Отключить навсегда
git config core.hooksPath ""
```
