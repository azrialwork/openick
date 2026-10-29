# Plan 0002 — Android ARM64 Build: a Bionic CLI Target Produced Entirely on GitHub Actions

| Field | Value |
| --- | --- |
| Plan ID | 0002 |
| File | `docs/plan/0002-android-arm64-build.md` |
| Status | Active |
| Created | 2026-10-29 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: the Android ARM64 (Bionic) build of the pinned OpenCode release. The delta foundation, upstream synchronization, and the standard release pipeline are governed by Plan 0001 and are not restated here. |

## 1. Purpose

Openick gains one additional CLI target: `android-arm64`, a build of the pinned
upstream OpenCode release that runs natively on Android (Bionic), for example
inside Termux on an ARM64 device. The target is produced entirely on GitHub
Actions. No build step runs on a contributor machine or on a device.

Verified facts this plan is built on, established by direct experiment on a
real Android ARM64 device (Termux, Bionic) against the pinned release:

- The official Bun 1.4.4 Android build runs natively on Bionic, and the pinned
  OpenCode source runs on it from source: CLI commands, the headless server,
  session storage, and a full agent round trip all pass.
- Bun 1.4.4 cross-compiles to the Android target from a Linux host. The
  compile target token is `bun-linux-arm64-android`, and the resulting binary
  is an AArch64 ELF whose interpreter is `/system/bin/linker64`.
- The TUI's JavaScript and TSX layer loads on Bionic once the SolidJS
  transform preload is active. The TUI stops at exactly one gate: the native
  render library. `@opentui/core` 0.4.5 ships no Android asset, and its loader
  rejects the target with `Unsupported OpenTUI Node asset target:
  android-arm64`. Supplying that asset is the central work of this plan.
- `@parcel/watcher` 2.5.1 resolves its native binding by a dynamically
  constructed package name, and an official `@parcel/watcher-android-arm64`
  package exists. `@ff-labs/fff-bun` 0.10.5 likewise ships an official
  `android-arm64` package. Neither dependency needs a patch.

## 2. Locked Decisions

The following decisions govern every part of this plan. They are final for
this plan and are implemented exactly as written.

1. The Android build is a delta under the Plan 0001 hybrid model: patches in
   `patches/`, whole new files in `overlay/`, automation in `scripts/` and
   `.github/workflows/`. The upstream source tree is never committed to this
   repository.
2. Every build step runs on GitHub Actions. The workflow in Section 8 is the
   only build path. Local machines and devices run verification only.
3. Every native component is built from its official upstream source at the
   exact revision the pinned release consumes. No third-party prebuilt
   binaries, no glibc runners, no compatibility shims, and no community
   builds are used at any stage.
4. The deliverable is one additional release asset,
   `opencode-android-arm64.tar.gz`, added to the existing GitHub Release of
   the pinned upstream tag. The archive contains one file, the `opencode`
   binary. The asset name extends the upstream CLI asset naming pattern
   (`opencode-<os>-<arch>`) with the `android` OS token; no existing asset is
   renamed, replaced, or removed, and the release tag and title stay identical
   to the upstream tag.
5. The `SHA256SUMS` asset of that release is regenerated at publication time
   so that it covers every asset of the release, including the Android asset.
   `delta-manifest.json` is not regenerated: the source delta it describes is
   unchanged by the addition of a build target.
6. Publication is a separate, deliberate step. The workflow builds and stages
   the artifact by default; it publishes to the release only when dispatched
   with `publish=true`, and `publish=true` is dispatched only after the
   on-device verification gate in Section 9 has passed.
7. `scripts/verify-branding.sh` is not modified. The Android workflow runs the
   tree-phase branding guard through `scripts/materialize.sh`, exactly as
   every other pipeline does, and verifies its own artifact with the checks
   in Section 9. No protected brand path is touched by any patch or overlay
   file in this plan.
8. The default build path is unchanged. The Android target is built only when
   `packages/opencode/script/build.ts` is invoked with the `--android` flag.
   The target list used by the Plan 0001 release pipeline, the `--single`
   smoke build used by validation, and every existing artifact name remain
   exactly as upstream and Plan 0001 define them.
