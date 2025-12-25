"""/plan command handler."""

import os
import sys

from ..config import LAYERS, get_layers_by_order, detect_layers_from_paths
from ..core.terraform import TerraformRunner, PlanResult
from ..core.github import GitHubClient
from ..core.dashboard import Dashboard


def run(args) -> int:
    """Execute plan command."""
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
    gh = None
    comment_id = None
    comment_url = ""
    if args.pr:
        try:
            gh = GitHubClient()
            pr_info = gh.get_pr(args.pr)
            dashboard = Dashboard(pr_number=args.pr, commit_sha=pr_info.head_sha, github=gh)
            dashboard.load()
            
            # Create a combined Running comment for all layers being planned
            title = f"Terraform Plan ({', '.join([l.name for l in layers])})"
            comment_id, comment_url = gh.create_running_comment(args.pr, title)
        except Exception as e:
            print(f"⚠️ Dashboard init failed: {e}")

    # Run plan for each layer
    all_outputs = []
    results = {}
    has_error = False

    for layer in layers:
        print(f"\n📦 Planning {layer.name}...")
        stage_key = f"plan-{layer.name}"

        if dashboard:
            dashboard.update_stage(stage_key, "running", link=comment_url)
            dashboard.save()

        runner = TerraformRunner(layer)
        all_outputs.append(f"--- Layer: {layer.name} ---")

        # Init first
        init_result = runner.init()
        if not init_result.success:
            print(f"❌ Init failed: {init_result.stderr}")
            results[layer.name] = "error"
            all_outputs.append(f"❌ Init failed:\n{init_result.stderr}")
            has_error = True
            if dashboard:
                dashboard.update_stage(stage_key, "failure", link=comment_url)
                dashboard.save()
            continue

        # Run plan
        plan_result = runner.plan(detailed_exitcode=True)
        all_outputs.append(plan_result.stdout + plan_result.stderr)

        if plan_result.plan_result == PlanResult.NO_CHANGES:
            print(f"✅ {layer.name}: No changes")
            results[layer.name] = "no_changes"
            if dashboard:
                dashboard.update_stage(stage_key, "success", link=comment_url)
        elif plan_result.plan_result == PlanResult.HAS_CHANGES:
            print(f"⚠️ {layer.name}: Changes detected")
            results[layer.name] = "has_changes"
            if dashboard:
                dashboard.update_stage(stage_key, "success", link=comment_url)
        else:
            print(f"❌ {layer.name}: Error")
            results[layer.name] = "error"
            has_error = True
            if dashboard:
                dashboard.update_stage(stage_key, "failure", link=comment_url)

        if dashboard:
            dashboard.save()

    # Update final combined comment with all plan results
    if gh and comment_id and args.pr:
        summary_title = "Terraform Plan Results"
        full_content = "\n\n".join(all_outputs)
        gh.update_result_comment(comment_id, args.pr, summary_title, full_content, not has_error)

    # Summary
    print("\n📊 Plan Summary:")
    for layer_name, status in results.items():
        icon = {"no_changes": "✅", "has_changes": "⚠️", "error": "❌"}.get(status, "❓")
        print(f"  {icon} {layer_name}: {status}")

    return 1 if has_error else 0
