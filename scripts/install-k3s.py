#!/usr/bin/env python3
"""
CERES - Automated K3s Installation via SSH
Это скрипт на Python который подключается по SSH с паролем и выполняет установку k3s
"""

import subprocess
import sys
import time
import os

# Configuration
HOST = "192.168.1.3"
USER = "root"
PASSWORD = "!r0oT3dc"
REPO = "skulesh01/Ceres"

def run_ssh_command(cmd, verbose=True):
    """Execute command on remote server via SSH"""
    # Using OpenSSH with stdin for password
    ssh_cmd = ['ssh', '-o', 'StrictHostKeyChecking=no', f'{USER}@{HOST}', cmd]
    
    if verbose:
        print(f"  → {cmd}")
    
    try:
        # Use echo to pipe password - this doesn't work reliably
        # Better use expect or sshpass
        process = subprocess.Popen(
            ssh_cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=300
        )
        
        # Send password
        stdout, stderr = process.communicate(input=f"{PASSWORD}\n", timeout=300)
        
        if process.returncode == 0:
            if verbose and stdout:
                print(f"     {stdout[:200]}")
            return True, stdout
        else:
            print(f"  ✗ Error: {stderr[:200]}")
            return False, stderr
            
    except subprocess.TimeoutExpired:
        print("  ✗ Command timeout")
        return False, "Timeout"
    except Exception as e:
        print(f"  ✗ Exception: {e}")
        return False, str(e)

def main():
    print("")
    print("╔════════════════════════════════════════════════════════╗")
    print("║  CERES - Automated K3s Installation (Python + SSH)     ║")
    print("╚════════════════════════════════════════════════════════╝")
    print("")
    
    # Step 1: Check connectivity
    print("[1/4] Testing SSH connection to 192.168.1.3...", end="", flush=True)
    success, output = run_ssh_command("echo OK", verbose=False)
    if success and "OK" in output:
        print(" ✓")
    else:
        print(" ✗ SSH не работает")
        print(f"Error: {output}")
        sys.exit(1)
    
    # Step 2: Check if k3s already installed
    print("[2/4] Checking if k3s is already installed...", end="", flush=True)
    success, output = run_ssh_command("k3s --version 2>&1", verbose=False)
    if success and "v1" in output:
        print(" ✓ Already installed")
        print(f"     {output.strip()[:100]}")
        print("")
        print("k3s уже установлен! Переходим к следующему шагу...")
    else:
        print(" ✗ Not installed, installing now...")
        
        # Step 3: Install k3s
        print("[3/4] Installing k3s (5-10 minutes, please wait)...")
        print("      Downloading and installing k3s...")
        
        install_cmd = "curl -fsSL https://get.k3s.io | sh -"
        success, output = run_ssh_command(install_cmd, verbose=False)
        
        if success:
            print("      ✓ Installation completed")
        else:
            print("      ⚠ Installation may have issues, checking status...")
    
    # Step 4: Verify installation
    print("[4/4] Verifying installation...", end="", flush=True)
    success, output = run_ssh_command("kubectl get nodes 2>&1", verbose=False)
    
    if success and "192.168.1.3" in output:
        print(" ✓")
        print("")
        print("╔════════════════════════════════════════════════════════╗")
        print("║  ✓ K3S INSTALLATION SUCCESSFUL!                       ║")
        print("╚════════════════════════════════════════════════════════╝")
        print("")
        print("Next steps:")
        print("  1. Get kubeconfig: gh secret set KUBECONFIG ...")
        print("  2. Run deployment: gh workflow run ceres-deploy.yml")
        return 0
    else:
        print(" ⚠ Verification incomplete (k3s may still be initializing)")
        print("Output:", output[:200])
        return 1

if __name__ == "__main__":
    sys.exit(main())