9. When implementation exposes a bug or an incorrect assumption in this plan,
   this file is corrected in the same commit series as the fix, and the
   correction is recorded in Section 13.
10. Every commit in this work is an atomic commit, as defined in Plan 0001
    Section 16 and in `AGENTS.md`.

## 3. Roles

| Role | Responsibility in this plan |
| --- | --- |
| Project Manager | This plan, the source pins in Section 5, and the publication decision in Section 8. |
| Programmer | The patches, the overlay file, the native build script, and the workflow. |
| Quality Control | The workflow gates in Section 9. A failing gate blocks publication. |
| Auditor | Provenance of the published asset: source pins, workflow run, ELF identity, `SHA256SUMS` coverage, and the on-device verification record. |

## 4. Scope

### 4.1 In scope

- One target: Android, ARM64, Bionic. One asset: `opencode-android-arm64.tar.gz`.
- A self-contained `opencode` binary that runs in Termux on Android ARM64:
  CLI, headless server, and TUI.
- The two native libraries the pinned release loads at runtime and for which
  no official Android build exists: `libopentui` (from `@opentui/core`
  0.4.5) and the `bun-pty` Rust library (from `bun-pty` 0.4.8).
- The delta components in Section 6 and the workflow in Section 8.

### 4.2 Out of scope

- Android x64, Android on other CPU architectures, and Android APK or
  installer packaging of any kind.
- Desktop targets, installers, and signing, exactly as in Plan 0001.
- Changes to the Plan 0001 pipelines (`check-upstream.yml`, `release.yml`,
  `validate.yml`) beyond what the new delta requires to keep their gates
  green.
- LSP server downloads on Android. Upstream defines no Android builds for
  the language servers it downloads, so those features degrade on the
  Android target exactly as they do when running the pinned source on the
  device today. This plan does not change that behavior.
- Advancing the upstream pin. This plan is implemented and verified against
  the pin recorded in the header. When the pin advances under Plan 0001, the
  Android build is revalidated against the new pin like every other delta
  component.

## 5. Source Pins and Toolchains

Every input is pinned. The workflow fails if a checked-out revision does not
match its pin.

| Input | Source | Pin |
| --- | --- | --- |
| OpenCode source | `anomalyco/opencode` | The tag and commit in `upstream.json` |
| OpenTUI native source | `anomalyco/opentui` | Tag `v0.4.5`, the release that publishes `@opentui/core` 0.4.5 |
| `bun-pty` Rust source | `sursaone/bun-pty` | Commit `41dd5b887f3f47d7c307fd93f828a75dbee97d5a`, the `gitHead` published as `bun-pty` 0.4.8 |
| Bun | `oven-sh/bun` via `oven-sh/setup-bun` | `1.4.4`, the version the pinned release pins |
| Zig | `mlugg/setup-zig` | `0.15.2`, the version the OpenTUI 0.4.5 build system requires and checks for |
| Rust | `rustup` stable on the runner | Target `aarch64-linux-android` |
| Android NDK | Preinstalled on the GitHub-hosted Ubuntu runner image | The runner image's default NDK; Android API level 24 for the Rust target's compiler and linker |

## 6. Delta Components

### 6.1 Patch 0001 — Android target in the upstream build script

File: `patches/0001-build-android-target.patch`
Upstream file: `packages/opencode/script/build.ts`

The patch makes four changes, all inert unless `--android` is passed:

1. It reads an `androidFlag` from `process.argv`, in the same style as the
   existing `--single` and `--baseline` flags.
2. When the flag is set, the target list is exactly one entry,
   `{ os: "android", arch: "arm64" }`, and the distribution name produced by
   the existing naming code is `opencode-android-arm64`.
3. The Bun compile target for the Android entry is
   `bun-linux-arm64-android`. The existing name-derived token
   (`bun-android-arm64`) is not a valid Bun target and is overridden for
   this entry only.
