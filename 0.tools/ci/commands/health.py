"""/health command handler."""

import os
import subprocess
from dataclasses import dataclass

from ..core.github import GitHubClient
from ..core.dashboard import Dashboard


@dataclass
class ServiceCheck:
    """Service health check result."""

    name: str
    url: str
    status_code: int
    healthy: bool


# Services to check
SERVICES = [
    ("K3s API", "i-k3s:6443"),
    ("Vault", "i-secrets"),
    ("K8s Dashboard", "i-kdashboard"),
    ("Kubero UI", "i-kcloud"),
    ("SigNoz", "i-signoz"),
    ("Portal", "@"),
]


def check_service(name: str, subdomain: str, base_domain: str) -> ServiceCheck:
    """Check a single service health."""
    if subdomain == "@":
        url = f"https://{base_domain}"
    elif ":" in subdomain:
        host, port = subdomain.split(":")
        url = f"https://{host}.{base_domain}:{port}"
    else:
        url = f"https://{subdomain}.{base_domain}"

    try:
        result = subprocess.run(
            [
                "curl",
                "-s",
                "-o",
                "/dev/null",
                "-w",
                "%{http_code}",
                "--connect-timeout",
                "5",
                url,
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
        code = int(result.stdout.strip())
        healthy = code in (200, 401, 403)  # 401/403 = auth required but reachable
        return ServiceCheck(name=name, url=url, status_code=code, healthy=healthy)
    except Exception:
        return ServiceCheck(name=name, url=url, status_code=0, healthy=False)


def run(args) -> int:
    """Execute health check command."""
    print("🏥 Running health checks...")

    base_domain = os.environ.get("BASE_DOMAIN", "")
    if not base_domain:
        print("❌ BASE_DOMAIN not set")
        return 1

    results = []
    for name, subdomain in SERVICES:
        print(f"  Checking {name}...", end=" ", flush=True)
        result = check_service(name, subdomain, base_domain)
        results.append(result)
        icon = "✅" if result.healthy else "❌"
        print(f"{icon} {result.status_code}")

    # Update dashboard if PR specified
    if args.pr:
        try:
            gh = GitHubClient()
            body = _build_table(results)
            gh.create_comment(args.pr, body)
            print(f"\n📝 Posted results to PR #{args.pr}")
        except Exception as e:
            print(f"\n⚠️ Failed to post results: {e}")

    # Summary
    healthy_count = sum(1 for r in results if r.healthy)
    print(f"\n📊 Health: {healthy_count}/{len(results)} services OK")

    return 0 if healthy_count == len(results) else 1


def _build_table(results: list[ServiceCheck]) -> str:
    """Build markdown table for results."""
    lines = [
        "### 🏥 Health Check Results",
        "",
        "| Service | URL | Status |",
        "|:---|:---|:---:|",
    ]

    for r in results:
        icon = "✅" if r.healthy else "❌"
        lines.append(f"| {r.name} | `{r.url}` | {icon} {r.status_code} |")

    return "\n".join(lines)
