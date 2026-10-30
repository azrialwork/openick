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
      --no-progress       Plain output: no progress bar, spinner, or color

Environment:
  OPENICK_VERSION         Same as --version
  OPENICK_BIN_DIR         Same as --bin-dir
  OPENICK_DOWNLOAD_BASE   Download base URL override (mirrors); the layout
                          <base>/<tag>/<asset> must match GitHub Releases
  OPENICK_NO_PROGRESS     Set to disable the progress bar, spinner, and color
  NO_COLOR                Set to disable color

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
no_progress=false

# A minimal error printer is needed while parsing options, before the full
# interface below is set up; it is replaced by the styled one afterwards.
error() { printf 'Error: %s\n' "$*" >&2; }

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
    --no-progress)
      no_progress=true
      shift
      ;;
    *)
      error "Unknown option '$1' (see --help)"
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# User interface (Plan 0006, Locked Decision 10: full ASCII)
#
# Every glyph the installer prints is plain ASCII: the banner and the
# success panel use +, -, =, and |; the progress bar uses # and -; the
# spinner cycles |, /, -, and \. Animation renders only when standard
# output is a terminal; piped or logged output gets plain step lines.
# ---------------------------------------------------------------------------

term_cols=80
if [[ -t 1 ]]; then
  term_cols="$(tput cols 2>/dev/null || printf '80')"
fi
case "$term_cols" in
  ''|*[!0-9]*) term_cols=80 ;;
esac

ui_anim=true
ui_color=true
[[ -t 1 ]] || { ui_anim=false; ui_color=false; }
[[ -n "${NO_COLOR:-}" ]] && ui_color=false
if [[ "$no_progress" == true || -n "${OPENICK_NO_PROGRESS:-}" ]]; then
  ui_anim=false
  ui_color=false
fi

c_green=""
c_red=""
c_accent=""
c_dim=""
c_reset=""
if [[ "$ui_color" == true ]]; then
  c_green=$'\033[32m'
  c_red=$'\033[31m'
  c_accent=$'\033[38;5;214m'
  c_dim=$'\033[2m'
  c_reset=$'\033[0m'
fi

error() { printf '  %s[FAILED]%s %s\n' "$c_red" "$c_reset" "$*" >&2; }
note() { printf '  %s%s%s\n' "$c_dim" "$*" "$c_reset"; }

