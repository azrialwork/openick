# Plan 0005 — TUI and Run Only: Remove Every Other Mode

| Field | Value |
| --- | --- |
| Plan ID | 0005 |
| File | `docs/plan/0005-tui-and-run-only.md` |
| Status | Completed |
| Created | 2026-10-30 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plans | `docs/plan/0002-android-arm64-build.md`, `docs/plan/0003-linux-android-bash-only.md`, `docs/plan/0004-remove-update-upgrade.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: reducing the shipped binary to two entry points, the interactive TUI and the `run` command, by deleting every other command and mode. The delta foundation is governed by Plan 0001, the Android target by Plan 0002, the platform pruning by Plan 0003, and the update feature removal by Plan 0004; none of them is restated here. |

## 1. Purpose

The shipped binary is an interactive terminal product with one scripted
entry point. It offers exactly two commands: the default TUI and
`opencode run`. Every other upstream mode — the web interface, the
standalone server, the editor protocol, the GitHub Actions agent, and the
one-shot management commands — is deleted from the materialized source.

Verified facts this plan is built on, established by a dependency mapping of
the pinned release with patches `0001` to `0008` applied:

- The CLI registers 21 commands next to the default TUI command in
  `packages/opencode/src/index.ts`. Every command module other than the TUI
  and `run` is imported only by `index.ts`; there are no cross-imports
  between command modules except inside the github module group and inside
  the `run` module group. Each removed command is a leaf entry point.
- The TUI and `run` both run on the internal HTTP server. The TUI worker
  starts it with `Server.listen` and the TUI talks to it through the SDK;
  `run` boots the same server in-process and drives it through the SDK
  client. The server core and its API route groups are shared
  infrastructure of the two surviving commands, not a mode of their own.
- The web mode is the largest single surface in the binary: `script/build.ts`
  compiles `packages/app` and embeds its distribution (85 MB, 1,787 files)
  into the binary through the generated `opencode-web-ui.gen.ts` map. The
  server serves that bundle through a catch-all UI route
  (`packages/opencode/src/server/shared/ui.ts`, consumed by the HTTP API
  server), and when no bundle is embedded it proxies the hosted upstream
  interface at `https://app.opencode.ai` instead.
- Two removed modes own deep exclusive modules: the ACP editor protocol
  (`packages/opencode/src/acp`, 3,661 lines, imported only by
  `cli/cmd/acp.ts`) and the GitHub Actions handler
  (`cli/cmd/github.handler.ts` and `cli/cmd/github.shared.ts`, 1,600 lines,
  imported only by `cli/cmd/github.ts`). The `debug` command directory
  (about 680 lines) is likewise imported only by `index.ts`.
- Interactive parity is internal to the TUI: provider connection, model
  selection, agent selection, MCP status, and session switching exist as
  TUI dialogs and slash commands (`/connect`, `/models`, `/agents`,
  `/mcps`, `/sessions`, `/org`). Deleting the one-shot management commands
  removes no interactive capability.
- `Installation.method()` has exactly one remaining caller,
  `opencode uninstall`. The user-agent strings of the model layer are built
  from the core `InstallationVersion` and do not depend on the installation
  service.
- The desktop application is not part of this surface: the CLI build never
  references `packages/desktop`, and Openick ships no desktop build.

## 2. Locked Decisions

1. **Two entry points.** The default TUI command and `RunCommand` are the
   only commands registered in `packages/opencode/src/index.ts`. The yargs
   shell `completion` command is removed with the rest. The built-in
   `--help` and `--version` flags are unchanged.
2. **Deletion, not disabling.** Every removed mode and command is deleted
   from the materialized source. No flag, environment variable, or
   configuration field may re-enable one. The build never compiles or
   embeds the web UI again, and the `OPENCODE_DISABLE_EMBEDDED_WEB_UI`
   runtime flag is deleted with the UI serving path it guarded.
3. **Three patches.** The removal ships as patches `0009`, `0010`, and
   `0011`, applied after patch `0008` in filename order and registered in
   `patches/README.md`. Patch `0009` removes the web, serve, and attach
   modes and the UI serving path. Patch `0010` removes the ACP and github
   modes. Patch `0011` removes the remaining utility commands, the
   uninstall command with the installation service, the `run --attach`
   option, and the yargs completion command.
4. **The server core stays.** `Server.listen`, the HTTP API route groups,
   and the SDK are shared infrastructure of the TUI and of `run` and are
   not modified, except that the catch-all UI route and its handler module
   are deleted by patch `0009`. Removing the standalone `serve` and `web`
   commands does not remove the server the TUI and `run` boot internally.
5. **Run is local only.** The `--attach` option of `opencode run`, which
   connects to an externally started server, is deleted by patch `0011`.
   `run` keeps its in-process server and its `--port` option.
6. **Repository automation is untouched.** This plan removes in-binary
   modes only. The upstream check, validation, and release workflows of
   Plans 0001 to 0003 are unchanged.
7. **Republication of the pinned release.** The `v1.19.5` release is
   republished through the Plan 0003 mechanism: `release.yml` is dispatched
   with `force=true`, then `build-android.yml` with `publish=true`. The
   final release contains the same ten assets as after Plan 0004.
