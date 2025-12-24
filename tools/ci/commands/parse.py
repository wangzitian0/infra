"""Parse slash commands from PR comments."""

import re
from dataclasses import dataclass
from typing import Literal

CommandType = Literal["plan", "apply", "health", "e2e", "review", "help", "unknown"]

# Compatibility aliases for old commands
ALIASES = {
    "infra dig": "/health",
    "infra e2e": "/e2e",
    "@claude": "/review",
    "infra help": "/help",
}


@dataclass
class ParsedCommand:
    """Parsed command from PR comment."""

    command: CommandType
    layers: list[str]
    args: list[str]
    raw: str


def normalize_comment(comment: str) -> str:
    """Normalize comment by applying aliases."""
    normalized = comment.strip().lower()
    for old, new in ALIASES.items():
        if normalized.startswith(old.lower()):
            normalized = new + normalized[len(old) :]
            break
    return normalized


def parse_command(comment: str) -> ParsedCommand | None:
    """Parse a slash command from comment body.

    Supported formats:
    - /plan
    - /plan bootstrap
    - /plan bootstrap platform
    - /apply
    - /apply bootstrap
    - /health
    - /e2e smoke
    - /review
    - /help
    """
    normalized = normalize_comment(comment)

    # Check if it starts with /
    if not normalized.startswith("/"):
        return None

    # Split into parts
    parts = normalized.split()
    if not parts:
        return None

    cmd = parts[0][1:]  # Remove leading /
    args = parts[1:]

    # Map command
    cmd_map = {
        "plan": "plan",
        "apply": "apply",
        "health": "health",
        "dig": "health",  # Alias
        "e2e": "e2e",
        "review": "review",
        "help": "help",
    }

    command_type = cmd_map.get(cmd, "unknown")
    if command_type == "unknown":
        return None

    # Parse layers for plan/apply
    layers = []
    remaining_args = []
    valid_layers = {"bootstrap", "platform", "data-staging", "data-prod", "all"}

    for arg in args:
        if arg in valid_layers:
            layers.append(arg)
        else:
            remaining_args.append(arg)

    # Default to "all" if no layers specified for plan/apply
    if command_type in ("plan", "apply") and not layers:
        layers = ["all"]

    return ParsedCommand(
        command=command_type,
        layers=layers,
        args=remaining_args,
        raw=comment,
    )


def run(args) -> int:
    """CLI handler for parse command."""
    result = parse_command(args.comment)
    if result:
        print(f"command={result.command}")
        print(f"layers={','.join(result.layers)}")
        print(f"args={','.join(result.args)}")
        return 0
    else:
        print("command=unknown")
        return 1
