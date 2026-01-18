# CERES Project Index — Быстрая навигация

## 🚀 **С чего начать?**

- **Новичок?** → [docs/00-QUICKSTART.md](docs/00-QUICKSTART.md) ⭐
- **Хочу использовать CLI?** → [docs/01-CLI-USAGE.md](docs/01-CLI-USAGE.md)
- **Проблема?** → [docs/05-TROUBLESHOOTING.md](docs/05-TROUBLESHOOTING.md)

---

## 📂 **Основные папки проекта**

### `scripts/` — РАБОЧИЕ СКРИПТЫ
```
ceres.ps1                ← ГЛАВНОЕ ПРИЛОЖЕНИЕ (точка входа)
test-cli.ps1            ← Функциональные тесты
_lib/
  ├── Common.ps1        ← Общие функции (Ready ✅)
  ├── Validate.ps1      ← Валидация (Ready ✅)
  ├── Analyze.ps1       ← Анализ (📋 Следующая)
  ├── Configure.ps1     ← Конфигурирование (📋)
  ├── Generate.ps1      ← Генерация (📋)
  └── Deploy.ps1        ← Развёртывание (📋)
```

### `docs/` — ДОКУМЕНТАЦИЯ
```
00-QUICKSTART.md        ← Начните отсюда!
01-CLI-USAGE.md         ← Все команды
02-ARCHITECTURE.md      ← Как устроено
03-PROFILES.md          ← Выбор конфигурации
04-DEPLOYMENT.md        ← Развёртывание
05-TROUBLESHOOTING.md   ← Решение проблем
10-DEVELOPER-GUIDE.md   ← Расширение
INDEX.md                ← Указатель док (вы здесь)
```

### `config/` — КОНФИГУРАЦИЯ
```
.env.example            ← Шаблон переменных
DEPLOYMENT_PLAN.json    ← Ваш выбранный план (генерируется)
profiles/
  ├── small.json        ← Docker на 1 машине
  ├── medium.json       ← K8s на 3 VM
  └── large.json        ← K8s HA на 5 VM
templates/              ← Шаблоны для генерации
validation/             ← JSON схемы
compose/                ← Docker Compose конфиги
flux/                   ← Kubernetes manifests
terraform/              ← Infrastructure as Code
ansible/                ← OS configuration
caddy/                  ← Reverse proxy
```

### `examples/` — ПРАКТИЧЕСКИЕ ПРИМЕРЫ
```
local-setup.md          ← Локальная разработка
proxmox-deployment.md   ← На Proxmox
github-actions.md       ← CI/CD интеграция
troubleshooting-cases.md ← Реальные случаи
```

### `archive/` — СТАРЫЕ ФАЙЛЫ (для справки)
```
legacy-scripts/         ← Старые скрипты (не используйте!)
old-docs/               ← Старая документация
README.md               ← Что здесь и почему
```

---

## 📋 **Таблица всех основных файлов**

| Файл | Папка | Для кого | Когда читать |
|------|-------|----------|--------------|
| **README.md** | Корень | Все | Первый раз |
| **00-QUICKSTART.md** | docs/ | Новичок | Сразу после README |
| **01-CLI-USAGE.md** | docs/ | Пользователь | Перед использованием |
| **02-ARCHITECTURE.md** | docs/ | DevOps | Для понимания системы |
| **03-PROFILES.md** | docs/ | Админ | При выборе конфига |
| **04-DEPLOYMENT.md** | docs/ | Админ | При развёртывании |
| **05-TROUBLESHOOTING.md** | docs/ | При проблемах | Если что-то не работает |
| **10-DEVELOPER-GUIDE.md** | docs/ | Разработчик | Для расширения |
| **CERES_CLI_STATUS.md** | Корень | DevOps | Статус разработки |
| **CERES_CLI_ARCHITECTURE.md** | Корень | Разработчик | Архитектура CLI |
| **ANALYZE_MODULE_PLAN.md** | Корень | Разработчик | План разработки |

---

## 🎯 **Быстрые ссылки по функциям**

### Анализ и выбор конфигурации
- Анализ ресурсов → `ceres analyze resources` (см. [01-CLI-USAGE.md](docs/01-CLI-USAGE.md))
- Выбор профила → `ceres configure` (см. [03-PROFILES.md](docs/03-PROFILES.md))
- Что нужно → [docs/04-DEPLOYMENT.md](docs/04-DEPLOYMENT.md)

### Валидация и генерация
- Проверка окружения → `ceres validate environment` (см. [01-CLI-USAGE.md](docs/01-CLI-USAGE.md))
- Генерация конфигов → `ceres generate from-profile`
- Что случилось? → [docs/05-TROUBLESHOOTING.md](docs/05-TROUBLESHOOTING.md)

### Развёртывание
- Docker Compose → [examples/local-setup.md](examples/local-setup.md)
- Kubernetes + Proxmox → [examples/proxmox-deployment.md](examples/proxmox-deployment.md)
- GitHub Actions → [examples/github-actions.md](examples/github-actions.md)