4. In Android mode, after the dependency installation block, the build
   copies the staged native assets (Section 7) from the directory named by
   the `OPENICK_ANDROID_ASSETS` environment variable into the package's
   `node_modules`: the fabricated `@opentui/core-android-arm64` package into
   `node_modules/@opentui/`, and `librust_pty_arm64.so` into the `bun-pty`
   package's `rust-pty/target/release/` directory. Android mode without the
   environment variable set is a build error.
5. The release tarball condition in the same file treats the Android
   distribution name as a tarball target, matching the Linux targets. The
   Openick workflow packages the artifact itself (Section 8); this change
   keeps the upstream script internally consistent for the new name.

No other behavior of the build script changes. Without `--android`, the
script is byte-for-byte equivalent in behavior to upstream.

### 6.2 Patch 0002 — Register the OpenTUI core dependency patch

File: `patches/0002-register-opentui-core-android.patch`
Upstream file: `package.json` (repository root of the upstream tree)

The patch adds one entry to the upstream `patchedDependencies` map:
`@opentui/core@0.4.5` is patched by `patches/@opentui%2Fcore@0.4.5.patch`
inside the materialized tree. Upstream already maintains dependency patches
in exactly this location and format; this plan adds one more and changes no
existing entry.

### 6.3 Overlay — The OpenTUI core dependency patch

File: `overlay/patches/@opentui%2Fcore@0.4.5.patch`

This file is copied by `scripts/materialize.sh` into the materialized tree
at `patches/@opentui%2Fcore@0.4.5.patch`, where Bun applies it to the
published `@opentui/core` 0.4.5 package on every `bun install`. It makes
the Android target a first-class asset target of the loader:

1. `NATIVE_FILE_NAMES` gains the entry `android: "libopentui.so"`, so the
   asset descriptor accepts the platform and computes the package name
   `@opentui/core-android-arm64`, the file name `libopentui.so`, and the
   asset key `@opentui/core-android-arm64/libopentui.so`. The current
   asset target on Android carries no `libc` field, so no other descriptor
   rule is affected.
2. `resolveNativeLibraryPath` gains an Android branch that statically
   imports `@opentui/core-android-arm64` for `arm64`, in the same form as
   every existing platform branch, so the bundler embeds the library file
   into the compiled binary exactly as it does for the other platforms.

The change is applied to every published file that carries the descriptor
or the resolver: the Bun chunk files, `node-assets.js`, and the Node chunk
file, so the Bun and Node entry points of the package agree.

### 6.4 Components that deliberately receive no patch

- `@parcel/watcher` 2.5.1 constructs its binding package name from
  `process.platform` and `process.arch` and requires it. On Android that
  name is `@parcel/watcher-android-arm64`, an official package that the
  build's `--os="*" --cpu="*"` installation step fetches and the bundler
  embeds. No patch.
- `@ff-labs/fff-bun` 0.10.5 ships the official `@ff-labs/fff-bin-android-arm64`
  package, fetched by the same installation step. No patch.
- `bun-pty` 0.4.8 selects its shared library by architecture on every
  non-Windows, non-macOS platform: on Android ARM64 it loads
  `librust_pty_arm64.so` from its `rust-pty/target/release/` directory.
  Supplying that file (Section 7) is sufficient. No code patch.

## 7. Native Builds

`scripts/build-android-natives.sh <work-dir> <assets-dir>` performs both
native builds from the Section 5 pins and stages the results. The workflow
in Section 8 is its only caller.

### 7.1 libopentui

1. Clone `anomalyco/opentui` at tag `v0.4.5` into the work directory and
   verify the checked-out commit is the commit the tag points to.
2. In `packages/core/src/zig`, run
   `zig build -Dtarget=aarch64-linux-android.24 --sysroot <NDK sysroot> -Doptimize=ReleaseFast`.
   Zig 0.15.2 cross-compiles the library, including its bundled C and C++
   components, using its own Android libc headers and libc++ support. The
   build script links the system libraries `dl` and `pthread`, which on
   Bionic are stub libraries that live only in the Android NDK sysroot, so
   the NDK sysroot is passed to the Zig build for library resolution; the
   target string carries the Android API level, 24. (Corrected during
   implementation: the first workflow run proved that Zig's bundled
   Android support contains no `dl`/`pthread` stubs to link against. See
   Section 13.)
