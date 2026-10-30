# Plan 0008 — Remove the Generate Command

| Field | Value |
| --- | --- |
| Plan ID | 0008 |
| File | `docs/plan/0008-remove-generate-command.md` |
| Status | Completed |
| Created | 2026-10-30 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plans | `docs/plan/0005-tui-and-run-only.md`, `docs/plan/0007-strip-native-libraries.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: the `opencode generate` command. No other command is in scope. |

## 1. Purpose

The `opencode generate` command prints the server's OpenAPI
specification, formatted through the `prettier` library, to standard
output. It is a maintainer tool for regenerating the committed
`openapi.json`; nothing in the TUI, in `opencode run`, or in any other
command calls it, and it has no options and no effect on configuration,
sessions, or providers. It is also the only importer of the `prettier`
package in the entire bundle graph, so its presence embeds roughly
3.5 MiB of formatter library and language plugins in every shipped
binary. The owner directs that the command be deleted in full.

Verified facts this plan is built on (measured on 2026-10-30):

- The command's whole surface is one module,
  `packages/opencode/src/cli/cmd/generate.ts`, plus its import and
  registration in `packages/opencode/src/index.ts` (two lines). No
  other source file references it.
- The help snapshot suite's command list does not include `generate`,
  so no snapshot changes are expected; the suite is still run as a
  gate.
- Stubbing the command's `prettier` usage in the development tree
  shrank the bundle outputs from 67.92 MiB to 64.41 MiB; deleting the
  command removes at least that much (the command module itself is
  also gone).
- The `Server.openapi()` machinery the command wrapped is shared
  infrastructure (the server's own documentation surface) and is not
  part of this plan.

## 2. Locked Decisions

1. **The command is deleted in full.** Patch
   `0012-remove-generate-command.patch` deletes
   `packages/opencode/src/cli/cmd/generate.ts` and its import and
   registration in `packages/opencode/src/index.ts`. Invoking
   `opencode generate` afterwards behaves like any unknown command.
2. **Scope is this one command.** Every other command, including all
   utility commands restored by the Plan 0005 revocation, stays. This
   plan is a separate single-command decision by the owner and does
   not reopen that revocation.
3. **The OpenAPI machinery stays.** `Server.openapi()` and the
   server's documentation surface are untouched; only the CLI wrapper
   is removed.
4. **The `prettier` dependency declaration stays.** Repository tooling
   outside the shipped bundle (for example `script/format.ts`) uses
   the package; the bundle loses it through reachability alone, which
   is where the size saving comes from.
5. **Nothing else changes.** No asset names, no branding; the release
   asset set remains ten assets.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project
Manager (plan, documentation), Programmer (the patch), Quality Control
(the test runs of Section 5), Auditor (the republication audit and the
completion record).

## 4. Scope

### 4.1 In scope

- Patch `0012-remove-generate-command.patch` against the two files of
  Section 1.
- The patch index in `patches/README.md`.
- The republication of release `v1.19.5` and its size audit against
  the Plan 0007 results.

### 4.2 Out of scope

- Any other command, including the remaining size candidates recorded
  in Plan 0007's research (models snapshot compression, the
  experimental code-mode tool); each is its own context.
- Removing `prettier` from `package.json` (Locked Decision 4).

## 5. Verification Gates

1. **Development tree.** The `packages/opencode` typecheck is clean,
   the help snapshot test passes, and a source inventory finds no
   remaining reference to the command's module.
2. **Local build.** The build script's `--single` mode produces a
   binary of at most 165,000,000 bytes (from 166,713,520 after Plan
   0007); `opencode --help` lists no `generate` command and still
   lists the other utility commands; the binary completes an
   `opencode run` round trip against a local mock provider and its
   TUI renders in a PTY.
3. **Repository gates.** The patch stack applies cleanly in order on a
   pristine checkout of the pin and matches the verified development
   tree; `./scripts/materialize.sh` completes and
   `./scripts/verify-branding.sh` passes.
4. **CI.** The `validate` workflow is green on the change.
5. **Republication audit.** Release `v1.19.5` is republished with
   exactly ten assets; fresh downloads match the published
   `SHA256SUMS`; the extracted Linux x64 binary reports 1.19.5, its
   help has no `generate` entry, and its size is recorded against the
   Plan 0007 figure of 166,713,520 bytes; the Android archive is
   republished through the `build-android` workflow.

## 6. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-30 | Plan created. |
| 2026-10-30 | Gate 1 correction, found during execution: the help snapshot test fails identically before and after this change in the development tree (one stale snapshot for commands removed by earlier plans), so the gate was applied as "no new failures relative to the pre-change baseline"; the counts matched exactly (1 failed snapshot, 7 assertions both ways). The `packages/opencode` typecheck is clean and the source inventory finds no remaining reference to the command. |
| 2026-10-30 | Completed. Local build: 163,043,504 bytes (Plan 0007: 166,713,520; −3,670,016), help lists 16 commands with no `generate` entry and every other command intact, `opencode run` mock round trip and PTY TUI render pass. The 12-patch stack applies cleanly on the pin; materialize and branding gates pass; `validate` run `41095434886` is green. Republication audit: release run `41095635104` and `build-android` run `41095932131` republished `v1.19.5` with exactly ten assets; fresh downloads match the published `SHA256SUMS` (9 of 9 listed assets OK) and the manifest lists 12 patches. The published Linux x64 binary is 163,043,504 bytes, byte-size-identical to the local build, reports 1.19.5, and its help has no `generate` command; the Android binary is 154,739,064 bytes (Plan 0007: 158,409,080; the same −3,670,016 delta). |

## 7. Acceptance Criteria

- [x] Patch `0012-remove-generate-command.patch` is in the stack and
  the development-tree gate (Gate 1) passes.
- [x] The local build gate (Gate 2) passes.
- [x] The repository gates (Gate 3) and CI gate (Gate 4) pass.
- [x] The republication audit (Gate 5) is recorded in the amendment
  log.
