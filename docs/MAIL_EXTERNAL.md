# Внешний почтовый сервер (на отдельной машине)

Этот документ описывает, как сделать «реальную почту из интернета», когда почтовик разворачивается **на отдельной машине/VM**, а CERES (k3s) использует его по SMTP для отправки писем (onboarding, reset password в Keycloak и т.д.).

## 0) Почему так лучше

- Почта требует открытых портов 25/587/993 и хорошей «доставляемости» (PTR/rDNS, SPF/DKIM/DMARC).
- Домашний интернет/динамический IP/блокировка 25 портов часто ломают нормальную почту.
- Отдельная VM/VPS со статическим публичным IP — самый практичный вариант.

Если вы хотите держать почтовик **у себя**, но иметь белый IP снаружи — используйте схему
"VPS как внешний IP (WireGuard gateway)": см. `docs/MAIL_VPS_GATEWAY.md`.

## 1) Что вам понадобится

- **Домен** (например `example.com`).
- **Публичный статический IP** для почтового сервера (лучше VPS).
- Возможность настроить **DNS** у регистратора/провайдера DNS.
- Возможность настроить **PTR (reverse DNS / rDNS)** у провайдера IP (обычно в панели VPS).

Рекомендуемая схема имен:
- `mail.example.com` — веб‑интерфейс и IMAP/SMTP хост.
- `MX` домена `example.com` указывает на `mail.example.com`.

## 2) Открытые порты

На внешней машине должны быть доступны из интернета:
- `25/tcp` — входящая почта (MX)
- `587/tcp` — submission (почтовые клиенты отправляют письма)
- `993/tcp` — IMAPS
- `443/tcp` — webmail / admin UI (если используете)

Если ваш провайдер/ISP блокирует 25 порт:
- входящая почта на ваш сервер работать **не будет**;
- решения: VPS у другого провайдера, или использовать готовый почтовый сервис (но тогда это уже не «сам хостишь приём почты»).

## 3) DNS записи (минимум)

Предположим, что ваш внешний IP почтовика = `X.X.X.X`.

1) A-запись:
- `mail.example.com  A  X.X.X.X`

2) MX-запись домена:
- `example.com  MX  10 mail.example.com`

3) SPF (минимальный старт):
- `example.com  TXT  "v=spf1 mx -all"`

4) DKIM:
- Генерируется вашим почтовым решением (mailcow/iRedMail и т.п.).
- Обычно это TXT запись вида `selector._domainkey.example.com`.

5) DMARC (минимальный старт, режим наблюдения):
- `_dmarc.example.com TXT "v=DMARC1; p=none; rua=mailto:dmarc@example.com; ruf=mailto:dmarc@example.com; fo=1"`

6) PTR / Reverse DNS (очень важно для доставляемости):
- `X.X.X.X -> mail.example.com`

## 4) Что поставить на внешнюю машину

Варианты:
- **mailcow-dockerized** (часто самый удобный «всё в одном» вариант)
- iRedMail
- Postfix + Dovecot + Roundcube (ручная сборка — больше работы)

Критерии:
- TLS сертификаты (Let’s Encrypt)
- DKIM подпись
- Нормальная конфигурация SMTP submission
- В идеале антиспам/антивирус (для продакшена)

## 5) Как связать CERES с внешней почтой

### 5.1 Отправка писем из CERES Mail UI (onboarding)

В CERES уже добавлена отправка по SMTP, если выставить переменные:

- `CERES_SMTP_HOST=mail.example.com`
- `CERES_SMTP_PORT=587`
- `CERES_SMTP_USER=no-reply@example.com`
- `CERES_SMTP_PASS=...`
- `CERES_SMTP_STARTTLS=true`
- `CERES_SMTP_TLS=false`
- `CERES_MAIL_FROM=no-reply@example.com`

На сервере CERES это можно прокинуть через `scripts/install-ui.sh` (он записывает переменные в `/etc/ceres/*.env`).

### 5.2 Настройка SMTP в Keycloak

Keycloak по умолчанию в манифесте не имеет жёстко заданного SMTP.
Для настройки используйте скрипт:

```bash
export CERES_SMTP_HOST=mail.example.com
export CERES_SMTP_PORT=587
export CERES_SMTP_USER=no-reply@example.com
export CERES_SMTP_PASS='***'
export CERES_MAIL_FROM=no-reply@example.com

bash ./scripts/configure-keycloak-smtp.sh
```

### 5.3 Не устанавливать Mailcow внутри k3s

Для режима «почта снаружи» при деплое/обновлении выставьте:

- `CERES_MAIL_MODE=external`

Тогда:
- `deployment/mailcow.yaml` не применяется
- применяется `deployment/ingress-domains-no-mail.yaml` (без `mail.ceres.local`)

Пример:

```bash
export CERES_MAIL_MODE=external
./bin/ceres deploy --cloud proxmox --environment prod --namespace ceres
```

## 6) Проверка

- Проверка DNS:
  - `nslookup -type=mx example.com`
  - `nslookup mail.example.com`
- Проверка SMTP submission:
  - подключение к `mail.example.com:587` (StartTLS)
- Проверка доставляемости:
  - отправка письма на `mail-tester.com` и исправление SPF/DKIM/DMARC/PTR

## 7) Важно про «один пароль везде» (LDAP)

Для того, чтобы пароль был один и тот же в SSO (Keycloak) и в почтовых клиентах (IMAP/SMTP), обычно делают так:
- LDAP — источник паролей
- Keycloak federates LDAP
- Почтовый сервер (Dovecot/Postfix) тоже проверяет логин/пароль в LDAP

Это уже следующий шаг после базового запуска внешней почты.
