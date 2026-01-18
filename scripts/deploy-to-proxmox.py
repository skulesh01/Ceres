#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Deploy CERES to Proxmox Host via Git Clone
Strategy: Clone project from GitHub, download dependencies on remote server
"""

import sys
import time
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / '_lib'))

try:
    from ssh_deployer import SSHDeployer, load_credentials, print_deployment_summary, ProgressBar
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


def deploy(deployer: SSHDeployer, creds: dict, remote_dir: str) -> int:
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
    progress.add_stage("Cloning from GitHub", 20)
    progress.add_stage("Installing deps", 15)
    progress.add_stage("Running deploy", 62)
    
    progress.update()
    if not deployer.connect():
        return 1
    
    # Setup timezone on remote server
    progress.update()
    print(f"\n>>> Setting timezone on server...")
    deployer.setup_timezone("Europe/Moscow")
    progress.update()
    
    print(f"\n>>> Preparing remote directory: {remote_dir}")
    deployer.run_command(f"rm -rf {remote_dir}/* 2>/dev/null; mkdir -p {remote_dir}/logs && touch {remote_dir}/logs/deployment.log", show_output=False)
    
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
        # Clone project from GitHub (no history with --depth 1)
        log_msg("\n>>> Cloning CERES project from GitHub...")
        github_repo = "https://github.com/skulesh01/Ceres.git"
        clone_cmd = f"cd {remote_dir} && git clone --depth 1 {github_repo} . 2>&1"
        result = deployer.run_command(clone_cmd, show_output=True, stream_output=False)
        if result:
            log_msg("[OK] Project cloned successfully")
        else:
            log_msg("[ERROR] Git clone failed")
            deployer.close()
            return 1
    except Exception as e:
        log_msg(f"[ERROR] Git clone exception: {e}")
        deployer.close()
        return 1
    
    progress.update()
    
    # Now run installation and deployment scripts
    log_msg("\n>>> Installing dependencies on remote server...")
    install_script = r'''
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | grep -E "(Reading|Building|Setting)" || echo "apt-get updated"
apt-get install -y -qq python3 python3-pip git wget curl 2>&1 | tail -5 || true
curl -fsSL https://get.docker.com -o /tmp/docker.sh && bash /tmp/docker.sh 2>&1 | tail -3 || true
python3 -m pip install --quiet paramiko docker --disable-pip-version-check 2>&1 | tail -2 || true
echo "=== Dependencies installation complete ==="
'''
    result = deployer.run_command(install_script, show_output=True, stream_output=False)
    if result:
        log_msg("[OK] Dependencies installed")
    else:
        log_msg("[WARN] Some dependencies may have failed, but continuing...")
    progress.update()
    
    log_msg("\n>>> Starting deployment orchestration from cloned project...")
    print("\n" + "=" * 80)
    print("LIVE OUTPUT FROM SERVER:")
    print("=" * 80 + "\n")
    
    # Run deployment script from cloned project with streaming output
    log_msg(">>> Running auto-deploy.py on server...")
    result = deployer.run_command(
        f"cd {remote_dir} && python3 auto-deploy.py 2>&1",
        show_output=True,
        stream_output=False
    )
    
    if result:
        log_msg("[OK] Deployment orchestration completed")
    else:
        log_msg("[ERROR] Deployment orchestration failed")
    
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
    parser = argparse.ArgumentParser(description='Deploy CERES to Proxmox host via Git Clone')
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
    
    if args.test:
        return test_connection(deployer)
    else:
        return deploy(deployer, creds, args.remote_dir)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nInterrupted")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] {e}")
        sys.exit(1)

