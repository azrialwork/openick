#!/usr/bin/env bash
# materialize.sh — build the full source tree for the pinned upstream
# release by applying the Openick delta (patches, then overlay) to a clean
# upstream checkout, and emit delta-manifest.json describing the result.
#
# Usage:
#   materialize.sh <work-dir>
#
# Outputs:
#   <work-dir>/tree/              the materialized source tree
#   <work-dir>/delta-manifest.json
#
# Environment:
#   OPENICK_UPSTREAM_JSON  path to a pin file (default: ../upstream.json)
#   OPENICK_UPSTREAM_DIR   path to an existing clean upstream checkout to
#                          copy instead of cloning (used by local validation)
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: materialize.sh <work-dir>" >&2
  exit 2
fi

WORK_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PIN_FILE="${OPENICK_UPSTREAM_JSON:-${REPO_ROOT}/upstream.json}"

REPOSITORY="$(jq -r '.repository' "${PIN_FILE}")"
TAG="$(jq -r '.tag' "${PIN_FILE}")"
VERSION="$(jq -r '.version' "${PIN_FILE}")"
COMMIT="$(jq -r '.commit' "${PIN_FILE}")"

TREE_DIR="${WORK_DIR}/tree"
mkdir -p "${WORK_DIR}"

if [[ -n "${OPENICK_UPSTREAM_DIR:-}" ]]; then
  echo "materialize: copying local upstream checkout ${OPENICK_UPSTREAM_DIR}"
  cp -a "${OPENICK_UPSTREAM_DIR}" "${TREE_DIR}"
  chmod -R u+w "${TREE_DIR}"
  git -C "${TREE_DIR}" checkout --quiet -- . 2>/dev/null || true
  git -C "${TREE_DIR}" clean --quiet -fdx 2>/dev/null || true
else
  echo "materialize: cloning ${REPOSITORY} at ${TAG}"
  git clone --quiet --depth 1 --branch "${TAG}" "https://github.com/${REPOSITORY}.git" "${TREE_DIR}"
fi

ACTUAL_COMMIT="$(git -C "${TREE_DIR}" rev-parse HEAD)"
if [[ "${ACTUAL_COMMIT}" != "${COMMIT}" ]]; then
  echo "error: upstream checkout is at ${ACTUAL_COMMIT}, pin requires ${COMMIT}" >&2
  exit 1
fi

# Apply the patch stack in filename order.
shopt -s nullglob
PATCHES=("${REPO_ROOT}"/patches/[0-9]*.patch)
for PATCH in "${PATCHES[@]}"; do
  echo "materialize: applying patch $(basename "${PATCH}")"
  git -C "${TREE_DIR}" apply --index "${PATCH}"
done

# Copy the overlay tree, excluding its README.md.
if [[ -d "${REPO_ROOT}/overlay" ]]; then
  (
    cd "${REPO_ROOT}/overlay"
    find . -type f ! -path './README.md' -print0 \
      | while IFS= read -r -d '' REL; do
          echo "materialize: overlay ${REL#./}"
          cp --parents "${REL}" "${TREE_DIR}"
        done
  )
fi

# Branding guard, tree phase.
"${SCRIPT_DIR}/verify-branding.sh" "${TREE_DIR}"

# Delta manifest with SHA-256 digests for provenance and audit.
export OPENICK_REPO_ROOT="${REPO_ROOT}"
export OPENICK_MANIFEST_PATH="${WORK_DIR}/delta-manifest.json"
export OPENICK_PIN_REPOSITORY="${REPOSITORY}"
export OPENICK_PIN_TAG="${TAG}"
export OPENICK_PIN_VERSION="${VERSION}"
export OPENICK_PIN_COMMIT="${COMMIT}"

python3 - <<'PYEOF'
import hashlib
import json
import os

root = os.environ["OPENICK_REPO_ROOT"]


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


patches = []
patches_dir = os.path.join(root, "patches")
if os.path.isdir(patches_dir):
    for name in sorted(os.listdir(patches_dir)):
        if name.endswith(".patch"):
            patches.append({"file": f"patches/{name}", "sha256": digest(os.path.join(patches_dir, name))})

overlay = []
overlay_dir = os.path.join(root, "overlay")
if os.path.isdir(overlay_dir):
    for dirpath, _dirs, files in os.walk(overlay_dir):
        for name in sorted(files):
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, overlay_dir)
            if rel != "README.md":
                overlay.append({"file": rel, "sha256": digest(full)})
    overlay.sort(key=lambda item: item["file"])

manifest = {
    "repository": os.environ["OPENICK_PIN_REPOSITORY"],
    "tag": os.environ["OPENICK_PIN_TAG"],
    "version": os.environ["OPENICK_PIN_VERSION"],
    "commit": os.environ["OPENICK_PIN_COMMIT"],
    "branding_guard": "passed",
    "patches": patches,
    "overlay": overlay,
}

with open(os.environ["OPENICK_MANIFEST_PATH"], "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, indent=2, sort_keys=True)
    fh.write("\n")

print(f"materialize: manifest written with {len(patches)} patch(es) and {len(overlay)} overlay file(s)")
PYEOF

echo "materialize: done at ${TREE_DIR}"
