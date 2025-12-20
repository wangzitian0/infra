#!/usr/bin/env python3
import json
import os
import sys

# ==============================================================================
# CONFIGURATION: Whitelist, Mapping, and 1Password Contract
# ==============================================================================

# Contract: Which secret lives in which 1Password item
# This is used by sync_secrets.py to maintain order.
OP_CONTRACT = {
    "Infra-VPS": ["VPS_HOST", "VPS_USER", "VPS_SSH_PORT", "VPS_SSH_KEY"],
    "Infra-R2": ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "R2_BUCKET", "R2_ACCOUNT_ID"],
    "Infra-Cloudflare": ["BASE_DOMAIN", "CLOUDFLARE_ZONE_ID", "INTERNAL_DOMAIN", "INTERNAL_ZONE_ID", "CLOUDFLARE_API_TOKEN"],
    "Infra-Atlantis": ["ATLANTIS_WEBHOOK_SECRET", "ATLANTIS_WEB_PASSWORD", "ATLANTIS_GH_APP_ID", "ATLANTIS_GH_APP_KEY"],
    "Infra-Vault": ["VAULT_ROOT_TOKEN", "VAULT_POSTGRES_PASSWORD", "VAULT_UNSEAL_KEY"],
    "Infra-OAuth": ["GH_OAUTH_CLIENT_ID", "GH_OAUTH_CLIENT_SECRET", "ENABLE_CASDOOR_OIDC", "ENABLE_PORTAL_SSO_GATE", "GH_PAT"],
}

# Mapping: GitHub Secret Name -> Terraform Variable Name
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
    "ENABLE_CASDOOR_OIDC": "TF_VAR_enable_casdoor_oidc",
    "ENABLE_PORTAL_SSO_GATE": "TF_VAR_enable_portal_sso_gate",
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

REQUIRED = [
    "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "R2_BUCKET", "R2_ACCOUNT_ID",
    "VPS_HOST", "VPS_SSH_KEY", "CLOUDFLARE_API_TOKEN", "CLOUDFLARE_ZONE_ID", 
    "BASE_DOMAIN"
]

def clean_value(val):
    if val is None: return None
    s = str(val).strip()
    if (s.startswith('"') and s.endswith('"')) or (s.startswith("'" ) and s.endswith("'")):
        s = s[1:-1].strip()
    return s

def export_to_github_env(name, value):
    github_env = os.environ.get("GITHUB_ENV")
    if not github_env: return
    with open(github_env, "a") as f:
        if "\n" in str(value):
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

    loaded_count = 0
    missing_required = []
    
    for source_key, target_var in MAPPING.items():
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
        loaded_count += 1

    internal_domain = clean_value(secrets.get("INTERNAL_DOMAIN"))
    base_domain = clean_value(secrets.get("BASE_DOMAIN"))
    domain = internal_domain or base_domain
    
    if domain:
        vault_addr = f"https://secrets.{domain}"
        export_to_github_env("TF_VAR_vault_address", vault_addr)
        export_to_github_env("VAULT_ADDR", vault_addr)
        print(f"✅ Derived VAULT_ADDR: {vault_addr}")

    if missing_required:
        for m in missing_required:
            print(f"::error::Required secret missing: {m}")
        sys.exit(1)

    print(f"✅ Successfully loaded {loaded_count} secrets.")

if __name__ == "__main__":
    main()
