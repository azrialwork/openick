# Patches

This directory holds the patch half of the Openick delta. Overlay files live
in `overlay/`; the rules for both halves are defined in
`docs/plan/0001-openick-delta-repository.md` and `AGENTS.md`.

## Rules

- Patches are named `NNNN-<slug>.patch`, numbered from `0001` in application
  order, and are applied in filename order with `git apply --index`.
- Each patch begins with a header block:

  ```
  Purpose: <what this patch changes and why>
  Upstream files: <comma-separated upstream paths>
  Rebase note: <what to check first when this patch stops applying>
  ```

  The header lines precede the diff. `git apply` ignores leading text up to
  the first diff header.
- A patch is generated against the pinned upstream tag in `upstream.json`.
- A patch never touches a binary name, a product name, a package name, an
  icon, a logo, or a favicon. `scripts/verify-branding.sh` enforces this rule
  on every materialized tree.
- Automation never edits a patch. A patch that stops applying to a new
  upstream release blocks synchronization until a contributor repairs it by
  hand.

## Current State

The patch stack carries the Android ARM64 delta defined in
`docs/plan/0002-android-arm64-build.md`:

- `0001-build-android-target.patch` adds an opt-in `--android` mode to the
  upstream build script (`packages/opencode/script/build.ts`). Without the
  flag the script behaves exactly as upstream.
- `0002-register-opentui-core-android.patch` registers the OpenTUI core
  dependency patch in the upstream `patchedDependencies` map
  (`package.json`).
