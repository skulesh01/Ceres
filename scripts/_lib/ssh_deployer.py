#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SSH Deployer Library
Переиспользуемая библиотека для SSH операций (upload, execute, test connection)
Используется: scripts/deploy-to-proxmox.py, Private/auto-deploy.py
"""

import sys
import time
import tarfile
import json
from pathlib import Path
from typing import Optional, Callable, Dict, List

try:
    import paramiko
except ImportError:
    print("Installing paramiko...")
    import subprocess
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'paramiko', '--quiet'])
    import paramiko


class ProgressBar:
    """Simple ASCII progress bar with stage tracking"""
    
    def __init__(self, width: int = 50):
        self.width = width
        self.stages = []
        self.current_stage = 0
        self.start_time = time.time()
    
    def add_stage(self, name: str, weight: float = 1.0):
        """Add a deployment stage with relative weight"""
        self.stages.append({'name': name, 'weight': weight, 'done': False})
    
    def update(self, progress: float = None):
        """Update progress bar (0.0-1.0) or auto-increment current stage"""
        if progress is None:
            # Auto-complete current stage and move to next
            if self.current_stage < len(self.stages):
                self.stages[self.current_stage]['done'] = True
                self.current_stage += 1
            progress = self._calculate_progress()
        
        elapsed = time.time() - self.start_time
        self._draw(progress, elapsed)
    
    def _calculate_progress(self) -> float:
        """Calculate overall progress based on completed stages"""
        if not self.stages:
            return 0.0
        total_weight = sum(s['weight'] for s in self.stages)
        done_weight = sum(s['weight'] for s in self.stages if s['done'])
        return done_weight / total_weight
    
    def _draw(self, progress: float, elapsed: int):
        """Draw progress bar"""
        progress = max(0.0, min(1.0, progress))
        filled = int(self.width * progress)
        bar = '█' * filled + '░' * (self.width - filled)
        
        percent = int(progress * 100)
        stage = self.stages[self.current_stage]['name'] if self.current_stage < len(self.stages) else 'Done'
        
        # Ensure elapsed is int
        elapsed = int(elapsed)
        
        # Estimate remaining time
        if progress > 0.01:
            total_time = elapsed / progress
            remaining = int(total_time - elapsed)
            remaining = max(0, remaining)
            eta = f"{remaining // 60}m {remaining % 60}s"
        else:
            eta = "calculating..."
        
        # Print on same line (use \r)
        sys.stdout.write(f"\r[{bar}] {percent:3d}% | {stage:25s} | {elapsed:3d}s → {eta}")
        sys.stdout.flush()
    
    def finish(self):
        """Mark as complete and print newline"""
        for s in self.stages:
            s['done'] = True
        self._draw(1.0, int(time.time() - self.start_time))
        print()  # Newline


class SSHDeployer:
    """SSH deployment helper with archive, upload, execute capabilities"""
    
    def __init__(self, host: str, user: str = 'root', password: str = None, timeout: int = 15):
        self.host = host
        self.user = user
        self.password = password
        self.timeout = timeout
        self.ssh = None
        self.sftp = None
    
    def connect(self) -> bool:
        """Connect to SSH server"""
        print(f"\n>>> Connecting to {self.user}@{self.host}...")
        try:
            self.ssh = paramiko.SSHClient()
            self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            self.ssh.connect(self.host, username=self.user, password=self.password, timeout=self.timeout)
            self.sftp = self.ssh.open_sftp()
            print("[OK] Connected")
            return True
        except Exception as e:
            print(f"[ERROR] Connection failed: {e}")
            return False
    
    def run_command(self, cmd: str, show_output: bool = True) -> bool:
        """Execute command on remote server
        
        Supports multi-line scripts and environment variables.
        """
        if not self.ssh:
            print("[ERROR] Not connected")
            return False
        
        try:
            chan = self.ssh.get_transport().open_session()
            # Use bash -lc to support multi-line and environment
            chan.exec_command(f"bash -lc '{cmd}'")
            
            stdout = chan.makefile('r')
            stderr = chan.makefile_stderr('r')
            
            if show_output:
                for line in stdout:
                    # Decode if bytes
                    if isinstance(line, bytes):
                        line = line.decode('utf-8', errors='ignore')
                    print(f"  {line.rstrip()}")
                for line in stderr:
                    if isinstance(line, bytes):
                        line = line.decode('utf-8', errors='ignore')
                    if line.strip():
                        print(f"  [ERR] {line.rstrip()}")
            
            exit_code = chan.recv_exit_status()
            return exit_code == 0
        except Exception as e:
            print(f"[ERROR] Command execution failed: {e}")
            return False
    
    def upload_file(self, local_path: Path, remote_path: str) -> bool:
        """Upload file to remote server"""
        try:
            if not self.sftp:
                print("[ERROR] SFTP not available")
                return False
            
            self.sftp.put(str(local_path), remote_path)
            return True
        except Exception as e:
            print(f"[ERROR] File upload failed: {e}")
            return False
    
    def upload_dir(self, local_dir: Path, remote_dir: str) -> bool:
        """Upload entire directory to remote"""
        try:
            self.run_command(f"mkdir -p {remote_dir}", show_output=False)
            for item in local_dir.rglob('*'):
                if item.is_file():
                    rel_path = item.relative_to(local_dir)
                    remote_path = f"{remote_dir}/{rel_path}".replace('\\', '/')
                    self.upload_file(item, remote_path)
            return True
        except Exception as e:
            print(f"[ERROR] Directory upload failed: {e}")
            return False
    
    def close(self):
        """Close SSH connection"""
        try:
            if self.sftp:
                self.sftp.close()
            if self.ssh:
                self.ssh.close()
        except Exception:
            pass


def create_project_archive(
    public_dir: Path,
    private_dir: Optional[Path] = None,
    exclude: List[str] = None
) -> Path:
    """Create tar.gz archive of project
    
    Args:
        public_dir: Path to public project directory
        private_dir: Optional private orchestrators directory
        exclude: List of patterns to exclude (default: .git, node_modules, __pycache__)
    
    Returns:
        Path to created archive
    """
    if exclude is None:
        exclude = ['.git', 'node_modules', '__pycache__', '.pyc', '.pytest_cache', '.venv']
    
    print("\n>>> Creating project archive...")
    archive_path = Path.home() / 'ceres-project.tar.gz'
    
    if archive_path.exists():
        archive_path.unlink()
    
    def should_exclude(path: Path) -> bool:
        path_str = str(path)
        return any(x in path_str for x in exclude)
    
    def add_dir(tar: tarfile.TarFile, base_path: Path, arc_base: str):
        """Add directory contents to tar, respecting excludes"""
        for p in base_path.rglob('*'):
            if should_exclude(p):
                continue
            
            arcname = f"{arc_base}/{p.relative_to(base_path)}" if arc_base else str(p.relative_to(base_path))
            arcname = arcname.replace('\\', '/')  # Normalize paths
            
            try:
                tar.add(str(p), arcname=arcname, recursive=False)
            except Exception as e:
                print(f"  [WARN] Skipped {p}: {e}")
    
    try:
        with tarfile.open(archive_path, 'w:gz') as tar:
            if public_dir.exists():
                add_dir(tar, public_dir, 'Ceres')
            if private_dir and private_dir.exists():
                # Add private orchestrators at archive root (no prefix)
                add_dir(tar, private_dir, '')
        
        size_mb = archive_path.stat().st_size / (1024 * 1024)
        print(f"[OK] Archive created: {size_mb:.1f}MB")
        return archive_path
    except Exception as e:
        print(f"[ERROR] Archive creation failed: {e}")
        raise


def load_credentials(creds_file: Path) -> Dict:
    """Load credentials from JSON file
    
    Expected structure:
    {
        "proxmox": {"host": "192.168.1.3", "user": "root", "password": "..."},
        "ssh": {"user": "root", "password": "..."},
        "services": {
            "keycloak": {"admin_password": "..."},
            "grafana": {"admin_password": "..."},
            ...
        }
    }
    """
    if not creds_file.exists():
        raise FileNotFoundError(f"Credentials file not found: {creds_file}")
    
    try:
        with open(creds_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON in credentials file: {e}")


def print_deployment_summary(creds: Dict, server_ip: str, elapsed_seconds: int):
    """Print nice deployment completion summary"""
    minutes, seconds = divmod(elapsed_seconds, 60)
    
    print("\n" + "=" * 80)
    print("                    ✓ DEPLOYMENT COMPLETED")
    print("=" * 80)
    print(f"\nTotal time: {minutes}m {seconds}s")
    
    keycloak_pass = creds.get('services', {}).get('keycloak', {}).get('admin_password')
    grafana_pass = creds.get('services', {}).get('grafana', {}).get('admin_password')
    
    print("\nAccess your services at:")
    print("  - https://auth.ceres           - Keycloak" + 
          (f" (admin/{keycloak_pass})" if keycloak_pass else ""))
    print("  - https://gitlab.ceres         - GitLab CE")
    print("  - https://zulip.ceres          - Zulip Chat")
    print("  - https://nextcloud.ceres      - Nextcloud")
    print("  - https://grafana.ceres        - Grafana" + 
          (f" (admin/{grafana_pass})" if grafana_pass else ""))
    
    print(f"\nConfigure DNS: *.ceres -> {server_ip}")
    print("\nNext steps:")
    print("  1. Add wildcard A record in your DNS")
    print("  2. Access Keycloak and create users")
    print("  3. Configure SMTP for email notifications")
    print("  4. Import Grafana dashboards")
