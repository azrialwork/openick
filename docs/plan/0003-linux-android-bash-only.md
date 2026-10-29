# Plan 0003 — Linux and Android Only, Bash Only: Platform Pruning of the Delta

| Field | Value |
| --- | --- |
| Plan ID | 0003 |
| File | `docs/plan/0003-linux-android-bash-only.md` |
| Status | Active |
| Created | 2026-10-29 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plan | `docs/plan/0002-android-arm64-build.md` (the Android target this plan retains) |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: restricting the build to Linux and Android targets with Bash as the only shell, by deleting the other platforms' code from the materialized source. The delta foundation is governed by Plan 0001 and the Android native builds by Plan 0002; neither is restated here. |

## 1. Purpose

Openick builds and ships exactly two platform families: Linux (the full set of
Linux variants the upstream build already produces) and Android ARM64 (Plan
0002). The terminal and shell layer runs Bash and nothing else. Code for every
other platform (Windows, macOS) and every other shell is deleted from the
materialized source tree by the delta. It is not hidden behind flags, not
disabled at runtime, and not merely excluded by the bundler: it is removed.

Verified facts this plan is built on, established by measurement against the
pinned release and by controlled experiments with the pinned toolchain
(Bun 1.4.4):

- Lines of bundled source (`packages/opencode/src`, `packages/core/src`,
  `packages/tui/src`) that mention `win32`, `darwin`, `powershell`, `pwsh`, or
  `cmd.exe` total about 11 KB of 4.8 MB (0.23 percent), spread over 41 files
  and 107 `process.platform` expressions. The pruning surface is small but
  wide.
- The bundler already folds direct `process.platform` branch comparisons per
  compile target (verified empirically with marker probes, with and without
  minification), so most branch code never reaches the current binaries. The
  dead code that genuinely remains in the binaries is concentrated in three
  places: platform-keyed data tables (the LSP download tables and the ripgrep
  platform map), one unconditionally imported module
  (`packages/tui/src/terminal-win32.ts`), and the dynamically referenced shell
  registry in `packages/core/src/shell.ts`. This plan removes all three, and
  every other occurrence, from the source.
- Android is not Linux at runtime: `process.platform` is `"android"` on
  Bionic and `"linux"` on Linux. Shared POSIX code paths serve both values and
  are retained.
- The expected binary size effect is under one percent. The owner has
  accepted this; the purpose of the plan is that the shipped code contains
  nothing for platforms and shells the project does not support.

## 2. Locked Decisions

1. **Targets.** The upstream build script's target list keeps every Linux
   entry it has today (x64, x64 baseline, arm64; glibc and musl) and loses
   every `darwin` and `win32` entry. The Android target of Plan 0002 is
   unchanged. A default build therefore produces Linux targets only.
2. **Deletion, not hiding.** All Windows- and macOS-specific code in the
   bundled source trees is deleted by patches. No feature flag, environment
   variable, or runtime switch may re-enable it.
3. **Bash only.** The shell layer resolves every shell request to Bash. The
   shell registry keeps only its Bash entry. Argument builders, environment
   sourcing logic, and selection fallbacks for fish, zsh, dash, ksh, sh, nu,
   cmd, PowerShell, and pwsh are deleted. A configured or inherited shell name
   that is not Bash does not change the outcome: commands run in Bash.
4. **Pruning scope.** The patches cover the bundled source trees
   (`packages/opencode/src`, `packages/core/src`, `packages/tui/src`) and the
   upstream build script. Upstream tests, documentation, and packages that are
   not bundled into the CLI are untouched; they are not part of the shipped
   binary.
5. **Patch organization.** The pruning ships as patches `0003` to `0007`, one
   context each, applied after patches `0001` and `0002` in filename order:
   build targets, the shell layer, the TUI Windows module, platform data
   tables, and the remaining platform branches.
6. **Packaging.** `scripts/package-release.sh` packages the six Linux
   archives only. The darwin and windows packaging entries are deleted.
7. **Republication of the pinned release.** The `v1.19.5` release is
   republished under this plan: `.github/workflows/release.yml` gains a
   `force` dispatch input (default `false`); with `force=true` an existing
   release for the pin is deleted (its tag is preserved) and the standard
   release flow proceeds. The Android workflow is then dispatched with
   `publish=true` exactly as in Plan 0002, re-adding the Android asset and
   regenerating `SHA256SUMS`. The final release contains ten assets: six Linux
   archives, `opencode-android-arm64.tar.gz`, the source archive,
   `delta-manifest.json`, and `SHA256SUMS`. No darwin or windows asset
   remains.
8. **Branding.** `scripts/verify-branding.sh` is not modified. The OpenCode
   binary name, branding, and asset naming rules of Plan 0001 are unchanged;
   Linux and Android assets keep their upstream names.
9. **Forward maintenance is accepted.** These patches touch files upstream
   changes frequently (the LSP definitions most of all). When a future
   upstream release makes a pruning patch fail to apply, Plan 0001's standing
   rule governs: the pin stays, a marker issue opens, and the patch is rebased
   manually. This recurring cost is a known and accepted consequence of this
   plan.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project Manager
(plan, packaging, workflow, documentation), Programmer (the patches), Quality
Control (typecheck, smoke builds, workflow gates), Auditor (release audit and
acceptance record).

## 4. Scope

### 4.1 In scope

- Patches `0003`–`0007` and their registration in `patches/README.md`.
- `scripts/package-release.sh` (Linux entries only).
- `.github/workflows/release.yml` (the `force` input only).
- Republication of the pinned release and its audit.
- The on-device Android verification of Section 8, gate 4.

### 4.2 Out of scope

