# ⚡ Быстрый старт: Redmine Ultimate (15 минут)

Полная настройка корпоративного проект-менеджмента — лучше чем Jira Enterprise!

---

## 🎯 Что получишь

✅ **27 бесплатных плагинов** (Scrum, Kanban, Gantt, Q&A, автоматизация)  
✅ **Email workflows** (13 типов уведомлений + согласование документов)  
✅ **Интеграции** (Keycloak SSO, GitLab, Mattermost)  
✅ **3 шаблона проектов** (Software Dev, Marketing, Operations)  
✅ **5 корпоративных ролей** (Product Owner, Scrum Master, Developer, QA, Stakeholder)  
✅ **Полная автоматизация** (авто-назначение, авто-закрытие, эскалация)

**Стоимость:** $0 (vs Jira Enterprise $14-$150/пользователь/месяц)

---

## 📋 Предварительные требования

- ✅ CERES развернут (K3s работает)
- ✅ PostgreSQL развернут
- ✅ Mailcow развернут (для email)
- ✅ Keycloak развернут (для SSO)

**Проверка:**
```bash
kubectl get pods -n postgresql
kubectl get pods -n mailcow
kubectl get pods -n keycloak
```

Все должны быть `Running`.

---

## 🚀 Шаг 1: Разворачиваем Redmine (5 минут)

```bash
ssh root@192.168.1.3
cd /root/Ceres

# Обновляемся до v3.2.1
git pull origin main

# Собираем и разворачиваем Redmine с 27 плагинами
./scripts/setup-redmine.sh
```

**Что происходит:**
1. Собирается Docker image с 27 плагинами (3 мин)
2. Импортируется в K3s (30 сек)
3. Создается БД в PostgreSQL (10 сек)
4. Разворачивается Redmine (30 сек)
5. Мигрируются все плагины (1 мин)
6. Создается admin пользователь
7. Создается пример проекта

**Результат:**
```
✅ Redmine deployed successfully!

Access: http://192.168.1.3:30310
Login: admin
Password: admin123

Plugins installed: 27
```

---

## 🎨 Шаг 2: Полная настройка (10 минут)

```bash
# Запускаем Ultimate конфигурацию
./scripts/configure-redmine-ultimate.sh
```

**Что будет настроено:**

### 1. Email (1 мин)

Скрипт спросит:
```
SMTP Server (default: mailcow.ceres.svc.cluster.local): [Enter]
SMTP Port (default: 587): [Enter]
SMTP User (default: redmine@ceres.local): [Enter]
SMTP Password: [ваш пароль]
From Email (default: redmine@ceres.local): [Enter]
```

**Результат:**
- ✅ 13 типов email уведомлений
- ✅ Тестовое письмо отправлено
- ✅ Уведомления о задачах, упоминаниях, статусах

### 2. Keycloak SSO (1 мин)

**Автоматически настроится:**
- ✅ SAML integration
- ✅ Атрибуты (email, username, firstName, lastName)
- ✅ Авто-создание пользователей

**⚠️ Ручной шаг (5 мин):**
1. Открой Keycloak: `http://keycloak.ceres.local`
2. Realm: CERES → Clients → Create
3. Client ID: `redmine`
4. Client Protocol: `saml`
5. Valid Redirect URIs: `http://redmine.ceres.local/*`
6. Save

### 3. GitLab Integration (2 мин)

**Автоматически настроится:**
- ✅ Webhook endpoint
- ✅ Secret token сгенерирован
- ✅ Авто-закрытие задач из коммитов

**⚠️ Ручной шаг (per project):**
1. Открой GitLab проект → Settings → Webhooks
2. URL: `http://redmine.redmine.svc.cluster.local:3000/github_hook`
3. Secret: (скопируй из вывода скрипта)
4. Events: ✅ Push, ✅ Comments, ✅ Merge requests
5. Add webhook

**Использование:**
```bash
git commit -m "Fix login bug, fixes #123"
git push
# → Задача #123 автоматически закроется
```

### 4. Mattermost Integration (1 мин)

Скрипт спросит:
```
Mattermost webhook URL (get from Mattermost): [paste URL]
```

**Получить webhook:**
1. Mattermost → Integrations → Incoming Webhooks
2. Add Incoming Webhook
3. Channel: `#projects`
4. Display Name: `Redmine`
5. Copy URL

**Результат:**
- ✅ Новая задача → сообщение в #projects
- ✅ Обновление → сообщение в #projects
- ✅ @mention → DM пользователю

### 5. Workflow Automation (2 мин)

**Автоматически настроится:**
- ✅ Авто-назначение багов на Manager
- ✅ Авто-закрытие задач при коммите с "fixes"
- ✅ Эскалация просроченных согласований

