# VPS как внешний IP для домашнего почтовика (WireGuard gateway)

Этот сценарий повторяет идею из статьи: **почтовый сервер живёт у вас** (дома/в офисе), а **VPS используется как внешний белый IP**.

Ключевая мысль: VPS — это не просто «прокси». Для почты VPS становится:

- публичной точкой входа (MX → IP VPS)
- исходным IP для отправки (репутация, rDNS/PTR, блокировки — всё на стороне VPS)

Поэтому «самый дешёвый VPS» подходит только если он:
- не блокирует `25/tcp`
- позволяет выставить **PTR/rDNS**
- даёт статический IPv4

## Схема

- `mail.example.com` указывает на **IP VPS**
- на VPS поднимается WireGuard и пробрасываются порты на домашний mail server через VPN
- домашний mail server (Postfix/Dovecot/mailcow/iRedMail) слушает порты как обычно

Порты, которые обычно пробрасывают:
- `25/tcp` входящая почта
- `587/tcp` submission (отправка из клиентов)
- `993/tcp` IMAPS
- `80/tcp` и `443/tcp` для webmail/admin + Let's Encrypt

## DNS (минимум)

На домене `example.com`:
- `A mail.example.com -> <VPS_PUBLIC_IP>`
- `MX example.com -> mail.example.com (prio 10)`
- `TXT SPF: v=spf1 ip4:<VPS_PUBLIC_IP> mx -all`
- `TXT DMARC: v=DMARC1; p=none; rua=mailto:dmarc@example.com; fo=1`
- `TXT DKIM` — выдаст ваш почтовый софт (selector._domainkey)

На VPS (в панели провайдера) обязательно:
- `PTR <VPS_PUBLIC_IP> -> mail.example.com`

## Практические ограничения

- **Shared hosting (хостинг-сайт)** почти всегда не подходит: нет root/sudo, нельзя поставить WireGuard, нельзя настроить форвардинг/NAT и управлять портами на уровне ОС.
- Если VPS провайдер блокирует 25 порт — входящая почта не заработает.
- Репутация IP сильно влияет на доставляемость (особенно в Gmail/Outlook). Дешёвый VPS может иметь плохую историю.

## Что CERES будет делать

CERES не должен «настраивать почтовик за вас» без данных доступа, потому что это отдельная инфраструктура.
Но CERES может:
- хранить единый конфиг в `/etc/ceres/ceres.env`
- использовать SMTP для отправки писем (onboarding)
- настраивать SMTP в Keycloak (reset password, verify email)
- при желании — генерировать список DNS записей, которые нужно применить

См. также: [docs/MAIL_EXTERNAL.md](MAIL_EXTERNAL.md)
