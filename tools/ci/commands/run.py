"""Unified CI entry point.

This is the main entry point called by GitHub Actions workflow.
It handles event parsing and routes to appropriate handlers.
"""

import os
import sys
import json
from typing import Optional

from ..core.github import GitHubClient
from . import plan, apply, verify, bootstrap


def parse_event() -> dict:
    """Parse GitHub event from environment."""
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    
    event_data = {}
    if event_path and os.path.exists(event_path):
        with open(event_path) as f:
            event_data = json.load(f)
    
    return {
        "name": event_name,
        "data": event_data,
    }


def parse_command(comment: str) -> tuple[Optional[str], list[str]]:
    """Parse command from PR comment.
    
    Returns:
        (command, layers) tuple
    """
    comment = comment.strip().lower()
    
    # Bootstrap commands
    if "/bootstrap" in comment:
        if "apply" in comment:
            return ("bootstrap-apply", [])
        return ("bootstrap-plan", [])
    
    # Standard commands
    if "/plan" in comment:
        # Extract layers if specified
        parts = comment.split()
        idx = parts.index("/plan") if "/plan" in parts else -1
        layers = parts[idx + 1:] if idx >= 0 and idx + 1 < len(parts) else ["all"]
        return ("plan", layers)
    
    if "/apply" in comment:
        parts = comment.split()
        idx = parts.index("/apply") if "/apply" in parts else -1
        layers = parts[idx + 1:] if idx >= 0 and idx + 1 < len(parts) else ["all"]
        return ("apply", layers)
    
    if "/e2e" in comment:
        return ("e2e", [])
        
    if "/review" in comment:
        return ("review", [])
        
    if "/help" in comment:
        return ("help", [])
    
    return (None, [])


def get_pr_number(event: dict) -> Optional[int]:
    """Extract PR number from event."""
    data = event.get("data", {})
    
    # Direct PR event
    if "pull_request" in data:
        return data["pull_request"].get("number")
    
    # Issue comment (on PR)
    if "issue" in data:
        issue = data["issue"]
        if "pull_request" in issue:
            return issue.get("number")
    
    return None


def get_run_url() -> str:
    """Get URL to current workflow run."""
    server = os.environ.get("GITHUB_SERVER_URL", "https://github.com")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    return f"{server}/{repo}/actions/runs/{run_id}"


def set_commit_status(gh: GitHubClient, pr_number: int, state: str, description: str, context: str = "CI"):
    """Set commit status on PR head."""
    try:
        pr = gh.get_pr(pr_number)
        run_url = get_run_url()
        gh.create_commit_status(
            sha=pr.head_sha,
            state=state,
            context=context,
            description=description,
            target_url=run_url,
        )
    except Exception as e:
        print(f"⚠️ Failed to set commit status: {e}")


class Args:
    """Simple args object for command handlers."""
    def __init__(self, **kwargs):
        for k, v in kwargs.items():
            setattr(self, k, v)


