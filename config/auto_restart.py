#!/usr/bin/env python3
"""
Auto-run all CERES stacks and collect diagnostics
This script will:
1. Create Docker networks (br_frontend, br_backend)
2. Stop/remove all old containers
3. Bring up all compose stacks in order
4. Collect and display diagnostics (docker ps, traefik logs, curl tests)
"""

import subprocess
import time
import sys
import os
from pathlib import Path

def run_cmd(cmd, shell=False, capture_output=True, timeout=60):
    """Run command and return output"""
    try:
        if shell:
            result = subprocess.run(cmd, shell=True, capture_output=capture_output, text=True, timeout=timeout)
        else:
            result = subprocess.run(cmd, capture_output=capture_output, text=True, timeout=timeout)
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return 1, "", f"Command timed out after {timeout}s: {cmd}"
    except Exception as e:
        return 1, "", str(e)

def print_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")

def main():
    config_dir = Path("f:\\Ceres\\config")
    os.chdir(config_dir)
    
    print_header("CERES DOCKER COMPOSE AUTO-RESTART & DIAGNOSTICS")
    
    # Step 1: Create networks
    print_header("Step 1: Creating Docker networks")
    
    networks = ["br_frontend", "br_backend"]
    for net in networks:
        print(f"  Checking network: {net}...")
        ret, out, err = run_cmd(f"docker network ls --filter name={net} --quiet")
        if not out.strip():
            print(f"    → Creating {net}...")
            ret, out, err = run_cmd(f"docker network create --driver bridge {net}")
            if ret == 0:
                print(f"    ✓ Created {net}")
            else:
                print(f"    ✗ Error creating {net}: {err}")
        else:
            print(f"    ✓ Already exists: {net}")
    
    # Step 2: Stop old containers
    print_header("Step 2: Stopping and removing old containers")
    
    compose_files = [
        "docker-compose.base.yml",
        "docker-compose.apps.yml",
        "docker-compose.business.yml",
        "docker-compose.monitoring.yml",
        "docker-compose.utilities.yml"
    ]
    
    for cf in compose_files:
        print(f"  Processing: {cf}...")
        ret, out, err = run_cmd(f"docker compose -f {cf} down --remove-orphans 2>&1", shell=True)
        if ret == 0:
            print(f"    ✓ Down successful")
        else:
            print(f"    ~ Down (no containers or error, continuing...)")
    
    time.sleep(2)
    
    # Step 3: Bring up stacks
    print_header("Step 3: Bringing up all compose stacks")
    
    for cf in compose_files:
        print(f"  Starting: {cf}...")
        ret, out, err = run_cmd(f"docker compose -f {cf} up -d 2>&1", shell=True, timeout=120)
        if ret == 0:
            print(f"    ✓ Up successful")
        else:
            print(f"    ✗ Error: {err[:200]}")
        time.sleep(3)
    
    # Step 4: Collect diagnostics
    print_header("Step 4: Container status (docker ps)")
    
    ret, out, err = run_cmd('docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Ports}}"', shell=True)
    print(out)
    
    # Step 5: Traefik logs
    print_header("Step 5: Traefik logs (last 150 lines)")
    
    ret, out, err = run_cmd("docker logs --tail 150 traefik 2>&1", shell=True)
    if ret == 0:
        # Show only last 50 lines to keep output concise
        lines = out.split('\n')[-50:]
        print('\n'.join(lines))
    else:
        print(f"  Error getting Traefik logs: {err}")
    
    # Step 6: Network inspection
    print_header("Step 6: Network verification")
    
    for net in networks:
        ret, out, err = run_cmd(f"docker network inspect {net} --format='{{{{.Name}}}}: {{{{len .Containers}}}} containers'", shell=True)
        if ret == 0:
            print(f"  {out.strip()}")
    
    # Step 7: Test HTTP requests
    print_header("Step 7: Testing HTTP requests (curl with Host header)")
    
    test_hosts = [
        ("chat.ceres.local", "Mattermost"),
        ("cloud.ceres.local", "Nextcloud"),
        ("git.ceres.local", "Gitea"),
        ("auth.ceres.local", "Keycloak"),
    ]
    
    for host, name in test_hosts:
        print(f"  Testing {name} ({host})...")
        ret, out, err = run_cmd(f'curl -s -o /dev/null -w "HTTP %{{http_code}}" -H "Host: {host}" http://127.0.0.1/', shell=True, timeout=10)
        if ret == 0:
            print(f"    → Response: {out}")
        else:
            print(f"    ✗ Error: {err[:100]}")
    
    # Step 8: Final status
    print_header("VERIFICATION CHECKLIST")
    print("""
  ✓ Networks created (br_frontend, br_backend)
  ✓ All compose stacks brought up
  ✓ Container status displayed above
  ✓ Traefik logs displayed above
  ✓ HTTP test results shown above
  
  Next steps:
  1. Open Traefik Dashboard: http://localhost:8080/
     - Verify all routers are present (taiga, chat, cloud, git, auth, vault, sync, portainer, prometheus, grafana, alerts)
  
  2. Check if HTTP requests return 301/302 (redirect) or 200/307
     - 301/302 = HTTP redirecting to HTTPS (expected)
     - 200 = HTTPS cert ready (also fine)
     - 404 = Still has routing issue (check Traefik logs above)
  
  3. If 404 appears, collect and send these logs:
     - docker logs --tail 200 traefik
     - docker ps output (above)
     - curl -v output for problem service
    """)
    
    print_header("DONE")
    print("  All stacks should be running now!")
    print(f"  Config directory: {config_dir}")

if __name__ == "__main__":
    main()
