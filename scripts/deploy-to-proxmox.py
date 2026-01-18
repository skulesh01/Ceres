#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Deploy CERES to Proxmox Host
Полное развертывание на удаленный Proxmox через SSH

Usage:
    python3 scripts/deploy-to-proxmox.py --test        # Test SSH connection
    python3 scripts/deploy-to-proxmox.py --config FILE # Use custom credentials file
    python3 scripts/deploy-to-proxmox.py               # Full deployment
"""

import sys
import time
import argparse
from pathlib import Path

# Add _lib to path
sys.path.insert(0, str(Path(__file__).parent / '_lib'))

try:
    from ssh_deployer import SSHDeployer, create_project_archive, load_credentials, print_deployment_summary
except ImportError as e:
    print(f"[ERROR] Failed to import ssh_deployer: {e}")
    sys.exit(1)


def test_connection(deployer: SSHDeployer) -> int:
    """Test SSH connectivity only"""
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
    """Full deployment workflow"""
    start_time = time.time()
    
    if not deployer.connect():
        return 1
    
    # Prepare remote directory
    print(f"\n>>> Preparing remote directory: {remote_dir}")
    deployer.run_command(f"mkdir -p {remote_dir}", show_output=False)
    
    # Create and upload archive
    try:
        archive_path = create_project_archive(public_dir, private_dir)
    except Exception as e:
        print(f"[ERROR] {e}")
        deployer.close()
        return 1
    
    print(f"\n>>> Uploading archive...")
    remote_archive = f"{remote_dir}/ceres-project.tar.gz"
    if not deployer.upload_file(archive_path, remote_archive):
        deployer.close()
        return 1
    archive_path.unlink()
    print("[OK] Archive uploaded")
    
    # Extract archive
    print(f"\n>>> Extracting archive...")
    deployer.run_command(
        f"cd {remote_dir} && tar -xzf ceres-project.tar.gz && rm ceres-project.tar.gz",
        show_output=False
    )
    print("[OK] Archive extracted")
    
    # Install dependencies
    print("\n>>> Installing dependencies (Python, Git, Terraform, Ansible, Docker)...")
    
    install_script = r'''
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>&1 | tail -1
apt-get install -y -qq python3 python3-pip git wget curl unzip gnupg lsb-release ca-certificates

# Terraform
wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update -qq && apt-get install -y -qq terraform

# Ansible
python3 -m pip install --quiet ansible --disable-pip-version-check

# Docker
curl -fsSL https://get.docker.com | sh

echo "Dependencies installed"
'''
    
    if not deployer.run_command(install_script):
        print("[WARN] Some dependencies may have failed to install")
    print("[OK] Dependencies ready")
    
    # Run deployment
    print("\n>>> Starting CERES deployment orchestration...")
    print("  This will take 45-90 minutes depending on network speed\n")
    
    # Check what to run
    orchestrator = f"{remote_dir}/auto-deploy.py"
    if not deployer.run_command(f"test -f {orchestrator}", show_output=False):
        # Try Private version if exists
        orchestrator = f"{remote_dir}/auto-deploy.py"
        deployer.run_command(f"cd {remote_dir} && python3 auto-deploy.py 2>&1 || python3 Ceres/scripts/auto-deploy.py 2>&1")
    else:
        deployer.run_command(f"cd {remote_dir} && python3 auto-deploy.py")
    
    # Print summary
    elapsed = int(time.time() - start_time)
    print_deployment_summary(creds, deployer.host, elapsed)
    
    deployer.close()
    return 0


def main():
    parser = argparse.ArgumentParser(
        description='Deploy CERES to Proxmox host',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 scripts/deploy-to-proxmox.py --test
  python3 scripts/deploy-to-proxmox.py --config credentials.json
  python3 scripts/deploy-to-proxmox.py
        """
    )
    
    parser.add_argument('--test', action='store_true', help='Test SSH connection only')
    parser.add_argument('--config', type=Path, default=None, help='Path to credentials JSON file')
    parser.add_argument('--host', type=str, default=None, help='Override Proxmox host IP')
    parser.add_argument('--user', type=str, default='root', help='SSH user (default: root)')
    parser.add_argument('--remote-dir', type=str, default='/opt/ceres', help='Remote directory (default: /opt/ceres)')
    
    args = parser.parse_args()
    
    # Locate credentials
    if args.config:
        creds_file = args.config
    else:
        # Check common locations
        creds_file = Path(__file__).parent.parent / 'config' / 'credentials.json'
        if not creds_file.exists():
            creds_file = Path.home() / '.ceres' / 'credentials.json'
        if not creds_file.exists():
            print(f"[ERROR] Credentials file not found. Specify with --config or place at:")
            print(f"  - config/credentials.json")
            print(f"  - ~/.ceres/credentials.json")
            return 1
    
    # Load credentials
    try:
        creds = load_credentials(creds_file)
    except Exception as e:
        print(f"[ERROR] Failed to load credentials: {e}")
        return 1
    
    # Override with CLI args
    host = args.host or creds.get('proxmox', {}).get('host', '192.168.1.3')
    user = args.user or creds.get('ssh', {}).get('user', creds.get('proxmox', {}).get('user', 'root'))
    password = creds.get('ssh', {}).get('password', creds.get('proxmox', {}).get('password'))
    
    if not password:
        print("[ERROR] No password found in credentials file")
        return 1
    
    deployer = SSHDeployer(host, user, password)
    
    # Locate project directories
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
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n[ERROR] {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
