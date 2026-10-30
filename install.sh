#!/usr/bin/env bash
# install.sh - Install the Openick build of OpenCode from GitHub Releases.
#
#   curl -fsSL https://raw.githubusercontent.com/azrialwork/openick/main/install.sh | bash
#
# The script detects the platform, downloads the matching release archive,
# verifies it against the release's SHA256SUMS, and installs the opencode
# binary for the current user. See docs/plan/0006-install-script.md.
set -euo pipefail

APP="opencode"
REPO="azrialwork/openick"
DOWNLOAD_BASE="${OPENICK_DOWNLOAD_BASE:-https://github.com/${REPO}/releases/download}"

info() { printf '%s\n' "$*"; }
error() { printf 'Error: %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Openick installer for OpenCode

Usage: install.sh [options]

Options:
  -h, --help              Display this help message
  -v, --version <version> Install a specific release (e.g. 1.19.5 or v1.19.5)
  -b, --binary <path>     Install from a local binary instead of downloading
      --bin-dir <dir>     Install directory (default: ~/.opencode/bin,
                          or \$PREFIX/bin under Termux)
      --no-modify-path    Don't modify shell config files (.bashrc, etc.)

Environment:
  OPENICK_VERSION         Same as --version
  OPENICK_BIN_DIR         Same as --bin-dir
  OPENICK_DOWNLOAD_BASE   Download base URL override (mirrors); the layout
                          <base>/<tag>/<asset> must match GitHub Releases

Examples:
  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash -s -- --version 1.19.5

Supported targets: Linux x64 and arm64 (glibc or musl), Android arm64 (Termux).
EOF
}

requested_version="${OPENICK_VERSION:-}"
binary_path=""
bin_dir="${OPENICK_BIN_DIR:-}"
no_modify_path=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      if [[ -n "${2:-}" ]]; then
        requested_version="$2"
        shift 2
      else
        error "--version requires a version argument"
        exit 1
      fi
      ;;
    --version=*)
      requested_version="${1#*=}"
      shift
      ;;
    -b|--binary)
      if [[ -n "${2:-}" ]]; then
        binary_path="$2"
        shift 2
      else
        error "--binary requires a path argument"
        exit 1
      fi
      ;;
    --binary=*)
      binary_path="${1#*=}"
      shift
      ;;
    --bin-dir)
      if [[ -n "${2:-}" ]]; then
        bin_dir="$2"
        shift 2
      else
        error "--bin-dir requires a directory argument"
        exit 1
      fi
      ;;
    --bin-dir=*)
      bin_dir="${1#*=}"
      shift
      ;;
    --no-modify-path)
      no_modify_path=true
      shift
      ;;
    *)
      error "Unknown option '$1' (see --help)"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

fetch_stdout() {
  # fetch_stdout <url> : write the response body to stdout
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O - "$1"
  else
    error "curl or wget is required but neither is installed."
    return 1
  fi
}

download() {
  # download <url> <output-file>
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    error "curl or wget is required but neither is installed."
    return 1
  fi
}

sha256_of() {
  # sha256_of <file> : print the lowercase hex SHA-256 of a file
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

is_android=false
if [[ "$(uname -o 2>/dev/null || true)" == "Android" || -n "${TERMUX_VERSION:-}" ]]; then
  is_android=true
fi

raw_arch="$(uname -m)"
case "$raw_arch" in
  x86_64) arch="x64" ;;
  aarch64|arm64) arch="arm64" ;;
  *) arch="" ;;
esac

if [[ "$is_android" == true ]]; then
  if [[ "$arch" != "arm64" ]]; then
    error "Unsupported Android architecture: ${raw_arch}. Only arm64 is shipped."
    exit 1
  fi
  filename="${APP}-android-arm64.tar.gz"
else
  raw_os="$(uname -s)"
  if [[ "$raw_os" != "Linux" ]]; then
    error "Unsupported operating system: ${raw_os}. Openick ships Linux and Android (Termux) builds only."
    exit 1
  fi
  if [[ -z "$arch" ]]; then
    error "Unsupported architecture: ${raw_arch}. Only x64 and arm64 are shipped."
    exit 1
  fi

  is_musl=false
  if [[ -f /etc/alpine-release ]]; then
    is_musl=true
  elif command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl; then
    is_musl=true
  fi

  target="linux-${arch}"
  if [[ "$arch" == "x64" ]] && ! grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
    target="${target}-baseline"
  fi
  if [[ "$is_musl" == true ]]; then
    target="${target}-musl"
  fi
  filename="${APP}-${target}.tar.gz"
fi

# ---------------------------------------------------------------------------
# Install directory
# ---------------------------------------------------------------------------

if [[ -n "$bin_dir" ]]; then
  INSTALL_DIR="$bin_dir"
elif [[ "$is_android" == true && -n "${PREFIX:-}" ]]; then
  INSTALL_DIR="${PREFIX}/bin"
else
  INSTALL_DIR="${HOME}/.opencode/bin"
fi
mkdir -p "$INSTALL_DIR"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

installed_version=""

