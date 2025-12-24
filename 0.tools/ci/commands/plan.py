"""/plan command handler."""

import os
import sys

from ..config import LAYERS, get_layers_by_order, detect_layers_from_paths
from ..core.terraform import TerraformRunner, PlanResult
from ..core.github import GitHubClient
from ..core.dashboard import Dashboard


def run(args) -> int:
    """Execute plan command.

    Args:
        args.layers: List of layer names or ["all"]
        args.pr: Optional PR number for dashboard update
    """
    print("🔍 Starting plan...")

    # Determine which layers to plan
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
        except Exception as e:
            print(f"⚠️ Dashboard init failed: {e}")

    # Run plan for each layer
    results = {}
    has_error = False

    for layer in layers:
        print(f"\n📦 Planning {layer.name}...")
        stage_key = f"plan-{layer.name}"

        if dashboard:
            dashboard.update_stage(stage_key, "running")
            dashboard.save()

        runner = TerraformRunner(layer)

        # Init first
        init_result = runner.init()
        if not init_result.success:
            print(f"❌ Init failed: {init_result.stderr}")
            results[layer.name] = "error"
            has_error = True
            if dashboard:
                dashboard.update_stage(stage_key, "failure")
                dashboard.save()
            continue

        # Run plan
        plan_result = runner.plan(detailed_exitcode=True)

        if plan_result.plan_result == PlanResult.NO_CHANGES:
            print(f"✅ {layer.name}: No changes")
            results[layer.name] = "no_changes"
            if dashboard:
                dashboard.update_stage(stage_key, "success")
        elif plan_result.plan_result == PlanResult.HAS_CHANGES:
            print(f"⚠️ {layer.name}: Changes detected")
            results[layer.name] = "has_changes"
            if dashboard:
                dashboard.update_stage(stage_key, "success")
        else:
            print(f"❌ {layer.name}: Error")
            print(plan_result.stderr)
            results[layer.name] = "error"
            has_error = True
            if dashboard:
                dashboard.update_stage(stage_key, "failure")

        if dashboard:
            dashboard.save()

    # Summary
    print("\n📊 Plan Summary:")
    for layer_name, status in results.items():
        icon = {"no_changes": "✅", "has_changes": "⚠️", "error": "❌"}.get(
            status, "❓"
        )
        print(f"  {icon} {layer_name}: {status}")

    return 1 if has_error else 0
