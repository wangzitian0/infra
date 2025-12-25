#!/usr/bin/env python3
"""Sync secrets from 1Password to GitHub Actions secrets."""
import argparse
import json
import os
import subprocess
import sys

sys.path.append(os.path.dirname(__file__))
from ci_load_secrets import OP_CONTRACT, MAPPING, DEFAULTS, REQUIRED, clean_value

# Field name mapping (1Password label -> GitHub Secret name)
FIELD_MAP = {
    "private key": "VPS_SSH_KEY",  # SSH Key type
}

# File attachment mapping (GitHub Secret name -> file path in 1Password item)
FILE_MAP = {
    "INFRA_FLASH_APP_KEY": ".zitian.github.pem",  # PEM file attachment
}


def tfvar_name(tf_var: str) -> str:
    prefix = "TF_VAR_"
    if tf_var.startswith(prefix):
        return tf_var[len(prefix):]
    return tf_var


def format_hcl_string(value: str) -> str:
    return json.dumps(value)


def read_op_item(item_title: str) -> dict:
    res = subprocess.run(
        ["op", "item", "get", item_title, "--vault", "my_cloud", "--format", "json"],
        capture_output=True, check=True
    )
    data = json.loads(res.stdout)

    found = {}
    for f in data.get("fields", []):
        label, value = f.get("label"), f.get("value")
        if label and value:
            found[FIELD_MAP.get(label, label)] = value
    return found


def collect_secrets() -> tuple[dict, list, list]:
    secrets = {}
    ordered_keys = []
    missing_required = set(REQUIRED)

    for item_title, fields in OP_CONTRACT.items():
        print(f"\nProcessing: {item_title}")
        try:
            found = read_op_item(item_title)
        except subprocess.CalledProcessError:
            print(f"  ❌ Failed to fetch {item_title}")
            continue

        for field in fields:
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

            val = clean_value(val)
            if val is None:
                print(f"  ⚠️  {field} is empty")
                continue

            secrets[field] = val
            ordered_keys.append(field)
            missing_required.discard(field)

    for key in list(missing_required):
        if clean_value(DEFAULTS.get(key)) is not None:
            missing_required.discard(key)

    return secrets, ordered_keys, sorted(missing_required)


def sync_to_github(secrets: dict, ordered_keys: list):
    for field in ordered_keys:
        val = secrets.get(field)
        if val is None:
            continue
        print(f"  📦 {field}...")
        subprocess.run(["gh", "secret", "set", field], input=val.encode(), check=True)

def write_tfvars(secrets: dict, tfvars_path: str, tfvars_example_path: str, write_tfvars_file: bool, write_example_file: bool):
    tfvars = {}

    for source_key, target_var in MAPPING.items():
        val = secrets.get(source_key)
        if val is None:
            val = clean_value(DEFAULTS.get(source_key))
        if val is None:
            continue
        tfvars[tfvar_name(target_var)] = val

    internal_domain = clean_value(secrets.get("INTERNAL_DOMAIN"))
    base_domain = clean_value(secrets.get("BASE_DOMAIN"))
    domain = internal_domain or base_domain
    if domain:
        tfvars["vault_address"] = f"https://secrets.{domain}"

    if write_tfvars_file:
        os.makedirs(os.path.dirname(tfvars_path), exist_ok=True)
        with open(tfvars_path, "w") as f:
            f.write("# Auto-generated from 1Password. Do not commit.\n")
            for key in sorted(tfvars.keys()):
                f.write(f"{key} = {format_hcl_string(tfvars[key])}\n")
        print(f"\n📝 Wrote tfvars: {tfvars_path}")

    if write_example_file:
        os.makedirs(os.path.dirname(tfvars_example_path), exist_ok=True)
        with open(tfvars_example_path, "w") as f:
            f.write("# Auto-generated keys for local Terraform. Safe to commit.\n")
            for key in sorted(tfvars.keys()):
                f.write(f'{key} = ""\n')
        print(f"📝 Wrote tfvars example: {tfvars_example_path}")


def sync(args):
    print("🚀 Starting 1Password sync...")

    secrets, ordered_keys, missing_required = collect_secrets()

    if missing_required:
        print(f"\n❌ Missing required secrets in 1Password: {missing_required}")
        sys.exit(1)

    if args.set_github:
        print("\n📤 Writing GitHub Secrets...")
        sync_to_github(secrets, ordered_keys)

    if args.write_tfvars or args.write_tfvars_example:
        write_tfvars(
            secrets,
            args.tfvars_path,
            args.tfvars_example_path,
            args.write_tfvars,
            args.write_tfvars_example,
        )

    print("\n✨ Sync complete.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Sync secrets from 1Password.")
    parser.add_argument(
        "--no-gh",
        dest="set_github",
        action="store_false",
        help="Skip writing GitHub Secrets."
    )
    parser.add_argument(
        "--write-tfvars",
        action="store_true",
        help="Write local tfvars file."
    )
    parser.add_argument(
        "--write-tfvars-example",
        action="store_true",
        help="Write tfvars.example file."
    )
    parser.add_argument(
        "--tfvars-path",
        default="bootstrap/local.tfvars",
        help="Path to write local tfvars (default: bootstrap/local.tfvars)."
    )
    parser.add_argument(
        "--tfvars-example-path",
        default="bootstrap/local.tfvars.example",
        help="Path to write tfvars example (default: bootstrap/local.tfvars.example)."
    )
    parser.add_argument(
        "--no-prompt",
        dest="prompt",
        action="store_false",
        help="Disable interactive target prompt."
    )
    parser.set_defaults(set_github=True, prompt=True)

    args = parser.parse_args()

    if args.prompt:
        print("Select sync targets (GitHub Secrets / tfvars.example / tfvars).")
        choice = input("Enter 3 digits (e.g., 010): ").strip()
        if not (len(choice) == 3 and set(choice) <= {"0", "1"}):
            print("❌ Invalid selection. Use 3 digits like 010.")
            sys.exit(1)
        args.set_github = choice[0] == "1"
        args.write_tfvars_example = choice[1] == "1"
        args.write_tfvars = choice[2] == "1"

    sync(args)
