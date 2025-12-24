"""PR Dashboard management."""

import json
import re
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Literal, Any

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
class ActionHistoryItem:
    """Record of an action."""
    action: str
    trigger: str
    output: str
    time: str


@dataclass
class DashboardState:
    """Persistent state of the dashboard."""
    stages: dict[str, dict]
    history: list[dict]


@dataclass
class Dashboard:
    """PR Dashboard for tracking pipeline status."""

    pr_number: int
    commit_sha: str
    github: GitHubClient
    comment_id: int | None = None
    stages: dict[str, StageStatus] = field(default_factory=dict)
    history: list[ActionHistoryItem] = field(default_factory=list)

    MARKER_PREFIX = "<!-- infra-dashboard:"
    STATE_PREFIX = "<!-- infra-dashboard-state:"

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
                "e2e": StageStatus("E2E Tests"),
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

    def _serialize_state(self) -> str:
        """Serialize current state to JSON string."""
        state = {
            "stages": {k: asdict(v) for k, v in self.stages.items()},
            "history": [asdict(h) for h in self.history]
        }
        return json.dumps(state)

    def _deserialize_state(self, json_str: str) -> None:
        """Deserialize state from JSON string."""
        try:
            state = json.loads(json_str)
            if "stages" in state:
                for k, v in state["stages"].items():
                    if k in self.stages:
                        self.stages[k] = StageStatus(**v)
            if "history" in state:
                self.history = [ActionHistoryItem(**h) for h in state["history"]]
        except Exception as e:
            print(f"⚠️ Failed to deserialize state: {e}")

    def render(self) -> str:
        """Render dashboard as markdown."""
        state_comment = f"{self.STATE_PREFIX}{self._serialize_state()} -->"
        
        lines = [
            self.marker,
            state_comment,
            f"## ⚙️ Commit Dashboard `{self.commit_sha[:7]}`",
            "### Stages",
            "| Stage | Status | Output | Time |",
            "|:---|:---:|:---|:---|",
        ]

        # Stages Table
        for stage in self.stages.values():
            icon = self._status_icon(stage.status)
            link = f"[View]({stage.link})" if stage.link else "-"
            time = stage.time or "-"
            lines.append(f"| {stage.name} | {icon} | {link} | {time} |")

        # Action History
        lines.extend([
            "",
            "<details><summary>📜 Action History</summary>",
            "",
            "| Action | Trigger | Output | Time |",
            "|:---|:---|:---|:---|",
        ])
        
        if not self.history:
            lines.append("| - | - | - | - |")
        else:
            for item in reversed(self.history): # Show newest first
                lines.append(f"| {item.action} | {item.trigger} | {item.output} | {item.time} |")
                
        lines.append("</details>")

        # Available Commands
        lines.extend([
            "",
            "<details><summary>📖 Available Infra Commands</summary>",
            "### Commands",
            "| 命令 | 作用 |",
            "|:---|:---|",
            "| `/plan` | 预览所有层变更 |",
            "| `/plan <layer>` | 预览指定层 |",
            "| `/apply` | 部署所有层 |",
            "| `/apply <layer>` | 部署指定层 |",
            "| `/e2e` | E2E 测试 |",
            "| `/review` | AI 审查 |",
            "| `/help` | 显示帮助 |",
            "</details>",
        ])

        # Next Step (Footer)
        lines.extend([
            "",
            "<!-- next-step -->",
            self._get_next_step(),
            "<!-- /next-step -->",
        ])

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

        # Check if all critical stages done
        # (Assuming all non-skipped are critical?)
        if all(s.status in ("success", "skipped") for s in self.stages.values()):
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
        append_history: bool = True
    ) -> None:
        """Update a stage status and optionally record history."""
        if stage_key in self.stages:
            prev_status = self.stages[stage_key].status
            
            self.stages[stage_key].status = status
            self.stages[stage_key].time = self._now()
            if link:
                self.stages[stage_key].link = link
                
            # Append history if status changed or forced
            if append_history and (status != prev_status or status in ("success", "failure")):
                # Map stage key to readable action
                action_map = {
                    "ci": "CI Validate",
                    "apply": "Terraform Apply",
                    "e2e": "E2E Tests",
                    "review": "AI Review"
                }
                # Handle plan-* keys
                if stage_key.startswith("plan-"):
                    action_name = f"Plan ({stage_key.replace('plan-', '')})"
                else:
                    action_name = action_map.get(stage_key, stage_key.capitalize())

                icon = self._status_icon(status)
                trigger = "CI/Bot" # We could pass this in if we had context
                output = f"[{status.upper()}]({link})" if link else status.upper()
                
                self.history.append(ActionHistoryItem(
                    action=action_name,
                    trigger=trigger,
                    output=output,
                    time=self._now()
                ))

    def load(self) -> bool:
        """Load existing dashboard from PR comments."""
        comment = self.github.find_comment_by_marker(self.pr_number, self.marker)
        if comment:
            self.comment_id = comment["id"]
            body = comment["body"]
            
            # Extract state JSON
            match = re.search(f"{self.STATE_PREFIX}(.*?) -->", body, re.DOTALL)
            if match:
                self._deserialize_state(match.group(1))
            return True
        return False

    def save(self) -> bool:
        """Save dashboard to PR comment. Returns True on success."""
        body = self.render()
        try:
            if self.comment_id:
                self.github.update_comment(self.comment_id, body)
            else:
                self.comment_id = self.github.create_comment(self.pr_number, body)
            return True
        except Exception as e:
            print(f"⚠️ Dashboard save failed: {e}")
            return False
