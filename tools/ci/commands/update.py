"""/update command handler (Update Dashboard Status)."""

from ..core.github import GitHubClient
from ..core.dashboard import Dashboard


def run(args) -> int:
    """Update dashboard stage status.

    Args:
        args.pr: PR number
        args.stage: Stage key (e.g. 'plan', 'apply', 'e2e')
        args.status: Status (pending, running, success, failure)
        args.link: Optional link to details/logs
    """
    print(f"update: Updating dashboard stage '{args.stage}' to '{args.status}' for PR #{args.pr}")

    try:
        gh = GitHubClient()
        if not args.pr:
            print("❌ PR number required")
            return 1
            
        pr_info = gh.get_pr(args.pr)
        dashboard = Dashboard(
            pr_number=args.pr,
            commit_sha=pr_info.head_sha,
            github=gh,
        )
        
        if dashboard.load():
             # Handle aggregate 'plan' stage
             if args.stage == "plan":
                 updated = False
                 for key in dashboard.stages:
                     if key.startswith("plan-"):
                         dashboard.update_stage(key, args.status, args.link)
                         updated = True
                 if not updated:
                     print("⚠️ No plan stages found to update.")
             else:
                 dashboard.update_stage(args.stage, args.status, args.link)

             if dashboard.save():
                 print("✅ Dashboard updated.")
                 return 0
             else:
                 print("❌ Failed to save dashboard.")
                 return 1
        else:
             print("⚠️ Dashboard not found.")
             # We could ignore this error (just skip update) to avoid failing CI
             return 0 

    except Exception as e:
        print(f"❌ Error updating dashboard: {e}")
        return 1
