from __future__ import annotations

from pathlib import Path
import subprocess
import mkdocs_gen_files
import re
import os
import json
from collections import defaultdict
from typing import NamedTuple, Optional

REPO_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_PREFIX = Path(".")

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
    "website",
}

EXCLUDE_FILES = {
    "CLAUDE.md",  # symlink to AGENTS.md
}

EXTRA_STATIC_FILES = [
    Path("website/mkdocs.yml"),
    Path("website/requirements.txt"),
    Path(".github/workflows/docs-site.yml"),
    Path(".github/workflows/readme-coverage.yml"),
]

# Files to move from Root (or flattened Root) to "Overview/" folder to clean up navigation
MOVED_TO_OVERVIEW = {
    "0.check_now.md",
    "AGENTS.md",
    "dir.md",
    "BRN-004.env_eaas_design.md",
}

def _write_text(dst: Path, text: str) -> None:
    with mkdocs_gen_files.open(dst, "w", encoding="utf-8") as f:
        f.write(text)

# Store file content in memory for backlink processing
processed_files: dict[Path, str] = {}

# Source → Dest mapping for link rewriting
src_to_dst: dict[Path, Path] = {}
src_to_content: dict[Path, str] = {}

# Regex for H1 extraction
title_pattern = re.compile(r'^#\s+(.*)', re.MULTILINE)

# Map for Sidebar Tooltips: { "SidebarLabel": "Real Title" }
SIDEBAR_TOOLTIPS = {}

class RepoSpec(NamedTuple):
    prefix: Path
    repo_url: str
    ref: str

def _git_cmd(repo_root: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=repo_root,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )

def _normalize_github_https(url: str) -> Optional[str]:
    url = url.strip()
    if not url:
        return None

    if url.startswith("git@github.com:"):
        url = "https://github.com/" + url.removeprefix("git@github.com:")

    if url.startswith("https://github.com/") and url.endswith(".git"):
        url = url[:-4]

    if url.startswith("http://github.com/"):
        url = "https://github.com/" + url.removeprefix("http://github.com/")

    if url.startswith("https://github.com/"):
        return url

    return None

def _repo_spec(repo_root: Path, prefix: Path) -> Optional[RepoSpec]:
    remote = _git_cmd(repo_root, ["config", "--get", "remote.origin.url"]).stdout.strip()
    repo_url = _normalize_github_https(remote)
    if not repo_url:
        return None

    ref = _git_cmd(repo_root, ["rev-parse", "HEAD"]).stdout.strip()
    if not ref:
        return None

    return RepoSpec(prefix=prefix, repo_url=repo_url, ref=ref)

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

def _map_path_for_site(rel: Path) -> Path:
    if rel.parts and rel.parts[0] == ".github":
        return Path("github") / Path(*rel.parts[1:])
    return rel

def _map_src_to_dst(rel: Path, rel_prefix: Path) -> Path:
    if not rel.parts:
        return rel_prefix / rel

    if rel.parts[0] == "docs":
        dst_rel = Path(*rel.parts[1:]) if len(rel.parts) > 1 else Path(rel.name)
        if dst_rel == Path("README.md"):
            dst_rel = Path("Overview/index.md")
    else:
        dst_rel = rel
        if dst_rel == Path("README.md"):
            dst_rel = Path("index.md")

    if dst_rel.name == "README.md" and dst_rel != Path("Overview/index.md"):
        dst_rel = dst_rel.with_name("index.md")

    if dst_rel.name in MOVED_TO_OVERVIEW:
        dst_rel = Path("Overview") / dst_rel

    return _map_path_for_site(rel_prefix / dst_rel)

_FENCE_RE = re.compile(r"^(```|~~~)")
_MD_LINK_RE = re.compile(r"(!?\[[^\]]*\])\(([^)\n]+)\)")

def _strip_angle_brackets(url: str) -> str:
    url = url.strip()
    if url.startswith("<") and url.endswith(">") and len(url) >= 2:
        return url[1:-1].strip()
    return url

def _relpath(from_dir: Path, to_path: Path) -> str:
    return os.path.relpath(str(to_path), start=str(from_dir)).replace(os.sep, "/")

