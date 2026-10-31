# Plan 0009 — OpenCode Provider and Free Models Only

| Field | Value |
| --- | --- |
| Plan ID | 0009 |
| File | `docs/plan/0009-opencode-provider-only.md` |
| Status | Completed |
| Created | 2026-10-31 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Upstream pin at creation | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Governing foundation plan | `docs/plan/0001-openick-delta-repository.md` |
| Related plans | `docs/plan/0005-tui-and-run-only.md`, `docs/plan/0008-remove-generate-command.md` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: restricting the product to the OpenCode provider and its free models. |

## 1. Purpose

The owner directs that the shipped product use only the OpenCode
provider (`opencode`) and only that provider's free models. Every
other provider in the models.dev registry (235 providers and 8,936
models in the registry at the time of writing) and every paid model
is removed from the product entirely: from the catalog every surface
reads, from the SDK code bundled into the binary, from the
provider-specific loaders and authentication plugins, and from the
configuration surface that could re-add a provider.

Verified facts this plan is built on (measured on 2026-10-31 against
the live registry and the pinned source tree):

- The registry's `opencode` provider uses the npm package
  `@ai-sdk/openai-compatible` against `https://opencode.ai` and lists
  130 models, of which 46 are free under the rule of Locked
  Decision 1 (no registry model has input cost 0 with nonzero output
  cost, and no free model carries paid cache tiers, so the rule is
  unambiguous on current data). The separate `opencode-go` provider
  is a paid subscription and is not the OpenCode provider.
- Every catalog consumer (the v1 `Provider` service, the v2 catalog
  plugin, the server provider handlers, the `models` and `providers`
  CLI commands) reads through `ModelsDev.Service.get()` in
  `packages/core`, whose `populate()` is the single point where the
  disk cache, the embedded snapshot, and the network fetch converge.
- The embedded registry snapshot is produced by
  `packages/opencode/script/generate.ts` and embedded by the build as
  the `OPENCODE_MODELS_DEV` define (5,961,021 bytes of registry JSON
  at the time of writing).
- Provider SDKs enter the bundle only through the `BUNDLED_PROVIDERS`
  map in `packages/opencode/src/provider/provider.ts` (24 entries)
  and provider behavior through the `custom()` loader map in the same
  file (24 entries, one per provider). The twelve built-in
  authentication plugins in `packages/opencode/src/plugin/index.ts`
  serve only other providers (OpenAI Codex, GitHub Copilot, Modal,
  GitLab, Poe, Cloudflare Workers, Cloudflare AI Gateway, Azure,
  DigitalOcean, Snowflake Cortex, xAI, Cerebras); none is referenced
  outside that file. The GitLab provider also has a dedicated model
  class wired into `packages/opencode/src/session/llm.ts`.
- The `Provider` service can create providers that are not in the
  catalog from user configuration (the "extend database from config"
  loop in `provider.ts`); without removing that loop, configuration
  alone could re-add any provider.

## 2. Locked Decisions

1. **The catalog rule.** Every catalog returned by
   `ModelsDev.Service` contains exactly one provider, `opencode`,
   and within it exactly the models whose base cost is free
   (`cost.input == 0` and `cost.output == 0`). The filter is applied
   inside `populate()` in `packages/core/src/models-dev.ts`, so the
   disk cache, the embedded snapshot, network fetches, and hourly
   refreshes are all filtered identically. The rule is data-driven:
   as the registry changes, the free set changes with it.
2. **The embedded snapshot is filtered at build time.**
   `packages/opencode/script/generate.ts` parses the registry JSON
   and applies the same rule before exporting it as the
   `OPENCODE_MODELS_DEV` define. An unparseable registry fails the
   build; the full registry is never embedded silently.
3. **One bundled SDK.** `BUNDLED_PROVIDERS` keeps only
   `@ai-sdk/openai-compatible`. The other 23 entries are deleted.
4. **One custom loader.** The `custom()` loader map keeps only the
   `opencode` loader, unchanged. The other loaders and helpers used
   exclusively by them are deleted.
5. **Configuration cannot add providers.** The "extend database from
   config" loop in `provider.ts` is deleted. Configuration of the
   `opencode` provider itself (options such as `apiKey` and
   `baseURL`, model whitelist and blacklist, variants) keeps working
   through the remaining merge paths, and
   `enabled_providers`/`disabled_providers` can only restrict
   further.
6. **The built-in authentication plugins for other providers are
   removed.** The twelve plugins of Section 1 are unregistered from
   `internalPlugins`, their imports are removed, and their module
   files under `packages/opencode/src/plugin/` are deleted. The
   plugin system itself and user-installed plugins are untouched.
7. **The GitLab workflow model wiring is removed** from
   `packages/opencode/src/session/llm.ts` (the
   `gitlab-ai-provider` import and its two branches).
8. **The TUI connect dialog matches the scope.** The custom-provider
   option and the OpenCode Go promotion are removed from
   `packages/tui/src/component/dialog-provider.tsx`, and its priority
   map keeps only `opencode`. The model dialog reads the
   server-filtered catalog and needs no change.
9. **The small-model fallback keeps working.** The `opencode`
   small-model family priority becomes `["gpt-nano", "grok"]`: the
   registry no longer offers a free `gpt-nano` family model, and
   `grok-code` (family `grok`) is free, so title and summary
   generation keep a fast free model. No other selection logic
   changes; the default-model priority already resolves inside the
   free set (`big-pickle`).
