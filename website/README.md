# Docs Website

This directory contains the configuration for the MkDocs static site generator.

## Prerequisites

- Python 3.10+

## Local Development

1. **Setup Virtual Environment**:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r website/requirements.txt
   ```

2. **Run Dev Server**:
   ```bash
   mkdocs serve -f website/mkdocs.yml
   ```
   The site will be available at `http://127.0.0.1:8000`.

3. **Build Static Site**:
   ```bash
   mkdocs build -f website/mkdocs.yml
   ```
   The output will be in `.site/`.

## Directory Structure

- `gen_pages.py`: Python script to generate the site structure (flattens `docs/` and pulls in root `README.md`).
- `mkdocs.yml`: Main configuration file.
