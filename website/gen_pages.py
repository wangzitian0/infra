from __future__ import annotations

from pathlib import Path
import subprocess
import mkdocs_gen_files
import re
import os
import json
from collections import defaultdict

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
processed_files = {}

# Regex for H1 extraction
title_pattern = re.compile(r'^#\s+(.*)', re.MULTILINE)

# Map for Sidebar Tooltips: { "SidebarLabel": "Real Title" }
SIDEBAR_TOOLTIPS = {}

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

def _process_file_content(repo_root: Path, rel: Path, rel_prefix: Path = Path()):
    src_path = repo_root / rel
    
    # Flattening Logic and Path Mapping
    if rel.parts[0] == "docs":
        # Flatten docs/ folder to root
        if len(rel.parts) > 1:
            dst_rel = Path(*rel.parts[1:])
        else:
            dst_rel = Path(rel.name)
        
        # Special handling for docs/README.md -> Overview/index.md
        if dst_rel == Path("README.md"):
            dst_rel = Path("Overview/index.md")
    else:
        dst_rel = rel
        # Map Root README.md to index.md
        if dst_rel == Path("README.md"):
            dst_rel = Path("index.md")

    # Rename any other README.md to index.md to ensure folder pages work
    if dst_rel.name == "README.md" and dst_rel != Path("Overview/index.md"):
         dst_rel = dst_rel.with_name("index.md")

    # Move specific loose files to Overview/
    if dst_rel.name in MOVED_TO_OVERVIEW:
        dst_rel = Path("Overview") / dst_rel

    dst_rel = rel_prefix / dst_rel

    if _should_skip(dst_rel) and not (rel.parts[0] == "docs"): 
        return
        
    content = src_path.read_text(encoding="utf-8")
    
    # Rewrite links to account for flattening and renaming
    content = content.replace("docs/README.md", "Overview/index.md")
    content = content.replace("](docs/", "](")
    content = content.replace("](../docs/", "](../")
    content = content.replace("](./docs/", "](./")
    
    for filename in MOVED_TO_OVERVIEW:
        content = re.sub(r'(\(\]|\]\.|]\.|\.\.|\/)' + re.escape(filename) + r'(\)|\.md)', r'\1Overview/' + filename + r'\2', content)

    content = content.replace("README.md", "index.md")
    
    # Process Title for Tooltip Mapping and Frontmatter
    h1_title = "Untitled"
    m = title_pattern.search(content)
    if m:
        h1_title = m.group(1).strip().replace('"', '\"') # Escape quotes for JS safety
    
    # 5. Sidebar Logic & Tooltips
    sidebar_label = ""
    # Case A: Standard File (not index.md)
    if dst_rel.name != "index.md":
        sidebar_label = dst_rel.stem
        if not content.startswith("---"): # Inject frontmatter only if not already present
            frontmatter = f"---\ntitle: {sidebar_label}\n---\n\n"
            content = frontmatter + content
    # Case B: Index File (Folder)
    else:
        if len(dst_rel.parts) > 1: # e.g., 1.bootstrap/index.md
            sidebar_label = dst_rel.parts[-2] # Folder name (e.g., "1.bootstrap")
        else: # Root index.md
            sidebar_label = "Home" 
            SIDEBAR_TOOLTIPS[REPO_ROOT.name] = h1_title 

    if sidebar_label: # Add to tooltip map if we have a sidebar label
        SIDEBAR_TOOLTIPS[sidebar_label] = h1_title
    
    processed_files[dst_rel] = content

def _collect_files(repo_root: Path, rel_prefix: Path = Path()):
    for rel in sorted(_git_ls_files(repo_root, "*.md")):
        if (repo_root / rel).exists():
            _process_file_content(repo_root, rel, rel_prefix)

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

# 2. Analyze Backlinks
backlinks = defaultdict(list)
link_pattern = re.compile(r'\[.*?\]\((.*?)\)')

def get_title(content):
    m = title_pattern.search(content)
    return m.group(1).strip() if m else "Untitled"

for src_path, content in processed_files.items():
    src_title = get_title(content)
    for match in link_pattern.finditer(content):
        link_target = match.group(1)
        if "://" in link_target or link_target.startswith("mailto:") or not link_target:
            continue
        target_file = link_target.split("#")[0]
        if not target_file:
            continue
        try:
            src_dir = os.path.dirname(str(src_path))
            norm_target = os.path.normpath(os.path.join(src_dir, target_file))
            target_path = Path(norm_target)
            if target_path in processed_files and target_path != src_path:
                backlinks[target_path].append((src_path, src_title))
        except Exception:
            continue

# 3. Write files
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

# 4. Generate Tooltip JS
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

# 5. Copy extra static files
for rel in EXTRA_STATIC_FILES:
    if _should_skip(rel):
        continue
    if not (REPO_ROOT / rel).exists():
        continue
    _write_text(rel, (REPO_ROOT / rel).read_text(encoding="utf-8"))