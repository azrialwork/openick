# Plan 0006 — The install.sh Installer

| Field | Value |
| --- | --- |
| Plan ID | 0006 |
| File | `docs/plan/0006-install-script.md` |
| Status | Completed |
| Created | 2026-10-30 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plans | `docs/plan/0002-android-arm64-build.md`, `docs/plan/0003-linux-android-bash-only.md`, `docs/plan/0005-tui-and-run-only.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: a user-facing installer script that downloads the correct Openick release archive for the user's platform and installs the `opencode` binary. The delta foundation is governed by Plan 0001 and the release asset set by Plans 0002 and 0003; neither is restated here. |

## 1. Purpose

A user installs Openick with one command:

```sh
curl -fsSL https://raw.githubusercontent.com/azrialwork/openick/main/install.sh | bash
```

The script detects the platform, selects the matching archive from the
pinned GitHub release, verifies it against the release's published
`SHA256SUMS`, installs the `opencode` binary for the current user, and
puts it on the `PATH`. It is modeled on the upstream `install` script of
the pinned release and adapted to the surface this repository ships.

Verified facts this plan is built on:

- The release carries exactly seven binary archives (Plan 0003 and 0005
  audits): `opencode-linux-x64.tar.gz`,
  `opencode-linux-x64-baseline.tar.gz`, `opencode-linux-x64-musl.tar.gz`,
  `opencode-linux-x64-baseline-musl.tar.gz`,
  `opencode-linux-arm64.tar.gz`, `opencode-linux-arm64-musl.tar.gz`, and
  `opencode-android-arm64.tar.gz`. Each archive contains the single
  `opencode` binary at its root. `SHA256SUMS` covers every asset.
- The upstream installer of the pinned release establishes the
  conventions this script keeps: install directory `$HOME/.opencode/bin`,
  a `--version` option, a `--binary` option for installing from a local
  file, a `--no-modify-path` option, musl detection through
  `/etc/alpine-release` and the `ldd` banner, and the baseline variant
  for x64 processors without AVX2 (checked in `/proc/cpuinfo`).
- This repository publishes only v1 releases whose tags equal the
  upstream pin, so the latest release of this repository is always a v1
  release; resolving "latest" against this repository cannot select a
  v2 build. The Plan 0001 prohibition on `releases/latest` governs
  upstream synchronization and does not apply to this repository's own
  releases.

## 2. Locked Decisions

1. **Location and delivery.** The installer is `install.sh` at the
   repository root, served to users through the raw GitHub URL above. It
   is not a release asset; the ten-asset release set of Plans 0003 and
   0004 is unchanged.
2. **Targets mirror the delta.** Linux x64 and arm64 (glibc and musl,
   with the baseline variant for x64 processors without AVX2) and Android
   arm64 under Termux. Any other operating system or architecture is
   refused with a message naming the supported targets.
3. **Version selection.** With no option, the script installs the latest
   release of this repository. `--version <tag>` (with or without the
   leading `v`) or the `OPENICK_VERSION` environment variable pins a
   specific release. A requested major version other than 1 is refused.
4. **Checksum verification is mandatory.** The script downloads the
   release's `SHA256SUMS` and verifies the archive before extraction; a
   mismatch aborts the installation. A system without `sha256sum` or
   `shasum` cannot install from a download and is told so; the
   `--binary` path is the documented alternative there.
5. **Per-user installation, no privilege escalation.** The default
   install directory is `$HOME/.opencode/bin`; under Termux it is
   `$PREFIX/bin`, which is already on the Termux `PATH`. `--bin-dir` or
   `OPENICK_BIN_DIR` overrides the directory. Unless `--no-modify-path`
   is given, the script appends the `PATH` export to the user's shell
   configuration file when the directory is not already on the `PATH`.
6. **Local binary installs.** `--binary <path>` installs a local
   `opencode` binary with the same directory and `PATH` handling and no
   download, for offline and sideloaded installs.
7. **Mirror override.** `OPENICK_DOWNLOAD_BASE` replaces the default
   download base (`https://github.com/azrialwork/openick/releases/download`),
   so mirrors and local test fixtures with the same `<base>/<tag>/<asset>`
   layout work unchanged.
8. **Branding.** The script installs the binary under its upstream name
   `opencode` and does not rename, rebrand, or wrap it.
   `scripts/verify-branding.sh` is not modified.
9. **Repository automation is untouched.** No workflow, packaging script,
   patch, or overlay changes under this plan.
