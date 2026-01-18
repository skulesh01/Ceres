#!/usr/bin/env python3
"""
Zulip Bot - GitLab Command Handler
Allows team to interact with GitLab via Zulip chat commands

Commands:
  /issue <title>       - Create new issue in default project
  /mr <title>          - Create merge request
  /deploy <branch>     - Trigger pipeline
  /status              - Show pipeline status
  /help                - Show help
"""

import os
import re
import requests
import zulip

# Configuration
GITLAB_URL = os.getenv('GITLAB_URL', 'https://gitlab.ceres')
GITLAB_TOKEN = os.getenv('GITLAB_API_TOKEN')
GITLAB_PROJECT_ID = os.getenv('GITLAB_DEFAULT_PROJECT_ID', '1')

client = zulip.Client(config_file=os.path.expanduser('~/.zuliprc'))

def create_issue(title, description=''):
    """Create GitLab issue"""
    url = f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/issues"
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    data = {
        "title": title,
        "description": description
    }
    
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 201:
        issue = response.json()
        return f"✅ Created issue #{issue['iid']}: {issue['web_url']}"
    else:
        return f"❌ Failed to create issue: {response.text}"

def create_merge_request(title, source_branch, target_branch='main'):
    """Create GitLab merge request"""
    url = f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/merge_requests"
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    data = {
        "title": title,
        "source_branch": source_branch,
        "target_branch": target_branch
    }
    
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 201:
        mr = response.json()
        return f"✅ Created MR !{mr['iid']}: {mr['web_url']}"
    else:
        return f"❌ Failed to create MR: {response.text}"

def trigger_pipeline(branch='main'):
    """Trigger GitLab pipeline"""
    url = f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/pipeline"
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    data = {"ref": branch}
    
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 201:
        pipeline = response.json()
        return f"🚀 Started pipeline #{pipeline['id']} for branch **{branch}**: {pipeline['web_url']}"
    else:
        return f"❌ Failed to trigger pipeline: {response.text}"

def get_pipeline_status():
    """Get latest pipeline status"""
    url = f"{GITLAB_URL}/api/v4/projects/{GITLAB_PROJECT_ID}/pipelines"
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    
    response = requests.get(url, headers=headers, params={"per_page": 1})
    if response.status_code == 200:
        pipelines = response.json()
        if pipelines:
            p = pipelines[0]
            status_emoji = {
                'success': '✅',
                'failed': '❌',
                'running': '🔄',
                'pending': '⏳',
                'canceled': '⚠️'
            }.get(p['status'], '❓')
            return f"{status_emoji} Pipeline #{p['id']}: **{p['status']}** ({p['ref']})\n{p['web_url']}"
        return "No pipelines found"
    else:
        return f"❌ Failed to get status: {response.text}"

def show_help():
    """Show help message"""
    return """**GitLab Bot Commands:**

`/issue <title>` - Create new issue
`/mr <title> <source_branch>` - Create merge request
`/deploy <branch>` - Trigger pipeline (default: main)
`/status` - Show latest pipeline status
`/help` - Show this help

**Examples:**
`/issue Fix login bug`
`/mr Add new feature feature-branch`
`/deploy develop`
`/status`
"""

@client.call_on_each_message
def handle_message(msg):
    """Handle incoming Zulip messages"""
    content = msg['content'].strip()
    
    # Ignore messages not starting with /
    if not content.startswith('/'):
        return
    
    # Parse command
    parts = content.split(maxsplit=1)
    command = parts[0].lower()
    args = parts[1] if len(parts) > 1 else ''
    
    response = ""
    
    if command == '/issue':
        if args:
            response = create_issue(args)
        else:
            response = "❌ Usage: `/issue <title>`"
    
    elif command == '/mr':
        if args:
            mr_parts = args.rsplit(maxsplit=1)
            if len(mr_parts) == 2:
                title, branch = mr_parts
                response = create_merge_request(title, branch)
            else:
                response = "❌ Usage: `/mr <title> <source_branch>`"
        else:
            response = "❌ Usage: `/mr <title> <source_branch>`"
    
    elif command == '/deploy':
        branch = args if args else 'main'
        response = trigger_pipeline(branch)
    
    elif command == '/status':
        response = get_pipeline_status()
    
    elif command == '/help':
        response = show_help()
    
    else:
        response = f"❓ Unknown command: {command}\nType `/help` for available commands"
    
    # Send response
    if response:
        client.send_message({
            "type": msg['type'],
            "to": msg['display_recipient'] if msg['type'] == 'stream' else msg['sender_email'],
            "topic": msg.get('subject', 'Bot Response'),
            "content": response
        })

if __name__ == '__main__':
    print("🤖 Zulip GitLab Bot started!")
    print(f"Listening for commands in Zulip...")
    print(f"GitLab: {GITLAB_URL}")
    print(f"Project ID: {GITLAB_PROJECT_ID}")
    client.call_on_each_message(handle_message)
