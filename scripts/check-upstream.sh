#!/usr/bin/env bash
# check-upstream.sh — detect the highest stable OpenCode v1.x.x release and
# compare it with the pin in upstream.json.
#
# Outputs (also appended to $GITHUB_OUTPUT when that variable is set):
#   current_tag=<tag from upstream.json>
#   latest_tag=<highest stable v1.x.x tag>
#   latest_sha=<commit SHA of latest_tag, empty when changed=false>
#   changed=true|false
#
# Exit codes:
#   0  detection succeeded; read the outputs
#   2  configuration or upstream data error
#   3  the highest upstream tag is lower than the pin; the pin never moves
#      backwards, so this is reported as an error
#
# Test hooks:
#   OPENICK_UPSTREAM_JSON  path to a pin file (default: ../upstream.json)
#   OPENICK_RELEASES_JSON  path to a saved GitHub releases API response; when
#                          set, the live API is not called
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PIN_FILE="${OPENICK_UPSTREAM_JSON:-${REPO_ROOT}/upstream.json}"

if [[ ! -f "${PIN_FILE}" ]]; then
  echo "error: pin file not found: ${PIN_FILE}" >&2
  exit 2
fi

REPOSITORY="$(jq -r '.repository' "${PIN_FILE}")"
CURRENT_TAG="$(jq -r '.tag' "${PIN_FILE}")"

if [[ -z "${REPOSITORY}" || -z "${CURRENT_TAG}" ]]; then
  echo "error: upstream.json must define repository and tag" >&2
  exit 2
fi

# Collect stable v1.x.x tag names.
if [[ -n "${OPENICK_RELEASES_JSON:-}" ]]; then
  RELEASES_JSON="$(cat "${OPENICK_RELEASES_JSON}")"
else
  RELEASES_JSON="$(gh api "repos/${REPOSITORY}/releases" --paginate)"
fi

LATEST_TAG="$(
  printf '%s' "${RELEASES_JSON}" \
    | jq -r '.[] | select(.draft == false and .prerelease == false) | .tag_name' \
    | grep -E '^v1\.[0-9]+\.[0-9]+$' \
    | sort -Vu \
    | tail -n 1 || true
)"

if [[ -z "${LATEST_TAG}" ]]; then
  echo "error: no stable v1.x.x release found for ${REPOSITORY}" >&2
  exit 2
fi

# Compare the pin with the detected tag.
HIGHEST="$(printf '%s\n%s\n' "${CURRENT_TAG}" "${LATEST_TAG}" | sort -V | tail -n 1)"
LOWEST="$(printf '%s\n%s\n' "${CURRENT_TAG}" "${LATEST_TAG}" | sort -V | head -n 1)"

CHANGED="false"
LATEST_SHA=""

if [[ "${LATEST_TAG}" == "${CURRENT_TAG}" ]]; then
  CHANGED="false"
elif [[ "${HIGHEST}" == "${LATEST_TAG}" && "${LOWEST}" == "${CURRENT_TAG}" ]]; then
  CHANGED="true"
else
  echo "error: detected tag ${LATEST_TAG} is lower than the pin ${CURRENT_TAG}" >&2
  exit 3
fi

# Resolve the commit SHA for a new tag: dereference annotated tags.
if [[ "${CHANGED}" == "true" && -z "${OPENICK_RELEASES_JSON:-}" ]]; then
  OBJECT_TYPE="$(gh api "repos/${REPOSITORY}/git/ref/tags/${LATEST_TAG}" --jq '.object.type')"
  OBJECT_SHA="$(gh api "repos/${REPOSITORY}/git/ref/tags/${LATEST_TAG}" --jq '.object.sha')"
  if [[ "${OBJECT_TYPE}" == "tag" ]]; then
    LATEST_SHA="$(gh api "repos/${REPOSITORY}/git/tags/${OBJECT_SHA}" --jq '.object.sha')"
  else
    LATEST_SHA="${OBJECT_SHA}"
  fi
fi

emit() {
  echo "$1"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "$1" >> "${GITHUB_OUTPUT}"
  fi
}

emit "current_tag=${CURRENT_TAG}"
emit "latest_tag=${LATEST_TAG}"
emit "latest_sha=${LATEST_SHA}"
emit "changed=${CHANGED}"