**Пример:**
```
Создается Bug → автоматически назначается на Manager
Developer делает коммит "fixes #456" → задача #456 автоматически закрывается
Согласование просрочено → Priority = High, email Manager-у
```

### 6. Project Templates (1 мин)

**Автоматически создаются 3 шаблона:**

1. **[TEMPLATE] Software Development**
   - Trackers: User Story, Bug, Feature, Task
   - Modules: Backlogs, Agile, Gantt, Repository, Wiki
   - Workflows: New → Assigned → In Progress → Code Review → Testing → Closed

2. **[TEMPLATE] Marketing Campaign**
   - Trackers: Campaign Task, Content Creation, Event
   - Categories: Social Media, Email, Events, Content

3. **[TEMPLATE] Operations & Support**
   - Trackers: Support Ticket, Maintenance, Incident
   - SLA tracking

**Использование:**
1. Administration → Projects → Copy project
2. Выбери шаблон → Copy
3. Готово!

### 7. Issue Templates (1 мин)

**Автоматически создаются:**
- ✅ Bug Report (Steps to reproduce, Environment, Screenshots)
- ✅ Feature Request (Business value, Acceptance criteria)
- ✅ User Story (As a [role] I want [feature] so that [benefit])

**Использование:**
1. New issue → Template → Select template
2. Заполняешь поля
3. Submit

### 8. Enterprise Roles (1 мин)

**Автоматически создаются:**
- 👔 **Product Owner** - Управление backlog, приоритеты
- 🎯 **Scrum Master** - Facilitation спринтов, отчеты
- 👨‍💻 **Developer** - Код, time tracking, задачи
- 🧪 **QA Engineer** - Тесты, баги
- 👀 **Stakeholder** - View-only (для руководства)

**Назначение:**
1. Project → Settings → Members
2. Add user → Select role
3. Save

---

## 🎉 Шаг 3: Первый проект (5 минут)

```bash
# Открой http://redmine.ceres.local
# Login: admin / admin123
```

### 1. Смени пароль админа

- My account → Change password
- Новый пароль → Save

### 2. Изучи пример проекта

- Projects → CERES Platform Development
- Вкладка **Backlogs** → Видишь спринты, user stories
- Вкладка **Agile** → Kanban board (drag & drop)
- Вкладка **Gantt** → Timeline с зависимостями

### 3. Создай свой проект

**Вариант 1: Из шаблона**
1. Administration → Projects
2. [TEMPLATE] Software Development → Copy
3. Name: `Мой Проект`
4. Identifier: `my-project`
5. Copy → Ready!

**Вариант 2: С нуля**
1. Projects → New project
2. Name: `Мой Проект`
3. Modules: ✅ Backlogs, ✅ Agile, ✅ Gantt
4. Create
5. Settings → Modules → Enable all
6. Settings → Trackers → ✅ User Story, ✅ Bug, ✅ Feature, ✅ Task

### 4. Создай первую задачу

1. New issue
2. Template: User Story
3. Subject: `As a user, I want to login via SSO`
4. Description: (автоматически заполнено из шаблона)
5. Assigned to: (выбери себя)
6. Target version: Sprint 1
7. Create

### 5. Переключись на Kanban

1. Вкладка **Agile**
2. Drag & drop задачу: Backlog → In Progress
3. Готово!

---

## 📧 Email Workflows (примеры)

### Пример 1: Bug Report

1. QA создает баг → Email Developer-у
2. Developer fix → Email QA
3. QA тестирует → Email Reporter (fixed)

### Пример 2: Согласование счета (3 уровня)

1. Бухгалтер загружает счет → Email Team Lead-у
2. Team Lead approve → Email Manager-у
3. Manager approve → Email CFO
4. CFO approve → Email всем (approved)

**Настройка:**
1. New issue → Tracker: Approval
2. Subject: `Счет #12345 - Канцелярия`
3. Attachments: invoice.pdf
4. Custom field "Approver": john.doe@ceres.local
5. Submit → Email отправлен с кнопками Approve/Reject

### Пример 3: @mention

```
Комментарий: "@ivanov посмотри этот баг, срочно!"
→ Email отправлен ivanov@ceres.local с текстом упоминания
```

---

## 🔧 Troubleshooting

### Email не отправляется

**Проверь SMTP:**
```bash
kubectl exec -n redmine $(kubectl get pod -n redmine -l app=redmine -o name | head -1) -- bundle exec rails console

# В консоли:
ActionMailer::Base.smtp_settings
# Проверь настройки

exit
```

