#!/usr/bin/env python3
import json
import os
import sys

# ==============================================================================
# CONFIGURATION: Whitelist, Mapping, and Defaults
# ==============================================================================
MAPPING = {
    "AWS_ACCESS_KEY_ID": "TF_VAR_aws_access_key_id",
    "AWS_SECRET_ACCESS_KEY": "TF_VAR_aws_secret_access_key",
    "R2_BUCKET": "TF_VAR_r2_bucket",
    "R2_ACCOUNT_ID": "TF_VAR_r2_account_id",
    "VPS_HOST": "TF_VAR_vps_host",
    "VPS_USER": "TF_VAR_vps_user",
    "VPS_SSH_PORT": "TF_VAR_ssh_port",
    "VPS_SSH_KEY": "TF_VAR_ssh_private_key",
    "K3S_CLUSTER_NAME": "TF_VAR_cluster_name",
    "K3S_API_ENDPOINT": "TF_VAR_api_endpoint",
    "K3S_CHANNEL": "TF_VAR_k3s_channel",
    "K3S_VERSION": "TF_VAR_k3s_version",
    "CLOUDFLARE_API_TOKEN": "TF_VAR_cloudflare_api_token",
    "CLOUDFLARE_ZONE_ID": "TF_VAR_cloudflare_zone_id",
    "BASE_DOMAIN": "TF_VAR_base_domain",
    "INTERNAL_DOMAIN": "TF_VAR_internal_domain",
    "INTERNAL_ZONE_ID": "TF_VAR_internal_zone_id",
    "GH_PAT": "TF_VAR_github_token",
    "ATLANTIS_WEBHOOK_SECRET": "TF_VAR_atlantis_webhook_secret",
    "ATLANTIS_GH_APP_ID": "TF_VAR_github_app_id",
    "ATLANTIS_GH_APP_KEY": "TF_VAR_github_app_key",
    "ATLANTIS_WEB_PASSWORD": "TF_VAR_atlantis_web_password",
    "VAULT_POSTGRES_PASSWORD": "TF_VAR_vault_postgres_password",
    "GH_OAUTH_CLIENT_ID": "TF_VAR_github_oauth_client_id",
    "GH_OAUTH_CLIENT_SECRET": "TF_VAR_github_oauth_client_secret",
    "VAULT_ROOT_TOKEN": "TF_VAR_vault_root_token",
}

DEFAULTS = {
    "VPS_USER": "root",
    "VPS_SSH_PORT": "22",
    "K3S_CLUSTER_NAME": "truealpha-k3s",
    "K3S_CHANNEL": "stable",
}

SYSTEM_ENV_ONLY = {
    "VAULT_ROOT_TOKEN": "VAULT_TOKEN",
}

def clean_value(val):
    """Cleans secret value: strips whitespace and surrounding quotes."""
    if val is None: return None
    s = str(val).strip()
    # Remove surrounding quotes if they exist (common issue from 1P exports)
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'" ) and s.endswith("'" )):
        s = s[1:-1].strip()
    return s

def export_to_github_env(name, value):
    github_env = os.environ.get("GITHUB_ENV")
    if not github_env:
        return
    with open(github_env, "a") as f:
        # Using a unique EOF marker to prevent collisions
        if "\n" in value:
            f.write(f"{name}<<GITHUB_VAR_EOF\n{value}\nGITHUB_VAR_EOF\n")
        else:
            f.write(f"{name}={value}\n")

def main():
    raw_json = os.environ.get("INPUT_SECRETS_JSON")
    if not raw_json:
        print("::error::Missing input: secrets_json")
        sys.exit(1)

    try:
        secrets = json.loads(raw_json)
    except Exception as e:
        print(f"::error::Failed to parse secrets_json: {e}")
        sys.exit(1)

    count = 0
    missing_required = []
    REQUIRED = [
        "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "R2_BUCKET", "R2_ACCOUNT_ID",
        "VPS_HOST", "VPS_SSH_KEY", "CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ZONE_ID", 
        "BASE_DOMAIN"
    ]

    for source_key, target_var in MAPPING.items():
        # Clean both the input and the default
        val = clean_value(secrets.get(source_key))
        if not val:
            val = clean_value(DEFAULTS.get(source_key))
        
        if val is None:
            if source_key in REQUIRED:
                missing_required.append(source_key)
            continue

        export_to_github_env(target_var, val)
        export_to_github_env(source_key, val)
        if source_key in SYSTEM_ENV_ONLY:
            export_to_github_env(SYSTEM_ENV_ONLY[source_key], val)
        count += 1

    if missing_required:
        for m in missing_required:
            print(f"::error::Required secret missing: {m}")
        sys.exit(1)

    print(f"Successfully loaded {count} secrets.")

if __name__ == "__main__":
    main()
