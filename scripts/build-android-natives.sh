#!/usr/bin/env bash
# build-android-natives.sh — build the two native libraries the pinned
# OpenCode release needs on Android and for which no official Android build
# exists, and stage them as Android build assets. See
# docs/plan/0002-android-arm64-build.md, Section 7.
#
#   libopentui.so          from anomalyco/opentui at tag v0.4.5, cross-compiled
#                          with Zig 0.15.2 for aarch64-linux-android, staged as
#                          the npm-shaped platform package
#                          @opentui/core-android-arm64.
#   librust_pty_arm64.so   from sursaone/bun-pty at the commit published as
#                          bun-pty 0.4.8, built with Cargo for the
#                          aarch64-linux-android target (Android API 24).
#
# Usage:
#   build-android-natives.sh <work-dir> <assets-dir>
#
# Outputs:
#   <assets-dir>/core-android-arm64/   platform package (package.json,
#                                      index.js, index.bun.js, index.d.ts,
#                                      libopentui.so)
#   <assets-dir>/librust_pty_arm64.so
#
# Environment:
#   ANDROID_NDK_HOME   path to an Android NDK. When unset, the newest NDK
#                      under ANDROID_HOME or the GitHub runner's default SDK
#                      location is used.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: build-android-natives.sh <work-dir> <assets-dir>" >&2
  exit 2
fi

WORK_DIR="$1"
ASSETS_DIR="$2"

OPENTUI_REPOSITORY="anomalyco/opentui"
OPENTUI_TAG="v0.4.5"
OPENTUI_VERSION="0.4.5"
BUN_PTY_REPOSITORY="sursaone/bun-pty"
BUN_PTY_COMMIT="41dd5b887f3f47d7c307fd93f828a75dbee97d5a"
ANDROID_API="24"
RUST_TARGET="aarch64-linux-android"
ZIG_TARGET="aarch64-linux-android"

mkdir -p "${WORK_DIR}" "${ASSETS_DIR}"

# ---------------------------------------------------------------------------
# libopentui (Zig)
# ---------------------------------------------------------------------------

OPENTUI_DIR="${WORK_DIR}/opentui"
if [[ ! -d "${OPENTUI_DIR}" ]]; then
  echo "natives: cloning ${OPENTUI_REPOSITORY} at ${OPENTUI_TAG}"
  git clone --quiet --depth 1 --branch "${OPENTUI_TAG}" \
    "https://github.com/${OPENTUI_REPOSITORY}.git" "${OPENTUI_DIR}"
fi

DESCRIBED="$(git -C "${OPENTUI_DIR}" describe --tags --exact-match)"
if [[ "${DESCRIBED}" != "${OPENTUI_TAG}" ]]; then
  echo "error: opentui checkout describes as ${DESCRIBED}, pin requires ${OPENTUI_TAG}" >&2
  exit 1
fi

echo "natives: building libopentui for ${ZIG_TARGET} with Zig $(zig version)"
(
  cd "${OPENTUI_DIR}/packages/core/src/zig"
  zig build "-Dtarget=${ZIG_TARGET}" -Doptimize=ReleaseFast
)

LIBOPENTUI="$(find "${OPENTUI_DIR}/packages/core/src/lib" -name 'libopentui.so' -type f | head -n 1)"
if [[ -z "${LIBOPENTUI}" ]]; then
  echo "error: zig build produced no libopentui.so" >&2
  exit 1
fi
echo "natives: libopentui built at ${LIBOPENTUI}"

CORE_PKG_DIR="${ASSETS_DIR}/core-android-arm64"
mkdir -p "${CORE_PKG_DIR}"
cp "${LIBOPENTUI}" "${CORE_PKG_DIR}/libopentui.so"

# The platform package mirrors the published @opentui/core-linux-arm64 0.4.5
# package file for file, with the Android identity substituted.
cat > "${CORE_PKG_DIR}/package.json" <<EOF
{
  "name": "@opentui/core-android-arm64",
  "version": "${OPENTUI_VERSION}",
  "description": "Prebuilt android-arm64 binaries for @opentui/core",
  "type": "module",
  "main": "index.js",
  "module": "index.js",
  "types": "index.d.ts",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/anomalyco/opentui",
    "directory": "packages/core"
  },
  "keywords": [
    "prebuild",
    "prebuilt"
  ],
  "exports": {
    ".": {
      "bun": "./index.bun.js",
      "import": "./index.js",
      "types": "./index.d.ts"
    }
  },
  "os": [
    "android"
  ],
  "cpu": [
    "arm64"
  ]
}
EOF