**Тестовое письмо:**
```bash
kubectl exec -n redmine $(kubectl get pod -n redmine -l app=redmine -o name | head -1) -- bundle exec rails runner "
  Mailer.test_email('your.email@ceres.local').deliver_now
"
```

### SSO не работает

1. Проверь Keycloak client создан
2. Valid Redirect URIs: `http://redmine.ceres.local/*`
3. Client Protocol: SAML
4. Restart Redmine:
   ```bash
   kubectl rollout restart deployment/redmine -n redmine
   ```

### Плагин не загрузился

```bash
# Проверь список плагинов
kubectl exec -n redmine $(kubectl get pod -n redmine -l app=redmine -o name | head -1) -- ls plugins/

# Мигрируй вручную
kubectl exec -n redmine $(kubectl get pod -n redmine -l app=redmine -o name | head -1) -- bundle exec rake redmine:plugins:migrate
```

---

## 📊 Метрики успеха

После настройки проверь:

### 1. Email уведомления

- Administration → Settings → Email notifications
- Должно быть: 13 event types enabled

### 2. Плагины

- Administration → Plugins
- Должно быть: 27 плагинов

### 3. Проекты

- Projects → All projects
- Должно быть: 4 проекта (Example + 3 шаблона)

### 4. Роли

- Administration → Roles and permissions
- Должно быть: 5 enterprise ролей

### 5. Automation

- Administration → Plugins → Redmine Automation
- Должно быть: 3 правила (auto-assign, auto-close, escalate)

---

## 🎯 Следующие шаги

### 1. Пригласи команду

- Administration → Users → New user
- Или через Keycloak SSO (auto-provisioning)

### 2. Настрой GitLab webhooks

- Для каждого проекта GitLab добавь webhook

### 3. Кастомизируй workflows

- Administration → Workflow
- Настрой переходы статусов для своих процессов

### 4. Создай custom fields

- Administration → Custom fields → New custom field
- Например: "Severity" для багов, "Business Value" для фич

### 5. Настрой Time Entry Activities

- Administration → Enumerations → Activities (time tracking)
- Добавь свои виды активностей (Code, Review, Testing, etc.)

---

## 📚 Документация

- [REDMINE_GUIDE.md](docs/REDMINE_GUIDE.md) - Полное руководство
- [EMAIL_WORKFLOWS.md](docs/EMAIL_WORKFLOWS.md) - Email и согласования
- [RELEASE_v3.2.1.md](RELEASE_v3.2.1.md) - Release notes
- [SESSION_v3.2.1.md](SESSION_v3.2.1.md) - Session summary

---

## 💰 Экономия

### Твоя команда (30 человек):

**Jira Enterprise:**
- Jira: $14/user × 30 = $420/month
- Confluence: $5/user × 30 = $150/month
- Total: $570/month (**$6,840/year**)

**CERES Redmine:**
- Software: $0
- Server (VM): $50/month
- Total: $50/month (**$600/year**)

**Экономия:** $6,240/year 💰

---

## 🏆 Чеклист готовности

После настройки проверь:

- [x] Redmine доступен на http://redmine.ceres.local
- [x] Login работает (admin/admin123)
- [x] 27 плагинов установлены
- [x] Email test отправлен
- [x] Keycloak SSO настроен
- [x] GitLab webhook добавлен (хотя бы в 1 проект)
- [x] Mattermost уведомления работают
- [x] 3 project templates созданы
- [x] 3 issue templates созданы
- [x] 5 enterprise ролей созданы
- [x] Example project изучен
- [x] Первая задача создана
- [x] Agile board работает (drag & drop)

**Всё отмечено?** 🎉 Ты готов к работе!

---

## ⚡ TL;DR (для ленивых)

```bash
# 1. Deploy Redmine (5 min)
./scripts/setup-redmine.sh

# 2. Configure everything (10 min)
./scripts/configure-redmine-ultimate.sh

# 3. Open browser
http://redmine.ceres.local
Login: admin / admin123

# 4. Profit! 🚀
```

**Время:** 15 минут  
**Результат:** Enterprise project management лучше чем Jira!  
**Стоимость:** $0 💰

---

**Вопросы?** Читай [EMAIL_WORKFLOWS.md](docs/EMAIL_WORKFLOWS.md) или [REDMINE_GUIDE.md](docs/REDMINE_GUIDE.md)

**Нужна помощь?** Open an issue: https://github.com/skulesh01/Ceres/issues

**Хочешь больше фич?** Roadmap в [RELEASE_v3.2.1.md](RELEASE_v3.2.1.md)

---

🏆 **CERES Redmine — Better than Jira Enterprise, бесплатно!**
