"""CLI entry point for CI module."""

import argparse
import sys

from .commands import plan, apply, verify, parse, init, update, check_vault, bootstrap, run


def main():
    parser = argparse.ArgumentParser(
        prog="ci",
        description="Infrastructure CI/CD Pipeline",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # run (unified entry point for GitHub Actions)
    run_parser = subparsers.add_parser("run", help="Unified entry point for CI (used by workflow)")

    # bootstrap (plan/apply bootstrap layer)
    bootstrap_parser = subparsers.add_parser("bootstrap", help="Bootstrap layer operations")
    bootstrap_parser.add_argument(
        "action",
        choices=["plan", "apply"],
        help="Action to perform",
    )
    bootstrap_parser.add_argument(
        "--pr", type=int, help="PR number for result posting"
    )

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

    # parse (internal: parse PR comment)
    parse_parser = subparsers.add_parser("parse", help="Parse PR comment")
    parse_parser.add_argument("comment", help="Comment body to parse")

    # init (dashboard initialization)
    init_parser = subparsers.add_parser("init", help="Initialize dashboard")
    init_parser.add_argument(
        "--pr", type=int, required=True, help="PR number"
    )

    # update (dashboard status update)
    update_parser = subparsers.add_parser("update", help="Update dashboard status")
    update_parser.add_argument("--pr", type=int, required=True, help="PR number")
    update_parser.add_argument("--stage", required=True, help="Stage key")
    update_parser.add_argument("--status", required=True, help="Status (success, failure, etc)")
    update_parser.add_argument("--link", help="Link to details")

    # check-vault (pre-flight check)
    check_vault_parser = subparsers.add_parser("check-vault", help="Check Vault seal status")

    args = parser.parse_args()

    # Dispatch to command handler
    handlers = {
        "run": run.run,
        "bootstrap": bootstrap.run,
        "plan": plan.run,
        "apply": apply.run,
        "verify": verify.run,
        "parse": parse.run,
        "init": init.run,
        "update": update.run,
        "check-vault": check_vault.run,
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