if [[ -n "$binary_path" ]]; then
  if [[ ! -f "$binary_path" ]]; then
    error "Binary not found at ${binary_path}"
    exit 1
  fi
  info "Installing ${APP} from ${binary_path}"
  cp "$binary_path" "${INSTALL_DIR}/${APP}.tmp.$$"
  chmod 755 "${INSTALL_DIR}/${APP}.tmp.$$"
  mv "${INSTALL_DIR}/${APP}.tmp.$$" "${INSTALL_DIR}/${APP}"
else
  if ! command -v tar >/dev/null 2>&1; then
    error "'tar' is required but not installed."
    exit 1
  fi
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    error "Neither 'sha256sum' nor 'shasum' is available, so the download cannot be verified. Install one of them, or install from a local binary with --binary."
    exit 1
  fi

  # Resolve and validate the version.
  version="${requested_version#v}"
  if [[ -z "$version" ]]; then
    tag="$(fetch_stdout "https://api.github.com/repos/${REPO}/releases/latest" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    version="${tag#v}"
    if [[ -z "$version" ]]; then
      error "Failed to resolve the latest release of ${REPO}."
      exit 1
    fi
  fi
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "'${requested_version}' is not a release version (expected e.g. 1.19.5)."
    exit 1
  fi
  if [[ "${version%%.*}" != "1" ]]; then
    error "Openick ships OpenCode v1 releases only; '${version}' is not a v1 release."
    exit 1
  fi
  tag="v${version}"

  if [[ -x "${INSTALL_DIR}/${APP}" ]]; then
    current="$("${INSTALL_DIR}/${APP}" --version 2>/dev/null || true)"
    if [[ "$current" == "$version" ]]; then
      info "${APP} ${version} is already installed at ${INSTALL_DIR}/${APP}."
      exit 0
    fi
    if [[ -n "$current" ]]; then
      info "Replacing installed version ${current}."
    fi
  fi

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  info "Downloading ${filename} from release ${tag}."
  download "${DOWNLOAD_BASE}/${tag}/${filename}" "${tmp_dir}/${filename}"
  download "${DOWNLOAD_BASE}/${tag}/SHA256SUMS" "${tmp_dir}/SHA256SUMS"

  expected="$(awk -v f="$filename" '$2 == f || $2 == "./" f {print $1}' "${tmp_dir}/SHA256SUMS")"
  if [[ -z "$expected" ]]; then
    error "${filename} is not listed in the SHA256SUMS of release ${tag}."
    exit 1
  fi
  actual="$(sha256_of "${tmp_dir}/${filename}")"
  if [[ "$actual" != "$expected" ]]; then
    error "Checksum mismatch for ${filename} (expected ${expected}, got ${actual}). Aborting; nothing was installed."
    exit 1
  fi
  info "Checksum verified."

  # The archive integrity is already proven by the checksum above. tar's
  # own exit status is not the success signal here: as root it can fail on
  # restoring the archive's uid/gid after extracting the file. The binary
  # existence check below decides success.
  tar -xzf "${tmp_dir}/${filename}" -C "$tmp_dir" || true
  if [[ ! -f "${tmp_dir}/${APP}" ]]; then
    error "The archive ${filename} does not contain an ${APP} binary."
    exit 1
  fi
  cp "${tmp_dir}/${APP}" "${INSTALL_DIR}/${APP}.tmp.$$"
  chmod 755 "${INSTALL_DIR}/${APP}.tmp.$$"
  mv "${INSTALL_DIR}/${APP}.tmp.$$" "${INSTALL_DIR}/${APP}"
  installed_version="$version"
fi

# ---------------------------------------------------------------------------
# PATH handling
# ---------------------------------------------------------------------------

if [[ "$no_modify_path" != true && ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  shell_name="$(basename "${SHELL:-bash}")"
  config_file=""
  path_command="export PATH=${INSTALL_DIR}:\$PATH"
  case "$shell_name" in
    fish)
      config_file="${HOME}/.config/fish/config.fish"
      path_command="fish_add_path ${INSTALL_DIR}"
      ;;
    zsh)
      config_file="${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    bash)
      config_file="${HOME}/.bashrc"
      ;;
    *)
      config_file="${HOME}/.profile"
      ;;
  esac

  if [[ -n "$config_file" ]]; then
    mkdir -p "$(dirname "$config_file")"
    touch "$config_file"
    if grep -Fxq "$path_command" "$config_file"; then
      info "${INSTALL_DIR} is already on the PATH in ${config_file}."
    elif [[ -w "$config_file" ]]; then
      {
        printf '\n# opencode\n'
        printf '%s\n' "$path_command"
      } >> "$config_file"
      info "Added ${INSTALL_DIR} to the PATH in ${config_file}."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

reported_version="$("${INSTALL_DIR}/${APP}" --version 2>/dev/null || true)"
info ""
if [[ -n "$reported_version" ]]; then
  info "Installed ${APP} ${reported_version} at ${INSTALL_DIR}/${APP}."
else
  info "Installed ${APP} at ${INSTALL_DIR}/${APP}."
fi
if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  info "Start a new shell, or run: export PATH=${INSTALL_DIR}:\$PATH"
fi
info "Run '${APP}' in a project directory to start."
