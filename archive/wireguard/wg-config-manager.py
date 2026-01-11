"""
WireGuard Config Manager - автоматизированное управление конфигами и почтой
Запускается как сервис в k3s и интегрируется с Keycloak для:
1. Отправки WireGuard конфигов новым пользователям по email
2. Отключения/удаления пользователей из VPN
3. Управления ключами и сертификатами
"""

import os
import json
import base64
import smtplib
import requests
import logging
import subprocess
from datetime import datetime
from pathlib import Path
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from flask import Flask, request, jsonify
from functools import wraps
import time

# ==================== КОНФИГУРАЦИЯ ====================
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class Config:
    """Конфигурация из переменных окружения"""
    # Keycloak
    KEYCLOAK_URL = os.getenv('KEYCLOAK_URL', 'http://keycloak:8080')
    KEYCLOAK_REALM = os.getenv('KEYCLOAK_REALM', 'master')
    KEYCLOAK_CLIENT = os.getenv('KEYCLOAK_CLIENT_ID', 'admin-cli')
    KEYCLOAK_SECRET = os.getenv('KEYCLOAK_CLIENT_SECRET', 'admin-cli-secret')
    KEYCLOAK_ADMIN = os.getenv('KEYCLOAK_ADMIN', 'admin')
    KEYCLOAK_ADMIN_PASSWORD = os.getenv('KEYCLOAK_ADMIN_PASSWORD', 'admin123')
    
    # SMTP
    SMTP_HOST = os.getenv('SMTP_HOST', 'postfix')
    SMTP_PORT = int(os.getenv('SMTP_PORT', '25'))
    SMTP_FROM = os.getenv('SMTP_FROM', 'ceres@company.local')
    SMTP_USE_TLS = os.getenv('SMTP_USE_TLS', 'false').lower() == 'true'
    
    # WireGuard
    WG_SERVER_IP = os.getenv('WG_SERVER_IP', '192.168.1.3')
    WG_PRIVATE_KEY = os.getenv('WG_PRIVATE_KEY', '')
    WG_PUBLIC_KEY = os.getenv('WG_PUBLIC_KEY', '')
    WG_ENDPOINT = os.getenv('WG_ENDPOINT', '192.168.1.3:51820')
    WG_NETWORK = os.getenv('WG_NETWORK', '10.8.0.0/24')
    WG_SERVER_INTERNAL_IP = os.getenv('WG_SERVER_INTERNAL_IP', '10.8.0.1')
    WG_SSH_KEY = os.getenv('WG_SSH_KEY', '/etc/wg-ssh-key')
    WG_SSH_USER = os.getenv('WG_SSH_USER', 'root')
    
    # Хранилище ключей
    CONFIG_STORAGE = '/data/wg-configs'
    
# ==================== KEYCLOAK HELPER ====================
class KeycloakManager:
    def __init__(self, config):
        self.config = config
        self.token = None
        self.token_expires = 0
        
    def get_token(self):
        """Получить JWT токен от Keycloak"""
        if time.time() < self.token_expires and self.token:
            return self.token
            
        url = f"{self.config.KEYCLOAK_URL}/realms/{self.config.KEYCLOAK_REALM}/protocol/openid-connect/token"
        
        data = {
            'client_id': self.config.KEYCLOAK_CLIENT,
            'client_secret': self.config.KEYCLOAK_SECRET,
            'username': self.config.KEYCLOAK_ADMIN,
            'password': self.config.KEYCLOAK_ADMIN_PASSWORD,
            'grant_type': 'password'
        }
        
        try:
            resp = requests.post(url, data=data, timeout=10)
            if resp.status_code == 200:
                self.token = resp.json()['access_token']
                self.token_expires = time.time() + 3600
                return self.token
        except Exception as e:
            logger.error(f"Ошибка получения Keycloak токена: {e}")
            return None
    
    def get_user_email(self, user_id):
        """Получить email пользователя из Keycloak"""
        token = self.get_token()
        if not token:
            return None
            
        headers = {'Authorization': f'Bearer {token}'}
        url = f"{self.config.KEYCLOAK_URL}/admin/realms/{self.config.KEYCLOAK_REALM}/users/{user_id}"
        
        try:
            resp = requests.get(url, headers=headers, timeout=10)
            if resp.status_code == 200:
                return resp.json().get('email')
        except Exception as e:
            logger.error(f"Ошибка получения email: {e}")
        return None
    
    def get_all_users(self):
        """Получить всех пользователей"""
        token = self.get_token()
        if not token:
            return []
            
        headers = {'Authorization': f'Bearer {token}'}
        url = f"{self.config.KEYCLOAK_URL}/admin/realms/{self.config.KEYCLOAK_REALM}/users"
        
        try:
            resp = requests.get(url, headers=headers, timeout=10)
            if resp.status_code == 200:
                return resp.json()
        except Exception as e:
            logger.error(f"Ошибка получения пользователей: {e}")
        return []