- The Android native libraries and workflow of Plan 0002 (unchanged).
- The embedded web UI and the models.dev snapshot (platform-agnostic content;
  not dead code under this plan's definition).
- Any change to supported Linux variants, architectures, or libc flavors.
- Upstream test suites and documentation inside the materialized tree.

## 5. Delta Components

### 5.1 Patch 0003 — Build targets: Linux only

`packages/opencode/script/build.ts`: every `darwin` and `win32` entry is
deleted from the target list. The macOS re-signing step and the Windows
`bunfs` root distinction lose their subjects and are deleted with them. The
`--android` mode of patch `0001` is untouched.

### 5.2 Patch 0004 — Shell layer: Bash only

`packages/core/src/shell.ts` is reduced to Bash: the registry keeps the Bash
entry only; shell resolution returns Bash (located on the `PATH`, with
`/bin/bash` as the final fallback); the Windows candidate chain, the Git Bash
lookup, the macOS default, and the per-shell argument builders for all other
shells are deleted. Callers in `packages/core/src/pty.ts`,
`packages/core/src/tool/bash.ts`, `packages/opencode/src/tool/shell.ts`, and
`packages/opencode/src/cli/cmd/run.ts` (and any other file the Programmer
finds referencing the removed surface) are simplified to the Bash path.

### 5.3 Patch 0005 — TUI Windows terminal module

`packages/tui/src/terminal-win32.ts` is deleted, together with its import and
both call sites in `packages/tui/src/app.tsx`.

### 5.4 Patch 0006 — Platform data tables

`packages/opencode/src/lsp/server.ts`: every per-LSP download and install
branch for darwin and win32 is deleted; the Linux entries remain, and the
extension and executable-suffix logic collapses to the POSIX form.
`packages/core/src/ripgrep/binary.ts`: the platform map keeps the Linux
entries only, and the `rg.exe` distinctions are deleted.

### 5.5 Patch 0007 — Remaining platform branches

Every remaining `win32` or `darwin` branch in the bundled source trees is
deleted and the surrounding expression simplified to its Linux/Android form:
`.exe` and `.cmd` suffix choices, `npm.cmd`, Windows path handling
(`path.win32`), the macOS managed-configuration paths, archive format choices,
watcher and process-spawner branches, and equivalent sites the Programmer's
inventory lists. After this patch, a search of the three bundled source trees
for `win32`, `darwin`, `powershell`, `pwsh`, and `cmd.exe` returns no hits
outside comments that document the deletion where the Programmer judges such a
note necessary; the acceptance check is run on code, and any comment hit must
be individually justified in the patch header.

## 6. Packaging and Workflow Changes

- `scripts/package-release.sh`: the three darwin and three windows
  `package_one` entries are deleted. The script's remaining behavior
  (branding gate, source archive, manifest, checksums) is unchanged.
- `.github/workflows/release.yml`: a boolean `force` input, default `false`.
  When `true` and a release for the requested tag exists, the workflow deletes
  that release (the git tag is not deleted) and proceeds through the standard
  flow. When `false`, behavior is exactly as before.

## 7. Republication Procedure

1. Dispatch `release.yml` with `tag=v1.19.5` and `force=true`.
2. Dispatch `build-android.yml` with `tag=v1.19.5` and `publish=true`.
3. Audit per Section 8, gate 5.

## 8. Verification Gates

1. **Inventory check.** In the materialized tree with all patches applied,
   the Section 5.5 search returns no unjustified hits, and the build target
   list contains no `darwin` or `win32` entry.
2. **Typecheck.** The affected packages typecheck (`bun run typecheck` in
   `packages/opencode` and `packages/core`, or the repository's equivalent
   workspace command) with no new errors against the pinned baseline.
3. **Repository validation.** The `validate` workflow is green on `main` with
   the full delta.
4. **On-device Android gate.** The republished Android asset passes the Plan
   0002 device protocol on a real Android ARM64 device in Termux: `--version`,
   a healthy server with session creation, a full mock-model `opencode run`
   round trip, a shell tool invocation executed by Bash, and the TUI rendering
   in a PTY. The device is restored afterwards and the restore is verified by
   snapshot diff.
5. **Publication audit.** The republished release lists exactly the ten
   assets of Locked Decision 7; a fresh download of one Linux asset and of
   the Android asset verifies against the published `SHA256SUMS`; the Linux
   x64 binary runs and reports the pinned version.

## 9. Failure Handling

A patch that fails to apply, a typecheck regression, or a failed gate stops
the work at that gate. Fixes land as new atomic commits; this plan is
corrected in the same commit series when implementation exposes an error in
it, with the correction recorded in Section 10. The pinned release is
republished only after gates 1–3 pass, and the Android asset is republished
only after gate 4 passes on the staged artifact built by the same workflow
run definition, following the Plan 0002 staging protocol.

## 10. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-29 | Plan created. |

## 11. Acceptance Criteria

- [ ] Patches `0003`–`0007` exist, carry the standard patch headers, and are
  listed in `patches/README.md`.
- [ ] The materialized tree passes the Section 8 inventory check (gate 1).
- [ ] Typecheck passes for the affected packages (gate 2).
- [ ] The `validate` workflow is green on `main` with the full delta (gate 3).
- [ ] `scripts/package-release.sh` packages Linux archives only, and
  `release.yml` carries the `force` input with default `false`.
- [ ] The `v1.19.5` release is republished with exactly the ten assets of
  Locked Decision 7 and no darwin or windows asset (gate 5).
- [ ] The republished Linux x64 binary runs and reports version `1.19.5`.
- [ ] The republished Android asset passes the on-device gate, including the
  Bash shell check and the TUI rendering check, and the device restore diff
  is identical (gate 4).
- [ ] `README.md` describes the Linux-and-Android-only, Bash-only build.