cat > "${CORE_PKG_DIR}/index.js" <<'EOF'
import { fileURLToPath } from "node:url"

export default fileURLToPath(new URL("./libopentui.so", import.meta.url))
EOF

cat > "${CORE_PKG_DIR}/index.bun.js" <<'EOF'
const module = await import("./libopentui.so", { with: { type: "file" } })

export default module.default
EOF

cat > "${CORE_PKG_DIR}/index.d.ts" <<'EOF'
declare const path: string
export default path
EOF

if [[ -f "${OPENTUI_DIR}/LICENSE" ]]; then
  cp "${OPENTUI_DIR}/LICENSE" "${CORE_PKG_DIR}/LICENSE"
fi

# ---------------------------------------------------------------------------
# bun-pty Rust library (Cargo)
# ---------------------------------------------------------------------------

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  SDK_ROOT="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
  ANDROID_NDK_HOME="$(ls -d "${SDK_ROOT}"/ndk/* 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [[ -z "${ANDROID_NDK_HOME:-}" || ! -d "${ANDROID_NDK_HOME}" ]]; then
  echo "error: no Android NDK found; set ANDROID_NDK_HOME" >&2
  exit 1
fi
echo "natives: using Android NDK at ${ANDROID_NDK_HOME}"

NDK_BIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin"
TARGET_CC="${NDK_BIN}/aarch64-linux-android${ANDROID_API}-clang"
TARGET_CXX="${NDK_BIN}/aarch64-linux-android${ANDROID_API}-clang++"
TARGET_AR="${NDK_BIN}/llvm-ar"
for TOOL in "${TARGET_CC}" "${TARGET_CXX}" "${TARGET_AR}"; do
  if [[ ! -x "${TOOL}" ]]; then
    echo "error: NDK tool missing: ${TOOL}" >&2
    exit 1
  fi
done

BUN_PTY_DIR="${WORK_DIR}/bun-pty"
if [[ ! -d "${BUN_PTY_DIR}" ]]; then
  echo "natives: cloning ${BUN_PTY_REPOSITORY}"
  git clone --quiet "https://github.com/${BUN_PTY_REPOSITORY}.git" "${BUN_PTY_DIR}"
fi
git -C "${BUN_PTY_DIR}" checkout --quiet "${BUN_PTY_COMMIT}"
ACTUAL_COMMIT="$(git -C "${BUN_PTY_DIR}" rev-parse HEAD)"
if [[ "${ACTUAL_COMMIT}" != "${BUN_PTY_COMMIT}" ]]; then
  echo "error: bun-pty checkout is at ${ACTUAL_COMMIT}, pin requires ${BUN_PTY_COMMIT}" >&2
  exit 1
fi

if ! rustup target list --installed | grep -qx "${RUST_TARGET}"; then
  echo "natives: adding Rust target ${RUST_TARGET}"
  rustup target add "${RUST_TARGET}"
fi

echo "natives: building rust-pty for ${RUST_TARGET}"
(
  cd "${BUN_PTY_DIR}/rust-pty"
  export CC_aarch64_linux_android="${TARGET_CC}"
  export CXX_aarch64_linux_android="${TARGET_CXX}"
  export AR_aarch64_linux_android="${TARGET_AR}"
  export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${TARGET_CC}"
  cargo build --release --target "${RUST_TARGET}"
)

LIBRUST_PTY="${BUN_PTY_DIR}/rust-pty/target/${RUST_TARGET}/release/librust_pty.so"
if [[ ! -f "${LIBRUST_PTY}" ]]; then
  echo "error: cargo build produced no librust_pty.so" >&2
  exit 1
fi
cp "${LIBRUST_PTY}" "${ASSETS_DIR}/librust_pty_arm64.so"
echo "natives: librust_pty_arm64.so staged"

echo "natives: done"
ls -la "${ASSETS_DIR}" "${CORE_PKG_DIR}"
