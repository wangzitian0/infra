"""Bootstrap layer command handler.

Handles /bootstrap plan and /bootstrap apply commands.
Bootstrap is special because it contains the Digger orchestrator itself,
so it must use native Terraform directly.
"""

import os
import subprocess
import sys
from typing import Optional

from ..core.github import GitHubClient


BOOTSTRAP_DIR = "bootstrap"
TF_STATE_KEY = "k3s/terraform.tfstate"


def setup_terraform_env():
    """Setup Terraform environment from GitHub Secrets."""
    # These are expected to be set by the workflow
    required_vars = [
        "TF_VAR_vps_host",
        "TF_VAR_ssh_private_key",
        "TF_VAR_cloudflare_api_token",
    ]
    
    missing = [v for v in required_vars if not os.environ.get(v)]
    if missing:
        print(f"⚠️ Missing env vars: {missing}")


def run_terraform(action: str, working_dir: str) -> tuple[int, str]:
    """Run terraform command.
    
    Returns:
        (exit_code, output)
    """
    cmd = ["terraform", action]
    
    if action == "plan":
        cmd.extend(["-input=false", "-no-color", "-detailed-exitcode", "-out=tfplan"])
    elif action == "apply":
        cmd.extend(["-input=false", "-auto-approve", "tfplan"])
    elif action == "init":
        cmd.extend(["-input=false", "-no-color"])
    
    print(f"🔧 Running: {' '.join(cmd)}")
    
    result = subprocess.run(
        cmd,
        cwd=working_dir,
        capture_output=True,
        text=True,
    )
    
    output = result.stdout + result.stderr
    return (result.returncode, output)


def post_plan_to_pr(gh: GitHubClient, pr_number: int, plan_output: str):
    """Post plan output to PR as comment."""
    # Truncate if too long
    if len(plan_output) > 60000:
        plan_output = plan_output[:60000] + "\n...(truncated)"
    
    body = f"""### 🔧 Bootstrap Terraform Plan

<details>
<summary>点击展开 Plan 输出</summary>

```hcl
{plan_output}
```
</details>
"""
    gh.create_comment(pr_number, body)


def post_result_to_pr(gh: GitHubClient, pr_number: int, success: bool, action: str):
    """Post result to PR."""
    if success:
        body = f"### ✅ Bootstrap {action.title()} Complete\n\nTerraform {action} finished successfully."
    else:
        run_url = f"{os.environ.get('GITHUB_SERVER_URL', '')}/{os.environ.get('GITHUB_REPOSITORY', '')}/actions/runs/{os.environ.get('GITHUB_RUN_ID', '')}"
        body = f"### ❌ Bootstrap {action.title()} Failed\n\nCheck the [Workflow Run]({run_url}) for details."
    
    gh.create_comment(pr_number, body)


def verify_health(domain: str) -> bool:
    """Verify Digger health endpoint."""
    import urllib.request
    import urllib.error
    
    url = f"https://digger.{domain}/health"
    print(f"🔎 Checking health: {url}")
    
    for i in range(15):
        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                if response.status == 200:
                    print("✅ Digger health OK")
                    return True
        except (urllib.error.URLError, urllib.error.HTTPError) as e:
            print(f"  Attempt {i+1}/15: {e}")
        
        import time
        time.sleep(4)
    
    print("❌ Health check failed")
    return False