def run(args) -> int:
    """Main entry point for CI.
    
    Called by: python -m ci run
    """
    print("🚀 CI Pipeline Starting...")
    
    event = parse_event()
    event_name = event["name"]
    event_data = event.get("data", {})
    
    print(f"📌 Event: {event_name}")
    
    gh = GitHubClient()
    pr_number = get_pr_number(event)
    
    # Route based on event type
    if event_name == "pull_request":
        # Auto-plan on PR
        print("📋 PR event - running plan...")
        cmd_args = Args(layers=["all"], pr=pr_number)
        return plan.run(cmd_args)
    
    elif event_name == "push":
        # Post-merge verify
        ref = os.environ.get("GITHUB_REF", "")
        if ref == "refs/heads/main":
            print("🔄 Post-merge - running verify...")
            cmd_args = Args(apply=True, pr=None)
            return verify.run(cmd_args)
        return 0
    
    elif event_name == "issue_comment":
        comment = event_data.get("comment", {}).get("body", "")
        command, layers = parse_command(comment)
        
        if not command:
            print("ℹ️ No recognized command in comment")
            return 0
        
        print(f"🎯 Command: {command}")
        
        # Acknowledge comment with emoji
        try:
            comment_id = event_data.get("comment", {}).get("id")
            if comment_id:
                gh.react_to_comment(comment_id, "eyes")
        except Exception as e:
            print(f"⚠️ Failed to react: {e}")
        
        # Set pending status on PR
        if pr_number:
            set_commit_status(gh, pr_number, "pending", f"{command} in progress...", "CI")
        
        # Post instant "Running..." comment with job link
        run_url = get_run_url()
        user = event_data.get("comment", {}).get("user", {}).get("login", "user")
        if pr_number:
            try:
                instant_body = f"⏳ **{command}** running...\n\n> Triggered by `/{command}` from @{user}\n> [View Job]({run_url})"
                gh.create_comment(pr_number, instant_body)
            except Exception as e:
                print(f"⚠️ Failed to post instant comment: {e}")
        
        # Execute command
        exit_code = 0
        try:
            if command == "plan":
                cmd_args = Args(layers=layers or ["all"], pr=pr_number)
                exit_code = plan.run(cmd_args)
            
            elif command == "apply":
                cmd_args = Args(layers=layers or ["all"], pr=pr_number)
                exit_code = apply.run(cmd_args)
            
            elif command == "bootstrap-plan":
                cmd_args = Args(action="plan", pr=pr_number)
                exit_code = bootstrap.run(cmd_args)
            
            elif command == "bootstrap-apply":
                cmd_args = Args(action="apply", pr=pr_number)
                exit_code = bootstrap.run(cmd_args)
                
            elif command == "e2e":
                print("🔍 Triggering E2E tests...")
                import subprocess
                pr = gh.get_pr(pr_number)
                if not pr.head_ref:
                    print("❌ Could not determine PR branch")
                    exit_code = 1
                else:
                    cmd = ["gh", "workflow", "run", "e2e-tests.yml", "--ref", pr.head_ref, "-f", f"pr_number={pr_number}"]
                    res = subprocess.run(cmd, capture_output=True, text=True)
                    if res.returncode == 0:
                        gh.create_comment(pr_number, f"🧪 E2E tests triggered for branch `{pr.head_ref}`.")
                    else:
                        print(f"❌ Trigger failed: {res.stderr}")
                        gh.create_comment(pr_number, f"❌ Failed to trigger E2E tests: {res.stderr}")
                        exit_code = 1

            elif command == "review":
                print("🔍 UI Review triggered...")
                # Placeholder for AI review logic
                gh.create_comment(pr_number, "🔍 AI Review triggered (Placeholder).")

            elif command == "help":
                help_text = """## 📖 Available Commands
| Command | Description |
|:---|:---|
| `/plan` | Run terraform plan (Digger) |
| `/apply` | Run terraform apply (Digger) |
| `/bootstrap plan` | Run bootstrap plan |
| `/bootstrap apply` | Run bootstrap apply |
| `/e2e` | Trigger E2E tests |
| `/review` | Trigger AI Code Review |
"""
                gh.create_comment(pr_number, help_text)
            
        except Exception as e:
            print(f"❌ Command failed: {e}")
            exit_code = 1
        
        # Set final status
        if pr_number:
            state = "success" if exit_code == 0 else "failure"
            desc = f"{command} {'completed' if exit_code == 0 else 'failed'}"
            set_commit_status(gh, pr_number, state, desc, "CI")
        
        return exit_code
    
    elif event_name == "workflow_dispatch":
        # Manual trigger
        inputs = event_data.get("inputs", {})
        command = inputs.get("command", "plan")
        layers = inputs.get("layers", "all").split(",")
        
        print(f"🎯 Manual: {command} {layers}")
        
        if command == "plan":
            cmd_args = Args(layers=layers, pr=None)
            return plan.run(cmd_args)
        elif command == "apply":
            cmd_args = Args(layers=layers, pr=None)
            return apply.run(cmd_args)
        elif command == "bootstrap":
            cmd_args = Args(action=inputs.get("action", "plan"), pr=None)
            return bootstrap.run(cmd_args)
    
    print("ℹ️ No action for this event")
    return 0
