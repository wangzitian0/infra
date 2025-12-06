#!/usr/bin/env bash
set -euo pipefail

# Usage: tools/docs-guard.sh <base-ref> [head-ref]
# Enforces that 0.check_now.md and directory README.md files are updated alongside code changes.

BASE_REF="${1:-}"
HEAD_REF="${2:-}"

if [[ -z "${BASE_REF}" ]]; then
  echo "Usage: $0 <base-ref> [head-ref]" >&2
  exit 2
fi

if [[ -n "${HEAD_REF}" ]]; then
  CHANGED_FILES="$(git diff --name-only "${BASE_REF}...${HEAD_REF}")"
else
  CHANGED_FILES="$(git diff --name-only "${BASE_REF}")"
fi

if [[ -z "${CHANGED_FILES}" ]]; then
  echo "No changes detected between ${BASE_REF} and ${HEAD_REF}."
  exit 0
fi

status=0

if ! grep -qx "0.check_now.md" <<< "${CHANGED_FILES}"; then
  echo "::error::0.check_now.md must be updated for every change."
  status=1
fi

dirs=()
while IFS= read -r file; do
  [[ -z "${file}" ]] && continue
  basename="$(basename "${file}")"
  [[ "${basename}" == "README.md" ]] && continue
  [[ "${file}" == "0.check_now.md" ]] && continue
  dir="$(dirname "${file}")"
  dirs+=("${dir}")
done <<< "${CHANGED_FILES}"

missing_readmes=()
missing_updates=()

if ((${#dirs[@]})); then
  while IFS= read -r dir; do
    if [[ "${dir}" == "." ]]; then
      readme_path="README.md"
    else
      readme_path="${dir}/README.md"
    fi
    if [[ ! -f "${readme_path}" ]]; then
      missing_readmes+=("${readme_path}")
      continue
    fi
    if ! grep -qx "${readme_path}" <<< "${CHANGED_FILES}"; then
      missing_updates+=("${readme_path} (required for changes in ${dir})")
    fi
  done <<< "$(printf "%s\n" "${dirs[@]}" | sort -u)"
fi

if (( ${#missing_readmes[@]} )); then
  echo "::error::Missing README.md files for changed directories: ${missing_readmes[*]}"
  status=1
fi

if (( ${#missing_updates[@]} )); then
  echo "::error::Update these README.md files to match changed directories: ${missing_updates[*]}"
  status=1
fi

if [[ "${status}" -ne 0 ]]; then
  echo "Documentation guard failed."
  exit 1
fi

echo "Documentation guard passed: 0.check_now.md and README.md files are aligned."
