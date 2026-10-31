# Plan 0010 — Remove the Experimental Code-Mode Tool

| Field | Value |
| --- | --- |
| Plan ID | 0010 |
| File | `docs/plan/0010-remove-code-mode.md` |
| Status | In progress |
| Created | 2026-10-31 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plans | `docs/plan/0008-remove-generate-command.md`, `docs/plan/0009-opencode-provider-only.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: removing the experimental code-mode tool. |

## 1. Purpose

The owner directs that the experimental code-mode tool be removed in
full. The tool (id `execute`) lets the model run a confined
orchestration script against connected MCP tools through the
`@opencode-ai/codemode` interpreter. It is off by default, gated by
the `OPENCODE_EXPERIMENTAL_CODE_MODE` runtime flag, but its dynamic
import is still embedded in every shipped binary together with the
TypeScript compiler the interpreter depends on.

Verified facts this plan is built on (measured on 2026-10-30 and
re-verified on 2026-10-31 against the pinned source tree):

- Stubbing the code-mode import out of the bundle shrank the bundle
  output from 64.41 MiB to 60.70 MiB, about 3.7 MiB, in the binary
  size research recorded for Plan 0007.
- `packages/opencode/src/tool/code-mode.ts` is the only importer of
  `@opencode-ai/codemode` in the product source, and the `typescript`
  package is imported only by that package's interpreter runtime, so
  both leave the bundle by reachability when the tool goes.
- The tool reaches the registry through a flag-gated dynamic import
  in `packages/opencode/src/tool/registry.ts`, which also carries
  the catalog description plumbing for the `execute` tool.
- With the flag on, `packages/opencode/src/session/tools.ts` keeps
  MCP tools out of the model's tool list (they are reachable only
  through the sandbox); with the flag off — the default and the only
  behavior normal use has ever seen — MCP tools are listed
  individually.

## 2. Locked Decisions

1. **The tool module is deleted.** `packages/opencode/src/tool/code-mode.ts`
   is removed in full, with its `execute` tool, its catalog
   description builder, and its `@opencode-ai/codemode` import.
2. **The registry wiring is removed.** `registry.ts` loses the
   flag-gated dynamic import, the conditional `execute` entry in the
   builtin tool map, `describeCodeMode`, and every `execute`
   special case in the tool listing path.
3. **MCP tools are always listed individually.** The
   `experimentalCodeMode` early return in `session/tools.ts` is
   deleted; the behavior users get today with the flag off becomes
   the only behavior.
4. **The flag is removed.** `experimentalCodeMode` and
   `OPENCODE_EXPERIMENTAL_CODE_MODE` are deleted from
   `packages/opencode/src/effect/runtime-flags.ts`.
5. **Tests follow the feature.** `test/tool/code-mode.test.ts` and
   `test/tool/code-mode-integration.test.ts` are deleted. In
   `test/tool/registry.test.ts` the two cases whose premise is the
   enabled flag are deleted with their layer helpers, and the
   remaining case keeps asserting that no `execute` tool is exposed.
6. **Deliberately retained.** The `packages/codemode` workspace
   package and the `package.json` dependency declarations stay (the
   reachability precedent of Plan 0008, Locked Decision 4, and Plan
   0009, Locked Decision 10). The `codemode` key handling in
   `packages/opencode/src/config/v2-compat.ts` also stays: it is
   configuration translation hygiene that strips an unsupported key
   from user configuration files, not part of the runtime tool.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project
Manager (plan, documentation), Programmer (the patch), Quality Control
(the test runs of Section 5), Auditor (the republication audit and the
completion record).

## 4. Scope

### 4.1 In scope

- Patch `0014-remove-code-mode.patch` covering Locked Decisions 1–5.
- The patch index in `patches/README.md`.
- The republication of release `v1.19.5` and its audit.

### 4.2 Out of scope

- MCP itself: servers, clients, and the individual MCP tools are
  untouched and remain listed to the model as before.
- The `packages/codemode` workspace package as a source tree.
- Any other experimental flag or tool.

## 5. Verification Gates

1. **Development tree.** Typechecks are clean in `packages/core`,
   `packages/opencode`, and `packages/tui`. Inventories confirm: no
   source file imports `@opencode-ai/codemode`, and no reference to
   `experimentalCodeMode` or the `execute` tool wiring remains. The
   touched test suites (tool, session, config) show no failures
   beyond the pre-existing baseline of the pre-plan tree.
2. **Local build.** The build script's `--single` mode produces a
   binary; its size is recorded against the Plan 0009 figure of
   151,083,184 bytes. The binary's model list still satisfies Plan
   0009's catalog rule, an `opencode run` mock round trip passes,
   and the TUI renders in a PTY.
3. **Repository gates.** The patch stack applies cleanly in order on
   a pristine checkout of the pin and matches the verified
   development tree; `./scripts/materialize.sh` completes and
   `./scripts/verify-branding.sh` passes.
4. **CI.** The `validate` workflow is green on the change.
5. **Republication audit.** Release `v1.19.5` is republished with
   exactly ten assets; fresh downloads match the published
   `SHA256SUMS`; the extracted Linux x64 binary reports 1.19.5, its
   `opencode models` output satisfies Plan 0009's rule, and its size
   is recorded; the Android archive is republished through the
   `build-android` workflow. No on-device testing (standing owner
   instruction).

## 6. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-31 | Plan created. |

## 7. Acceptance Criteria

- [ ] Patch `0014-remove-code-mode.patch` is in the stack and the
  development-tree gate (Gate 1) passes.
- [ ] The local build gate (Gate 2) passes.
- [ ] The repository gates (Gate 3) and CI gate (Gate 4) pass.
- [ ] The republication audit (Gate 5) is recorded in the amendment
  log.
