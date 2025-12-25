#!/usr/bin/env python3
"""Bootstrap layer management - simplified.

This script handles the Bootstrap layer (L1) which cannot use Digger
due to chicken-egg dependency (Digger needs cluster to exist).

Usage:
    python bootstrap.py plan
    python bootstrap.py apply
"""

import subprocess
import sys
import os
from pathlib import Path


def run_command(cmd: list[str], cwd: str = None) -> tuple[int, str, str]:
    """Run a command and return exit code, stdout, stderr."""
    result = subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True
    )
    return result.returncode, result.stdout, result.stderr


def run_terragrunt(action: str, cwd: str = "bootstrap") -> int:
    """Run terragrunt command for bootstrap layer.
    
    Args:
        action: 'plan' or 'apply'
        cwd: Working directory (default: bootstrap)
    
    Returns:
        Exit code (0 = success)
    """
    bootstrap_dir = Path(cwd)
    if not bootstrap_dir.exists():
        print(f"❌ Bootstrap directory not found: {bootstrap_dir}")
        return 1
    
    print(f"🚀 Running terragrunt {action} in {bootstrap_dir}")
    print(f"📁 Working directory: {bootstrap_dir.absolute()}")
    
    # Step 1: Init
    print("\n" + "="*60)
    print("Step 1: terragrunt init")
    print("="*60)
    
    exit_code, stdout, stderr = run_command(
        ["terragrunt", "init", "-no-color"],
        cwd=str(bootstrap_dir)
    )
    
    if stdout:
        print(stdout)
    if stderr:
        print(stderr, file=sys.stderr)
    
    if exit_code != 0:
        print(f"❌ Init failed with exit code {exit_code}")
        return exit_code
    
    print("✅ Init completed")
    
    # Step 2: Plan or Apply
    print("\n" + "="*60)
    print(f"Step 2: terragrunt {action}")
    print("="*60)
    
    cmd = ["terragrunt", action, "-no-color"]
    if action == "apply":
        cmd.append("-auto-approve")
    elif action == "plan":
        cmd.extend(["-out=tfplan"])
    
    exit_code, stdout, stderr = run_command(cmd, cwd=str(bootstrap_dir))
    
    if stdout:
        print(stdout)
    if stderr:
        print(stderr, file=sys.stderr)
    
    if exit_code != 0:
        print(f"❌ {action.capitalize()} failed with exit code {exit_code}")
        return exit_code
    
    print(f"✅ {action.capitalize()} completed")
    return 0


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: bootstrap.py [plan|apply]")
        print("\nExamples:")
        print("  python bootstrap.py plan   # Preview changes")
        print("  python bootstrap.py apply  # Apply changes")
        sys.exit(1)
    
    action = sys.argv[1].lower()
    if action not in ["plan", "apply"]:
        print(f"❌ Invalid action: {action}")
        print("Valid actions: plan, apply")
        sys.exit(1)
    
    print("="*60)
    print(f"🎯 Bootstrap {action.upper()}")
    print("="*60)
    print(f"Action: {action}")
    print(f"Layer: L1 (Bootstrap)")
    print(f"Managed by: Python script (not Digger)")
    print("="*60 + "\n")
    
    exit_code = run_terragrunt(action)
    
    if exit_code == 0:
        print("\n" + "="*60)
        print(f"✅ SUCCESS: Bootstrap {action} completed")
        print("="*60)
    else:
        print("\n" + "="*60)
        print(f"❌ FAILED: Bootstrap {action} failed")
        print("="*60)
    
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