step_ok() {
  # step_ok <label> [detail]
  if [[ $# -ge 2 ]]; then
    printf '  %s[OK]%s %s %s(%s)%s\n' "$c_green" "$c_reset" "$1" "$c_dim" "$2" "$c_reset"
  else
    printf '  %s[OK]%s %s\n' "$c_green" "$c_reset" "$1"
  fi
}

print_banner() {
  printf '\n'
  if [[ "$term_cols" -ge 50 ]]; then
    printf '  +%s+\n' "$(printf '%44s' '' | tr ' ' '=')"
    printf '  | %-42s |\n' "Openick Installer"
    printf '  | %-42s |\n' "OpenCode for Linux and Android"
    printf '  +%s+\n' "$(printf '%44s' '' | tr ' ' '=')"
  else
    printf '  Openick Installer - OpenCode for Linux and Android\n'
  fi
  printf '\n'
}

spin_pid=""
spin_frames='|/-\'

spinner_start() {
  # spinner_start <label> : animate an indeterminate step on a terminal
  [[ "$ui_anim" == true ]] || return 0
  local label="$1"
  (
    local i=0
    while true; do
      printf '\r  [%s] %s ' "${spin_frames:$((i % 4)):1}" "$label"
      i=$((i + 1))
      sleep 0.12
    done
  ) &
  spin_pid=$!
}

spinner_stop() {
  [[ -n "$spin_pid" ]] || return 0
  kill "$spin_pid" 2>/dev/null || true
  wait "$spin_pid" 2>/dev/null || true
  spin_pid=""
  printf '\r\033[K'
}

file_size() {
  stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null || printf '0'
}

fmt_mb() {
  # fmt_mb <bytes> : print megabytes with one decimal, e.g. "34.8 MB"
  local tenths=$(( $1 * 10 / 1048576 ))
  printf '%d.%d MB' $((tenths / 10)) $((tenths % 10))
}

repeat_char() {
  # repeat_char <char> <count>
  printf '%*s' "$2" '' | tr ' ' "$1"
}

render_bar() {
  # render_bar <downloaded> <total> <start-seconds>
  local downloaded="$1" total="$2" start="$3"
  local elapsed=$((SECONDS - start))
  local width=28
  if [[ "$term_cols" -ge 100 ]]; then
    width=38
  elif [[ "$term_cols" -lt 70 ]]; then
    width=18
  fi
  if [[ "$total" -gt 0 ]]; then
    local pct=$((downloaded * 100 / total))
    if [[ "$pct" -gt 100 ]]; then pct=100; fi
    local filled=$((width * pct / 100))
    local bar=""
    bar+="$(repeat_char '#' "$filled")"
    bar+="$(repeat_char '-' $((width - filled)))"
    local rate=0 eta="--"
    if [[ "$elapsed" -gt 0 && "$downloaded" -gt 0 ]]; then
      rate=$((downloaded / elapsed))
    fi
    if [[ "$rate" -gt 0 && "$downloaded" -lt "$total" ]]; then
      eta="$(( (total - downloaded + rate - 1) / rate ))s"
    fi
    printf '\r\033[K  %s[%s]%s %3d%%  %s / %s  %s/s  ETA %s' \
      "$c_accent" "$bar" "$c_reset" "$pct" \
      "$(fmt_mb "$downloaded")" "$(fmt_mb "$total")" "$(fmt_mb "$rate")" "$eta"
  else
    printf '\r\033[K  %s[%s]%s %s downloaded' \
      "$c_accent" "$(repeat_char '#' 10)" "$c_reset" "$(fmt_mb "$downloaded")"
  fi
}

success_panel() {
  # success_panel <version-or-empty>
  local version="$1"
  local title="OpenCode installed"
  if [[ -n "$version" ]]; then
    title="OpenCode ${version} installed"
  fi
  local loc_line="Location: ${INSTALL_DIR}/${APP}"
  local run_line="Run:      ${APP}"
  local width=${#title}
  width=$((width + 5)) # account for the "[OK] " marker on the title line
  if [[ ${#loc_line} -gt "$width" ]]; then width=${#loc_line}; fi
  if [[ ${#run_line} -gt "$width" ]]; then width=${#run_line}; fi
  width=$((width + 4))
  if [[ "$width" -gt $((term_cols - 2)) || "$term_cols" -lt 50 ]]; then
    step_ok "$title"
    note "$loc_line"
    note "$run_line"
    return 0
  fi
  local border=""
  border="$(repeat_char '=' $((width - 2)))"
  printf '\n'
  printf '  +%s+\n' "$border"
  printf '  | %s[OK]%s %-*s |\n' "$c_green" "$c_reset" $((width - 9)) "$title"
  printf '  | %-*s |\n' $((width - 4)) "$loc_line"
  printf '  | %-*s |\n' $((width - 4)) "$run_line"
  printf '  +%s+\n' "$border"
  printf '\n'
}

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

download_with_progress() {
  # download_with_progress <url> <output-file> <display-name>
  # On a terminal with curl, show the ASCII progress bar; everywhere else
  # this is exactly download().
  local url="$1" out="$2" name="$3"
  if [[ "$ui_anim" != true ]] || ! command -v curl >/dev/null 2>&1; then
    download "$url" "$out"
    return
  fi
  local total=0
  total="$(curl -fsSIL "$url" 2>/dev/null | tr 'A-Z' 'a-z' | awk -F': *' '$1 == "content-length" { v = $2 } END { gsub(/\r/, "", v); print v + 0 }' || true)"
  case "$total" in
    ''|*[!0-9]*) total=0 ;;
  esac
  if [[ "$total" -gt 0 ]]; then
    note "Downloading ${name} ($(fmt_mb "$total"))"
  else
    note "Downloading ${name}"
  fi
  curl -fsSL -o "$out" "$url" &
  local pid=$!
  local start=$SECONDS
  local downloaded=0
  while kill -0 "$pid" 2>/dev/null; do
    downloaded="$(file_size "$out")"
    render_bar "$downloaded" "$total" "$start"
    sleep 0.15
  done
  local rc=0
  wait "$pid" || rc=$?
  downloaded="$(file_size "$out")"
  render_bar "$downloaded" "$total" "$start"
  printf '\n'
  local elapsed=$((SECONDS - start))
  if [[ "$rc" -eq 0 ]]; then
    local rate=0
    if [[ "$elapsed" -gt 0 ]]; then rate=$((downloaded / elapsed)); fi
    step_ok "Download" "$(fmt_mb "$downloaded") in ${elapsed}s, avg $(fmt_mb "$rate")/s"
  fi
  return "$rc"
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
# Run
# ---------------------------------------------------------------------------

print_banner

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
  platform_desc="Android arm64 (Termux)"
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
  libc_desc="glibc"
  if [[ "$is_musl" == true ]]; then libc_desc="musl"; fi

  target="linux-${arch}"
  avx_desc=""
  if [[ "$arch" == "x64" ]]; then
    if grep -qwi avx2 /proc/cpuinfo 2>/dev/null; then
      avx_desc=", AVX2"
    else
      target="${target}-baseline"
      avx_desc=", no AVX2 (baseline)"
    fi
  fi
  if [[ "$is_musl" == true ]]; then
    target="${target}-musl"
  fi
  filename="${APP}-${target}.tar.gz"
  platform_desc="Linux ${arch}, ${libc_desc}${avx_desc}"
fi

step_ok "Platform" "$platform_desc"

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
  cp "$binary_path" "${INSTALL_DIR}/${APP}.tmp.$$"
  chmod 755 "${INSTALL_DIR}/${APP}.tmp.$$"
  mv "${INSTALL_DIR}/${APP}.tmp.$$" "${INSTALL_DIR}/${APP}"
  step_ok "Install" "${INSTALL_DIR}/${APP} (local binary)"
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
    spinner_start "Resolving the latest release"
    tag="$(fetch_stdout "https://api.github.com/repos/${REPO}/releases/latest" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
    spinner_stop
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
  if [[ -n "$requested_version" ]]; then
    step_ok "Release" "${tag}, pinned"
  else
    step_ok "Release" "${tag}, latest"
  fi

  if [[ -x "${INSTALL_DIR}/${APP}" ]]; then
    current="$("${INSTALL_DIR}/${APP}" --version 2>/dev/null || true)"
    if [[ "$current" == "$version" ]]; then
      step_ok "Install" "${APP} ${version} is already installed at ${INSTALL_DIR}/${APP}"
      exit 0
    fi
    if [[ -n "$current" ]]; then
      note "Replacing installed version ${current}."
    fi
  fi

  tmp_dir="$(mktemp -d)"
  trap 'spinner_stop; rm -rf "$tmp_dir"' EXIT

  if ! download_with_progress "${DOWNLOAD_BASE}/${tag}/${filename}" "${tmp_dir}/${filename}" "$filename"; then
    error "Failed to download ${filename} from release ${tag}."
    exit 1
  fi
  if ! download "${DOWNLOAD_BASE}/${tag}/SHA256SUMS" "${tmp_dir}/SHA256SUMS"; then
    error "Failed to download SHA256SUMS from release ${tag}."
    exit 1
  fi

  expected="$(awk -v f="$filename" '$2 == f || $2 == "./" f {print $1}' "${tmp_dir}/SHA256SUMS")"
  if [[ -z "$expected" ]]; then
    error "${filename} is not listed in the SHA256SUMS of release ${tag}."
    exit 1
  fi
  spinner_start "Verifying checksum"
  actual="$(sha256_of "${tmp_dir}/${filename}")"
  spinner_stop
  if [[ "$actual" != "$expected" ]]; then
    error "Checksum mismatch for ${filename} (expected ${expected}, got ${actual}). Aborting; nothing was installed."
    exit 1
  fi
  step_ok "Checksum" "SHA-256 verified"

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
  step_ok "Install" "${INSTALL_DIR}/${APP}"
fi

# ---------------------------------------------------------------------------
# PATH handling
# ---------------------------------------------------------------------------

if [[ ":${PATH}:" == *":${INSTALL_DIR}:"* ]]; then
  step_ok "PATH" "${INSTALL_DIR} is already on the PATH"
elif [[ "$no_modify_path" == true ]]; then
  note "PATH not modified (--no-modify-path)."
else
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
      step_ok "PATH" "${INSTALL_DIR} is already in ${config_file}"
    elif [[ -w "$config_file" ]]; then
      {
        printf '\n# opencode\n'
        printf '%s\n' "$path_command"
      } >> "$config_file"
      step_ok "PATH" "added ${INSTALL_DIR} to ${config_file}"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

reported_version="$("${INSTALL_DIR}/${APP}" --version 2>/dev/null || true)"
success_panel "$reported_version"
if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  note "Start a new shell, or run: export PATH=${INSTALL_DIR}:\$PATH"
fi
note "Run '${APP}' in a project directory to start."
