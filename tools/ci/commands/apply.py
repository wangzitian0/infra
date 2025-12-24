"""/apply command handler."""

from ..config import LAYERS, get_layers_by_order
from ..core.terraform import TerraformRunner, PlanResult
from ..core.github import GitHubClient
from ..core.dashboard import Dashboard


def run(args) -> int:
    """Execute apply command.

    Args:
        args.layers: List of layer names or ["all"]
        args.pr: Optional PR number for dashboard update
    """
    print("🚀 Starting apply...")

    # Determine which layers to apply
    if "all" in args.layers:
        layers = get_layers_by_order()
    else:
        layers = [LAYERS[name] for name in args.layers if name in LAYERS]

    if not layers:
        print("❌ No valid layers specified")
        return 1

    # Initialize dashboard if PR specified
    dashboard = None
    if args.pr:
        try:
            gh = GitHubClient()
            pr_info = gh.get_pr(args.pr)
            dashboard = Dashboard(
                pr_number=args.pr,
                commit_sha=pr_info.head_sha,
                github=gh,
            )
            dashboard.load()
            dashboard.update_stage("apply", "running")
            dashboard.save()
        except Exception as e:
            print(f"⚠️ Dashboard init failed: {e}")

    # Apply layers sequentially
    results = {}
    has_error = False

    for layer in layers:
        print(f"\n📦 Applying {layer.name}...")

        runner = TerraformRunner(layer)

        # Init first
        init_result = runner.init()
        if not init_result.success:
            print(f"❌ Init failed: {init_result.stderr}")
            results[layer.name] = "error"
            has_error = True
            break  # Stop on error for sequential apply

        # Check if there are changes (plan first)
        plan_result = runner.plan(detailed_exitcode=True)
        if plan_result.plan_result == PlanResult.NO_CHANGES:
            print(f"✅ {layer.name}: No changes to apply")
            results[layer.name] = "no_changes"
            continue
        elif plan_result.plan_result == PlanResult.ERROR:
            print(f"❌ {layer.name}: Plan error")
            print(plan_result.stderr)
            results[layer.name] = "error"
            has_error = True
            break

        # Apply
        apply_result = runner.apply(auto_approve=True)
        if apply_result.success:
            print(f"✅ {layer.name}: Applied successfully")
            results[layer.name] = "applied"
        else:
            print(f"❌ {layer.name}: Apply failed")
            print(apply_result.stderr)
            results[layer.name] = "error"
            has_error = True
            break

    # Update dashboard
    if dashboard:
        dashboard.update_stage("apply", "failure" if has_error else "success")
        dashboard.save()

    # Summary
    print("\n📊 Apply Summary:")
    for layer_name, status in results.items():
        icon = {"no_changes": "⏭️", "applied": "✅", "error": "❌"}.get(status, "❓")
        print(f"  {icon} {layer_name}: {status}")

    return 1 if has_error else 0
