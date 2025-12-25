"""/apply command handler."""

from ..config import LAYERS, get_layers_by_order
from ..core.terraform import TerraformRunner, PlanResult
from ..core.github import GitHubClient
from ..core.dashboard import Dashboard


def run(args) -> int:
    """Execute apply command."""
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
    gh = None
    comment_id = None
    comment_url = ""
    if args.pr:
        try:
            gh = GitHubClient()
            pr_info = gh.get_pr(args.pr)
            dashboard = Dashboard(pr_number=args.pr, commit_sha=pr_info.head_sha, github=gh)
            dashboard.load()
            
            # Create a combined Running comment for all layers being applied
            title = f"Terraform Apply ({', '.join([l.name for l in layers])})"
            comment_id, comment_url = gh.create_running_comment(args.pr, title)
            
            dashboard.update_stage("apply", "running", link=comment_url)
            dashboard.save()
        except Exception as e:
            print(f"⚠️ Dashboard init failed: {e}")

    # Apply layers sequentially
    all_outputs = []
    results = {}
    has_error = False

    for layer in layers:
        print(f"\n📦 Applying {layer.name}...")
        all_outputs.append(f"--- Layer: {layer.name} ---")

        runner = TerraformRunner(layer)

        # Init first
        init_result = runner.init()
        if not init_result.success:
            print(f"❌ Init failed: {init_result.stderr}")
            results[layer.name] = "error"
            all_outputs.append(f"❌ Init failed:\n{init_result.stderr}")
            has_error = True
            break  # Stop on error for sequential apply

        # Check if there are changes (plan first)
        plan_result = runner.plan(detailed_exitcode=True)
        if plan_result.plan_result == PlanResult.NO_CHANGES:
            print(f"✅ {layer.name}: No changes to apply")
            results[layer.name] = "no_changes"
            all_outputs.append("✅ No changes to apply")
            continue
        elif plan_result.plan_result == PlanResult.ERROR:
            print(f"❌ {layer.name}: Plan error")
            results[layer.name] = "error"
            all_outputs.append(f"❌ Plan error:\n{plan_result.stderr}")
            has_error = True
            break

        # Apply
        apply_result = runner.apply(auto_approve=True)
        all_outputs.append(apply_result.stdout + apply_result.stderr)
        
        if apply_result.success:
            print(f"✅ {layer.name}: Applied successfully")
            results[layer.name] = "applied"
        else:
            print(f"❌ {layer.name}: Apply failed")
            results[layer.name] = "error"
            has_error = True
            break

    # Update final combined comment with all results
    if gh and comment_id and args.pr:
        summary_title = "Terraform Apply Results"
        full_content = "\n\n".join(all_outputs)
        gh.update_result_comment(comment_id, args.pr, summary_title, full_content, not has_error)

    # Update dashboard
    if dashboard:
        dashboard.update_stage("apply", "failure" if has_error else "success", link=comment_url)
        dashboard.save()

    # Summary
    print("\n📊 Apply Summary:")
    for layer_name, status in results.items():
        icon = {"no_changes": "⏭️", "applied": "✅", "error": "❌"}.get(status, "❓")
        print(f"  {icon} {layer_name}: {status}")

    return 1 if has_error else 0
