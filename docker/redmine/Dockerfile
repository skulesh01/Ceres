# CERES Redmine - Full-Featured Project Management
# Based on official Redmine 5.1 with 20+ plugins

FROM redmine:5.1

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    vim \
    libpq-dev \
    imagemagick \
    ghostscript \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Switch to redmine user
USER redmine

# Install plugins
WORKDIR /usr/src/redmine/plugins

# ============================================
# MUST-HAVE PLUGINS
# ============================================

# 1. Redmine Backlogs - FULL Scrum (Sprint planning, Burndown charts, Story points)
RUN git clone https://github.com/backlogs/redmine_backlogs.git

# 2. Redmine Agile FREE - Kanban boards
RUN git clone https://github.com/redmineup/redmine_agile.git

# 3. Checklists - Чеклисты в задачах
RUN git clone https://github.com/redmineup/redmine_checklists.git

# 4. Tags - Теги для задач и проектов
RUN git clone https://github.com/redmineup/redmineup_tags.git

# 5. Issue Templates - Шаблоны задач (Bug, Feature, Support)
RUN git clone https://github.com/akiko-pusu/redmine_issue_templates.git

# 6. WYSIWYG Editor - Визуальный редактор вместо Textile
RUN git clone https://github.com/taqueci/redmine_wysiwyg_editor.git

# 7. Dashboard - Дашборд с виджетами
RUN git clone https://github.com/jgraichen/redmine_dashboard.git

# 8. Messenger - @mentions в комментариях
RUN git clone https://github.com/AlphaNodes/redmine_messenger.git

# 9. Clipboard Image Paste - Вставка скриншотов
RUN git clone https://github.com/peclik/clipboard_image_paste.git

# 10. Theme Changer - Переключение тем для пользователей
RUN git clone https://github.com/haru/redmine_theme_changer.git

# ============================================
# INTEGRATIONS
# ============================================

# 11. Slack/Mattermost - Webhooks уведомления
RUN git clone https://github.com/sciyoshi/redmine-slack.git redmine_slack

# 12. GitHub/GitLab Hook - Webhooks от Git
RUN git clone https://github.com/koppen/redmine_github_hook.git

# 13. LDAP Sync - Синхронизация с Keycloak
RUN git clone https://github.com/thorin/redmine_ldap_sync.git

# 14. SAML - Keycloak SSO
RUN git clone https://github.com/chrodriguez/redmine_omniauth_saml.git

# ============================================
# PROJECT MANAGEMENT ENHANCEMENTS
# ============================================

# 15. DrawIO - Диаграммы в Wiki
RUN git clone https://github.com/mikitex70/redmine_drawio.git

# 16. Wiki Extensions - PlantUML, Mermaid
RUN git clone https://github.com/haru/redmine_wiki_extensions.git

# 17. DMSF - Document Management System
RUN git clone https://github.com/danmunn/redmine_dmsf.git

# 18. Lightbox2 - Превью изображений/PDF
RUN git clone https://github.com/paginagmbh/redmine_lightbox2.git

# 19. Workload - Визуализация загрузки команды
RUN git clone https://github.com/xvolks/redmine_workload.git

# 20. Spent Time - Улучшенный учет времени
RUN git clone https://github.com/eyp/redmine_spent_time.git

# 21. Issue Charts - Графики и аналитика
RUN git clone https://github.com/masaki-yamakawa/redmine_issue_charts.git

# ============================================
# THEMES
# ============================================

WORKDIR /usr/src/redmine/public/themes

# PurpleMine2 - Современная responsive тема
RUN git clone https://github.com/mrliptontea/PurpleMine2.git

# Circle Theme - Material Design
RUN git clone https://github.com/kodeka/circle-theme.git

# Gitmike - GitHub-like theme
RUN git clone https://github.com/makotokw/redmine-theme-gitmike.git gitmike

# A1 Theme - Корпоративная тема
RUN git clone https://github.com/rchady/redmine-theme-a1.git a1

# ============================================
# SETUP
# ============================================

# Switch back to root for installation
USER root

# Install plugin dependencies
WORKDIR /usr/src/redmine

# Create Gemfile.local for plugin dependencies
RUN echo "gem 'holidays'" >> Gemfile.local && \
    echo "gem 'icalendar'" >> Gemfile.local

# Install gems
RUN bundle install --without development test

# Migrate plugins (will be run on first start via entrypoint)
# RUN bundle exec rake redmine:plugins:migrate RAILS_ENV=production

# Set permissions
RUN chown -R redmine:redmine /usr/src/redmine

# Create custom entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER redmine

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["rails", "server", "-b", "0.0.0.0"]
