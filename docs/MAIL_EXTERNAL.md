# Внешняя почта (VPS/VM или почта как сервис)

Этот документ описывает два рабочих варианта «реальной почты из интернета», когда CERES (k3s) использует внешний SMTP для отправки писем (onboarding, reset password в Keycloak и т.д.):

- **Почта как сервис** (рекомендуется, если вы не хотите/не можете покупать VPS).
- **Свой почтовый сервер на отдельной машине/VM/VPS** (максимум контроля, но больше ответственности).

## 0) Почему так лучше

- Почта требует открытых портов 25/587/993 и хорошей «доставляемости» (PTR/rDNS, SPF/DKIM/DMARC).
- Домашний интернет/динамический IP/блокировка 25 портов часто ломают нормальную почту.
- Отдельная VM/VPS со статическим публичным IP — самый практичный вариант.

Если вы хотите держать почтовик **у себя**, но иметь белый IP снаружи — используйте схему
"VPS как внешний IP (WireGuard gateway)": см. `docs/MAIL_VPS_GATEWAY.md`.

## 1) Что вам понадобится

- **Домен** (например `example.com`).
- **Публичный статический IP** для почтового сервера (только если вы поднимаете свой почтовик на VM/VPS).
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

Если вы **не хотите** поднимать свой почтовик на VPS/VM — этот раздел можно пропустить.

### 4.0 Почта как сервис (без VPS)

Если у вас домен на reg.ru (или другом провайдере), самый простой путь — включить у них «почту для домена» и создать ящики.

Что сделать в панели почты провайдера:

1) Создайте технический ящик для отправки, например `no-reply@praximo.tech`.
2) Посмотрите в настройках почтового клиента (обычно раздел «IMAP/SMTP») точные параметры:
  - SMTP Host
  - SMTP Port (обычно `587`)
  - тип шифрования: StartTLS/SSL
  - логин (обычно email целиком)
3) Примените DNS записи, которые предлагает провайдер (MX/SPF/DKIM/DMARC). Не угадывайте MX — берите из панели.

После этого CERES/Keycloak настраиваются так же, как и с «собственным» почтовиком: вам нужен только доступ к SMTP.

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

Под вашу ситуацию (почта как сервис) это будет, например:

- `CERES_SMTP_HOST=<smtp-host-из-панели-почты>`
- `CERES_SMTP_PORT=587`
- `CERES_SMTP_USER=no-reply@praximo.tech`
- `CERES_SMTP_PASS=<пароль-ящика-или-app-password>`
- `CERES_SMTP_STARTTLS=true` (если в панели написано StartTLS)
- `CERES_SMTP_TLS=true` (если в панели написано SSL/TLS и порт `465`)
- `CERES_MAIL_FROM=no-reply@praximo.tech`

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

Важно про TLS сертификаты:

- Если ваш SMTP/IMAPS сервер отдаёт **самоподписанный сертификат**, Keycloak и CERES, как правило, не смогут подключиться (ошибка валидации TLS).
- На shared hosting это часто решается выбором **Let's Encrypt** сертификата для `mail.<domain>` в панели (не "самоподписанный").
- Быстрая проверка (любой Linux/macOS): `openssl s_client -starttls smtp -connect mail.example.com:587 -servername mail.example.com | egrep 'subject=|issuer='`.
  Если `issuer=` совпадает с `subject=` — сертификат самоподписанный.

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
