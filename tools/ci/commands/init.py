"""/init command handler (Dashboard initialization)."""

from ..core.github import GitHubClient
from ..core.dashboard import Dashboard


def run(args) -> int:
    """Initialize dashboard on PR.

    Args:
        args.pr: PR number
    """
    print(f"init: Initializing dashboard for PR #{args.pr}")

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
        
        # Check if already exists? load() checks for existing marker.
        # But for init, we might want to force create or just ensure it exists.
        loaded = dashboard.load()
        if loaded:
             print("✅ Dashboard already exists.")
             # Update it? Or leave it?
             # For init job, we usually just want to ensure it's there.
             return 0

        # Save new dashboard
        if dashboard.save():
            print("✅ Dashboard created.")
            return 0
        else:
            print("❌ Failed to create dashboard.")
            return 1

    except Exception as e:
        print(f"❌ Error initializing dashboard: {e}")
        return 1
