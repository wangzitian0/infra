#!/usr/bin/env python3
import os
import re
import sys

# Import mapping from loader (sibling directory: ../secrets)
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../secrets")))
try:
    from ci_load_secrets import MAPPING
except ImportError:
    print("::error::Could not import ci_load_secrets.py from ../secrets/")
    sys.exit(1)

def get_terraform_variables():
    """Scans all variables.tf files and extracts variable names without defaults."""
    vars_found = set()
    # Find all variables.tf files in directories starting with [1-4].
    for root, dirs, files in os.walk("."):
        if not re.match(r"./[1-4]\.", root):
            continue
        for file in files:
            if file == "variables.tf":
                path = os.path.join(root, file)
                with open(path, "r") as f:
                    content = f.read()
                    # Find all variable blocks
                    # Simplified regex to find variable "name" { ... }
                    blocks = re.findall(r'variable\s+"([^\"]+)"\s+\{[^}]+\}', content, re.DOTALL)
                    for var_name in blocks:
                        # Only check variables that DON'T have a default value
                        # This avoids false positives for optional config
                        block_content = re.search(r'variable\s+"' + var_name + r'"\s+\{([^}]+)\}', content, re.DOTALL).group(1)
                        if "default" not in block_content:
                            vars_found.add(var_name)
    return vars_found

def check_integrity():
    print("🧐 Checking IaC Variable Integrity...")
    
    tf_vars = get_terraform_variables()
    mapped_vars = {v.replace("TF_VAR_", "") for v in MAPPING.values()}
    
    # 1. TF -> Loader Check
    missing_in_loader = tf_vars - mapped_vars
    
    # Exclude common built-ins that might be passed differently
    EXCLUDED = {"kubeconfig_path", "environment"} 
    missing_in_loader = missing_in_loader - EXCLUDED

    if missing_in_loader:
        print("\n❌ INTEGRITY ERROR: Variables defined in Terraform but missing from Python Loader!")
        print("Add these to tools/secrets/ci_load_secrets.py MAPPING:")
        for v in sorted(missing_in_loader):
            print(f"  - {v}")
        return False

    # 2. Loader -> GH Check (Requires GH CLI, skip if not in CI)
    # This is handled by sync_secrets.py normally, but we can do a sanity check if needed.

    print("✅ All required Terraform variables are mapped in Python Loader.")
    return True

if __name__ == "__main__":
    if not check_integrity():
        sys.exit(1)
