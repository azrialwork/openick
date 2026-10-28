#!/usr/bin/env bash
# verify-branding.sh — enforce the rule that the OpenCode binary and brand
# are never modified by the Openick delta.
#
# Usage:
#   verify-branding.sh <tree-dir>
#       Tree-phase checks: no patch or overlay path touches a protected brand
#       path, and the materialized packages/opencode/package.json keeps the
#       upstream name and bin fields.
#   verify-branding.sh <tree-dir> <dist-dir> <expected-version>
#       Adds the artifact-phase checks: every built artifact directory follows
#       the upstream naming pattern, and the native binary reports the
#       expected version.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 ]]; then
  echo "usage: verify-branding.sh <tree-dir> [<dist-dir> <expected-version>]" >&2
  exit 2
fi

TREE_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export OPENICK_TREE_DIR="${TREE_DIR}"
export OPENICK_REPO_ROOT="${REPO_ROOT}"

python3 - <<'PYEOF'
import fnmatch
import json
import os
import re
import subprocess
import sys

tree = os.environ["OPENICK_TREE_DIR"]
root = os.environ["OPENICK_REPO_ROOT"]
failures = []

PROTECTED = [
    "packages/desktop/icons/*",
    "packages/app/public/favicon*",
    "packages/app/public/apple-touch-icon*",
    "packages/console/app/public/favicon*",
    "packages/console/app/public/apple-touch-icon*",
]


def is_protected(path: str) -> bool:
    if any(fnmatch.fnmatch(path, pattern) for pattern in PROTECTED):
        return True
    # Any path segment that names a logo asset is protected.
    return any("logo" in segment.lower() for segment in path.split("/"))


touched = set()

# Paths touched by patches: collect the b/ side of every diff header.
patches_dir = os.path.join(root, "patches")
if os.path.isdir(patches_dir):
    for name in sorted(os.listdir(patches_dir)):
        if not name.endswith(".patch"):
            continue
        with open(os.path.join(patches_dir, name), encoding="utf-8", errors="replace") as fh:
            for line in fh:
                match = re.match(r"^\+\+\+ b/(.+)$", line.rstrip("\n"))
                if match:
                    touched.add(match.group(1))

# Paths provided by the overlay (its README.md is never copied).
overlay_dir = os.path.join(root, "overlay")
if os.path.isdir(overlay_dir):
    for dirpath, _dirs, files in os.walk(overlay_dir):
        for name in files:
            rel = os.path.relpath(os.path.join(dirpath, name), overlay_dir)
            if rel != "README.md":
                touched.add(rel)

for path in sorted(touched):
    if is_protected(path):
        failures.append(f"delta touches a protected brand path: {path}")

# The materialized package identity must match the upstream tag (HEAD).
pkg_path = os.path.join(tree, "packages/opencode/package.json")
if not os.path.isfile(pkg_path):
    failures.append("packages/opencode/package.json is missing from the materialized tree")
else:
    pristine = subprocess.run(
        ["git", "-C", tree, "show", "HEAD:packages/opencode/package.json"],
        capture_output=True, text=True,
    )
    if pristine.returncode != 0:
        failures.append("cannot read the pristine packages/opencode/package.json from the upstream checkout")
    else:
        before = json.loads(pristine.stdout)
        with open(pkg_path, encoding="utf-8") as fh:
            after = json.load(fh)
        for field in ("name", "bin"):
            if before.get(field) != after.get(field):
                failures.append(f"packages/opencode/package.json field '{field}' differs from upstream")

if failures:
    for failure in failures:
        print(f"branding guard: FAIL: {failure}", file=sys.stderr)
    sys.exit(1)

print("branding guard: tree phase passed")
PYEOF

# Artifact-phase checks, when a dist directory and a version are supplied.
if [[ $# -eq 3 ]]; then
  DIST_DIR="$2"
  EXPECTED_VERSION="$3"
  PATTERN='^opencode-(linux|darwin|windows)-(arm64|x64)(-baseline)?(-musl)?$'
  FOUND_NATIVE=""
  while IFS= read -r -d '' ENTRY; do
    NAME="$(basename "${ENTRY}")"
    if ! [[ "${NAME}" =~ ${PATTERN} ]]; then
      echo "branding guard: FAIL: artifact directory breaks the upstream naming pattern: ${NAME}" >&2
      exit 1
    fi
    if [[ -x "${ENTRY}/bin/opencode" ]]; then
      FOUND_NATIVE="${ENTRY}/bin/opencode"
    fi
  done < <(find "${DIST_DIR}" -mindepth 1 -maxdepth 1 -type d -print0)

  if [[ -z "${FOUND_NATIVE}" ]]; then
    echo "branding guard: FAIL: no runnable native opencode binary found in ${DIST_DIR}" >&2
    exit 1
  fi

  REPORTED="$("${FOUND_NATIVE}" --version | tr -d '[:space:]')"
  if [[ "${REPORTED}" != "${EXPECTED_VERSION}" ]]; then
    echo "branding guard: FAIL: binary reports version '${REPORTED}', expected '${EXPECTED_VERSION}'" >&2
    exit 1
  fi
  echo "branding guard: artifact phase passed (binary version ${REPORTED})"
fi