### Проблемы
- Не работает → [docs/05-TROUBLESHOOTING.md](docs/05-TROUBLESHOOTING.md)
- Конкретный случай → [examples/troubleshooting-cases.md](examples/troubleshooting-cases.md)
- Логи → `ceres logs <service>`

### Для разработчиков
- Расширить систему → [docs/10-DEVELOPER-GUIDE.md](docs/10-DEVELOPER-GUIDE.md)
- Архитектура CLI → [CERES_CLI_ARCHITECTURE.md](CERES_CLI_ARCHITECTURE.md)
- Планы разработки → [ANALYZE_MODULE_PLAN.md](ANALYZE_MODULE_PLAN.md)

---

## 🔄 **Сценарии использования**

### Сценарий 1: Локальная разработка (Docker)
```
1. README.md (обзор)
2. docs/00-QUICKSTART.md (установка)
3. docs/01-CLI-USAGE.md (команды)
4. examples/local-setup.md (пример)
5. ceres configure --preset small
6. ceres deploy applications
```

### Сценарий 2: Production на Proxmox
```
1. README.md
2. docs/00-QUICKSTART.md
3. docs/02-ARCHITECTURE.md
4. docs/03-PROFILES.md (выбрать medium или large)
5. docs/04-DEPLOYMENT.md
6. examples/proxmox-deployment.md
7. ceres deploy all --profile medium
```

### Сценарий 3: CI/CD автоматизация
```
1. docs/00-QUICKSTART.md
2. examples/github-actions.md
3. docs/01-CLI-USAGE.md (non-interactive режим)
4. Настроить GitHub Secrets
5. Запустить pipeline
```

### Сценарий 4: Расширение системы
```
1. docs/02-ARCHITECTURE.md
2. CERES_CLI_ARCHITECTURE.md
3. docs/10-DEVELOPER-GUIDE.md
4. ANALYZE_MODULE_PLAN.md (как пример)
5. Создавать свои модули
```

---

## 📊 **Структура документов по уровню**

### Уровень 1: Новичок
- README.md
- docs/00-QUICKSTART.md
- docs/01-CLI-USAGE.md

### Уровень 2: Пользователь/Админ
- docs/03-PROFILES.md
- docs/04-DEPLOYMENT.md
- docs/05-TROUBLESHOOTING.md
- examples/local-setup.md

### Уровень 3: DevOps
- docs/02-ARCHITECTURE.md
- examples/proxmox-deployment.md
- examples/github-actions.md
- config/terraform/README.md
- config/ansible/README.md

### Уровень 4: Разработчик/Архитектор
- docs/10-DEVELOPER-GUIDE.md
- CERES_CLI_ARCHITECTURE.md
- ANALYZE_MODULE_PLAN.md
- examples/troubleshooting-cases.md
- config/*/README.md (все)

---

## ✅ **Чек-лист для разных ролей**

### Администратор сервера
- [ ] Прочитать README.md
- [ ] Прочитать docs/00-QUICKSTART.md
- [ ] Выбрать профил в docs/03-PROFILES.md
- [ ] Развернуть по docs/04-DEPLOYMENT.md
- [ ] Сохранить docs/05-TROUBLESHOOTING.md в закладки

### DevOps инженер
- [ ] Прочитать README.md
- [ ] Изучить docs/02-ARCHITECTURE.md
- [ ] Изучить CERES_CLI_ARCHITECTURE.md
- [ ] Посмотреть examples/proxmox-deployment.md
- [ ] Посмотреть examples/github-actions.md

### Разработчик (добавить сервис)
- [ ] Прочитать docs/02-ARCHITECTURE.md
- [ ] Прочитать docs/10-DEVELOPER-GUIDE.md
- [ ] Изучить CERES_CLI_ARCHITECTURE.md
- [ ] Посмотреть ANALYZE_MODULE_PLAN.md как пример

### Тестировщик
- [ ] README.md
- [ ] docs/00-QUICKSTART.md
- [ ] docs/01-CLI-USAGE.md
- [ ] examples/local-setup.md
- [ ] Закладка на docs/05-TROUBLESHOOTING.md

---

## 🔗 **Перекрёстные ссылки**

- **Как выбрать профил?** → [docs/03-PROFILES.md](docs/03-PROFILES.md)
- **Как развернуть?** → [docs/04-DEPLOYMENT.md](docs/04-DEPLOYMENT.md)
- **Не работает?** → [docs/05-TROUBLESHOOTING.md](docs/05-TROUBLESHOOTING.md)
- **Как использовать CLI?** → [docs/01-CLI-USAGE.md](docs/01-CLI-USAGE.md)
- **Как устроено?** → [docs/02-ARCHITECTURE.md](docs/02-ARCHITECTURE.md)
- **Я разработчик** → [docs/10-DEVELOPER-GUIDE.md](docs/10-DEVELOPER-GUIDE.md)

---

**Готовы начать?** → [docs/00-QUICKSTART.md](docs/00-QUICKSTART.md) ⭐

**Потеряетесь?** → Вернитесь сюда!
