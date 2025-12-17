# Docs Website

This directory contains the configuration for the MkDocs static site generator.

## Prerequisites

- Python 3.10+

## Local Development

1. **Setup Virtual Environment** (assuming Python 3.12 is available):
   ```bash
   python3.12 -m venv .venv
   .venv/bin/python -m pip install -r website/requirements.txt
   ```

2. **Run Dev Server**:
   ```bash
   .venv/bin/mkdocs serve -f website/mkdocs.yml
   ```
   The site will be available at `http://127.0.0.1:8000`.

3. **Build Static Site**:
   ```bash
   .venv/bin/mkdocs build -f website/mkdocs.yml
   ```
   The output will be in `.site/`.

## Directory Structure

- `gen_pages.py`: Generates the MkDocs file tree from git-tracked `*.md` (including submodules), rewrites internal links to match the generated paths, and falls back to GitHub blob links for non-doc files.
- `mkdocs.yml`: Main configuration file.

Notes:
- MkDocs ignores dot-directories by default; `.github/...` content is mapped to `github/...` in the generated site.
- If you want `apps/` docs, run `git submodule update --init --recursive` before building.
