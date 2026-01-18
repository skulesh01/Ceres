#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Deploy CERES to Proxmox Host with Progress Bar
"""

import sys
import time
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / '_lib'))

try:
    from ssh_deployer import SSHDeployer, create_project_archive, load_credentials, print_deployment_summary, ProgressBar
except ImportError as e:
    print(f"[ERROR] Failed to import ssh_deployer: {e}")
    sys.exit(1)


def test_connection(deployer: SSHDeployer) -> int:
    print("\n>>> Testing SSH connection...")
    ok = deployer.connect()
    deployer.close()
    if ok:
        print("[OK] SSH test passed\n")
        return 0
    else:
        print("[ERROR] SSH test failed\n")
        return 1


def deploy(deployer: SSHDeployer, creds: dict, public_dir: Path, private_dir: Path, remote_dir: str) -> int:
    start_time = time.time()
    
    # Setup local logs directory inside project
    from ssh_deployer import get_project_logs_dir
    import datetime
    local_logs_dir = get_project_logs_dir()
    log_timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    local_log_file = local_logs_dir / f"deploy-{log_timestamp}.log"
    
    progress = ProgressBar()
    progress.add_stage("Setup timezone", 1)
    progress.add_stage("Connecting", 2)
    progress.add_stage("Uploading archive", 15)
    progress.add_stage("Extracting files", 5)
    progress.add_stage("Installing deps", 15)
    progress.add_stage("Running deploy", 63)
    
    progress.update()
    if not deployer.connect():
        return 1
    
    # Setup timezone on remote server
    progress.update()
    print(f"\n>>> Setting timezone on server...")
    deployer.setup_timezone("Europe/Moscow")
    progress.update()
    
    print(f"\n>>> Preparing remote directory: {remote_dir}")
    deployer.run_command(f"mkdir -p {remote_dir}/logs && touch {remote_dir}/logs/deployment.log", show_output=False)
    
    # Log to both local file and remote with timestamp
    def log_msg(msg: str):
        timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        timestamped_msg = f"[{timestamp}] {msg}"
        print(msg)
        with open(local_log_file, 'a', encoding='utf-8') as f:
            f.write(timestamped_msg + '\n')
            f.flush()  # Force flush to disk
        # Log to remote with proper escaping
        safe_msg = msg.replace("'", "'\\''")
        deployer.run_command(f"echo '[{timestamp}] {safe_msg}' >> {remote_dir}/logs/deployment.log", show_output=False)
    
    log_msg(f"[{time.strftime('%H:%M:%S')}] Deployment started")
    
    try:
        log_msg("\n>>> Creating project archive...")
        archive_path = create_project_archive(public_dir, private_dir)
        
        # Show what we're about to upload
        archive_size_mb = archive_path.stat().st_size / (1024 * 1024)
        log_msg(f">>> Archive ready: {archive_path.name} ({archive_size_mb:.1f}MB)")
        log_msg(f">>> Uploading to {deployer.host}:{remote_dir}/...")
    except Exception as e:
        log_msg(f"[ERROR] {e}")
        deployer.close()
        return 1
    
    progress.update()
    log_msg(f"\n>>> Uploading archive...")
    remote_archive = f"{remote_dir}/ceres-project.tar.gz"
    if not deployer.upload_file(archive_path, remote_archive):
        deployer.close()
        return 1
    archive_path.unlink()
    print("[OK] Archive uploaded")
    progress.update()
    
    print(f"\n>>> Extracting archive...")
    deployer.run_command(f"cd {remote_dir} && tar -xzf ceres-project.tar.gz && rm ceres-project.tar.gz", show_output=False)
    print("[OK] Archive extracted")
    progress.update()
    
    print("\n>>> Installing dependencies...")
    install_script = r'''
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | tail -1
apt-get install -y -qq python3 python3-pip git wget curl unzip gnupg lsb-release ca-certificates
wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update -qq && apt-get install -y -qq terraform
python3 -m pip install --quiet ansible --disable-pip-version-check
curl -fsSL https://get.docker.com | sh
echo "Dependencies installed"
'''
    if not deployer.run_command(install_script):
        print("[WARN] Some dependencies may have failed")
    print("[OK] Dependencies ready")
    progress.update()
    
    print("\n>>> Starting CERES deployment orchestration...\n")
    print("=" * 80)
    print("LIVE OUTPUT FROM SERVER:")
    print("=" * 80 + "\n")
    
    # Run with streaming output to see real-time logs
    deployer.run_command(
        f"cd {remote_dir} && python3 auto-deploy.py 2>&1 | tee {remote_dir}/logs/deployment.log || python3 Ceres/scripts/auto-deploy.py 2>&1 | tee {remote_dir}/logs/deployment.log",
        show_output=True,
        stream_output=True
    )
    
    print("\n" + "=" * 80)
    
    # Download final logs
    print("\n>>> Retrieving deployment logs from server...")
    remote_log = f"{remote_dir}/logs/deployment.log"
    deployer.get_remote_logs(remote_log, local_log_file, follow=False)
    
    progress.update()
    progress.finish()
    
    elapsed = int(time.time() - start_time)
    print_deployment_summary(creds, deployer.host, elapsed, local_log_file)
    deployer.close()
    return 0


def main():
    parser = argparse.ArgumentParser(description='Deploy CERES to Proxmox host')
    parser.add_argument('--test', action='store_true', help='Test SSH connection only')
    parser.add_argument('--config', type=Path, default=None, help='Path to credentials JSON file')
    parser.add_argument('--host', type=str, default=None, help='Override Proxmox host IP')
    parser.add_argument('--user', type=str, default='root', help='SSH user (default: root)')
    parser.add_argument('--remote-dir', type=str, default='/opt/ceres', help='Remote directory')
    
    args = parser.parse_args()
    
    if args.config:
        creds_file = args.config
    else:
        creds_file = Path(__file__).parent.parent / 'config' / 'credentials.json'
        if not creds_file.exists():
            creds_file = Path.home() / '.ceres' / 'credentials.json'
        if not creds_file.exists():
            print("[ERROR] Credentials file not found")
            return 1
    
    try:
        creds = load_credentials(creds_file)
    except Exception as e:
        print(f"[ERROR] {e}")
        return 1
    
    host = args.host or creds.get('proxmox', {}).get('host', '192.168.1.3')
    user = args.user or creds.get('ssh', {}).get('user', creds.get('proxmox', {}).get('user', 'root'))
    password = creds.get('ssh', {}).get('password', creds.get('proxmox', {}).get('password'))
    
    if not password:
        print("[ERROR] No password in credentials")
        return 1
    
    deployer = SSHDeployer(host, user, password)
    script_dir = Path(__file__).parent
    public_dir = script_dir.parent
    private_dir = script_dir.parent.parent / 'Ceres-Private'
    
    if args.test:
        return test_connection(deployer)
    else:
        return deploy(deployer, creds, public_dir, private_dir if private_dir.exists() else None, args.remote_dir)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nInterrupted")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] {e}")
        sys.exit(1)