10. **Dependency declarations stay.** `package.json` entries for the
    removed SDK and authentication packages are not edited; the
    bundle loses them through reachability alone (the precedent of
    Plan 0008, Locked Decision 4).
11. **Deliberately retained dead code.** Provider-specific string
    branches in `provider/transform.ts` (they import no SDK) and the
    runtime `Npm.add` fallback in `resolveSDK` (reachable only
    through plugin-supplied models) are left in place; both are inert
    for every model the filtered catalog can contain.

## 3. Roles

Work under this plan names its role per task, as in Plan 0001: Project
Manager (plan, documentation), Programmer (the patch), Quality Control
(the test runs of Section 5), Auditor (the republication audit and the
completion record).

## 4. Scope

### 4.1 In scope

- Patch `0013-opencode-free-models-only.patch` covering Locked
  Decisions 1–9, including updates to tests that exist solely to
  verify removed providers' behavior.
- The patch index in `patches/README.md`.
- The republication of release `v1.19.5` and its audit.

### 4.2 Out of scope

- The plugin system, MCP, the `ai` SDK core, and the
  `@ai-sdk/provider` types.
- User-installed plugins, including any that extend the `opencode`
  provider at runtime.
- Removing the `providers` or `models` commands; both keep working
  against the filtered catalog.

## 5. Verification Gates

1. **Development tree.** Typechecks are clean in `packages/core`,
   `packages/opencode`, and `packages/tui`. Inventories confirm:
   `BUNDLED_PROVIDERS` holds one entry, the `custom()` map holds one
   loader, and no source file imports a removed provider SDK or a
   deleted authentication plugin. Tests that verified removed
   behavior are updated in the patch; the remaining provider and
   catalog tests pass.
2. **Local build.** The build script's `--single` mode produces a
   binary whose `opencode models` output lists only `opencode`
   free models (the list is compared against the Locked Decision 1
   rule applied to the live registry). A configuration file that
   defines another provider changes nothing in that output. A
   configuration that points the `opencode` provider's `baseURL` at
   a local mock completes an `opencode run` round trip with a free
   model, and the TUI renders in a PTY.
3. **Repository gates.** The patch stack applies cleanly in order on
   a pristine checkout of the pin and matches the verified
   development tree; `./scripts/materialize.sh` completes and
   `./scripts/verify-branding.sh` passes.
4. **CI.** The `validate` workflow is green on the change.
5. **Republication audit.** Release `v1.19.5` is republished with
   exactly ten assets; fresh downloads match the published
   `SHA256SUMS`; the extracted Linux x64 binary reports 1.19.5, its
   `opencode models` output satisfies Gate 2's rule, and its size is
   recorded against the Plan 0008 figure of 163,043,504 bytes; the
   Android archive is republished through the `build-android`
   workflow. No on-device testing (standing owner instruction).

## 6. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-31 | Plan created. |
| 2026-10-31 | Test scope refined during implementation, recorded here per the governance rule. Beyond the provider and plugin suites named in Section 4.1, the session and server suites carried their own copies of the config-defined test provider; they were migrated to the same harness as the rest of the tree (the `opencode` provider pointed at the fake LLM server, model `opencode/test-model` added as a free model to the test fixture catalog). Tests whose premise was a removed provider or SDK were deleted wherever they sat: the recorded native-runtime scenarios file, the per-SDK payload tests in the LLM stream suite, the non-`opencode` session-header cases, and one small-model test whose premise (a preferred-family model being active in the free catalog) no longer holds — in the live registry every `gpt-nano` family model is paid and `grok-code` is marked deprecated today, so the Locked Decision 9 priority is retained as a data-driven fallback that resolves whenever the registry offers such a model again. No product behavior changed by these test decisions. |
| 2026-10-31 | Completion record (Auditor). Gate 1: typechecks clean in core, opencode, and tui; provider and plugin suites 713 pass / 0 fail; every other suite shows no failure beyond the pre-existing baseline of the pre-plan tree (verified by stash comparison). Gate 2: local `--single` build is 151,083,184 bytes; its `opencode models` output is exactly the eight active free models the Locked Decision 1 rule yields on the live registry (46 free in total, the rest deprecated); a configuration defining other providers changes nothing; the mock round trip and the PTY TUI render pass, the TUI resolving its default model to the free `big-pickle` with no key configured. Gate 3: the thirteen-patch stack applies cleanly on a pristine checkout of the pin and reproduces the development tree; `materialize.sh` completes with a 13-patch manifest and `verify-branding.sh` passes. One local materialize run failed inside patch `0004` with a racy-index `does not match index` error from the fresh shallow clone; a retry completed cleanly and the stack test is unaffected, so this is recorded as a local environment flake, not a patch defect. Gate 4: `validate` run `41194305148` green. Gate 5: release run `41194376767` and `build-android` run `41194503802` republished `v1.19.5` with exactly 10 assets; fresh downloads match `SHA256SUMS` (9 of 9 listed files OK); the manifest lists 13 patches; the published Linux x64 binary is 151,083,184 bytes (Plan 0008: 163,043,504; −11,960,320), reports 1.19.5, and its `opencode models` output matches the rule; the Android binary is 142,811,512 bytes (was 154,739,064). All acceptance criteria met. |

## 7. Acceptance Criteria

- [x] Patch `0013-opencode-free-models-only.patch` is in the stack
  and the development-tree gate (Gate 1) passes.
- [x] The local build gate (Gate 2) passes.
- [x] The repository gates (Gate 3) and CI gate (Gate 4) pass.
- [x] The republication audit (Gate 5) is recorded in the amendment
  log.