def _resolve_repo_url(target_src: Path, repo_specs: list[RepoSpec]) -> Optional[RepoSpec]:
    for spec in repo_specs:
        if spec.prefix and target_src.parts[: len(spec.prefix.parts)] == spec.prefix.parts:
            return spec
    for spec in repo_specs:
        if not spec.prefix.parts:
            return spec
    return None

def _rewrite_links(
    content: str,
    *,
    src_path: Path,
    dst_path: Path,
    repo_root: Path,
    repo_specs: list[RepoSpec],
    static_src_to_dst: dict[Path, Path],
) -> str:
    in_fence = False
    fence = ""
    out_lines: list[str] = []

    def replace_match(match: re.Match[str]) -> str:
        label = match.group(1)
        raw = _strip_angle_brackets(match.group(2))

        if not raw or raw.startswith("#") or "://" in raw or raw.startswith("mailto:"):
            return match.group(0)

        path_part, sep, fragment = raw.partition("#")
        path_part = path_part.strip()
        if not path_part:
            return match.group(0)

        # Preserve any title portion: (url "title")
        url_token, *rest = path_part.split(maxsplit=1)
        title_suffix = f" {rest[0]}" if rest else ""

        # Resolve target relative to the *source* file location (repo layout).
        normalized = Path(os.path.normpath(os.path.join(src_path.parent.as_posix(), url_token)))

        # If the file doesn't exist, try a best-effort sibling match: X.md → X.*.md (unique).
        abs_candidate = repo_root / normalized
        if normalized.suffix == ".md" and not abs_candidate.exists():
            parent = abs_candidate.parent
            stem = abs_candidate.stem
            candidates = sorted(parent.glob(f"{stem}.*.md")) if parent.exists() else []
            if len(candidates) == 1:
                normalized = candidates[0].relative_to(repo_root)

        if normalized in src_to_dst:
            target_dst = src_to_dst[normalized]
            rel = _relpath(dst_path.parent, target_dst)
            return f"{label}({rel}{sep}{fragment}{title_suffix})"

        if normalized in static_src_to_dst:
            rel = _relpath(dst_path.parent, static_src_to_dst[normalized])
            return f"{label}({rel}{sep}{fragment}{title_suffix})"

        # Fallback: link to GitHub blob (per-repo, pinned to current checkout ref).
        spec = _resolve_repo_url(normalized, repo_specs)
        if spec:
            rel_in_repo = normalized
            if spec.prefix.parts:
                rel_in_repo = Path(*normalized.parts[len(spec.prefix.parts) :])
            gh = f"{spec.repo_url}/blob/{spec.ref}/{rel_in_repo.as_posix()}"
            return f"{label}({gh}{sep}{fragment}{title_suffix})"

        return match.group(0)

    for line in content.splitlines(keepends=True):
        m = _FENCE_RE.match(line)
        if m:
            marker = m.group(1)
            if not in_fence:
                in_fence = True
                fence = marker
            elif fence == marker:
                in_fence = False
                fence = ""
            out_lines.append(line)
            continue

        if in_fence:
            out_lines.append(line)
            continue

        out_lines.append(_MD_LINK_RE.sub(replace_match, line))

    return "".join(out_lines)

def _register_file(repo_root: Path, rel: Path, rel_prefix: Path = Path()) -> None:
    full_src = rel_prefix / rel
    dst_rel = _map_src_to_dst(rel, rel_prefix)

    if _should_skip(dst_rel):
        return

    src_to_dst[full_src] = dst_rel
    src_to_content[full_src] = (repo_root / rel).read_text(encoding="utf-8")

def _collect_files(repo_root: Path, rel_prefix: Path = Path()):
    for rel in sorted(_git_ls_files(repo_root, "*.md")):
        if (repo_root / rel).exists():
            _register_file(repo_root, rel, rel_prefix)

# 1. Collect all content
_collect_files(REPO_ROOT)

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
    _collect_files(sub_root, rel_prefix=sub_path)

# 2. Build repo specs for GitHub fallback
repo_specs: list[RepoSpec] = []
root_spec = _repo_spec(REPO_ROOT, prefix=Path())
if root_spec:
    repo_specs.append(root_spec)

for sub_path in _git_submodule_paths(REPO_ROOT):
    sub_root = REPO_ROOT / sub_path
    spec = _repo_spec(sub_root, prefix=sub_path)
    if spec:
        repo_specs.append(spec)

