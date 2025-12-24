"""Health check command handler."""

import subprocess
import sys


def run(args) -> int:
    """Run service health checks.
    
    Args:
        args.pr: Optional PR number for result posting
    
    Returns:
        0 on success, 1 on failure.
    """
    print("🏥 Running health checks...")
    
    services = [
        ("vault", "platform", "vault-0"),
        ("casdoor", "platform", "casdoor"),
        ("platform-pg", "platform", "platform-pg-1"),
    ]
    
    all_healthy = True
    results = []
    
    for name, namespace, pod_prefix in services:
        try:
            result = subprocess.run(
                ["kubectl", "get", "pods", "-n", namespace, "-l", f"app.kubernetes.io/name={name}", "-o", "jsonpath={.items[0].status.phase}"],
                capture_output=True,
                text=True,
                timeout=30
            )
            status = result.stdout.strip()
            if status == "Running":
                results.append(f"✅ {name}: Running")
            else:
                results.append(f"❌ {name}: {status or 'Not Found'}")
                all_healthy = False
        except subprocess.TimeoutExpired:
            results.append(f"⏱️ {name}: Timeout")
            all_healthy = False
        except Exception as e:
            results.append(f"❌ {name}: Error - {e}")
            all_healthy = False
    
    print("\n".join(results))
    
    if all_healthy:
        print("\n🎉 All services healthy!")
        return 0
    else:
        print("\n⚠️ Some services are unhealthy.")
        return 1
