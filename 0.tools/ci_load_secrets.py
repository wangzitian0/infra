#!/usr/bin/env python3
import json
import os
import sys

# ==============================================================================
# CONFIGURATION: Whitelist and Mapping
# Format: "GITHUB_SECRET_NAME": "TF_VAR_NAME"
# If TF_VAR_NAME is None, it only exports to shell env, not as TF_VAR.
# ==============================================================================
MAPPING = {
    # L1 Bootstrap: R2 Backend
    "AWS_ACCESS_KEY_ID": "TF_VAR_aws_access_key_id",
    "AWS_SECRET_ACCESS_KEY": "TF_VAR_aws_secret_access_key",
    "R2_BUCKET": "TF_VAR_r2_bucket",
    "R2_ACCOUNT_ID": "TF_VAR_r2_account_id",
    
    # L1 Bootstrap: VPS/SSH
    "VPS_HOST": "TF_VAR_vps_host",
    "VPS_USER": "TF_VAR_vps_user",
    "VPS_SSH_PORT": "TF_VAR_ssh_port",
    "VPS_SSH_KEY": "TF_VAR_ssh_private_key",
    
    # L1 Bootstrap: K3s
    "K3S_CLUSTER_NAME": "TF_VAR_cluster_name",
    "K3S_API_ENDPOINT": "TF_VAR_api_endpoint",
    "K3S_CHANNEL": "TF_VAR_k3s_channel",
    "K3S_VERSION": "TF_VAR_k3s_version",
    
    # L1 Bootstrap: Cloudflare
    "CLOUDFLARE_API_TOKEN": "TF_VAR_cloudflare_api_token",
    "CLOUDFLARE_ZONE_ID": "TF_VAR_cloudflare_zone_id",
    "BASE_DOMAIN": "TF_VAR_base_domain",
    "INTERNAL_DOMAIN": "TF_VAR_internal_domain",
    "INTERNAL_ZONE_ID": "TF_VAR_internal_zone_id",
    
    # L1 Bootstrap: Atlantis/GitHub
    "GH_PAT": "TF_VAR_github_token",
    "ATLANTIS_WEBHOOK_SECRET": "TF_VAR_atlantis_webhook_secret",
    "ATLANTIS_GH_APP_ID": "TF_VAR_github_app_id",
    "ATLANTIS_GH_APP_KEY": "TF_VAR_github_app_key",
    "ATLANTIS_WEB_PASSWORD": "TF_VAR_atlantis_web_password",
    
    # L2 Platform
    "VAULT_POSTGRES_PASSWORD": "TF_VAR_vault_postgres_password",
    "GH_OAUTH_CLIENT_ID": "TF_VAR_github_oauth_client_id",
    "GH_OAUTH_CLIENT_SECRET": "TF_VAR_github_oauth_client_secret",
    
    # L3/L4: Vault Access
    "VAULT_ROOT_TOKEN": "TF_VAR_vault_root_token",
}

# Values that should be exported directly to env for tools (not as TF_VAR)
SYSTEM_ENV_ONLY = {
    "VAULT_ROOT_TOKEN": "VAULT_TOKEN",
}

def export_to_github_env(name, value):
    """Exports a variable to GITHUB_ENV, handling multiline values."""
    github_env = os.environ.get("GITHUB_ENV")
    if not github_env:
        # Fallback to stdout for local testing
        print(f"DEBUG: {name}={value}")
        return

    with open(github_env, "a") as f:
        if "\n" in value:
            # Multiline syntax
            f.write(f"{name}<<EOF\n")
            f.write(f"{value}\n")
            f.write("EOF\n")
        else:
            f.write(f"{name}={value}\n")

def main():
    # 1. Get the JSON input from the environment variable (passed by the Action)
    raw_json = os.environ.get("INPUT_SECRETS_JSON")
    if not raw_json:
        print("::error::Missing input: secrets_json")
        sys.exit(1)

    try:
        secrets = json.loads(raw_json)
    except Exception as e:
        print(f"::error::Failed to parse secrets_json: {e}")
        sys.exit(1)

    # 2. Iterate through mapping and export
    count = 0
    missing = []
    
    # Critical secrets that MUST exist for basic operation
    REQUIRED = [
        "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "R2_BUCKET", "R2_ACCOUNT_ID",
        "VPS_HOST", "VPS_SSH_KEY", "CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ZONE_ID", 
        "BASE_DOMAIN"
    ]

    for source_key, target_var in MAPPING.items():
        val = secrets.get(source_key)
        
        if val is None:
            if source_key in REQUIRED:
                missing.append(source_key)
            continue

        # Export as TF_VAR_...
        export_to_github_env(target_var, val)
        
        # Export as original name for scripts to use
        export_to_github_env(source_key, val)
        
        # System specific mappings (e.g. VAULT_TOKEN)
        if source_key in SYSTEM_ENV_ONLY:
            export_to_github_env(SYSTEM_ENV_ONLY[source_key], val)
            
        count += 1

    if missing:
        for m in missing:
            print(f"::error::Required secret missing in 1Password/GitHub: {m}")
        sys.exit(1)

    print(f"Successfully loaded and mapped {count} secrets.")

if __name__ == "__main__":
    main()
