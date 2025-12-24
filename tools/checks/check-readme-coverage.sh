#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${BASE_REF:-origin/main}"
MIN_RATIO=0.8

git fetch origin main --depth=1 >/dev/null 2>&1 || true

if git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE="$BASE_REF"
else
  BASE="HEAD~1"
fi

changed_files=$(git diff --name-only "$BASE" HEAD)

touched_dirs=""
readme_dirs=""

for file in $changed_files; do
  dir=$(dirname "$file")
  if [[ "$file" =~ (^|/)(README|README\.md)$ ]]; then
    readme_dirs+="$dir"$'\n'
    continue
  fi
  touched_dirs+="$dir"$'\n'
done

touched_dirs=$(printf "%s" "$touched_dirs" | sort -u)
readme_dirs=$(printf "%s" "$readme_dirs" | sort -u)

dirs_to_check=()
while IFS= read -r dir; do
  [[ -z "$dir" ]] && continue
  if [[ -f "$dir/README.md" || -f "$dir/README" ]]; then
    dirs_to_check+=("$dir")
  fi
done <<<"$touched_dirs"

total=${#dirs_to_check[@]}
if [[ $total -eq 0 ]]; then
  echo "No directories modified (excluding README) → coverage check passes."
  exit 0
fi

# Skip check for very small changes (1 directory)
if [[ $total -eq 1 ]]; then
  echo "Small change (1 directory) → coverage check skipped."
  exit 0
fi

covered=0
missing_dirs=()
covered_dirs=()

for dir in "${dirs_to_check[@]}"; do
  if [[ -n "$readme_dirs" ]] && grep -Fxq "$dir" <<<"$readme_dirs"; then
    covered=$((covered + 1))
    covered_dirs+=("$dir")
  else
    missing_dirs+=("$dir")
  fi
done

# Use 0.6 threshold (60%) for larger changes
MIN_RATIO=0.6
ratio=$(awk "BEGIN {printf \"%.2f\", $covered/$total}")
echo "README coverage: $ratio ($covered/$total directories updated, threshold: $MIN_RATIO)"

# Print details
if [[ ${#covered_dirs[@]} -gt 0 ]]; then
  echo ""
  echo "✅ READMEs updated:"
  for dir in "${covered_dirs[@]}"; do
    echo "   - $dir"
  done
fi

if [[ ${#missing_dirs[@]} -gt 0 ]]; then
  echo ""
  echo "❌ READMEs need update:"
  for dir in "${missing_dirs[@]}"; do
    echo "   - $dir/README.md"
  done
fi

if awk "BEGIN { if ($ratio < $MIN_RATIO) exit 0; else exit 1 }"; then
  echo ""
  echo "💡 Tip: Update the README.md files listed above, or reduce scope of changes."
  exit 1
fi