10. **Full ASCII interface.** Every character the installer prints is
    plain ASCII, and the script source itself is ASCII-only: the banner
    and the success panel are drawn with `+`, `-`, `=`, and `|`; the
    download progress bar uses `#` and `-`; the spinner cycles `|`, `/`,
    `-`, and `\`; completed steps are marked `[OK]` and failures
    `[FAILED]`. Color is used sparingly on terminals (green step results,
    red errors, one accent color for the progress bar) and is suppressed
    by `NO_COLOR`, by the `--no-progress` option, and by the
    `OPENICK_NO_PROGRESS` environment variable. Animation renders only
    when standard output is a terminal; output to a pipe or a log falls
    back to plain step lines. The interface change alters no install
    behavior of Decisions 1 to 9: platform detection, version rules,
    mandatory checksum verification, and failure semantics are unchanged,
    and the presentation code is isolated from the install logic.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project
Manager (plan, documentation), Programmer (the script), Quality Control
(the test runs of Section 6), Auditor (the completion record).

## 4. Scope

### 4.1 In scope

- `install.sh` at the repository root.
- The Install section of `README.md` carrying the one-line command.
- The local verification runs of Section 6.

### 4.2 Out of scope

- Any change to the release asset set, the workflows, or the packaging
  scripts.
- A Windows or macOS installer; the delta ships neither platform.
- Package-manager distributions (npm, Homebrew, distribution packages).

## 5. Script Behavior

1. Parse options: `-h`/`--help`, `-v`/`--version`, `-b`/`--binary`,
   `--bin-dir`, `--no-modify-path`.
2. Resolve the version (Locked Decision 3). For the latest release, read
   the tag from this repository's `releases/latest` API entry.
3. Detect the platform: `uname -s` and `uname -m`; Android through
   `uname -o` or the Termux environment; musl and AVX2 as in Section 1.
   Compose the archive name from the Section 1 matrix.
4. Download the archive and `SHA256SUMS` from `<base>/<tag>/` with `curl`
   (or `wget` when `curl` is absent), verify the checksum, extract to a
   temporary directory, and move the `opencode` binary into the install
   directory with mode `0755`. The temporary directory is removed on any
   exit.
5. Handle the `PATH` (Locked Decision 5) and print the installed version
   by running the installed binary's `--version`.
6. Present the run in the full ASCII interface of Locked Decision 10: a
   banner, one `[OK]` line per completed step, and, on a terminal, a
   live progress bar for the archive download showing percent,
   downloaded and total megabytes, transfer rate, and estimated time
   remaining when the total size is known.

## 6. Verification Gates

1. **Syntax.** `bash -n install.sh` passes.
2. **Real install.** On this machine (Linux x64, glibc), the script
   installs the current release from GitHub into a scratch directory;
   the installed binary reports the release version and the checksum
   verification passes.
3. **Simulated targets.** With a stubbed `uname` (and `ldd` where
   relevant) and a local mirror using the Locked Decision 7 layout, the
   script selects `opencode-android-arm64.tar.gz` for a Termux
   environment and `opencode-linux-arm64-musl.tar.gz` for a musl arm64
   environment, and installs into the Termux prefix directory in the
   Android case.
4. **Checksum failure.** Against a mirror whose archive does not match
   its `SHA256SUMS`, the script aborts and installs nothing.
5. **Repository gates.** `./scripts/materialize.sh` completes against the
   pinned tag and `./scripts/verify-branding.sh` passes, per the
   repository's validation-before-merge rules.

## 7. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-30 | Plan created. |
| 2026-10-30 | Two defects found by the gate 2 real-install run and fixed in the same series: the published `SHA256SUMS` prefixes asset names with `./`, so the checksum lookup now accepts both the bare name and the `./`-prefixed name; and `tar` extraction no longer decides success by its exit status, because as root it fails on restoring the archive's uid/gid after extracting the file — the checksum (verified before extraction) proves the archive, and the binary existence check decides success. |
| 2026-10-30 | Plan completed. All gates pass: `bash -n` is clean; the real install from GitHub into a scratch directory verifies the checksum, installs, and reports 1.19.5, and a rerun reports the version as already installed; the simulated Termux run installs `opencode-android-arm64.tar.gz` into the stubbed `$PREFIX/bin` with the installed binary's SHA-256 identical to the archive's binary, and the simulated musl arm64 run (stubbed `uname` and `ldd`) selects and installs `opencode-linux-arm64-musl.tar.gz`; against a corrupted mirror archive the script aborts with a checksum error and installs nothing; the `--binary` path installs a local binary that reports 1.19.5; `materialize.sh` completes against the pin and `verify-branding.sh` passes. |
| 2026-10-30 | Amendment: Locked Decision 10 locks a full ASCII interface for the installer (ASCII banner, step markers, progress bar, spinner, and success panel; terminal-only animation with plain fallbacks), at the repository owner's direction. No install behavior changes. The acceptance criterion for the interface is added below and is checked when the amendment's gates pass. |

## 8. Acceptance Criteria

- [x] `install.sh` exists at the repository root and passes gate 1.
- [x] The real-install gate passes (gate 2).
- [x] The simulated-target gates pass (gate 3).
- [x] The checksum-failure gate passes (gate 4).
- [x] The repository gates pass (gate 5).
- [x] `README.md` carries an Install section with the one-line command.
- [ ] The full ASCII interface (Locked Decision 10) is implemented: the
  script source and all of its output are ASCII-only, the terminal run
  shows the progress bar, and the plain fallbacks work.
