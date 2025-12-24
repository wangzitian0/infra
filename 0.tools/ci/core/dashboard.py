"""PR Dashboard management."""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Literal

from .github import GitHubClient

Status = Literal["pending", "running", "success", "failure", "skipped"]


@dataclass
class StageStatus:
    """Status of a pipeline stage."""

    name: str
    status: Status = "pending"
    link: str = ""
    time: str = ""


@dataclass
class Dashboard:
    """PR Dashboard for tracking pipeline status."""

    pr_number: int
    commit_sha: str
    github: GitHubClient
    comment_id: int | None = None
    stages: dict[str, StageStatus] = field(default_factory=dict)

    MARKER_PREFIX = "<!-- infra-dashboard:"

    def __post_init__(self):
        """Initialize default stages."""
        if not self.stages:
            self.stages = {
                "ci": StageStatus("CI Validate"),
                "plan-bootstrap": StageStatus("Plan: bootstrap"),
                "plan-platform": StageStatus("Plan: platform"),
                "plan-data-staging": StageStatus("Plan: data-staging"),
                "plan-data-prod": StageStatus("Plan: data-prod"),
                "apply": StageStatus("Apply"),
                "review": StageStatus("AI Review"),
            }

    @property
    def marker(self) -> str:
        """Get unique marker for this dashboard."""
        return f"{self.MARKER_PREFIX}{self.commit_sha} -->"

    def _status_icon(self, status: Status) -> str:
        """Convert status to emoji."""
        icons = {
            "pending": "⏳",
            "running": "🔄",
            "success": "✅",
            "failure": "❌",
            "skipped": "⏭️",
        }
        return icons.get(status, "❓")

    def _now(self) -> str:
        """Get current timestamp."""
        return datetime.utcnow().strftime("%H:%M UTC")

    def render(self) -> str:
        """Render dashboard as markdown."""
        lines = [
            self.marker,
            f"## ⚙️ Commit `{self.commit_sha}` Pipeline",
            "",
            "| Stage | Status | Output | Time |",
            "|:---|:---:|:---|:---|",
        ]

        for stage in self.stages.values():
            icon = self._status_icon(stage.status)
            link = f"[View]({stage.link})" if stage.link else "-"
            time = stage.time or "-"
            lines.append(f"| {stage.name} | {icon} | {link} | {time} |")

        lines.extend(
            [
                "",
                "<!-- next-step -->",
                self._get_next_step(),
                "<!-- /next-step -->",
            ]
        )

        return "\n".join(lines)

    def _get_next_step(self) -> str:
        """Determine next step message."""
        # Check for failures
        for stage in self.stages.values():
            if stage.status == "failure":
                return f"❌ {stage.name} failed. Check output and fix."

        # Check for running
        for stage in self.stages.values():
            if stage.status == "running":
                return f"🔄 {stage.name} in progress..."

        # Check if all done
        all_done = all(
            s.status in ("success", "skipped") for s in self.stages.values()
        )
        if all_done:
            return "✅ **Ready to merge!**"

        # Find next pending
        for stage in self.stages.values():
            if stage.status == "pending":
                return f"⏳ Waiting for {stage.name}..."

        return "⏳ Waiting..."

    def update_stage(
        self,
        stage_key: str,
        status: Status,
        link: str = "",
    ) -> None:
        """Update a stage status."""
        if stage_key in self.stages:
            self.stages[stage_key].status = status
            self.stages[stage_key].time = self._now()
            if link:
                self.stages[stage_key].link = link

    def load(self) -> bool:
        """Load existing dashboard from PR comments."""
        comment = self.github.find_comment_by_marker(self.pr_number, self.marker)
        if comment:
            self.comment_id = comment["id"]
            # TODO: Parse existing stages from comment body
            return True
        return False

    def save(self) -> None:
        """Save dashboard to PR comment."""
        body = self.render()
        if self.comment_id:
            self.github.update_comment(self.comment_id, body)
        else:
            self.comment_id = self.github.create_comment(self.pr_number, body)
