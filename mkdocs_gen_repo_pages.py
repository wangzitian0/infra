from __future__ import annotations

from pathlib import Path
import subprocess

import mkdocs_gen_files


REPO_ROOT = Path(__file__).resolve().parent
OUTPUT_PREFIX = Path("repo")

EXCLUDE_PARTS = {
    ".git",
    ".site",
    ".venv",
    "__pycache__",
    "node_modules",
    "site",
    "venv",
}

EXCLUDE_TOP_LEVEL = {
    "mkdocs",
}

EXCLUDE_FILES = {
    "CLAUDE.md",  # symlink to AGENTS.md
}

EXTRA_STATIC_FILES = [
    Path("mkdocs.yml"),
    Path("requirements-mkdocs.txt"),
    Path(".github/workflows/docs-site.yml"),
]


def _git_ls_files(repo_root: Path, pattern: str) -> list[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", pattern],
        cwd=repo_root,
        check=True,
        stdout=subprocess.PIPE,
    )
    return [Path(p.decode("utf-8")) for p in result.stdout.split(b"\0") if p]


def _git_submodule_paths(repo_root: Path) -> list[Path]:
    if not (repo_root / ".gitmodules").exists():
        return []
    result = subprocess.run(
        ["git", "config", "-f", ".gitmodules", "--get-regexp", r"^submodule\..*\.path$"],
        cwd=repo_root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if result.returncode != 0:
        return []
    paths: list[Path] = []
    for line in result.stdout.splitlines():
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        paths.append(Path(parts[1].strip()))
    return paths


def _should_skip(rel_path: Path) -> bool:
    if not rel_path.parts:
        return True
    if rel_path.parts[0] in EXCLUDE_TOP_LEVEL:
        return True
    if any(part in EXCLUDE_PARTS for part in rel_path.parts):
        return True
    if rel_path.name in EXCLUDE_FILES:
        return True
    return False


def _write_text(dst: Path, text: str) -> None:
    with mkdocs_gen_files.open(dst, "w", encoding="utf-8") as f:
        f.write(text)


def _copy_tracked_md(repo_root: Path, rel_prefix: Path = Path()) -> None:
    for rel in sorted(_git_ls_files(repo_root, "*.md")):
        dst_rel = rel_prefix / rel
        if _should_skip(dst_rel):
            continue
        _write_text(
            OUTPUT_PREFIX / dst_rel,
            (repo_root / rel).read_text(encoding="utf-8"),
        )


_copy_tracked_md(REPO_ROOT)

for sub_path in _git_submodule_paths(REPO_ROOT):
    sub_root = REPO_ROOT / sub_path
    if not sub_root.exists():
        continue
    try:
        subprocess.run(
            ["git", "-C", str(sub_root), "rev-parse", "--is-inside-work-tree"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        continue
    _copy_tracked_md(sub_root, rel_prefix=sub_path)

for rel in EXTRA_STATIC_FILES:
    if _should_skip(rel):
        continue
    if not (REPO_ROOT / rel).exists():
        continue
    _write_text(OUTPUT_PREFIX / rel, (REPO_ROOT / rel).read_text(encoding="utf-8"))