# ==================== WIREGUARD HELPER ====================
class WireGuardManager:
    def __init__(self, config):
        self.config = config
        
    def generate_keypair(self):
        """Сгенерировать пару ключей WireGuard"""
        try:
            privkey = subprocess.check_output(['wg', 'genkey']).decode().strip()
            pubkey = subprocess.check_output(
                f'echo {privkey} | wg pubkey',
                shell=True
            ).decode().strip()
            return privkey, pubkey
        except Exception as e:
            logger.error(f"Ошибка генерации ключей: {e}")
            return None, None
    
    def create_user_config(self, username, user_email, client_privkey, client_pubkey):
        """Создать конфиг для пользователя"""
        config = f"""[Interface]
PrivateKey = {client_privkey}
Address = 10.8.0.{self._get_next_vpn_ip()}/32
DNS = 8.8.8.8, 8.8.4.4
# Пользователь: {username}
# Email: {user_email}
# Создан: {datetime.now().isoformat()}

[Peer]
PublicKey = {self.config.WG_PUBLIC_KEY}
AllowedIPs = 10.8.0.0/24, 192.168.1.0/24
Endpoint = {self.config.WG_ENDPOINT}
PersistentKeepalive = 25
"""
        return config
    
    def _get_next_vpn_ip(self):
        """Получить следующий IP для VPN клиента (начиная с 10)"""
        try:
            configs = Path(self.config.CONFIG_STORAGE).glob('*.conf')
            ips = set()
            for conf_file in configs:
                with open(conf_file) as f:
                    content = f.read()
                    if 'Address = 10.8.0.' in content:
                        ip = content.split('Address = 10.8.0.')[1].split('/')[0]
                        try:
                            ips.add(int(ip))
                        except:
                            pass
            next_ip = max(ips) + 1 if ips else 10
            if next_ip > 254:
                raise Exception("VPN network exhausted!")
            return next_ip
        except:
            return 10
    
    def add_peer_to_server(self, username, client_pubkey):
        """Добавить peer на WireGuard сервер через SSH"""
        try:
            # Эта команда должна быть выполнена на WireGuard сервере
            # Здесь используется SSH для добавления peer
            cmd = f"wg set wg0 peer {client_pubkey} allowed-ips 10.8.0.{self._get_next_vpn_ip()}/32"
            
            # Используем SSH для выполнения на сервере
            ssh_cmd = [
                'ssh',
                '-i', self.config.WG_SSH_KEY,
                f'{self.config.WG_SSH_USER}@{self.config.WG_SERVER_IP}',
                cmd
            ]
            
            subprocess.run(ssh_cmd, check=True, capture_output=True, timeout=10)
            logger.info(f"Peer {username} добавлен в WireGuard")
            return True
        except Exception as e:
            logger.error(f"Ошибка добавления peer: {e}")
            return False
    
    def remove_peer_from_server(self, client_pubkey):
        """Удалить peer из WireGuard сервера"""
        try:
            cmd = f"wg set wg0 peer {client_pubkey} remove"
            
            ssh_cmd = [
                'ssh',
                '-i', self.config.WG_SSH_KEY,
                f'{self.config.WG_SSH_USER}@{self.config.WG_SERVER_IP}',
                cmd
            ]
            
            subprocess.run(ssh_cmd, check=True, capture_output=True, timeout=10)
            logger.info(f"Peer {client_pubkey[:20]}... удален из WireGuard")
            return True
        except Exception as e:
            logger.error(f"Ошибка удаления peer: {e}")
            return False

