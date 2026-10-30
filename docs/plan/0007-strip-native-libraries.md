# Plan 0007 — Stripped Native Libraries

| Field | Value |
| --- | --- |
| Plan ID | 0007 |
| File | `docs/plan/0007-strip-native-libraries.md` |
| Status | In progress |
| Created | 2026-10-30 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plans | `docs/plan/0002-android-arm64-build.md`, `docs/plan/0003-linux-android-bash-only.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: removing symbol and debug data from the native libraries embedded in the shipped binaries. Binary size work on the JavaScript bundle and the models snapshot is a separate context and is not covered here. |

## 1. Purpose

The published Linux x64 binary is 176,740,528 bytes. Its single largest
patchable component is the embedded OpenTUI native library: the
`libopentui.so` that the bundler embeds from the `@opentui/core` platform
package is 13,745,312 bytes, and roughly ten megabytes of it are symbol
and debug data that the runtime never uses. Stripping that library
shrinks every shipped binary by about ten megabytes with no functional
change.

Verified facts this plan is built on (all measured on 2026-10-30):

- Stripping the Linux x64 `libopentui.so` with `strip` reduces it from
  13,745,312 to 3,710,056 bytes; the stripped library keeps its full
  dynamic symbol table (1,834 defined symbols), which is what the
  loader resolves at runtime.
- A prototype binary built with the stripped library is 166,705,328
  bytes (down from 176,740,528), passes the build's `--version` smoke
  test, and its TUI renders normally in a PTY.
- In the compressed release archive the same strip is worth 3,597,460
  down to 827,909 bytes for this one file.
- The x86_64 GNU `strip` on the build host cannot process AArch64 ELF
  files ("Unable to recognise the format"), so cross-target stripping
  requires `llvm-strip`; the Android NDK's `llvm-strip` reduces the
  AArch64 Linux `libopentui.so` from 13,995,736 to 3,578,088 bytes.
- Stripping the compiled `opencode` binary itself is destructive and
  nearly worthless: it removes only 52 KB and destroys the embedded
  payload, after which the file falls back to bare Bun behavior. The
  binary itself is therefore never stripped under this plan.

## 2. Locked Decisions

1. **Every embedded `libopentui.so` is stripped.** For each build
   target, the platform package's `libopentui.so` is stripped of symbol
   and debug data immediately before that target's bundle step. This
   covers all Linux targets (glibc and musl, x64 and arm64) and the
   staged Android platform package of Plan 0002.
2. **The Android PTY library is stripped at the same place.** The
   `librust_pty_arm64.so` that the build script's `--android` mode
   stages into the `bun-pty` package is stripped by the same build
   script step, so all native stripping is controlled from one place.
3. **The compiled binary is never stripped.** Only the native library
   files are stripped, before bundling. No post-build modification of
   the `opencode` binary takes place.
4. **Tool contract.** The strip tool resolves in this order:
   `$OPENICK_STRIP`, `llvm-strip`, `strip`. The first one found on the
   `PATH` is used. If no tool is found, or a strip invocation fails,
   the build aborts with an error naming the file and the tool; no
   build silently ships an unstripped library.
5. **CI provides the tool.** The `release`, `validate`, and
   `check-upstream` workflows install the `llvm` package before any
   step that runs the build script. The `build-android` workflow
   resolves `OPENICK_STRIP` to the Android NDK's `llvm-strip` for its
   build step.
6. **Nothing else changes.** No source behavior, no asset names, no
   branding; the release asset set remains the ten assets of Plans
   0003 and 0004. `scripts/verify-branding.sh` is not modified.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project
Manager (plan, documentation), Programmer (the patch and the workflow
changes), Quality Control (the test runs of Section 6), Auditor (the
republication audit and the completion record).

## 4. Scope

### 4.1 In scope

- Patch `0011-strip-native-libraries.patch` against
  `packages/opencode/script/build.ts`, implementing Locked Decisions
  1, 2, and 4.
- The `llvm` provisioning steps in `.github/workflows/release.yml`,
  `.github/workflows/validate.yml`, and
  `.github/workflows/check-upstream.yml`, and the `OPENICK_STRIP`
  resolution in `.github/workflows/build-android.yml`.
- The patch index in `patches/README.md`.
- The republication of release `v1.19.5` and its size audit.

### 4.2 Out of scope

- JavaScript bundle reductions (the `generate` command's prettier
  dependency, the experimental code-mode tool) and models snapshot
  compression; each is a separate context with its own plan.
- Stripping any other native file. The watcher and file-search native
  libraries are not embedded as separate assets in the bundle, and the
  compiled binary itself is excluded by Locked Decision 3.
- Any change to the Android native build itself (Plan 0002); the
  natives are stripped when the build script stages them, not when
  they are compiled.

## 5. Implementation

1. In `packages/opencode/script/build.ts`, add a stripping step that,
   for each target, locates the target's OpenTUI platform package
   (`@opentui/core-<os>-<arch>` with the `-musl` suffix where the
   target carries one, and `@opentui/core-android-arm64` for the
   Android target) in the installed dependency tree — the sibling scope
   directory of the resolved `@opentui/core` package first, then the
   flat `node_modules/@opentui` layouts — and strips its
   `libopentui.so` before the bundle step for that target. A target
   whose library cannot be found aborts the build.
2. In the same script's `--android` staging, strip the copied
   `librust_pty_arm64.so` in the `bun-pty` package directory.
3. Stripping is idempotent: re-running the build on an already stripped
   library succeeds and changes nothing.
4. Provision the tool in the workflows per Locked Decision 5.

## 6. Verification Gates

1. **Local build.** The build script's `--single` mode on this machine
   produces a Linux x64 binary of at most 168,000,000 bytes; the binary
   reports its version, completes an `opencode run` round trip against
   a local mock provider, and its TUI renders in a PTY.
2. **Abort behavior.** A build invoked with `OPENICK_STRIP=/bin/false`
   aborts with the error of Locked Decision 4 and produces no binary.
3. **Repository gates.** The patch stack applies cleanly in order on a
   pristine checkout of the pin; `./scripts/materialize.sh` completes
   and `./scripts/verify-branding.sh` passes.
4. **CI.** The `validate` workflow is green on the change.
5. **Republication audit.** Release `v1.19.5` is republished; every
   archive is smaller than its pre-plan size (recorded in Section 7),
   the extracted Linux x64 binary is within 1 MB of the 166,705,328
   byte prototype, fresh downloads match the published `SHA256SUMS`,
   and the Android archive is republished through the
   `build-android` workflow with its binary size recorded.

## 7. Pre-Plan Release Sizes (baseline for Gate 5)

| Asset | Bytes before this plan |
| --- | --- |
| `opencode-linux-x64.tar.gz` | 69,079,631 |
| `opencode-linux-x64-baseline.tar.gz` | 69,079,298 |
| `opencode-linux-x64-musl.tar.gz` | 69,107,114 |
| `opencode-linux-x64-baseline-musl.tar.gz` | 69,107,114 |
| `opencode-linux-arm64.tar.gz` | 67,938,036 |
| `opencode-linux-arm64-musl.tar.gz` | 67,678,947 |
| `opencode-android-arm64.tar.gz` | 61,234,929 |
| Linux x64 binary inside its archive | 176,740,528 |

## 8. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-30 | Plan created. |

## 9. Acceptance Criteria

- [ ] Patch `0011-strip-native-libraries.patch` is in the stack and the
  local build gate (Gate 1) passes.
- [ ] The abort behavior gate (Gate 2) passes.
- [ ] The repository gates (Gate 3) and CI gate (Gate 4) pass.
- [ ] The republication audit (Gate 5) is recorded in the amendment
  log.
