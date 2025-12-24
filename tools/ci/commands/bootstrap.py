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
    """Execute bootstrap command.
    
    Args:
        args.action: "plan" or "apply"
        args.pr: Optional PR number
    """
    action = getattr(args, "action", "plan")
    pr_number = getattr(args, "pr", None)
    
    print(f"🏗️ Bootstrap {action}...")
    
    setup_terraform_env()
    
    gh = None
    if pr_number:
        try:
            gh = GitHubClient()
        except Exception as e:
            print(f"⚠️ GitHub client init failed: {e}")
    
    working_dir = BOOTSTRAP_DIR
    
    # Init
    print("\n📦 Terraform init...")
    exit_code, output = run_terraform("init", working_dir)
    if exit_code != 0:
        print(f"❌ Init failed:\n{output}")
        if gh and pr_number:
            post_result_to_pr(gh, pr_number, False, "init")
        return 1
    
    # Plan
    print("\n📋 Terraform plan...")
    exit_code, plan_output = run_terraform("plan", working_dir)
    
    # detailed-exitcode: 0=no changes, 1=error, 2=has changes
    if exit_code == 1:
        print(f"❌ Plan failed:\n{plan_output}")
        if gh and pr_number:
            post_result_to_pr(gh, pr_number, False, "plan")
        return 1
    
    has_changes = (exit_code == 2)
    print(f"{'⚠️ Changes detected' if has_changes else '✅ No changes'}")
    
    # Post plan to PR
    if gh and pr_number:
        post_plan_to_pr(gh, pr_number, plan_output)
    
    # Apply if requested
    if action == "apply" and has_changes:
        print("\n🚀 Terraform apply...")
        exit_code, apply_output = run_terraform("apply", working_dir)
        
        if exit_code != 0:
            print(f"❌ Apply failed:\n{apply_output}")
            if gh and pr_number:
                post_result_to_pr(gh, pr_number, False, "apply")
            return 1
        
        print("✅ Apply complete")
        
        # Health check
        domain = os.environ.get("INTERNAL_DOMAIN") or os.environ.get("BASE_DOMAIN", "")
        if domain:
            if not verify_health(domain):
                if gh and pr_number:
                    post_result_to_pr(gh, pr_number, False, "health check")
                return 1
        
        if gh and pr_number:
            post_result_to_pr(gh, pr_number, True, "apply")
    
    elif action == "plan":
        if gh and pr_number:
            gh.create_comment(pr_number, "> To apply: comment `/bootstrap apply`")
    
    return 0
