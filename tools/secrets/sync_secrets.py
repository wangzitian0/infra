#!/usr/bin/env python3
"""Sync secrets from 1Password to GitHub Actions secrets."""
import json
import subprocess
import os
import sys

sys.path.append(os.path.dirname(__file__))
from ci_load_secrets import OP_CONTRACT

# Field name mapping for SSH Key type items (1Password uses "private key" as label)
SSH_KEY_FIELD_MAP = {"private key": "VPS_SSH_KEY"}


def sync():
    print("🚀 Starting 1Password -> GitHub Sync...")
    
    for item_title, fields in OP_CONTRACT.items():
        print(f"\nProcessing: {item_title}")
        try:
            res = subprocess.run(
                ["op", "item", "get", item_title, "--vault", "my_cloud", "--format", "json"],
                capture_output=True, check=True
            )
            data = json.loads(res.stdout)
            
            # Build field map with SSH Key type normalization
            found = {}
            for f in data.get("fields", []):
                label, value = f.get("label"), f.get("value")
                if label and value:
                    found[SSH_KEY_FIELD_MAP.get(label, label)] = value
            
            for field in fields:
                val = found.get(field)
                if not val:
                    print(f"  ⚠️  {field} not found")
                    continue
                
                print(f"  📦 {field}...")
                subprocess.run(["gh", "secret", "set", field], input=val.encode(), check=True)
                
        except subprocess.CalledProcessError:
            print(f"  ❌ Failed to fetch {item_title}")

    print("\n✨ Sync complete.")


if __name__ == "__main__":
    sync()

