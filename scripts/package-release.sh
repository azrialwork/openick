#!/usr/bin/env bash
# package-release.sh — package built OpenCode CLI binaries into release
# assets that carry the upstream asset names exactly, add the materialized
# source archive and the delta manifest, and generate SHA256SUMS.
#
# Usage:
#   package-release.sh <tree-dir> <manifest-path> <output-dir>
#
# The tree must already contain a full build in
# packages/opencode/dist (produced by the upstream build script without
# --single). The tag and version are read from upstream.json.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: package-release.sh <tree-dir> <manifest-path> <output-dir>" >&2
  exit 2
fi

TREE_DIR="$1"
MANIFEST_PATH="$2"
OUTPUT_DIR="$3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TAG="$(jq -r '.tag' "${REPO_ROOT}/upstream.json")"
VERSION="$(jq -r '.version' "${REPO_ROOT}/upstream.json")"
DIST_DIR="${TREE_DIR}/packages/opencode/dist"

if [[ ! -d "${DIST_DIR}" ]]; then
  echo "error: build output not found: ${DIST_DIR}" >&2
  exit 1
fi

# Artifact-phase branding guard: naming pattern and binary version.
"${SCRIPT_DIR}/verify-branding.sh" "${TREE_DIR}" "${DIST_DIR}" "${VERSION}"

mkdir -p "${OUTPUT_DIR}"

# Map each build output directory to its upstream release asset name.
package_one() {
  local DIR_NAME="$1"
  local ASSET="$2"
  local SRC="${DIST_DIR}/${DIR_NAME}/bin"
  local STAGE
  STAGE="$(mktemp -d)"

  if [[ ! -d "${SRC}" ]]; then
    echo "error: missing build output directory: ${SRC}" >&2
    exit 1
  fi

  # The binary keeps its upstream file name: opencode.
  if [[ -f "${SRC}/opencode" ]]; then
    cp "${SRC}/opencode" "${STAGE}/opencode"
    chmod +x "${STAGE}/opencode"
  else
    echo "error: no opencode binary in ${SRC}" >&2
    exit 1
  fi

  case "${ASSET}" in
    *.tar.gz)
      tar -czf "${OUTPUT_DIR}/${ASSET}" -C "${STAGE}" .
      ;;
    *.zip)
      (cd "${STAGE}" && zip -q -X "${OUTPUT_DIR}/${ASSET}" ./*)
      ;;
    *)
      echo "error: unsupported asset extension: ${ASSET}" >&2
      exit 1
      ;;
  esac
  rm -rf "${STAGE}"
  echo "package: ${ASSET}"
}

package_one "opencode-linux-arm64"            "opencode-linux-arm64.tar.gz"
package_one "opencode-linux-arm64-musl"       "opencode-linux-arm64-musl.tar.gz"
package_one "opencode-linux-x64"              "opencode-linux-x64.tar.gz"
package_one "opencode-linux-x64-baseline"     "opencode-linux-x64-baseline.tar.gz"
package_one "opencode-linux-x64-musl"         "opencode-linux-x64-musl.tar.gz"
package_one "opencode-linux-x64-baseline-musl" "opencode-linux-x64-baseline-musl.tar.gz"

# Materialized source archive, without VCS data, dependencies, or build
# output.
tar -czf "${OUTPUT_DIR}/openick-source-${TAG}.tar.gz" \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='packages/opencode/dist' \
  --exclude='packages/app/dist' \
  -C "$(dirname "${TREE_DIR}")" "$(basename "${TREE_DIR}")"
echo "package: openick-source-${TAG}.tar.gz"

cp "${MANIFEST_PATH}" "${OUTPUT_DIR}/delta-manifest.json"
echo "package: delta-manifest.json"

# Checksums cover every asset and are verified before the run ends.
(
  cd "${OUTPUT_DIR}"
  sha256sum ./* > SHA256SUMS
  sha256sum -c SHA256SUMS > /dev/null
)
echo "package: SHA256SUMS verified"