8. **No on-device testing.** Verification under this plan is the CI gates
   of Section 8 and local functional checks of the Linux build, per the
   owner's standing instruction of 2026-10-29.
9. **Branding.** `scripts/verify-branding.sh` is not modified. The OpenCode
   binary name, branding, and asset naming rules of Plan 0001 are unchanged.
10. **Tests follow the deleted surface.** Upstream tests that reference a
    deleted API are updated inside the patch that deletes the API, per the
    Plan 0003 precedent. No other test changes are in scope.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project Manager
(plan, packaging, workflow, documentation), Programmer (the patches), Quality
Control (typecheck, smoke builds, workflow gates), Auditor (release audit and
acceptance record).

## 4. Scope

### 4.1 In scope

- Patches `0009`, `0010`, and `0011` and their registration in
  `patches/README.md`.
- Republication of the pinned release and its audit.
- The `README.md` statement that the binary ships the TUI and `run` only.

### 4.2 Out of scope

- The HTTP API route groups and the server core, which are infrastructure
  of the surviving commands (Locked Decision 4).
- The SDK package, the session and agent core, the MCP client service, the
  plugin runtime, and provider authentication services: the deleted
  commands were wrappers over these, and the services stay for the TUI and
  `run`.
- The desktop application (upstream `packages/desktop`); it is not built
  or shipped by this repository.
- The contents of `packages/app`; the delta stops building and embedding
  it, and does not edit it.

## 5. Delta Components

Patch `0009-remove-web-serve-attach.patch` deletes:

- `packages/opencode/src/cli/cmd/web.ts`,
  `packages/opencode/src/cli/cmd/serve.ts`, and
  `packages/opencode/src/cli/cmd/attach.ts`, with their imports and command
  registrations in `packages/opencode/src/index.ts`.
- The web UI bundle step in `packages/opencode/script/build.ts`: the build
  no longer compiles `packages/app`, no longer generates
  `opencode-web-ui.gen.ts`, and never embeds a UI file map, for every
  target including Android.
- `packages/opencode/src/server/shared/ui.ts` (embedded UI serving and the
  `app.opencode.ai` proxy fallback), its catch-all UI route in
  `packages/opencode/src/server/routes/instance/httpapi/server.ts`, and the
  `disableEmbeddedWebUi` runtime flag in
  `packages/opencode/src/effect/runtime-flags.ts`.

Patch `0010-remove-acp-github.patch` deletes:

- `packages/opencode/src/cli/cmd/acp.ts` and the whole
  `packages/opencode/src/acp` module, with the import and registration in
  `packages/opencode/src/index.ts`.
- `packages/opencode/src/cli/cmd/github.ts`,
  `packages/opencode/src/cli/cmd/github.handler.ts`, and
  `packages/opencode/src/cli/cmd/github.shared.ts`, with the import and
  registration in `packages/opencode/src/index.ts`.

Patch `0011-remove-utility-commands.patch` deletes:

- The remaining command modules, with their imports and registrations in
  `packages/opencode/src/index.ts`: `cli/cmd/providers.ts`,
  `cli/cmd/account.ts` (the account and console commands),
  `cli/cmd/models.ts`, `cli/cmd/agent.ts`, `cli/cmd/mcp.ts`,
  `cli/cmd/session.ts`, `cli/cmd/export.ts`, `cli/cmd/import.ts`,
  `cli/cmd/stats.ts`, `cli/cmd/plug.ts`, `cli/cmd/db.ts`, the
  `cli/cmd/debug` directory, `cli/cmd/generate.ts`, and `cli/cmd/pr.ts`;
  and the yargs `completion` command registered in `index.ts`.
- `packages/opencode/src/cli/cmd/uninstall.ts` and
  `packages/opencode/src/installation/index.ts`, with the
  `Installation.node` registrations in
  `packages/opencode/src/effect/app-runtime.ts` and
  `packages/opencode/src/server/routes/instance/httpapi/server.ts`.
- The `--attach` option of the `run` command and its code path in
  `packages/opencode/src/cli/cmd/run.ts`.
- The upstream tests that cover only the deleted surface, per Locked
  Decision 10, inside the patch that deletes the corresponding API.

## 6. Packaging and Workflow Changes

None. Packaging and workflows are exactly as after Plan 0004; republication
uses the existing `force` input of `release.yml` and the existing
`build-android.yml` publish flow. The release archives shrink because the
binaries no longer embed the web UI; the asset set is unchanged.

## 7. Republication Procedure

1. `validate` is green on `main` with the full delta.
2. `release.yml` is dispatched with `tag=v1.19.5` and `force=true`.
3. `build-android.yml` is dispatched with `tag=v1.19.5` and `publish=true`.
4. The Auditor performs gate 5 of Section 8.

## 8. Verification Gates

