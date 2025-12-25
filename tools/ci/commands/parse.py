"""CI Event Parsing Command.

Parses GitHub Actions events and outputs variables for workflow routing.
Outputs are set using GITHUB_OUTPUT environment variable.
"""

import os
import json
import sys
from typing import Optional

# Re-use logic from run.py if possible, or duplicate for independence
# For now, we'll keep it self-contained to avoid circular deps if run checks parse

def set_output(key: str, value: str):
    """Set GitHub Action output."""
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a") as f:
            f.write(f"{key}={value}\n")
    else:
        print(f"::set-output name={key}::{value}")
    print(f"Output: {key}={value}")

def run(args) -> int:
    """Main execution for parse command."""
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    
    print(f"Parsing event: {event_name}")
    
    # Defaults
    mode = "skip"
    command = "unknown"
    layers = "all"
    pr_number = ""
    should_run = "false"
    
    # Load event data
    event_data = {}
    if event_path and os.path.exists(event_path):
        with open(event_path) as f:
            event_data = json.load(f)

    if event_name == "pull_request":
        # PR Event -> Auto Plan
        # Mode: digger (for plan/apply) or python (for handling)?
        # For standard Digger flow, we need 'digger'.
        # But wait, original ci.yml routed PR to 'plan' (Digger).
        mode = "digger" 
        command = "plan"
        pr_number = str(event_data.get("number", ""))
        should_run = "true"

    elif event_name == "push":
        # Push to main -> Verify
        ref = os.environ.get("GITHUB_REF", "")
        if ref == "refs/heads/main":
            mode = "post-merge"
            command = "apply"
            should_run = "true"
    
    elif event_name == "issue_comment":
        if not event_data.get("issue", {}).get("pull_request"):
            # Not a PR comment
            should_run = "false"
        else:
            body = event_data.get("comment", {}).get("body", "").strip().lower()
            pr_number = str(event_data.get("issue", {}).get("number", ""))
            
            # Routing Logic
            if "/bootstrap" in body:
                mode = "python"
                if "apply" in body:
                    command = "bootstrap-apply"
                else:
                    command = "bootstrap-plan"
                should_run = "true"
            
            elif "/plan" in body or "digger plan" in body:
                mode = "digger"
                command = "plan"
                should_run = "true"
                # TODO: Parse layers from body if needed
                
            elif "/apply" in body or "digger apply" in body:
                mode = "digger"
                command = "apply"
                should_run = "true"
                
            elif "/verify" in body:
                mode = "python"
                command = "verify"
                should_run = "true"
                
            elif "/e2e" in body:
                mode = "python"
                command = "e2e"
                should_run = "true"
            
            elif "/review" in body:
                mode = "python"
                command = "review"
                should_run = "true"

            elif "/help" in body:
                mode = "python" # Help via python script custom handler
                command = "help"
                should_run = "true"

    elif event_name == "workflow_dispatch":
        mode = "python" # Default to python for manual, unless inputs say otherwise
        # But wait, if I want to run manual digger plan?
        # Inputs: command, layers
        # If command is plan/apply -> digger? 
        # Actually in original ci.yml manually dispatching plan/apply went to Digger.
        inputs = event_data.get("inputs", {})
        inp_cmd = inputs.get("command", "")
        
        if inp_cmd in ["plan", "apply"]:
            mode = "digger"
            command = inp_cmd
            layers = inputs.get("layers", "all")
        elif inp_cmd == "bootstrap":
            mode = "python"
            command = "bootstrap-" + inputs.get("action", "plan") # bootstrap inputs usually has action
        else:
            mode = "python"
            command = inp_cmd
            
        should_run = "true"

    # Set outputs
    set_output("mode", mode)
    set_output("command", command)
    set_output("layers", layers)
    set_output("pr_number", pr_number)
    set_output("should_run", should_run)
    
    return 0
