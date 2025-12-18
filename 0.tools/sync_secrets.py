#!/usr/bin/env python3
import json
import subprocess
import os
import sys

# Import contract from loader to keep them in sync
sys.path.append(os.path.dirname(__file__))
from ci_load_secrets import OP_CONTRACT

def clean_value(val):
    if not val: return None
    s = str(val).strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'"') and s.endswith("'")):
        s = s[1:-1].strip()
    return s

def verify_rsa_key(key_content):
    try:
        proc = subprocess.run(
            ["openssl", "rsa", "-check", "-noout"],
            input=key_content.encode('utf-8'),
            capture_output=True
        )
        return proc.returncode == 0
    except:
        return False

def sync():
    print("🚀 Starting 1Password -> GitHub Sync (Standardized)...")
    
    for item_title, fields in OP_CONTRACT.items():
        print(f"\nProcessing Item: {item_title}")
        try:
            # Fetch all fields for this item at once
            res = subprocess.run(["op", "item", "get", item_title, "--vault", "my_cloud", "--format", "json"], 
                                 capture_output=True, check=True)
            data = json.loads(res.stdout)
            
            # Map field labels to values
            found_fields = {f.get("label"): f.get("value") for f in data.get("fields", []) if f.get("label") and f.get("value")}
            
            for field_name in fields:
                val = clean_value(found_fields.get(field_name))
                if not val:
                    print(f"  ⚠️  Field {field_name} not found in {item_title}")
                    continue
                
                # RSA Verification
                if "KEY" in field_name:
                    if not verify_rsa_key(val):
                        print(f"  ❌ ERROR: Key {field_name} is CORRUPTED. Skipping.")
                        continue
                    print(f"  ✅ Key {field_name} valid.")

                # Sync to GitHub
                print(f"  📦 Syncing {field_name}...")
                subprocess.run(["gh", "secret", "set", field_name], input=val.encode('utf-8'), check=True)
                
        except subprocess.CalledProcessError:
            print(f"  ❌ Failed to fetch item {item_title}. Make sure it exists in 'my_cloud' vault.")

    print("\n✨ Sync complete.")

if __name__ == "__main__":
    sync()