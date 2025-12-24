"""CLI entry point for CI module."""

import argparse
import sys

from .commands import plan, apply, verify, health, parse


def main():
    parser = argparse.ArgumentParser(
        prog="ci",
        description="Infrastructure CI/CD Pipeline",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # /plan
    plan_parser = subparsers.add_parser("plan", help="Run terraform plan")
    plan_parser.add_argument(
        "layers",
        nargs="*",
        default=["all"],
        help="Layers to plan (default: all)",
    )
    plan_parser.add_argument(
        "--pr", type=int, help="PR number for dashboard update"
    )

    # /apply
    apply_parser = subparsers.add_parser("apply", help="Run terraform apply")
    apply_parser.add_argument(
        "layers",
        nargs="*",
        default=["all"],
        help="Layers to apply (default: all)",
    )
    apply_parser.add_argument(
        "--pr", type=int, help="PR number for dashboard update"
    )

    # /verify (post-merge drift scan)
    verify_parser = subparsers.add_parser("verify", help="Drift scan all layers")
    verify_parser.add_argument(
        "--apply", action="store_true", help="Apply if drift detected"
    )
    verify_parser.add_argument(
        "--pr", type=int, help="Merged PR number for result posting"
    )

    # /health
    health_parser = subparsers.add_parser("health", help="Service health check")
    health_parser.add_argument(
        "--pr", type=int, help="PR number for dashboard update"
    )

    # parse (internal: parse PR comment)
    parse_parser = subparsers.add_parser("parse", help="Parse PR comment")
    parse_parser.add_argument("comment", help="Comment body to parse")

    args = parser.parse_args()

    # Dispatch to command handler
    handlers = {
        "plan": plan.run,
        "apply": apply.run,
        "verify": verify.run,
        "health": health.run,
        "parse": parse.run,
    }

    handler = handlers.get(args.command)
    if handler:
        exit_code = handler(args)
        sys.exit(exit_code or 0)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