# ==================== EMAIL HELPER ====================
class EmailManager:
    def __init__(self, config):
        self.config = config
    
    def send_wg_config(self, recipient_email, username, wg_config):
        """Отправить WireGuard конфиг по email"""
        try:
            msg = MIMEMultipart('alternative')
            msg['Subject'] = f'WireGuard VPN конфиг для {username}'
            msg['From'] = self.config.SMTP_FROM
            msg['To'] = recipient_email
            
            # Текстовая версия
            text = f"""
Здравствуйте, {username}!

Вашему аккаунту добавлена конфигурация для подключения к корпоративной VPN (WireGuard).

Инструкции:
1. Скачайте WireGuard для вашей ОС: https://www.wireguard.com/install/
2. Установите приложение
3. Импортируйте прилагаемый конфиг (файл wg-config.conf)
4. Активируйте туннель в приложении WireGuard

После подключения у вас будет доступ к корпоративным сервисам и локальной сети компании.

Если у вас возникнут проблемы, обратитесь в IT-отдел.

С уважением,
Администрация CERES
"""
            
            # HTML версия
            html = f"""
<html>
<body>
<p>Здравствуйте, <b>{username}</b>!</p>
<p>Вашему аккаунту добавлена конфигурация для подключения к корпоративной VPN (WireGuard).</p>
<h3>Инструкции:</h3>
<ol>
<li>Скачайте WireGuard для вашей ОС: <a href="https://www.wireguard.com/install/">https://www.wireguard.com/install/</a></li>
<li>Установите приложение</li>
<li>Импортируйте прилагаемый конфиг (файл wg-config.conf)</li>
<li>Активируйте туннель в приложении WireGuard</li>
</ol>
<p>После подключения у вас будет доступ к корпоративным сервисам и локальной сети компании.</p>
<p>Если у вас возникнут проблемы, обратитесь в IT-отдел.</p>
<p><small>© 2026 CERES Administration</small></p>
</body>
</html>
"""
            
            msg.attach(MIMEText(text, 'plain'))
            msg.attach(MIMEText(html, 'html'))
            
            # Отправляем
            with smtplib.SMTP(self.config.SMTP_HOST, self.config.SMTP_PORT) as server:
                if self.config.SMTP_USE_TLS:
                    server.starttls()
                server.send_message(msg)
            
            logger.info(f"Email отправлен {recipient_email}")
            return True
        except Exception as e:
            logger.error(f"Ошибка отправки email: {e}")
            return False

# ==================== ИНИЦИАЛИЗАЦИЯ ====================
config = Config()
Path(config.CONFIG_STORAGE).mkdir(parents=True, exist_ok=True)

keycloak = KeycloakManager(config)
wireguard = WireGuardManager(config)
email = EmailManager(config)

# ==================== API ENDPOINTS ====================

