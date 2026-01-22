# CERES Redmine - Project Management (public plugins only)
# NOTE: Some plugin/theme repos referenced previously require auth (private/paid).

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

# Install plugins
WORKDIR /usr/src/redmine/plugins

# ============================================
# MUST-HAVE PLUGINS
# ============================================

# 1. Redmine Backlogs - FULL Scrum (Sprint planning, Burndown charts, Story points)
RUN git clone --depth=1 https://github.com/backlogs/redmine_backlogs.git

# Compatibility fix for Ruby 3.4+: File.exists? was removed
# NOTE: In GNU sed BRE, '?' is literal; do NOT escape it, otherwise it becomes a quantifier.
RUN sed -i 's/File\.exists?/File.exist?/g' redmine_backlogs/Gemfile

# 2. Issue Templates - Шаблоны задач (Bug, Feature, Support)
RUN git clone --depth=1 https://github.com/akiko-pusu/redmine_issue_templates.git

# 3. WYSIWYG Editor - Визуальный редактор вместо Textile
RUN git clone --depth=1 https://github.com/taqueci/redmine_wysiwyg_editor.git

# 4. Dashboard - Дашборд с виджетами
RUN git clone --depth=1 https://github.com/jgraichen/redmine_dashboard.git

# 5. Clipboard Image Paste - Вставка скриншотов
RUN git clone --depth=1 https://github.com/peclik/clipboard_image_paste.git

# 6. Theme Changer - Переключение тем для пользователей
RUN git clone --depth=1 https://github.com/haru/redmine_theme_changer.git

# ============================================
# INTEGRATIONS
# ============================================

# 7. Slack/Mattermost - Webhooks уведомления
RUN git clone --depth=1 https://github.com/sciyoshi/redmine-slack.git redmine_slack

# 8. GitHub Hook - Webhooks от Git
RUN git clone --depth=1 https://github.com/koppen/redmine_github_hook.git

# ============================================
# PROJECT MANAGEMENT ENHANCEMENTS
# ============================================

# 9. DrawIO - Диаграммы в Wiki
RUN git clone --depth=1 https://github.com/mikitex70/redmine_drawio.git

# 10. Wiki Extensions - PlantUML, Mermaid
RUN git clone --depth=1 https://github.com/haru/redmine_wiki_extensions.git

# 11. DMSF - Document Management System
RUN git clone --depth=1 https://github.com/danmunn/redmine_dmsf.git

# 12. Lightbox2 - Превью изображений/PDF
RUN git clone --depth=1 https://github.com/paginagmbh/redmine_lightbox2.git

# 13. Custom Workflows - Расширенная автоматизация
RUN git clone --depth=1 https://github.com/anteo/redmine_custom_workflows.git

# ============================================
# THEMES
# ============================================

# Themes are optional; some repositories are private or change availability.
# Use Redmine default UI theme by default.

# ============================================
# SETUP
# ============================================

# Install plugin dependencies
WORKDIR /usr/src/redmine

# Create Gemfile.local for plugin dependencies
RUN echo "gem 'holidays'" >> Gemfile.local && \
    echo "gem 'icalendar'" >> Gemfile.local

# IMPORTANT:
# - Do not run `bundle install` at build time.
# - The upstream Redmine entrypoint (from base image) generates config/database.yml
#   and runs `bundle check || bundle install` + migrations at container start.
# - This keeps the image build fast and keeps Kubernetes deployment "native".
