"""Vault seal status check command."""

import sys
import subprocess
import json


def print_error(msg: str):
    print(f"❌ {msg}", file=sys.stderr)


def print_info(msg: str):
    print(f"ℹ️  {msg}")


def print_warning(msg: str):
    print(f"⚠️  {msg}")


def run(args=None) -> int:
    """Check if Vault is sealed.
    
    Returns:
        0 if Vault is unsealed (or not deployed yet).
        1 if Vault is sealed (blocking CI).
    """
    print_info("🔒 Checking Vault status...")

    try:
        # Check if Vault pod exists first
        # We use kubectl exec to check status locally on the pod to bypass auth/network complexities
        check_pod = subprocess.run(
            ["kubectl", "get", "pod", "vault-0", "-n", "platform"],
            capture_output=True,
            text=True
        )
        
        if check_pod.returncode != 0:
            print_warning("Vault pod not found. Assuming first deployment (Safe to proceed).")
            return 0

        # Get Vault Status
        result = subprocess.run(
            ["kubectl", "exec", "vault-0", "-n", "platform", "--", "vault", "status", "-format=json"],
            capture_output=True,
            text=True
        )
        
        # 'vault status' returns exit code 2 when sealed, 0 when unsealed
        # checking stdout is safer
        output = result.stdout.strip()
        
        if not output:
             # Fallback if json fails (maybe vault binary issue or connection refused)
             if "connection refused" in result.stderr:
                 print_error("Vault connection refused. Service might be down.")
                 return 1
             print_warning("Could not determine Vault status. Proceeding with caution.")
             return 0

        try:
            status = json.loads(output)
            if status.get("sealed") is True:
                print_error("=" * 40)
                print_error("⛔ CRITICAL: VAULT IS SEALED ⛔")
                print_error("-" * 40)
                print_error("CI cannot proceed because secrets cannot be injected.")
                print_error("👉 ACTION REQUIRED: Unseal Vault manually.")
                print_error("   kubectl exec -it vault-0 -n platform -- vault operator unseal <KEY>")
                print_error("-" * 40)
                return 1
            else:
                print_info("✅ Vault is Unsealed and Ready.")
                return 0
                
        except json.JSONDecodeError:
            print_warning(f"Failed to parse Vault status: {output}")
            return 0

    except FileNotFoundError:
        print_error("kubectl command not found.")
        return 1
    except Exception as e:
        print_error(f"Vault check failed: {e}")
        return 1
