#!/usr/bin/env python3
"""Sync secrets from 1Password to GitHub Actions secrets."""
import json
import subprocess
import os
import sys

sys.path.append(os.path.dirname(__file__))
from ci_load_secrets import OP_CONTRACT

# Field name mapping (1Password label -> GitHub Secret name)
FIELD_MAP = {
    "private key": "VPS_SSH_KEY",  # SSH Key type
}

# File attachment mapping (GitHub Secret name -> file path in 1Password item)
FILE_MAP = {
    "INFRA_FLASH_APP_KEY": ".zitian.github.pem",  # PEM file attachment
}


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
            
            # Build field map with normalization
            found = {}
            for f in data.get("fields", []):
                label, value = f.get("label"), f.get("value")
                if label and value:
                    found[FIELD_MAP.get(label, label)] = value
            
            for field in fields:
                # Check if this field should be read from a file attachment
                if field in FILE_MAP:
                    file_name = FILE_MAP[field]
                    try:
                        res = subprocess.run(
                            ["op", "read", f"op://my_cloud/{item_title}/{file_name}"],
                            capture_output=True, check=True
                        )
                        val = res.stdout.decode()
                    except subprocess.CalledProcessError:
                        print(f"  ⚠️  {field} (file: {file_name}) not found")
                        continue
                else:
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
