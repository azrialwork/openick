# Openick

Openick is a delta repository for [OpenCode](https://github.com/anomalyco/opencode).
It tracks the latest stable release of the official OpenCode v1.x.x line,
applies a small, auditable set of changes on top of it, and publishes the
result as a GitHub Release that carries the exact upstream version number.

Openick is not a fork. The `main` branch of this repository never contains the
OpenCode source tree. It contains only the difference between Openick and
upstream, plus the automation that builds and releases from that difference.

## The OpenCode Product Is Unmodified in Name and Brand

Every Openick release ships the official OpenCode binary under its original
name, with its original branding, icons, package names, and release asset
names. An automated branding guard runs on every build and fails the pipeline
if a patch or an overlay file touches a protected brand asset or renames the
binary. See `scripts/verify-branding.sh`.

## How It Works

1. **Pin.** `upstream.json` records the upstream repository, the tracked tag,
   and the exact commit SHA. The current pin is OpenCode `v1.19.5`.
2. **Check.** A GitHub Actions workflow runs every six hours. It selects the
   highest stable `v1.x.x` release from `anomalyco/opencode` and compares it
   with the pin. An unchanged pin ends the run with no commits and no noise.
3. **Materialize.** For a new release, the workflow clones the upstream tag,
   applies the patch stack from `patches/`, copies the overlay tree from
   `overlay/`, and records every applied change in a delta manifest.
4. **Validate.** The materialized tree must pass four gates: clean patch
   application, the branding guard, a smoke build of the CLI, and a version
   check against the built binary.
5. **Auto-merge.** A fully validated pin update is committed directly to
   `main` by the workflow. No pull request and no human approval are involved
   in a routine upstream update.
6. **Release.** The release workflow builds the OpenCode CLI for Linux
   (every Linux variant the upstream build defines), packages the binaries
   under the upstream asset names, and publishes a GitHub Release whose tag
   is identical to the upstream tag. The release also carries the
   materialized source archive, the delta manifest, and a `SHA256SUMS`
   checksum file.
7. **Android build.** A separate workflow builds one additional target,
   Android ARM64 (Bionic), entirely on GitHub Actions, and publishes it to
   the same release as the asset `opencode-android-arm64.tar.gz`. The
   native libraries this target needs are built in the workflow from their
   pinned upstream sources. See `docs/plan/0002-android-arm64-build.md`.

Openick builds for Linux and Android only, and its shell layer runs Bash
only. The delta deletes the Windows and macOS code and every other shell
from the materialized source; it does not hide or disable them. See
`docs/plan/0003-linux-android-bash-only.md`.

The binary has no self-update feature: the upstream `opencode upgrade`
command, its update checks, and its update notifications are deleted by
the delta. New versions of the software ship as new Openick releases.
See `docs/plan/0004-remove-update-upgrade.md`.

The binary ships exactly two entry points: the interactive TUI and
`opencode run`. Every other upstream mode and command — the web
interface and its embedded UI, the standalone server, the ACP editor
protocol, the GitHub Actions agent, and the one-shot management
commands — is deleted by the delta. See
`docs/plan/0005-tui-and-run-only.md`.

A patch that no longer applies to a new upstream release blocks the update.
The pin stays on the previous version, and the workflow opens an issue that
names the failing patch and the target release.

## Repository Layout

| Path | Purpose |
| --- | --- |
| `upstream.json` | The upstream pin: repository, tag, version, and commit SHA. |
| `patches/` | Numbered patches applied to the upstream tree, in filename order. |
| `overlay/` | Whole files added to or replaced in the upstream tree, mirroring its layout. |
| `scripts/` | Detection, materialization, branding guard, and packaging scripts. |
| `.github/workflows/` | The six-hour check, the validation workflow, the release workflow, and the Android build workflow. |
| `docs/plan/` | Numbered plan files. One file covers one context and states decisions without alternatives. |

## Releases

Releases are published on the
[Releases page](https://github.com/azrialwork/openick/releases). The tag of
each release matches the upstream OpenCode release it is built from: Openick
`v1.19.5` is OpenCode `v1.19.5` plus the delta contained in this repository at
the pin commit. Each release states the upstream commit SHA, lists every patch
and overlay file with digests in `delta-manifest.json`, and provides
`SHA256SUMS` for every asset.

Openick releases contain the OpenCode CLI only. Desktop installers are built
and signed by the upstream project and are available from the
[upstream releases](https://github.com/anomalyco/opencode/releases).

Each release also carries an Android ARM64 build of the CLI,
`opencode-android-arm64.tar.gz`, which runs natively on Android (Bionic),
for example inside Termux on an ARM64 device. It is the same OpenCode
binary, built for the Android target under
`docs/plan/0002-android-arm64-build.md`.

## Documentation and Governance

The foundation and operating rules of this repository are defined in
[Plan 0001 — Openick Delta Repository](docs/plan/0001-openick-delta-repository.md).
Contributors and automated agents follow [AGENTS.md](AGENTS.md). Every commit
in this repository is atomic: one logical change per commit, independently
revertible, with the automated synchronization commit touching `upstream.json`
only.

## License

OpenCode is distributed under the MIT License by its authors. The delta,
automation, and documentation in this repository are provided for use with the
upstream project and remain subject to the upstream license terms where they
apply to upstream material.
