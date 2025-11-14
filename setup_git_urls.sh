#!/usr/bin/env bash
set -euo pipefail

CACHE_ROOT="/home/runner/pytorch-data/git-cache"
MAIN_REPO_URL="https://github.com/pytorch/pytorch.git"
MAIN_REPO_PATH="${CACHE_ROOT}/pytorch.git"
SUBMODULES_DIR="${CACHE_ROOT}/submodules"
TMP_DIR="${CACHE_ROOT}/temp"

echo "=== [1/5] Allow file protocol globally ==="
git config --global protocol.file.allow always

echo "=== [2/5] Map main repo ==="
if [ -d "${MAIN_REPO_PATH}" ]; then
  git config --global url."file://${MAIN_REPO_PATH}".insteadOf "${MAIN_REPO_URL}"
  echo "✅ Mapped ${MAIN_REPO_URL} → ${MAIN_REPO_PATH}"
else
  echo "⚠️ Missing ${MAIN_REPO_PATH}, skipping main repo."
fi

mkdir -p "${TMP_DIR}"
count=0

extract_and_map_recursively() {
  local repo_path="$1"
  local repo_name
  repo_name=$(basename "$repo_path" .git)

  # Extract .gitmodules from this repo mirror (if any)
  if git --git-dir="$repo_path" show HEAD:.gitmodules >"${TMP_DIR}/${repo_name}.gitmodules" 2>/dev/null; then
    echo "📦 Found .gitmodules in ${repo_name}"
    # For each submodule URL
    while read -r url; do
      [ -z "$url" ] && continue
      subrepo_name=$(basename "$url" .git)
      org_name=$(echo "$url" | awk -F'github.com/' '{print $2}' | cut -d'/' -f1)
      match_path=$(find "${SUBMODULES_DIR}" -maxdepth 1 -type d -iname "*${subrepo_name}*.git*" | head -n 1)

      if [ -n "$match_path" ]; then
        git config --global url."file://${match_path}".insteadOf "https://github.com/${org_name}/${subrepo_name}.git"
        echo "✅ ${url} → ${match_path}"
        count=$((count + 1))
        # Recurse into that submodule mirror
        extract_and_map_recursively "$match_path"
      else
        echo "⚠️ Mirror not found for ${url}"
      fi
    done < <(git config --file "${TMP_DIR}/${repo_name}.gitmodules" --get-regexp '\.url$' | awk '{print $2}')
  fi
}

echo "=== [3/5] Recursively mapping mirrors ==="
extract_and_map_recursively "$MAIN_REPO_PATH"

echo "=== [4/5] Summary ==="
echo "✅ Added ${count} global insteadOf mappings."

echo "=== [5/5] Validation ==="
git --no-pager config --global --get-regexp '^url\..*\.insteadOf' || echo "⚠️ No mappings found."
