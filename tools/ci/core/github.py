"""GitHub API client for CI operations."""

import os
import json
from dataclasses import dataclass
from typing import Any
import subprocess


@dataclass
class PRInfo:
    """Pull Request information."""

    number: int
    head_sha: str
    head_ref: str
    base_ref: str
    title: str


class GitHubClient:
    """GitHub API client using gh CLI."""

    def __init__(self, token: str | None = None):
        self.token = token or os.environ.get("GITHUB_TOKEN", "")
        self.repo = os.environ.get("GITHUB_REPOSITORY", "")

    def _run_gh(self, args: list[str]) -> dict[str, Any] | list[Any] | str:
        """Run gh CLI command and return JSON result."""
        env = os.environ.copy()
        if self.token:
            env["GH_TOKEN"] = self.token

        cmd = ["gh"] + args
        result = subprocess.run(cmd, capture_output=True, text=True, env=env)

        if result.returncode != 0:
            raise RuntimeError(f"gh failed: {result.stderr}")

        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError:
            return result.stdout.strip()

    def get_pr(self, pr_number: int) -> PRInfo:
        """Get PR information."""
        data = self._run_gh(
            [
                "pr",
                "view",
                str(pr_number),
                "--json",
                "number,headRefOid,headRefName,baseRefName,title",
            ]
        )
        return PRInfo(
            number=data["number"],
            head_sha=data["headRefOid"][:7],
            head_ref=data["headRefName"],
            base_ref=data["baseRefName"],
            title=data["title"],
        )

    def get_changed_files(self, pr_number: int) -> list[str]:
        """Get list of changed files in PR."""
        data = self._run_gh(
            ["pr", "view", str(pr_number), "--json", "files"]
        )
        return [f["path"] for f in data.get("files", [])]

    def create_comment(self, pr_number: int, body: str) -> int:
        """Create a comment on PR, return comment ID."""
        result = self._run_gh(
            [
                "pr",
                "comment",
                str(pr_number),
                "--body",
                body,
            ]
        )
        # gh pr comment doesn't return ID directly, need to fetch
        return self._find_latest_comment_id(pr_number)

    def update_comment(self, comment_id: int, body: str) -> None:
        """Update an existing comment."""
        self._run_gh(
            [
                "api",
                f"/repos/{self.repo}/issues/comments/{comment_id}",
                "-X",
                "PATCH",
                "-f",
                f"body={body}",
            ]
        )

    def find_comment_by_marker(self, pr_number: int, marker: str) -> dict | None:
        """Find a comment containing a specific marker."""
        comments = self._run_gh(
            [
                "api",
                f"/repos/{self.repo}/issues/{pr_number}/comments",
                "--paginate",
            ]
        )
        for comment in comments:
            if marker in comment.get("body", ""):
                return comment
        return None

    def _find_latest_comment_id(self, pr_number: int) -> int:
        """Find the latest comment ID on a PR."""
        comments = self._run_gh(
            [
                "api",
                f"/repos/{self.repo}/issues/{pr_number}/comments",
                "--paginate",
            ]
        )
        if comments:
            return comments[-1]["id"]
        return 0

    def add_reaction(self, comment_id: int, reaction: str = "eyes") -> None:
        """Add reaction to a comment."""
        self._run_gh(
            [
                "api",
                f"/repos/{self.repo}/issues/comments/{comment_id}/reactions",
                "-X",
                "POST",
                "-f",
                f"content={reaction}",
            ]
        )
