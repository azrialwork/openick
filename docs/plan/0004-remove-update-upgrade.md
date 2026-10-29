# Plan 0004 — Remove the Update and Upgrade Feature

| Field | Value |
| --- | --- |
| Plan ID | 0004 |
| File | `docs/plan/0004-remove-update-upgrade.md` |
| Status | Active |
| Created | 2026-10-29 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plans | `docs/plan/0002-android-arm64-build.md`, `docs/plan/0003-linux-android-bash-only.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: deleting the in-binary update and upgrade feature from the materialized source. The delta foundation is governed by Plan 0001, the Android target by Plan 0002, and the platform pruning by Plan 0003; none of them is restated here. |

## 1. Purpose

The shipped binary carries no self-update capability. Openick releases are
the only update channel: a new version of the software reaches the user as a
new Openick release, never through the binary replacing itself.

Verified facts this plan is built on, established by inspection of the pinned
release:

- The upstream update and upgrade feature has five surfaces in the bundled
  source trees: (1) the `opencode upgrade [target]` command
  (`packages/opencode/src/cli/cmd/upgrade.ts`, 105 lines) including its
  `--major` path to OpenCode 2; (2) the TUI update dialog and notification
  (`packages/tui/src/component/dialog-update.tsx`, 192 lines;
  `packages/tui/src/context/update-notification.tsx`, 132 lines) and the
  `/update` slash command; (3) a background version check that runs at TUI
  startup and repeats every ten minutes, resolving the newest version from
  the npm registry (`packages/opencode/src/cli/upgrade.ts`,
  `packages/opencode/src/cli/cmd/tui.ts`,
  `packages/opencode/src/cli/tui/worker.ts`); (4) the installation engine's
  upgrade functions (`packages/opencode/src/installation/index.ts`:
  `latest()`, `upgrade()`, `upgradeMajor()`, `isUpdate()`, and the per-method
  command tables for curl, npm, bun, brew, scoop, and choco); (5) the
  configuration surface: the `autoupdate` field in the core config schema and
  the `OPENCODE_DISABLE_AUTOUPDATE` and `OPENCODE_ALWAYS_NOTIFY_UPDATE`
  flags.
- The upstream upgrade path does not deliver Openick builds. It installs the
  stock upstream binary through the detected install method (npm, bun, brew,
  scoop, choco, or the curl script), replacing the Openick binary and every
  delta in it, and its major-upgrade path moves the user to OpenCode 2, which
  this repository's v1-only policy forbids. The feature is a standing exit
  from the delta, not a convenience.
- `Installation.method()` and the `Method` type are not upgrade surface:
  `opencode uninstall` depends on them. They stay.
- The expected binary size effect is negligible (the feature totals roughly
  one thousand lines of source). The purpose of this plan is coherence: the
  binary offers no path that replaces it with a different product build.

## 2. Locked Decisions

1. **Deletion, not disabling.** Every surface listed in Section 1 is deleted
   by the delta. No feature flag, environment variable, configuration field,
   or runtime switch may re-enable an update check, an update notification,
   or an upgrade. The `autoupdate` configuration field and both update flags
   are deleted with the feature.
2. **One patch.** The removal ships as patch `0008`, applied after patch
   `0007` in filename order, and registered in `patches/README.md`.
3. **The uninstall path survives.** `Installation.method()`, the `Method`
   type, the installation service registration, and `InstallationVersion`
   are unchanged. `opencode uninstall` behaves exactly as upstream.
4. **Repository automation is untouched.** This plan removes the in-binary
   feature only. The upstream check, validation, and release workflows of
   Plans 0001 to 0003 are unchanged.
5. **Republication of the pinned release.** The `v1.19.5` release is
   republished through the Plan 0003 mechanism: `release.yml` is dispatched
   with `force=true`, then `build-android.yml` with `publish=true`. The
   final release contains the same ten assets as after Plan 0003.
6. **No on-device testing.** Verification under this plan is the CI gates of
   Section 8 and local functional checks of the Linux build. No end-to-end
   test on the owner's Android device is performed or required; this is the
   owner's instruction of 2026-10-29 and it supersedes the device-gate
   pattern of Plans 0002 and 0003 for this plan.
7. **Branding.** `scripts/verify-branding.sh` is not modified. The OpenCode
   binary name, branding, and asset naming rules of Plan 0001 are unchanged.
8. **Tests follow the deleted surface.** Upstream tests that reference a
   deleted API are updated inside patch `0008`, per the Plan 0003 precedent.
   No other test changes are in scope.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project Manager
(plan, packaging, workflow, documentation), Programmer (the patch), Quality
Control (typecheck, smoke builds, workflow gates), Auditor (release audit and
acceptance record).

## 4. Scope

### 4.1 In scope

- Patch `0008` and its registration in `patches/README.md`.
- Republication of the pinned release and its audit.
- The `README.md` statement that the binary has no self-update feature.

### 4.2 Out of scope

- The desktop application's updater (upstream `packages/desktop`); Openick
  ships no desktop build.
- The repository's own upstream synchronization automation (Plan 0001).
- Database and provider "update" operations and every other generic use of
  the word update in the source; only the self-update feature is removed.
- Any change to `opencode uninstall`.

## 5. Delta Components

Patch `0008-remove-update-upgrade.patch` deletes:

- `packages/opencode/src/cli/cmd/upgrade.ts`, with its import and command
  registration in `packages/opencode/src/index.ts`.
- `packages/opencode/src/cli/upgrade.ts`, with its call in
  `packages/opencode/src/cli/tui/worker.ts`.
- The updater factory in `packages/opencode/src/cli/cmd/tui.ts` (the
  subscription, polling, check, and apply machinery) and the `updater` prop
  it feeds to the TUI.
- `packages/tui/src/component/dialog-update.tsx` and
  `packages/tui/src/context/update-notification.tsx`, with the provider, the
  `/update` slash command, and the home-screen notification in
  `packages/tui/src/app.tsx` and `packages/tui/src/routes/home.tsx`.
- From `packages/opencode/src/installation/index.ts`: `latest()`,
  `upgrade()`, `upgradeMajor()`, `isUpdate()`, `UpgradeFailedError`,
  `MAJOR_INSTRUCTIONS`, the major-upgrade command tables, and the helpers
  that serve only them. `method()`, the `Method` type, and the service
  registration remain.
- The `OPENCODE_DISABLE_AUTOUPDATE` and `OPENCODE_ALWAYS_NOTIFY_UPDATE`
  flags in `packages/core/src/flag/flag.ts`.
- The `autoupdate` field in `packages/core/src/config.ts` and in the v1
  config schema and migration map, and its mention in the bundled
  customize-opencode skill document.
- The `/global/upgrade` endpoint: its input and result schemas, path, and
  endpoint definition in
  `packages/opencode/src/server/routes/instance/httpapi/groups/global.ts`
  and its handler in
  `packages/opencode/src/server/routes/instance/httpapi/handlers/global.ts`.
- The installation update events (`installation.updated`,
  `installation.update-available`): `packages/schema/src/installation-event.ts`
  and their registration in `packages/schema/src/event-manifest.ts`.
- The upstream tests that cover only the deleted surface, per Locked
  Decision 8: `packages/opencode/test/installation/installation.test.ts`,
  `packages/opencode/test/cli/upgrade.test.ts`,
  `packages/opencode/test/server/httpapi-global.test.ts`, and
  `packages/tui/test/component/dialog-update.test.ts` are deleted; the
  `autoupdate` assertions in the two config test files are removed.

## 6. Packaging and Workflow Changes

None. Packaging and workflows are exactly as after Plan 0003; republication
uses the existing `force` input of `release.yml` and the existing
`build-android.yml` publish flow.

## 7. Republication Procedure

1. `validate` is green on `main` with the full delta.
2. `release.yml` is dispatched with `tag=v1.19.5` and `force=true`.
3. `build-android.yml` is dispatched with `tag=v1.19.5` and `publish=true`.
4. The Auditor performs gate 5 of Section 8.

## 8. Verification Gates

1. **Inventory.** A search of the bundled source trees
   (`packages/opencode/src`, `packages/core/src`, `packages/tui/src`) for
   `UpgradeCommand`, `upgradeMajor`, `autoupdate`, `AUTOUPDATE`,
   `NOTIFY_UPDATE`, `DialogUpdate`, `update-notification`, `isUpdate`, and
   `MAJOR_INSTRUCTIONS` returns no hits.
2. **Typecheck.** The affected upstream packages (`packages/core`,
   `packages/opencode`, `packages/tui`) typecheck with no new errors.
3. **Functional checks of the Linux build.** The pruned binary built from the
   materialized tree: reports version `1.19.5`; answers `opencode upgrade`
   as an unknown command; completes a mock-provider agent round trip;
   renders the TUI home screen without an update notification; and starts
   normally with a configuration file that still carries the removed
   `autoupdate` key.
4. **CI.** The `validate` workflow is green on `main` with the full delta.
5. **Publication audit.** The republished release contains exactly the ten
   assets of Plan 0003, Locked Decision 7; fresh downloads of the Linux x64
   archive and the Android archive verify against the published
   `SHA256SUMS`; the published Linux x64 binary runs and reports `1.19.5`.

## 9. Failure Handling

If gate 3 shows that a configuration carrying the legacy `autoupdate` key no
longer loads, that is a plan defect: the finding and its correction are
recorded in the Amendment Log in the same commit series, per the governing
rules. If patch `0008` stops applying to a future upstream release, Plan
0001's standing rule governs: the pin stays, a marker issue opens, and the
patch is rebased manually.

## 10. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-29 | Plan created. |
| 2026-10-29 | Scope completion recorded during implementation: the feature also has a server face that Section 1 did not list — the `/global/upgrade` HTTP endpoint in the global API group and handler, and the `installation.updated` / `installation.update-available` event definitions in `packages/schema`. Both are deleted by patch `0008`, and Section 5 now lists them. The web application's update toast is not part of this surface: it calls the desktop platform bridge (`platform.updater`), which is undefined in the CLI-served web UI, and stays untouched under Section 4.2. |
| 2026-10-29 | Gate 3 evidence note: with the command deleted, `opencode upgrade` is treated by the CLI as a project directory argument of the default command (its standard behavior for any unknown word) and no update action exists; the help output contains no upgrade entry. A configuration file carrying the removed `autoupdate` key loads normally, so no Section 9 defect arises. |

## 11. Acceptance Criteria

- [ ] Patch `0008` exists, carries the standard patch header, and is listed
  in `patches/README.md`.
- [ ] The materialized tree passes the Section 8 inventory check (gate 1).
- [ ] Typecheck passes for the affected packages (gate 2).
- [ ] The functional checks of the Linux build pass, including the unknown
  command answer for `opencode upgrade` and the legacy configuration key
  check (gate 3).
- [ ] The `validate` workflow is green on `main` with the full delta
  (gate 4).
- [ ] The `v1.19.5` release is republished with exactly the ten assets of
  Plan 0003, Locked Decision 7 (gate 5).
- [ ] Fresh downloads verify against the published `SHA256SUMS`, and the
  republished Linux x64 binary reports version `1.19.5` (gate 5).
- [ ] `README.md` states that the binary has no self-update feature and that
  new versions ship as Openick releases.
