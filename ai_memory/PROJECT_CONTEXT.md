# Контекст Проекта: Модульная Инфраструктура (Ceres.local)

## 1. Цели Проекта
Создание полностью открытой, модульной и масштабируемой инфраструктуры для операционной деятельности компании.
- **Домен:** `Ceres.local`
- **Стек:** Docker Compose, Traefik, Keycloak.
- **ОС:** Windows 10/11 (Host), Linux Containers.

## 2. Текущий Статус
- **Инфраструктура:** Подготовлена (docker-compose.yml, deploy.ps1).
- **Проблема:** Ожидание запуска Docker Desktop (требовалась виртуализация в BIOS).
- **Следующий шаг:** Запуск `deploy.ps1`.

## 3. Ключевые Компоненты
- **Traefik:** Reverse Proxy & SSL.
- **Keycloak:** SSO & Identity Management.
- **Taiga:** Project Management.
- **ProcessMaker:** BPM.
- **Nextcloud:** File Storage.
- **Prometheus/Grafana:** Monitoring.

## 4. История
- **27.11.2025:** Подготовка скриптов развертывания, исправление ошибок в YAML/PS1. Обнаружена проблема с виртуализацией.
