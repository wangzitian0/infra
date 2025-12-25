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
            head_sha=data["headRefOid"],  # Full SHA for commit status API
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

    def react_to_comment(self, comment_id: int, reaction: str = "eyes") -> None:
        """Alias for add_reaction for compatibility."""
        self.add_reaction(comment_id, reaction)

    def create_running_comment(self, pr_number: int, title: str) -> tuple[int, str]:
        """Create a standardized 'Running' comment for a long-running CI task.
        
        Returns:
            (comment_id, comment_url)
        """
        repo = self.repo
        body = f"""### ⏳ {title}
*Work in progress...*

[⬅️ Back to Dashboard](https://github.com/{repo}/pull/{pr_number})
"""
        comment_id = self.create_comment(pr_number, body)
        url = f"https://github.com/{repo}/pull/{pr_number}#issuecomment-{comment_id}"
        return comment_id, url

    def update_result_comment(self, comment_id: int, pr_number: int, title: str, content: str, success: bool) -> None:
        """Update a previously created 'Running' comment with actual results."""
        # Truncate content if too long for GitHub comments (~65k limit)
        if len(content) > 60000:
            content = content[:60000] + "\n...(truncated)"

        icon = "✅" if success else "❌"
        repo = self.repo
        body = f"""### {icon} {title}
<details open>
<summary>Logs</summary>

```text
{content}
```
</details>

[⬅️ Back to Dashboard](https://github.com/{repo}/pull/{pr_number})
"""
        self.update_comment(comment_id, body)

    def create_commit_status(
        self,
        sha: str,
        state: str,
        context: str = "CI",
        description: str = "",
        target_url: str = "",
    ) -> None:
        """Create a commit status.
        
        Args:
            sha: Commit SHA (can be short or full)
            state: pending, success, failure, error
            context: Status context/name
            description: Short description
            target_url: URL to link to
        """
        args = [
            "api",
            f"/repos/{self.repo}/statuses/{sha}",
            "-X",
            "POST",
            "-f",
            f"state={state}",
            "-f",
            f"context={context}",
        ]
        if description:
            args.extend(["-f", f"description={description}"])
        if target_url:
            args.extend(["-f", f"target_url={target_url}"])
        
        self._run_gh(args)

