#!/usr/bin/env python3
"""
Webhook listener для Keycloak
При создании нового пользователя в Keycloak:
1. Создаёт VPN конфигурацию
2. Отправляет на email (используя существующий Postfix)
"""

from flask import Flask, request, jsonify
import subprocess
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
import json
import os

app = Flask(__name__)

# Конфигурация
WG_SERVER_IP = os.getenv("WG_SERVER_IP", "192.168.1.3")
WG_SERVER_PORT = os.getenv("WG_SERVER_PORT", "51820")
SMTP_HOST = os.getenv("SMTP_HOST", "postfix.mail-vpn.svc.cluster.local")
SMTP_PORT = int(os.getenv("SMTP_PORT", "25"))
SMTP_FROM = os.getenv("SMTP_FROM", "admin@ceres.local")
MAIL_DOMAIN = os.getenv("MAIL_DOMAIN", "ceres.local")

def generate_wg_config(username, email):
    """Генерирует WireGuard конфигурацию"""
    try:
        # Генерируем ключи
        privkey = subprocess.check_output(['wg', 'genkey']).decode().strip()
        pubkey = subprocess.check_output(['wg', 'pubkey'], input=privkey.encode()).decode().strip()
        
        # Получаем публичный ключ сервера
        server_pubkey = subprocess.check_output(['wg', 'show', 'wg0', 'public-key']).decode().strip()
        
        # Определяем IP клиента
        peers = subprocess.check_output(['wg', 'show', 'wg0', 'allowed-ips']).decode()
        last_ip = 1
        for line in peers.split('\n'):
            if line.strip():
                ip = line.split()[1].split('/')[0]
                last_octet = int(ip.split('.')[-1])
                if last_octet > last_ip:
                    last_ip = last_octet
        
        client_ip = f"10.8.0.{last_ip + 1}"
        
        # Добавляем peer на сервер
        subprocess.run([
            'wg', 'set', 'wg0',
            'peer', pubkey,
            'allowed-ips', f"{client_ip}/32"
        ], check=True)
        
        # Создаём конфигурацию
        config = f"""[Interface]
PrivateKey = {privkey}
Address = {client_ip}/24
DNS = 1.1.1.1

[Peer]
PublicKey = {server_pubkey}
Endpoint = {WG_SERVER_IP}:{WG_SERVER_PORT}
AllowedIPs = 10.8.0.0/24
PersistentKeepalive = 25
"""
        
        return config, client_ip
        
    except Exception as e:
        print(f"Error generating WireGuard config: {e}")
        return None, None

def send_email(to_email, username, wg_config):
    """Отправляет email с VPN конфигурацией"""
    try:
        msg = MIMEMultipart()
        msg['From'] = SMTP_FROM
        msg['To'] = to_email
        msg['Subject'] = '🔐 Ваши учетные данные для доступа к корпоративной сети'
        
        body = f"""Здравствуйте!

Для вас созданы учетные данные для доступа к корпоративной инфраструктуре Ceres.

📧 ПОЧТА
   Email:    {to_email}
   Webmail:  https://mail.ceres.local (будет доступно позже)

🔒 VPN (WIREGUARD)
   Конфигурация во вложении: {username}.conf
   
   Инструкция по подключению:
   1. Скачайте WireGuard: https://www.wireguard.com/install/
   2. Импортируйте файл {username}.conf
   3. Активируйте подключение
   4. Проверьте доступ к внутренним ресурсам

📚 КОРПОРАТИВНЫЕ РЕСУРСЫ (через VPN)
   SSO:         https://auth.ceres.local
   Wiki:        https://wiki.ceres.local
   Чат:         https://mattermost.ceres.local
   Файлы:       https://nextcloud.ceres.local
   Git:         https://gitea.ceres.local
   Проекты:     https://taiga.ceres.local

При возникновении вопросов обращайтесь к администратору.

--
Ceres Enterprise Platform | Автоматическое сообщение
"""
        
        msg.attach(MIMEText(body, 'plain'))
        
        # Прикрепляем конфигурацию
        attachment = MIMEApplication(wg_config.encode())
        attachment.add_header('Content-Disposition', 'attachment', filename=f'{username}.conf')
        msg.attach(attachment)
        
        # Отправляем
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.send_message(msg)
        
        print(f"Email sent to {to_email}")
        return True
        
    except Exception as e:
        print(f"Error sending email: {e}")
        return False

@app.route('/webhook/keycloak', methods=['POST'])
def keycloak_webhook():
    """Обработчик webhook от Keycloak"""
    try:
        data = request.get_json()
        print(f"Received webhook: {json.dumps(data, indent=2)}")
        
        # Проверяем что это событие создания пользователя
        event_type = data.get('type')
        if event_type != 'REGISTER':
            return jsonify({'status': 'ignored', 'reason': 'not a registration event'}), 200
        
        # Извлекаем данные пользователя
        user_data = data.get('details', {})
        username = user_data.get('username')
        email = user_data.get('email')
        
        if not username or not email:
            return jsonify({'status': 'error', 'reason': 'missing username or email'}), 400
        
        print(f"Processing new user: {username} ({email})")
        
        # Генерируем VPN конфигурацию
        wg_config, client_ip = generate_wg_config(username, email)
        if not wg_config:
            return jsonify({'status': 'error', 'reason': 'failed to generate VPN config'}), 500
        
        print(f"Generated VPN config for {username}, IP: {client_ip}")
        
        # Отправляем email
        if send_email(email, username, wg_config):
            return jsonify({
                'status': 'success',
                'username': username,
                'email': email,
                'vpn_ip': client_ip
            }), 200
        else:
            return jsonify({'status': 'error', 'reason': 'failed to send email'}), 500
        
    except Exception as e:
        print(f"Error processing webhook: {e}")
        return jsonify({'status': 'error', 'reason': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200

if __name__ == '__main__':
    print("Starting Keycloak webhook listener...")
    print(f"SMTP: {SMTP_HOST}:{SMTP_PORT}")
    print(f"WireGuard: {WG_SERVER_IP}:{WG_SERVER_PORT}")
    app.run(host='0.0.0.0', port=5000, debug=True)