def run(args) -> int:
    """Execute bootstrap command."""
    action = getattr(args, "action", "plan")
    pr_number = getattr(args, "pr", None)
    
    print(f"🏗️ Bootstrap {action}...")
    setup_terraform_env()
    
    gh = None
    dashboard = None
    comment_id = None
    comment_url = ""
    
    if pr_number:
        try:
            gh = GitHubClient()
            from ..core.dashboard import Dashboard
            dashboard = Dashboard(pr_number=pr_number, commit_sha=gh.get_pr(pr_number).head_sha, github=gh)
            dashboard.load()
        except Exception as e:
            print(f"⚠️ Dashboard init failed: {e}")

    working_dir = BOOTSTRAP_DIR
    stage_key = "apply" if action == "apply" else "plan-bootstrap"
    title_action = "Bootstrap Apply" if action == "apply" else "Bootstrap Plan"

    # 1. Create Running Comment & Update Dashboard
    if dashboard and gh:
        try:
            comment_id, comment_url = gh.create_running_comment(pr_number, f"{title_action} Running...")
            dashboard.update_stage(stage_key, "running", link=comment_url)
            dashboard.save()
        except Exception as e:
            print(f"⚠️ Failed to create starting comment: {e}")

    # Init
    print("\n📦 Terraform init...")
    exit_code, output = run_terraform("init", working_dir)
    if exit_code != 0:
        print(f"❌ Init failed:\n{output}")
        if dashboard and gh and comment_id:
            gh.update_result_comment(comment_id, pr_number, f"{title_action} Init Failed", output, False)
            dashboard.update_stage(stage_key, "failure", link=comment_url)
            dashboard.save()
        return 1
    
    # Plan
    print("\n📋 Terraform plan...")
    exit_code, plan_output = run_terraform("plan", working_dir)
    has_changes = (exit_code == 2)
    
    if exit_code == 1:
        print(f"❌ Plan failed:\n{plan_output}")
        if dashboard and gh and comment_id:
            gh.update_result_comment(comment_id, pr_number, f"{title_action} Failed", plan_output, False)
            dashboard.update_stage(stage_key, "failure", link=comment_url)
            dashboard.save()
        return 1
    
    # Success Plan
    if dashboard and gh and comment_id:
        # For Plan: Log is the output
        # For Apply: We haven't run apply yet if this is just plan
        if action == "plan":
            title = f"{title_action} (Changes)" if has_changes else f"{title_action} (No Changes)"
            gh.update_result_comment(comment_id, pr_number, title, plan_output, True)
            dashboard.update_stage(stage_key, "success", link=comment_url)
            dashboard.save()
            
            # Hint for apply
            if has_changes:
                gh.create_comment(pr_number, "> **Next**: Run `/bootstrap apply` to deploy.")

    # Apply if requested
    if action == "apply" and has_changes:
        # We reused the comment for Plan phase (if any), but wait.
        # If action is apply, we skipped the "Plan" stage update in Dashboard?
        # Actually bootstrap run does Init -> Plan -> Apply.
        # If we are in "Apply" mode, we usually want to show Apply output.
        # But we just ran Plan.
        # Let's assume for Apply mode, we update the SAME comment to show progress?
        # Or maybe we just append?
        # For simplicity: If Apply mode, we overwrite the Plan output with Apply output 
        # OR we should have separate stages. 
        # But here we have one 'comment_id'.
        # Let's keep it simple: If Apply, we update the comment again with Apply output.
        
        print("\n🚀 Terraform apply...")
        # Update comment to say "Applying..."
        if dashboard and gh and comment_id:
             try:
                 gh.update_comment(comment_id, f"### 🔄 {title_action} Applying...\nRunning terraform apply...")
             except: pass

        exit_code, apply_output = run_terraform("apply", working_dir)
        
        if exit_code != 0:
            print(f"❌ Apply failed:\n{apply_output}")
            if dashboard and gh and comment_id:
                gh.update_result_comment(comment_id, pr_number, f"{title_action} Failed", apply_output, False)
                dashboard.update_stage(stage_key, "failure", link=comment_url)
                dashboard.save()
            return 1
        
        print("✅ Apply complete")
        if dashboard and gh and comment_id:
            gh.update_result_comment(comment_id, pr_number, f"{title_action} Complete", apply_output, True)
            dashboard.update_stage(stage_key, "success", link=comment_url)
            dashboard.save()
            
    return 0
            
    return 0