1. **Inventory.** A search of the bundled source trees
   (`packages/opencode/src`, `packages/core/src`, `packages/tui/src`) for
   `ServeCommand`, `WebCommand`, `AttachCommand`, `AcpCommand`,
   `GithubCommand`, `ProvidersCommand`, `ConsoleCommand`, `ModelsCommand`,
   `AgentCommand`, `McpCommand`, `SessionCommand`, `ExportCommand`,
   `ImportCommand`, `StatsCommand`, `PluginCommand`, `DbCommand`,
   `DebugCommand`, `GenerateCommand`, `UninstallCommand`, `PrCommand`,
   `serveUIEffect`, and `opencode-web-ui` returns no hits.
2. **Typecheck.** The affected upstream packages (`packages/core`,
   `packages/opencode`, `packages/tui`, `packages/schema`) typecheck with
   no new errors.
3. **Functional checks of the Linux build.** The binary built from the
   materialized tree: reports version `1.19.5`; its help output lists the
   `run` command and no removed command; completes a mock-provider agent
   round trip through `opencode run`; renders the TUI in a pseudo-terminal
   and completes a prompt round trip against the mock provider inside the
   TUI; and is materially smaller than the Plan 0004 binary, with the size
   recorded in the Amendment Log.
4. **CI.** The `validate` workflow is green on `main` with the full delta.
5. **Publication audit.** The republished release contains exactly the ten
   assets of Plan 0004, Locked Decision 7; fresh downloads of the Linux x64
   archive and the Android archive verify against the published
   `SHA256SUMS`; the published Linux x64 binary runs, reports `1.19.5`,
   and its help output lists `run` and no removed command.

## 9. Failure Handling

If gate 3 shows the TUI or `run` broken by a removal, the removal crossed
into shared infrastructure: that is a plan defect, and the finding and its
correction are recorded in the Amendment Log in the same commit series, per
the governing rules. If a patch of this plan stops applying to a future
upstream release, Plan 0001's standing rule governs: the pin stays, a
marker issue opens, and the patch is rebased manually.

## 10. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-30 | Plan created. |
| 2026-10-30 | Implementation scope completion recorded: three test surfaces of the deleted commands were found outside the typechecked trees during implementation — the `serve` subprocess integration tests, the `acp` integration tests, and the read-only command smokes (`mcp list`, `providers list`, `models`, `agent list`, `session list`, `stats`, `db path`) — and are deleted inside patches `0009`, `0010`, and `0011` respectively, per Locked Decision 10. The CLI help snapshot test now pins only the surviving surface and its snapshot is regenerated inside patch `0011`; the two `--attach` cases of the `run` process tests are deleted there as well. |
| 2026-10-30 | Gate 3 evidence notes: with the commands deleted, a removed command word is treated by the CLI as a project directory argument of the default command (its standard behavior for any unknown word); the help output lists exactly the default TUI command and `run`. The published Linux x64 binary is 172,988,592 bytes against 213,354,672 bytes after Plan 0004 (−40,366,080 bytes, −18.9 percent), the web UI bundle being the bulk of the reduction. The `run` process integration suite is timing-sensitive on a loaded machine: under full-file parallel load, several of its 30-second subprocess budgets expire on the pre-plan tree as well (7 pass / 6 fail before this plan, 6 pass / 5 fail after, the deleted attach cases accounting for the count difference); every case passes when run individually on the final tree. This is a property of the test harness budgets, not of the delta. |
| 2026-10-30 | Plan completed. Patches `0009` (11 files, −934), `0010` (36 files, −10,665), and `0011` (46 files, +20/−6,548) pass all gates: the Section 8 inventory returns no hits on the materialized tree; typecheck is clean for `packages/core`, `packages/opencode`, `packages/tui`, and `packages/schema`; the touched upstream test suites pass (runtime flags, control plane, config, and the run unit suites, 148/148, plus the regenerated help snapshot test); the Linux build completes the mock round trip through `opencode run` and a full prompt round trip inside the TUI in a pseudo-terminal; `validate` is green on `main` (run `40993746439`); the release was republished (runs `40993835214` and `40994034822`) with exactly the ten assets of Plan 0004, Locked Decision 7; fresh downloads of the Linux x64 and Android archives verify against the published `SHA256SUMS`, and the published Linux x64 binary reports `1.19.5` with only the TUI and `run` in its help output. Per Locked Decision 8, no on-device testing was performed. |

## 11. Acceptance Criteria

- [x] Patches `0009`, `0010`, and `0011` exist, carry the standard patch
  header, and are listed in `patches/README.md`.
- [x] The materialized tree passes the Section 8 inventory check (gate 1).
- [x] Typecheck passes for the affected packages (gate 2).
- [x] The functional checks of the Linux build pass, including the TUI
  pseudo-terminal round trip, the `run` round trip, and the help output
  check (gate 3).
- [x] The `validate` workflow is green on `main` with the full delta
  (gate 4).
- [x] The `v1.19.5` release is republished with exactly the ten assets of
  Plan 0004, Locked Decision 7 (gate 5).
- [x] Fresh downloads verify against the published `SHA256SUMS`, and the
  republished Linux x64 binary reports version `1.19.5` (gate 5).
- [x] `README.md` states that the binary ships the TUI and `run` only.