static_src_to_dst: dict[Path, Path] = {src: _map_path_for_site(src) for src in EXTRA_STATIC_FILES}

# 3. Rewrite content and build tooltip map
for src_path, dst_path in src_to_dst.items():
    content = src_to_content[src_path]

    # Process Title for Tooltip Mapping and Frontmatter
    h1_title = "Untitled"
    m = title_pattern.search(content)
    if m:
        h1_title = m.group(1).strip().replace('"', '\\"')

    sidebar_label = ""
    if dst_path.name != "index.md":
        sidebar_label = dst_path.stem
        if not content.startswith("---"):
            content = f"---\ntitle: {sidebar_label}\n---\n\n{content}"
    else:
        if len(dst_path.parts) > 1:
            sidebar_label = dst_path.parts[-2]
        else:
            sidebar_label = "Home"
            SIDEBAR_TOOLTIPS[REPO_ROOT.name] = h1_title

    if sidebar_label:
        SIDEBAR_TOOLTIPS[sidebar_label] = h1_title

    content = _rewrite_links(
        content,
        src_path=src_path,
        dst_path=dst_path,
        repo_root=REPO_ROOT,
        repo_specs=repo_specs,
        static_src_to_dst=static_src_to_dst,
    )

    processed_files[dst_path] = content

# 4. Analyze Backlinks
backlinks = defaultdict(list)
link_pattern = re.compile(r'\[.*?\]\((.*?)\)')

def get_title(content):
    m = title_pattern.search(content)
    return m.group(1).strip() if m else "Untitled"

for dst_path, content in processed_files.items():
    src_title = get_title(content)
    for match in link_pattern.finditer(content):
        link_target = match.group(1)
        if "://" in link_target or link_target.startswith("mailto:") or not link_target:
            continue
        target_file = link_target.split("#")[0]
        if not target_file:
            continue
        try:
            src_dir = os.path.dirname(str(dst_path))
            norm_target = os.path.normpath(os.path.join(src_dir, target_file))
            target_path = Path(norm_target)
            if target_path in processed_files and target_path != dst_path:
                backlinks[target_path].append((dst_path, src_title))
        except Exception:
            continue

# 5. Write files
for path, content in processed_files.items():
    if path in backlinks:
        links = backlinks[path]
        links.sort(key=lambda x: x[1])
        seen_src_paths = set()
        unique_links = []
        for src_path, title in links:
            if src_path not in seen_src_paths:
                seen_src_paths.add(src_path)
                unique_links.append((src_path, title))
        
        if unique_links:
            backlinks_section = ["", "---", "", "### 🔗 Referenced In", ""]
            for src_path, title in unique_links:
                try:
                    rel_link = os.path.relpath(str(src_path), os.path.dirname(str(path)))
                    if not rel_link.endswith(".md") and not Path(rel_link).is_dir():
                        rel_link += ".md"
                    backlinks_section.append(f"- [{title}]({rel_link})")
                except ValueError:
                    continue
            content += "\n".join(backlinks_section)
    
    _write_text(OUTPUT_PREFIX / path, content)

# 6. Generate Tooltip JS
js_content = f"""
document.addEventListener("DOMContentLoaded", function() {{
    var titles = {json.dumps(SIDEBAR_TOOLTIPS)};
    var links = document.querySelectorAll('.md-nav__link');
    links.forEach(function(link) {{
        var text = link.textContent.trim();
        if (text === "Home" && titles["Home"]) {{ 
            link.setAttribute('title', titles["Home"]);
        }} else if (text === "{REPO_ROOT.name}" && titles["{REPO_ROOT.name}"]) {{ 
            link.setAttribute('title', titles["{REPO_ROOT.name}"]);
        }} else if (titles[text]) {{
            link.setAttribute('title', titles[text]);
        }}
    }});
}}); 
"""
_write_text(OUTPUT_PREFIX / "js/titles.js", js_content)

# 7. Copy extra static files
for rel in EXTRA_STATIC_FILES:
    src = REPO_ROOT / rel
    if not src.exists():
        continue
    _write_text(static_src_to_dst[rel], src.read_text(encoding="utf-8"))
