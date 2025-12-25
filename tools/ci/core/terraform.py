"""Terraform/Terragrunt execution wrapper."""

import os
import subprocess
from dataclasses import dataclass
from enum import Enum
from typing import Literal

from ..config import Layer


class PlanResult(Enum):
    """Result of terraform plan."""

    NO_CHANGES = 0
    ERROR = 1
    HAS_CHANGES = 2


@dataclass
class ExecutionResult:
    """Result of terraform/terragrunt execution."""

    success: bool
    exit_code: int
    stdout: str
    stderr: str
    plan_result: PlanResult | None = None


class TerraformRunner:
    """Wrapper for terraform/terragrunt commands."""

    def __init__(self, layer: Layer, repo_root: str | None = None):
        self.layer = layer
        # Determine repo root: GITHUB_WORKSPACE > git root > cwd
        if repo_root:
            self.repo_root = repo_root
        elif os.environ.get("GITHUB_WORKSPACE"):
            self.repo_root = os.environ["GITHUB_WORKSPACE"]
        else:
            # Try to find git root
            try:
                import subprocess
                result = subprocess.run(
                    ["git", "rev-parse", "--show-toplevel"],
                    capture_output=True, text=True
                )
                self.repo_root = result.stdout.strip() if result.returncode == 0 else os.getcwd()
            except Exception:
                self.repo_root = os.getcwd()
        self.work_dir = os.path.join(self.repo_root, layer.path)

    def _run(
        self,
        cmd: list[str],
        capture: bool = True,
        detailed_exitcode: bool = False,
    ) -> ExecutionResult:
        """Run a command and return result."""
        env = os.environ.copy()
        env["TF_IN_AUTOMATION"] = "true"
        env["TF_INPUT"] = "false"
        # Terragrunt non-interactive mode via env var (not CLI flag)
        env["TERRAGRUNT_NON_INTERACTIVE"] = "true"

        # Print command being run
        print(f"  🔧 Running: {' '.join(cmd)}")

        try:
            result = subprocess.run(
                cmd,
                cwd=self.work_dir,
                capture_output=capture,
                text=True,
                env=env,
            )

            plan_result = None
            if detailed_exitcode:
                if result.returncode == 0:
                    plan_result = PlanResult.NO_CHANGES
                elif result.returncode == 2:
                    plan_result = PlanResult.HAS_CHANGES
                else:
                    plan_result = PlanResult.ERROR

            success = result.returncode == 0 or (
                detailed_exitcode and result.returncode == 2
            )

            # On error (not exit code 2 for plan changes), print full output
            if result.returncode != 0 and result.returncode != 2:
                print(f"\n❌ Command failed with exit code {result.returncode}")
                if result.stdout:
                    print(f"\n=== STDOUT ===\n{result.stdout}")
                if result.stderr:
                    print(f"\n=== STDERR ===\n{result.stderr}")

            return ExecutionResult(
                success=success,
                exit_code=result.returncode,
                stdout=result.stdout or "",
                stderr=result.stderr or "",
                plan_result=plan_result,
            )
        except Exception as e:
            print(f"\n❌ Exception running command: {e}")
            return ExecutionResult(
                success=False,
                exit_code=1,
                stdout="",
                stderr=str(e),
                plan_result=PlanResult.ERROR,
            )

    def _get_base_cmd(self) -> str:
        """Get base command (terraform or terragrunt)."""
        return self.layer.engine

    def init(self) -> ExecutionResult:
        """Run init."""
        cmd = [self._get_base_cmd(), "init", "-no-color"]
        return self._run(cmd)

    def plan(self, detailed_exitcode: bool = True) -> ExecutionResult:
        """Run plan with optional detailed exit code."""
        cmd = [self._get_base_cmd(), "plan", "-no-color"]
        if detailed_exitcode:
            cmd.append("-detailed-exitcode")
        return self._run(cmd, detailed_exitcode=detailed_exitcode)

    def apply(self, auto_approve: bool = True) -> ExecutionResult:
        """Run apply."""
        cmd = [self._get_base_cmd(), "apply", "-no-color"]
        if auto_approve:
            cmd.append("-auto-approve")
        return self._run(cmd)

    def validate(self) -> ExecutionResult:
        """Run validate."""
        cmd = [self._get_base_cmd(), "validate", "-no-color"]
        return self._run(cmd)
