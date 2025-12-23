#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURATION ===
CACHE_ROOT="${CACHE_ROOT:-/home/runner/pytorch-data/git-cache}"   # base cache path
MAIN_REPO_URL="https://github.com/pytorch/pytorch.git"
MAIN_REPO_NAME="pytorch.git"
SUBMODULES_DIR="${CACHE_ROOT}/submodules"

mkdir -p "${CACHE_ROOT}" "${SUBMODULES_DIR}"

echo "=== [1/4] Cloning or updating PyTorch mirror ==="
if [ ! -d "${CACHE_ROOT}/${MAIN_REPO_NAME}" ]; then
  git clone --mirror "${MAIN_REPO_URL}" "${CACHE_ROOT}/${MAIN_REPO_NAME}"
else
  (cd "${CACHE_ROOT}/${MAIN_REPO_NAME}" && git remote update --prune)
fi

# --------------------------------------------------------------------
# Helper: mirror a single repo (and optionally its submodules recursively)
mirror_repo() {
  local repo_url="$1"
  local repo_name
  repo_name=$(basename "${repo_url}")
  local target="${SUBMODULES_DIR}/${repo_name}.git"

  if [ ! -d "${target}" ]; then
    echo "Creating mirror for ${repo_url}"
    git clone --mirror "${repo_url}" "${target}" || {
      echo "⚠️ Warning: failed to mirror ${repo_url}"
      return
    }
  else
    echo "Updating mirror for ${repo_url}"
    (cd "${target}" && git remote update --prune || echo "⚠️ Warning: failed to update ${repo_url}")
  fi

  # --- Recursively check for submodules in this mirrored repo ---
  local tmp_dir
  tmp_dir=$(mktemp -d)
  if git --git-dir="${target}" show HEAD:.gitmodules > "${tmp_dir}/.gitmodules" 2>/dev/null; then
    local sub_urls
    sub_urls=$(git config --file "${tmp_dir}/.gitmodules" --get-regexp '^submodule\..*\.url' | awk '{print $2}' | sort -u || true)
    if [ -n "${sub_urls}" ]; then
      echo "📦 Found $(echo "$sub_urls" | wc -l) submodules in ${repo_name}"
      for sub_url in ${sub_urls}; do
        mirror_repo "${sub_url}"
      done
    fi
  fi
  rm -rf "${tmp_dir}"
}
# --------------------------------------------------------------------

echo "=== [2/4] Extracting PyTorch submodules ==="
TMP_DIR=$(mktemp -d)
if git --git-dir="${CACHE_ROOT}/${MAIN_REPO_NAME}" show HEAD:.gitmodules > "${TMP_DIR}/.gitmodules" 2>/dev/null; then
  echo "Extracted .gitmodules from mirror"
else
  echo "No .gitmodules found in mirror, skipping submodules."
  exit 0
fi

# --------------------------------------------------------------------
echo "=== [3/4] Mirroring PyTorch submodules recursively ==="
SUBMODULE_URLS=$(git config --file "${TMP_DIR}/.gitmodules" --get-regexp '^submodule\..*\.url' | awk '{print $2}' | sort -u)
for url in ${SUBMODULE_URLS}; do
  mirror_repo "${url}"
done
# --------------------------------------------------------------------

echo "=== [4/4] Cleanup ==="
rm -rf "${TMP_DIR}"

echo "✅ Recursive git cache ready at ${CACHE_ROOT}"
