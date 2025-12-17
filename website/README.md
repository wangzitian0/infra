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

- `gen_pages.py`: Python script to generate the site structure (flattens `docs/` and pulls in root `README.md`).
- `mkdocs.yml`: Main configuration file.
