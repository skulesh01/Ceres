#!/usr/bin/env python3
"""
E2E Integration Test Suite
Tests all service integrations end-to-end
"""

import os
import time
import requests
from requests.auth import HTTPBasicAuth
import json

# Configuration
GITLAB_URL = os.getenv('GITLAB_URL', 'http://localhost:8080')
GITLAB_TOKEN = os.getenv('GITLAB_API_TOKEN')
ZULIP_URL = os.getenv('ZULIP_URL', 'http://localhost:8000')
ZULIP_EMAIL = os.getenv('ZULIP_BOT_EMAIL')
ZULIP_API_KEY = os.getenv('ZULIP_BOT_API_KEY')
KEYCLOAK_URL = os.getenv('KEYCLOAK_URL', 'http://localhost:8080')
NEXTCLOUD_URL = os.getenv('NEXTCLOUD_URL', 'http://localhost')
GRAFANA_URL = os.getenv('GRAFANA_URL', 'http://localhost:3000')

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    END = '\033[0m'

def print_test(name):
    print(f"\n{Colors.CYAN}[TEST] {name}{Colors.END}")

def print_success(msg):
    print(f"{Colors.GREEN}✅ {msg}{Colors.END}")

def print_error(msg):
    print(f"{Colors.RED}❌ {msg}{Colors.END}")

def print_warning(msg):
    print(f"{Colors.YELLOW}⚠️  {msg}{Colors.END}")