def require_auth(f):
    """Простая аутентификация по Bearer токену"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        expected_token = os.getenv('API_TOKEN', 'secret-token')
        
        if not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Unauthorized'}), 401
        
        token = auth_header.split(' ')[1]
        if token != expected_token:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(*args, **kwargs)
    return decorated_function

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'timestamp': datetime.now().isoformat()})

@app.route('/api/v1/user/register', methods=['POST'])
@require_auth
def register_user():
    """
    Зарегистрировать нового пользователя и отправить конфиг
    POST /api/v1/user/register
    {
        "user_id": "uuid",
        "username": "john.doe",
        "email": "john@company.local"
    }
    """
    try:
        data = request.get_json()
        user_id = data.get('user_id')
        username = data.get('username')
        user_email = data.get('email')
        
        if not all([user_id, username, user_email]):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Генерируем ключи
        client_privkey, client_pubkey = wireguard.generate_keypair()
        if not client_privkey:
            return jsonify({'error': 'Failed to generate keypair'}), 500
        
        # Создаем конфиг
        wg_config = wireguard.create_user_config(username, user_email, client_privkey, client_pubkey)
        
        # Сохраняем конфиг
        config_file = Path(config.CONFIG_STORAGE) / f"{user_id}.conf"
        config_file.write_text(wg_config)
        config_file.chmod(0o600)
        
        # Добавляем peer на сервер
        wireguard.add_peer_to_server(username, client_pubkey)
        
        # Отправляем email
        email.send_wg_config(user_email, username, wg_config)
        
        # Сохраняем метаданные
        metadata = {
            'user_id': user_id,
            'username': username,
            'email': user_email,
            'public_key': client_pubkey,
            'created_at': datetime.now().isoformat(),
            'enabled': True
        }
        
        metadata_file = Path(config.CONFIG_STORAGE) / f"{user_id}.json"
        metadata_file.write_text(json.dumps(metadata, indent=2))
        
        return jsonify({
            'status': 'registered',
            'message': f'WireGuard конфиг отправлен на {user_email}',
            'user_id': user_id
        }), 201
    
    except Exception as e:
        logger.error(f"Ошибка регистрации: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/user/<user_id>/disable', methods=['POST'])
@require_auth
def disable_user(user_id):
    """Отключить пользователя (удалить из VPN)"""
    try:
        metadata_file = Path(config.CONFIG_STORAGE) / f"{user_id}.json"
        
        if not metadata_file.exists():
            return jsonify({'error': 'User not found'}), 404
        
        with open(metadata_file) as f:
            metadata = json.load(f)
        
        # Удаляем peer с сервера
        public_key = metadata.get('public_key')
        if public_key:
            wireguard.remove_peer_from_server(public_key)
        
        # Обновляем метаданные
        metadata['enabled'] = False
        metadata['disabled_at'] = datetime.now().isoformat()
        metadata_file.write_text(json.dumps(metadata, indent=2))
        
        return jsonify({'status': 'disabled', 'user_id': user_id}), 200
    
    except Exception as e:
        logger.error(f"Ошибка отключения пользователя: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/user/<user_id>/enable', methods=['POST'])
@require_auth
def enable_user(user_id):
    """Включить пользователя обратно"""
    try:
        metadata_file = Path(config.CONFIG_STORAGE) / f"{user_id}.json"
        
        if not metadata_file.exists():
            return jsonify({'error': 'User not found'}), 404
        
        with open(metadata_file) as f:
            metadata = json.load(f)
        
        # Добавляем peer на сервер
        config_file = Path(config.CONFIG_STORAGE) / f"{user_id}.conf"
        if config_file.exists():
            public_key = metadata.get('public_key')
            if public_key:
                wireguard.add_peer_to_server(metadata['username'], public_key)
        
        # Обновляем метаданные
        metadata['enabled'] = True
        metadata['enabled_at'] = datetime.now().isoformat()
        metadata_file.write_text(json.dumps(metadata, indent=2))
        
        return jsonify({'status': 'enabled', 'user_id': user_id}), 200
    
    except Exception as e:
        logger.error(f"Ошибка включения пользователя: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/v1/users', methods=['GET'])
@require_auth
def list_users():
    """Получить список всех управляемых пользователей"""
    try:
        configs = Path(config.CONFIG_STORAGE).glob('*.json')
        users = []
        
        for config_file in configs:
            with open(config_file) as f:
                metadata = json.load(f)
                users.append(metadata)
        
        return jsonify({'users': users, 'total': len(users)}), 200
    
    except Exception as e:
        logger.error(f"Ошибка получения пользователей: {e}")
        return jsonify({'error': str(e)}), 500

# ==================== ГЛАВНАЯ ====================
if __name__ == '__main__':
    port = int(os.getenv('PORT', '5000'))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Запуск WireGuard Config Manager на порту {port}")
    logger.info(f"Keycloak URL: {config.KEYCLOAK_URL}")
    logger.info(f"SMTP: {config.SMTP_HOST}:{config.SMTP_PORT}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)
