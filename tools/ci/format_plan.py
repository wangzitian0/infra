#!/usr/bin/env python3
import sys
import re

def format_plan(plan_text):
    """Parse terraform plan output and return a markdown summary."""
    # Look for "Plan: X to add, Y to change, Z to destroy"
    summary_match = re.search(r"Plan: (\d+) to add, (\d+) to change, (\d+) to destroy", plan_text)
    
    if not summary_match:
        # Check for "No changes"
        if "No changes. Infrastructure is up-to-date." in plan_text:
            return "✅ **No changes.** Infrastructure is up-to-date."
        return "⚠️ Could not parse plan summary. Check logs for details."

    add, change, destroy = summary_match.groups()
    
    # Extract specific changes if possible (resource addresses)
    # Pattern: "# resource_type.name will be created"
    # Pattern: "# resource_type.name will be updated"
    # Pattern: "# resource_type.name will be destroyed"
    
    created = re.findall(r"# ([\w\.-]+) will be created", plan_text)
    updated = re.findall(r"# ([\w\.-]+) will be updated in-place", plan_text)
    destroyed = re.findall(r"# ([\w\.-]+) will be destroyed", plan_text)
    replaced = re.findall(r"# ([\w\.-]+) must be replaced", plan_text)

    summary = f"### 📊 Terraform Plan Summary\n\n"
    summary += f"| Action | Count |\n"
    summary += f"| :--- | :--- |\n"
    summary += f"| 🟢 **Add** | {add} |\n"
    summary += f"| 🟡 **Change** | {change} |\n"
    summary += f"| 🔴 **Destroy** | {destroy} |\n\n"

    if created or updated or destroyed or replaced:
        summary += "#### 📄 Change Details\n"
        if created:
            summary += "**Created:**\n" + "\n".join([f"- `+` {c}" for c in created]) + "\n"
        if updated:
            summary += "**Updated:**\n" + "\n".join([f"- `~` {u}" for u in updated]) + "\n"
        if replaced:
            summary += "**Replaced:**\n" + "\n".join([f"- `+/-` {r}" for r in replaced]) + "\n"
        if destroyed:
            summary += "**Destroyed:**\n" + "\n".join([f"- `-` {d}" for d in destroyed]) + "\n"
            
    return summary

if __name__ == "__main__":
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            print(format_plan(f.read()))
    else:
        print(format_plan(sys.stdin.read()))
