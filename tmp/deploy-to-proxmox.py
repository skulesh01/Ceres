#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CERES: Non-interactive full deployment to Proxmox host
- Uploads public Ceres + Private orchestrators
- Installs dependencies (Python, Git, Terraform, Ansible, Docker)
- Runs Private auto-deploy orchestrator remotely
"""

import sys
import os
import time
import tarfile
import json
import subprocess
from pathlib import Path

# Ensure paramiko is available
try:
    import paramiko
except ImportError:
    print("Installing paramiko...")
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'paramiko', '--quiet'])
    import paramiko

CREDS_FILE = Path(__file__).parent / 'credentials.json'
creds = json.loads(CREDS_FILE.read_text(encoding='utf-8'))

SERVER_IP = creds.get('proxmox', {}).get('host', '192.168.1.3')
SERVER_USER = creds.get('ssh', {}).get('user', creds.get('proxmox', {}).get('user', 'root'))
SERVER_PASSWORD = creds.get('ssh', {}).get('password', creds.get('proxmox', {}).get('password'))
REMOTE_DIR = "/opt/ceres"

PUBLIC_DIR = Path(__file__).parent.parent / 'Ceres'
PRIVATE_DIR = Path(__file__).parent

class SSHDeployer:
    def __init__(self):
        self.ssh = None
        self.sftp = None

    def connect(self):
        print(f"\n>>> Connecting to {SERVER_USER}@{SERVER_IP}...")
        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            self.ssh.connect(SERVER_IP, username=SERVER_USER, password=SERVER_PASSWORD, timeout=15)
            self.sftp = self.ssh.open_sftp()
            print("[OK] Connected")
            return True
        except Exception as e:
            print(f"[ERROR] Connection failed: {e}")
            return False

    def run_command(self, cmd, show_output=True):
        # Use bash -lc to handle multi-line scripts and environment
        chan = self.ssh.get_transport().open_session()
        chan.exec_command(f"bash -lc '{cmd}'")
        stdout = chan.makefile('r')
        stderr = chan.makefile_stderr('r')
        if show_output:
            for line in stdout:
                print(f"  {line.rstrip()}")
            for line in stderr:
                if line.strip():
                    print(f"  [ERR] {line.rstrip()}")
        exit_code = chan.recv_exit_status()
        return exit_code == 0

    def upload_file(self, local_path, remote_path):
        self.sftp.put(str(local_path), remote_path)

    def close(self):
        try:
            if self.sftp:
                self.sftp.close()
            if self.ssh:
                self.ssh.close()
        except Exception:
            pass

def create_archive():
    print("\n>>> Creating project archive...")
    archive_path = Path.home() / 'ceres-project.tar.gz'
    if archive_path.exists():
        archive_path.unlink()

    def add_dir(tar, base_path: Path, arc_base: str):
        for p in base_path.rglob('*'):
            sp = str(p)
            if any(x in sp for x in ['.git', 'node_modules', '__pycache__']) or sp.endswith('.pyc'):
                continue
            arcname = f"{arc_base}/{p.relative_to(base_path)}" if arc_base else str(p.relative_to(base_path))
            tar.add(p, arcname=arcname)

    with tarfile.open(archive_path, 'w:gz') as tar:
        if PUBLIC_DIR.exists():
            add_dir(tar, PUBLIC_DIR, 'Ceres')
        # Include Private orchestrators at archive root
        add_dir(tar, PRIVATE_DIR, '')
    return archive_path

def test_connection():
    d = SSHDeployer()
    ok = d.connect()
    d.close()
    print("[OK] SSH connection test passed" if ok else "[ERROR] SSH connection test failed")
    return 0 if ok else 1

def main():
    start_time = time.time()
    deployer = SSHDeployer()
    if not deployer.connect():
        return 1

    print(f"\n>>> Preparing remote directory {REMOTE_DIR}...")
    deployer.run_command(f"mkdir -p {REMOTE_DIR}", show_output=False)

    archive_path = create_archive()
    print("\n>>> Uploading archive...")
    remote_archive = f"{REMOTE_DIR}/ceres-project.tar.gz"
    deployer.upload_file(archive_path, remote_archive)
    archive_path.unlink()

    print("\n>>> Extracting archive...")
    deployer.run_command(f"cd {REMOTE_DIR} && tar -xzf ceres-project.tar.gz && rm ceres-project.tar.gz", show_output=False)

    print("\n>>> Installing dependencies (Python, Git, Terraform, Ansible, Docker)...")
    install_script = r'''
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq python3 python3-pip git wget curl unzip gnupg lsb-release ca-certificates
wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update -qq && apt-get install -y -qq terraform
python3 -m pip install --quiet ansible
curl -fsSL https://get.docker.com | sh
echo "Dependencies installed"
'''
    deployer.run_command(install_script)

    print("\n>>> Starting CERES deployment...")
    # Run Private orchestrator
    deployer.run_command(f"cd {REMOTE_DIR} && python3 auto-deploy.py")

    elapsed = int(time.time() - start_time)
    minutes, seconds = divmod(elapsed, 60)
    print("\n" + "=" * 80)
    print("                    DEPLOYMENT COMPLETED")
    print("=" * 80)
    print(f"\nTotal time: {minutes}m {seconds}s")

    keycloak_pass = creds.get('services', {}).get('keycloak', {}).get('admin_password')
    grafana_pass = creds.get('services', {}).get('grafana', {}).get('admin_password')
    print("\nAccess your services at:")
    print("  - https://auth.ceres           - Keycloak" + (f" (admin/{keycloak_pass})" if keycloak_pass else ""))
    print("  - https://gitlab.ceres         - GitLab CE")
    print("  - https://zulip.ceres          - Zulip Chat")
    print("  - https://nextcloud.ceres      - Nextcloud")
    print("  - https://grafana.ceres        - Grafana" + (f" (admin/{grafana_pass})" if grafana_pass else ""))
    print(f"\nConfigure DNS: *.ceres -> {SERVER_IP}")

    deployer.close()
    return 0

if __name__ == '__main__':
    if '--test' in sys.argv:
        sys.exit(test_connection())
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] {e}")
        sys.exit(1)