# ==========================================
# Test 1: GitLab API
# ==========================================
def test_gitlab():
    print_test("GitLab API Connectivity")
    try:
        headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
        response = requests.get(f"{GITLAB_URL}/api/v4/projects", headers=headers, timeout=10)
        if response.status_code == 200:
            projects = response.json()
            print_success(f"GitLab API working! Found {len(projects)} projects")
            return True
        else:
            print_error(f"GitLab API returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"GitLab connection failed: {e}")
        return False

# ==========================================
# Test 2: Zulip API
# ==========================================
def test_zulip():
    print_test("Zulip API Connectivity")
    try:
        auth = HTTPBasicAuth(ZULIP_EMAIL, ZULIP_API_KEY)
        response = requests.get(f"{ZULIP_URL}/api/v1/streams", auth=auth, timeout=10)
        if response.status_code == 200:
            streams = response.json()
            print_success(f"Zulip API working! Found {len(streams.get('streams', []))} streams")
            return True
        else:
            print_error(f"Zulip API returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Zulip connection failed: {e}")
        return False

# ==========================================
# Test 3: GitLab → Zulip Webhook
# ==========================================
def test_gitlab_zulip_webhook():
    print_test("GitLab → Zulip Webhook Integration")
    try:
        # Check if webhook exists
        headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
        response = requests.get(f"{GITLAB_URL}/api/v4/projects/1/hooks", headers=headers, timeout=10)
        
        if response.status_code == 200:
            hooks = response.json()
            zulip_hooks = [h for h in hooks if 'zulip' in h.get('url', '')]
            if zulip_hooks:
                print_success(f"Found {len(zulip_hooks)} GitLab→Zulip webhooks")
                return True
            else:
                print_warning("No Zulip webhooks found in GitLab")
                return False
        else:
            print_error(f"Failed to get webhooks: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Webhook test failed: {e}")
        return False

# ==========================================
# Test 4: Keycloak Health
# ==========================================
def test_keycloak():
    print_test("Keycloak SSO Health")
    try:
        response = requests.get(f"{KEYCLOAK_URL}/health", timeout=10)
        if response.status_code == 200:
            print_success("Keycloak is healthy")
            return True
        else:
            print_error(f"Keycloak returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Keycloak connection failed: {e}")
        return False

# ==========================================
# Test 5: Nextcloud API
# ==========================================
def test_nextcloud():
    print_test("Nextcloud API Connectivity")
    try:
        response = requests.get(f"{NEXTCLOUD_URL}/status.php", timeout=10)
        if response.status_code == 200:
            status = response.json()
            print_success(f"Nextcloud {status.get('version')} is running")
            return True
        else:
            print_error(f"Nextcloud returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Nextcloud connection failed: {e}")
        return False

# ==========================================
# Test 6: Grafana Health
# ==========================================
def test_grafana():
    print_test("Grafana Health")
    try:
        response = requests.get(f"{GRAFANA_URL}/api/health", timeout=10)
        if response.status_code == 200:
            print_success("Grafana is healthy")
            return True
        else:
            print_error(f"Grafana returned {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Grafana connection failed: {e}")
        return False

# ==========================================
# Test 7: Create Issue in GitLab
# ==========================================
def test_create_gitlab_issue():
    print_test("Create GitLab Issue")
    try:
        headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
        data = {
            "title": "E2E Test Issue",
            "description": "This is an automated test issue"
        }
        response = requests.post(
            f"{GITLAB_URL}/api/v4/projects/1/issues",
            headers=headers,
            json=data,
            timeout=10
        )
        
        if response.status_code == 201:
            issue = response.json()
            print_success(f"Created issue #{issue['iid']}: {issue['web_url']}")
            return True, issue['iid']
        else:
            print_error(f"Failed to create issue: {response.status_code}")
            return False, None
    except Exception as e:
        print_error(f"Issue creation failed: {e}")
        return False, None

# ==========================================
# Test 8: Verify Zulip Notification
# ==========================================
def test_zulip_notification(wait_seconds=5):
    print_test(f"Verify Zulip Notification (waiting {wait_seconds}s)")
    try:
        time.sleep(wait_seconds)
        
        auth = HTTPBasicAuth(ZULIP_EMAIL, ZULIP_API_KEY)
        response = requests.get(
            f"{ZULIP_URL}/api/v1/messages",
            auth=auth,
            params={"anchor": "newest", "num_before": 10},
            timeout=10
        )
        
        if response.status_code == 200:
            messages = response.json().get('messages', [])
            test_messages = [m for m in messages if 'E2E Test Issue' in m.get('content', '')]
            if test_messages:
                print_success("Found GitLab issue notification in Zulip!")
                return True
            else:
                print_warning("No notification found in Zulip (may take longer)")
                return False
        else:
            print_error(f"Failed to get messages: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Notification check failed: {e}")
        return False

# ==========================================
# Main Test Runner
# ==========================================
def main():
    print(f"\n{Colors.CYAN}{'='*60}")
    print("  CERES E2E INTEGRATION TEST SUITE")
    print(f"{'='*60}{Colors.END}\n")
    
    results = {}
    
    # Basic connectivity tests
    results['GitLab'] = test_gitlab()
    results['Zulip'] = test_zulip()
    results['Keycloak'] = test_keycloak()
    results['Nextcloud'] = test_nextcloud()
    results['Grafana'] = test_grafana()
    
    # Integration tests
    results['GitLab→Zulip Webhook'] = test_gitlab_zulip_webhook()
    
    # End-to-end workflow test
    success, issue_id = test_create_gitlab_issue()
    results['Create GitLab Issue'] = success
    
    if success:
        results['Zulip Notification'] = test_zulip_notification()
    
    # Summary
    print(f"\n{Colors.CYAN}{'='*60}")
    print("  TEST SUMMARY")
    print(f"{'='*60}{Colors.END}\n")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test, result in results.items():
        status = f"{Colors.GREEN}✅ PASS{Colors.END}" if result else f"{Colors.RED}❌ FAIL{Colors.END}"
        print(f"  {test:30s} {status}")
    
    print(f"\n{Colors.CYAN}Result: {passed}/{total} tests passed{Colors.END}\n")
    
    if passed == total:
        print(f"{Colors.GREEN}🎉 All tests passed! Integration is working perfectly!{Colors.END}\n")
        return 0
    else:
        print(f"{Colors.YELLOW}⚠️  Some tests failed. Check configuration and try again.{Colors.END}\n")
        return 1

if __name__ == '__main__':
    exit(main())