3. Stage the produced `libopentui.so` as an npm-shaped platform package at
   `<assets-dir>/core-android-arm64/`, mirroring the published
   `@opentui/core-linux-arm64` 0.4.5 package file for file: `package.json`
   (name `@opentui/core-android-arm64`, version `0.4.5`, `os: ["android"]`,
   `cpu: ["arm64"]`, the same exports map), `index.js`, `index.bun.js`,
   `index.d.ts`, and `libopentui.so`.

### 7.2 bun-pty Rust library

1. Clone `sursaone/bun-pty` into the work directory and check out commit
   `41dd5b887f3f47d7c307fd93f828a75dbee97d5a`.
2. Build the crate in `rust-pty/` with Cargo for the
   `aarch64-linux-android` target, using the runner NDK's Clang (API level
   24) as the target linker and C compiler.
3. Stage the produced `librust_pty.so` as
   `<assets-dir>/librust_pty_arm64.so`, the exact file name the `bun-pty`
   loader selects on Android ARM64.

## 8. Workflow

File: `.github/workflows/build-android.yml`

- Trigger: `workflow_dispatch` only, with two inputs: `tag` (required; must
  equal the pin in `upstream.json`) and `publish` (boolean, default
  `false`).
- Concurrency group `build-android-<tag>`, no cancellation of a running
  build. Permissions: `contents: write`, used only by the publication steps.
- Steps, in order:
  1. Check out `main` and confirm the requested tag equals the pin.
  2. Set up Bun 1.4.4, Zig 0.15.2, and the Rust `aarch64-linux-android`
     target.
  3. Materialize the pinned release with the delta:
     `./scripts/materialize.sh`. This step runs the tree-phase branding
     guard, as in every pipeline.
  4. Run `./scripts/build-android-natives.sh` to stage the native assets.
  5. Install dependencies in the materialized tree with `bun install`. Bun
     applies the Section 6.3 dependency patch during this step.
  6. Build the Android target:
     `OPENCODE_VERSION=<pin version> OPENICK_ANDROID_ASSETS=<assets-dir> bun run ./packages/opencode/script/build.ts --android`.
  7. Package `dist/opencode-android-arm64/bin/opencode` as
     `opencode-android-arm64.tar.gz`.
  8. Run the artifact identity checks of Section 9 and upload the tarball
     as a workflow artifact. The run ends here unless `publish` is `true`.
  9. Publication, only when `publish` is `true`: upload the tarball to the
     GitHub Release of the pinned tag with `--clobber`, then regenerate
     `SHA256SUMS` from the release's full asset list and upload it with
     `--clobber`, then print the release asset list as the audit record.

## 9. Verification Gates

Quality Control owns these gates. Publication requires all of them.

1. **Existing gates stay green.** The `validate` workflow passes on `main`
   with this delta applied: materialization succeeds, the tree-phase
   branding guard passes, and the `--single` smoke build is unaffected.
2. **Artifact identity (in the workflow).** `file` reports the packaged
   binary as an ELF 64-bit AArch64 executable, and `readelf` reports its
   interpreter as `/system/bin/linker64`. Any other result fails the run
   before anything is staged or published.
3. **On-device smoke test (before publication).** The staged artifact is
   run on a real Android ARM64 device in Termux, inside a throwaway
   sandbox directory, and must pass all of the following: `--version`
   prints the pinned version; the headless server answers `/global/health`
   as healthy and creates a session; a full `opencode run` round trip
   against an on-device mock model completes; and the TUI starts and
   renders its interface, which is the gate that was blocked before this
   plan. The device is restored to its prior state after the test and the
   restoration is verified by snapshot diff, as in the earlier device
   experiments.
