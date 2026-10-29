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
ZIG_TARGET="aarch64-linux-android.${ANDROID_API}"

mkdir -p "${WORK_DIR}" "${ASSETS_DIR}"

# The Android NDK is resolved once, up front: the Rust build needs its
# toolchain, and the Zig build of libopentui needs its sysroot, which
# provides the Bionic libc the Zig toolchain cannot provide itself and
# the libdl stub library (Plan 0002, Section 7.1).
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  SDK_ROOT="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
  ANDROID_NDK_HOME="$(ls -d "${SDK_ROOT}"/ndk/* 2>/dev/null | sort -V | tail -n 1 || true)"
fi
if [[ -z "${ANDROID_NDK_HOME:-}" || ! -d "${ANDROID_NDK_HOME}" ]]; then
  echo "error: no Android NDK found; set ANDROID_NDK_HOME" >&2
  exit 1
fi
echo "natives: using Android NDK at ${ANDROID_NDK_HOME}"
NDK_SYSROOT="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
NDK_LIB_DIR="${NDK_SYSROOT}/usr/lib/aarch64-linux-android/${ANDROID_API}"
if [[ ! -d "${NDK_SYSROOT}" || ! -d "${NDK_LIB_DIR}" ]]; then
  echo "error: NDK sysroot layout not recognized under ${ANDROID_NDK_HOME}" >&2
  exit 1
fi

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "natives: applying the Android patch to the OpenTUI Zig build"
git -C "${OPENTUI_DIR}" apply "${SCRIPT_DIR}/opentui-zig-android.patch"

# Zig cannot see the NDK sysroot's arch-specific headers (asm/types.h and
# its siblings) through a plain libc file, so stage a merged include tree:
# the generic sysroot headers with the AArch64 header tree merged over
# them, as symlinks.
NDK_INCLUDE_DIR="${WORK_DIR}/ndk-include"
rm -rf "${NDK_INCLUDE_DIR}"
mkdir -p "${NDK_INCLUDE_DIR}"
cp -rs "${NDK_SYSROOT}/usr/include/." "${NDK_INCLUDE_DIR}/"
cp -rs "${NDK_SYSROOT}/usr/include/aarch64-linux-android/." "${NDK_INCLUDE_DIR}/"

ZIG_LIBC_FILE="${WORK_DIR}/ndk-libc.txt"
{
  echo "include_dir=${NDK_INCLUDE_DIR}"
  echo "sys_include_dir=${NDK_INCLUDE_DIR}"
  echo "crt_dir=${NDK_LIB_DIR}"
  echo "msvc_lib_dir="
  echo "kernel32_lib_dir="
  echo "gcc_dir="
} > "${ZIG_LIBC_FILE}"

echo "natives: building libopentui for ${ZIG_TARGET} with Zig $(zig version)"
(
  cd "${OPENTUI_DIR}/packages/core/src/zig"
  OPENICK_ANDROID_LIB_DIR="${NDK_LIB_DIR}" \
    zig build "-Dtarget=${ZIG_TARGET}" --libc "${ZIG_LIBC_FILE}" -Doptimize=ReleaseFast
)

LIBOPENTUI="$(find "${OPENTUI_DIR}/packages/core/src/zig/lib" -name 'libopentui.so' -type f | head -n 1)"
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

# termios 0.2.2 (a portable-pty dependency) has no Android OS target. Vendor
# the official crates.io archive, verify its index checksum, patch in the
# Android module (scripts/termios-android.patch), and substitute the crate
# through a [patch.crates-io] section. Plan 0002, Section 7.2.
TERMIOS_VERSION="0.2.2"
TERMIOS_SHA256="d5d9cf598a6d7ce700a4e6a9199da127e6819a61e64b68609683cc9a01b5683a"
TERMIOS_DIR="${WORK_DIR}/termios-${TERMIOS_VERSION}"
if [[ ! -d "${TERMIOS_DIR}" ]]; then
  echo "natives: vendoring termios ${TERMIOS_VERSION} from crates.io"
  curl -fsSL -o "${WORK_DIR}/termios.crate" \
    "https://static.crates.io/crates/termios/termios-${TERMIOS_VERSION}.crate"
  echo "${TERMIOS_SHA256}  ${WORK_DIR}/termios.crate" | sha256sum -c - > /dev/null
  mkdir -p "${WORK_DIR}/termios-extract"
  tar -xzf "${WORK_DIR}/termios.crate" -C "${WORK_DIR}/termios-extract"
  mv "${WORK_DIR}/termios-extract/termios-${TERMIOS_VERSION}" "${TERMIOS_DIR}"
  rm -rf "${WORK_DIR}/termios-extract"
fi
if [[ ! -f "${TERMIOS_DIR}/src/os/android.rs" ]]; then
  (
    cd "${TERMIOS_DIR}"
    patch -p1 < "${SCRIPT_DIR}/termios-android.patch" > /dev/null
  )
fi
if ! grep -q 'patch.crates-io' "${BUN_PTY_DIR}/rust-pty/Cargo.toml"; then
  {
    echo ""
    echo "[patch.crates-io]"
    echo "termios = { path = \"../termios-${TERMIOS_VERSION}\" }"
  } >> "${BUN_PTY_DIR}/rust-pty/Cargo.toml"
fi

echo "natives: building rust-pty for ${RUST_TARGET}"
(
  cd "${BUN_PTY_DIR}/rust-pty"
  export PATH="${NDK_BIN}:${PATH}"
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
