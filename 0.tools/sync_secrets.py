#!/usr/bin/env python3
import json
import subprocess
import os
import sys

# Mapping CI keys to 1Password Field Labels
FIELD_MAP = {
    "AWS_ACCESS_KEY_ID": "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY": "AWS_SECRET_ACCESS_KEY",
    "R2_BUCKET": "R2_BUCKET",
    "R2_ACCOUNT_ID": "R2_ACCOUNT_ID",
    "VPS_HOST": "VPS_HOST",
    "VPS_SSH_KEY": "VPS_SSH_KEY",
    "CLOUDFLARE_API_TOKEN": "CLOUDFLARE_API_TOKEN",
    "CLOUDFLARE_ZONE_ID": "CLOUDFLARE_ZONE_ID",
    "BASE_DOMAIN": "BASE_DOMAIN",
    "INTERNAL_DOMAIN": "INTERNAL_DOMAIN",
    "INTERNAL_ZONE_ID": "INTERNAL_ZONE_ID",
    "ATLANTIS_WEBHOOK_SECRET": "ATLANTIS_WEBHOOK_SECRET",
    "ATLANTIS_WEB_PASSWORD": "ATLANTIS_WEB_PASSWORD",
    "ATLANTIS_GH_APP_ID": "ATLANTIS_GH_APP_ID",
    "ATLANTIS_GH_APP_KEY": "ATLANTIS_GH_APP_KEY",
    "GH_OAUTH_CLIENT_ID": "GH_OAUTH_CLIENT_ID",
    "GH_OAUTH_CLIENT_SECRET": "GH_OAUTH_CLIENT_SECRET",
    "VAULT_POSTGRES_PASSWORD": "VAULT_POSTGRES_PASSWORD",
    "VAULT_ROOT_TOKEN": "VAULT_ROOT_TOKEN",
}

def clean_value(val):
    if not val: return None
    s = str(val).strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'"') and s.endswith("'")):
        s = s[1:-1].strip()
    return s

def verify_rsa_key(key_content):
    """Run openssl to verify RSA key structure."""
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
    print("🚀 Starting 1Password -> GitHub Sync with Left-Shift Validation...")
    
    # 1. Fetch from 1P
    items = ["VPS SSH", "R2 Backend (AWS)", "Cloudflare API", "Atlantis", 
             "PostgreSQL (Platform)", "GitHub OAuth", "Vault (zitian.party)"]
    
    all_fields = {}
    for item in items:
        try:
            res = subprocess.run(["op", "item", "get", item, "--vault", "my_cloud", "--format", "json"], 
                                 capture_output=True, check=True)
            data = json.loads(res.stdout)
            for f in data.get("fields", []):
                if f.get("label") and f.get("value"):
                    all_fields[f["label"]] = f["value"]
        except:
            print(f"⚠️  Skipping item: {item} (not found or error)")

    # 2. Validate and Set
    for target, source in FIELD_MAP.items():
        val = clean_value(all_fields.get(source))
        if not val:
            continue
            
        # RSA Verification
        if "KEY" in target:
            if not verify_rsa_key(val):
                print(f"❌ ERROR: Key {target} is CORRUPTED. Sync aborted for this key.")
                continue
            print(f"✅ Key {target} passed OpenSSL check.")

        # Set Secret
        print(f"📦 Syncing {target}...")
        subprocess.run(["gh", "secret", "set", target], input=val.encode('utf-8'), check=True)

    print("\n✨ Sync complete. Documentation and GitHub are aligned.")

if __name__ == "__main__":
    sync()