4. **Publication audit (after publication).** The asset list of the release
   shows `opencode-android-arm64.tar.gz` alongside the pre-existing assets;
   the published `SHA256SUMS` contains a line for the Android asset; and a
   fresh download of the asset matches that checksum.

## 10. Branding Compliance

- No patch or overlay file touches a protected brand path, a binary name, a
  product name, a package name, an icon, a logo, or a favicon. The binary
  inside the Android archive is named `opencode`, reports the pinned
  upstream version, and carries upstream branding unmodified.
- The dependency patch in Section 6.3 changes platform resolution logic
  only. It contains no name, wordmark, or asset of any product.
- `scripts/verify-branding.sh` is not modified by this plan (Locked
  Decision 7). Its artifact-phase naming pattern covers the Plan 0001
  targets; the Android artifact is verified by Section 9 gates 2 and 3
  instead of by that pattern.

## 11. Failure Handling

- The workflow fails closed at every gate. A failed native build, a failed
  identity check, or a pin mismatch ends the run with nothing staged and
  nothing published.
- Publication is idempotent: re-running `publish=true` re-uploads the same
  asset and regenerates `SHA256SUMS` from the then-current asset list.
- A defect found in a published Android asset is corrected by a corrected
  build and a `publish=true` re-dispatch under this plan's amendment rules.
  Plan 0001's release immutability rule governs the release as a whole; the
  Android asset is an addition to the release, and its correction never
  modifies or re-uploads any pre-existing asset other than `SHA256SUMS`,
  whose regeneration is its defined behavior (Locked Decision 5).

## 12. Repository Layout Additions

```text
docs/plan/0002-android-arm64-build.md          this plan
patches/0001-build-android-target.patch        Section 6.1
patches/0002-register-opentui-core-android.patch
                                               Section 6.2
overlay/patches/@opentui%2Fcore@0.4.5.patch    Section 6.3
scripts/build-android-natives.sh               Section 7
.github/workflows/build-android.yml            Section 8
```

`patches/README.md` and `overlay/README.md` are updated in the same series
to describe the non-empty delta state.

## 13. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-29 | Initial version of this plan. |
| 2026-10-29 | Corrected Section 7.1 during implementation: the Zig build of `libopentui` links the system libraries `dl` and `pthread`, whose Bionic stubs exist only in the Android NDK sysroot. The build therefore passes the NDK sysroot and API level 24 in the target string. The original text, which stated that no NDK is involved in the Zig build, was wrong; the first `build-android` run failed with `unable to find dynamic system library 'dl'`. |

## 14. Acceptance Criteria

This plan is implemented when every item is true:

- [ ] This plan file exists and the implementation matches it.
- [ ] `patches/0001-build-android-target.patch` and
      `patches/0002-register-opentui-core-android.patch` apply cleanly to
      the pinned upstream tree, and
      `overlay/patches/@opentui%2Fcore@0.4.5.patch` is registered and
      applied by `bun install` in the materialized tree.
- [ ] `./scripts/materialize.sh` completes against the pinned tag with this
      delta, and the tree-phase branding guard passes.
- [ ] The `validate` workflow passes on `main` with this delta.
- [ ] A `build-android` dispatch with `publish=false` for the pinned tag
      completes and stages `opencode-android-arm64.tar.gz` as a workflow
      artifact.
- [ ] The staged binary passes the artifact identity gate: ELF 64-bit
      AArch64, interpreter `/system/bin/linker64`.
- [ ] The on-device smoke test passes in full on a real Android ARM64
      device, including the TUI rendering gate, and the device is restored
      and verified by snapshot diff afterwards.
- [ ] A `build-android` dispatch with `publish=true` adds
      `opencode-android-arm64.tar.gz` to the GitHub Release of the pinned
      tag, and the release `SHA256SUMS` covers it and verifies against a
      fresh download.
- [ ] `README.md`, `patches/README.md`, and `overlay/README.md` describe
      the implemented state and contain no statement that contradicts this
      plan.
- [ ] The commit history that lands this work on `main` consists of atomic
      commits as defined in Plan 0001 Section 16, with one logical change
      per commit.
