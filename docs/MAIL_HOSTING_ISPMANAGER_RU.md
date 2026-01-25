# Почта на хостинге (ISPmanager/reg.ru) + CERES SMTP

Цель: включить корпоративную почту на хостинге и подключить CERES/Keycloak к SMTP, чтобы работали письма (onboarding, reset password и т.п.) — без VPS.

## Что делаем в панели ISPmanager

### 1) Почтовый домен

- Почта → Почтовые домены → Добавить
- Домен: `praximo.tech`
- IP: IP хостинга (например `31.31.196.6`)
- Действие по умолчанию: **Сообщение об ошибке** (не catch-all)
- Включить: **SpamAssassin**, **DKIM**, **DMARC**, **SSL**
- DKIM selector: обычно `dkim`
- DKIM key length: **2048** (если доступно)

### 2) Сертификат (ВАЖНО)

- SSL-сертификаты → Let’s Encrypt → Выпустить
- Доменное имя: минимум `mail.praximo.tech` (можно добавить `praximo.tech`)
- Wildcard: выключено
- DNS-проверка: выключено (обычная HTTP)

Затем вернитесь в Почта → Почтовые домены → `praximo.tech` → редактировать и выберите **Let’s Encrypt** сертификат (не самоподписанный). Иначе CERES/Keycloak будут падать на проверке TLS.

### 3) Почтовый ящик

Создайте технический ящик для отправки:

- `no-reply@praximo.tech`
- Пароль: сложный (храните у себя)

## DNS (проверка)

Проверьте, что DNS записи появились:

- MX для `praximo.tech` указывает на почтовую инфраструктуру хостинга (например `mx1.hosting.reg.ru`, `mx2.hosting.reg.ru`)
- SPF/DKIM/DMARC присутствуют

## Настройка CERES на сервере (Proxmox)

На сервере CERES (где `/root/Ceres`):

```bash
cd /root/Ceres
sudo bash ./scripts/configure-ceres-smtp.sh
```

Рекомендуемые значения для ispmanager mail:

- `CERES_DOMAIN`: `praximo.tech`
- `CERES_MAIL_FROM`: `no-reply@praximo.tech`
- `CERES_SMTP_HOST`: `mail.praximo.tech`
- `CERES_SMTP_PORT`: `587`
- `CERES_SMTP_USER`: `no-reply@praximo.tech`
- `CERES_SMTP_STARTTLS`: `true`
- `CERES_SMTP_TLS`: `false`

Скрипт:
- пишет `/etc/ceres/ceres.env` (600)
- настраивает SMTP в Keycloak (best-effort)
- может отправить тестовое письмо (по желанию)

См. также: [docs/MAIL_EXTERNAL.md](MAIL_EXTERNAL.md)
