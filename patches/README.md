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

The stack also carries the platform pruning defined in
`docs/plan/0003-linux-android-bash-only.md`:

- `0003-build-targets-linux-only.patch` restricts the upstream build
  script to the Linux target family.
- `0004-shell-bash-only.patch` reduces the shell layer to Bash only.
- `0005-delete-tui-windows-terminal.patch` deletes the TUI's Windows
  terminal module and its call sites.
- `0006-platform-tables-linux-only.patch` trims the LSP and ripgrep
  platform tables to their Linux entries.
- `0007-remaining-platform-branches.patch` deletes every remaining
  Windows and macOS branch in the bundled source trees.

A further patch carries the update-feature removal defined in
`docs/plan/0004-remove-update-upgrade.md`:

- `0008-remove-update-upgrade.patch` deletes the in-binary update and
  upgrade feature: the `opencode upgrade` command, the TUI update dialog
  and notification, the periodic version check, the `/global/upgrade`
  server endpoint, the installation upgrade functions, and the
  `autoupdate` configuration surface.

Two further patches carry the mode reduction defined in
`docs/plan/0005-tui-and-run-only.md`:

- `0009-remove-web-serve-attach.patch` deletes the web, serve, and attach
  modes: the three commands, the build step that compiled and embedded
  the web UI, the server's UI catch-all route and hosted-interface proxy
  fallback, and the `OPENCODE_DISABLE_EMBEDDED_WEB_UI` flag.
- `0010-remove-acp-github.patch` deletes the ACP editor protocol mode
  (the `acp` command and the whole protocol module) and the GitHub
  Actions mode (the `github` command, its handler, and its shared
  module).

A third Plan 0005 patch, `0011-remove-utility-commands.patch`, was
revoked by the owner on 2026-10-30 and removed from this delta. The
utility commands it deleted are present in the materialized tree again.
