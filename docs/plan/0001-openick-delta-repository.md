# Plan 0001 — Openick Delta Repository: Upstream Synchronization, Auto-Merge, and Release

| Field | Value |
| --- | --- |
| Plan ID | 0001 |
| File | `docs/plan/0001-openick-delta-repository.md` |
| Status | Active |
| Created | 2026-10-29 |
| Repository | `azrialwork/openick` |
| Upstream | `anomalyco/opencode` |
| Tracked upstream line | v1.x.x (stable releases only) |
| Initial upstream pin | `v1.19.5` at commit `810c0eba1a7348036f8bdf61e6632d0c36c6876c` |
| Language | All repository content is written in professional native English. |
| Context rule | This file covers one context only: the foundation and operation of Openick as a delta repository. Unrelated work requires a new numbered plan file. |

## 1. Purpose

Openick is a delta repository. It does not fork OpenCode and it does not carry a
copy of the OpenCode source tree on its `main` branch. Openick stores only the
difference between this project and the official upstream project, together
with the automation that applies that difference to a pinned upstream release,
validates the result, advances the pin without human intervention, and
publishes a GitHub Release that carries the exact upstream version number.

The upstream product remains OpenCode in every respect. The OpenCode binary
name, product name, visual identity, icons, logos, favicons, package names, and
release asset names are never modified by any patch, any overlay file, or any
script in this repository.

## 2. Locked Decisions

The following decisions govern every part of this plan. They are final for
this plan and are implemented exactly as written.

1. The delta model is hybrid: patches modify existing upstream files, and
   overlay files add or replace whole files.
2. A validated upstream update is merged into `main` automatically. No pull
   request is opened for a routine upstream update and no human approval is
   required. Section 8 defines the exact auto-merge mechanism.
3. Every published Openick release is a GitHub Release. The release tag and
   the release title are identical to the upstream tag, for example `v1.19.5`.
   Openick adds no version suffix, prefix, or independent version sequence.
4. The OpenCode binary and the OpenCode brand are untouched. Section 6 defines
   the enforcement guard.
5. The upstream check runs every six hours on GitHub Actions.
6. Upstream tracking covers the v1.x.x line only. A v2.x.x release is ignored
   by the detection algorithm in Section 5.
7. This plan is the single source of truth for this context. When
   implementation work exposes a bug or an incorrect assumption in this plan,
   this file is corrected in the same commit series as the fix, and the
   correction is recorded in Section 15.
8. Every commit in this repository is an atomic commit, as defined in
   Section 16. This rule applies to human contributors, to automated agents,
   and to the synchronization automation.

## 3. Roles

Work on this repository is performed under four roles. The active role is
selected by the nature of the task, and the role is named in the commit body
or in the pull request description that carries the work.

| Role | Responsibility in this repository |
| --- | --- |
| Project Manager | Owns this plan, the pin advancement policy, the release cadence, and the scope boundaries in Section 4. |
| Programmer | Writes and maintains patches, overlay files, scripts, and workflows. |
| Quality Control | Owns the validation gates in Section 7. A gate that fails blocks the auto-merge and the release. |
| Auditor | Verifies provenance of every release: pin, commit SHA, applied patches, overlay inventory, branding guard result, and checksums. |

## 4. Scope

### 4.1 In scope

- The upstream pin file `upstream.json`.
- The patch stack in `patches/`.
- The overlay tree in `overlay/`.
- The synchronization, materialization, branding guard, and packaging scripts
  in `scripts/`.
- The GitHub Actions workflows in `.github/workflows/` defined in Sections 8,
  9, and 10.
- GitHub Releases of the OpenCode command-line binaries, the materialized
  source archive, the delta manifest, and the checksum file defined in
  Section 10.
- Repository documentation: `README.md`, `AGENTS.md`, and the plan files in
  `docs/plan/`.

### 4.2 Out of scope

- Desktop installers. The upstream desktop build depends on upstream signing
  identities, upstream runners, and upstream infrastructure that do not exist
  in this repository. Openick releases ship the OpenCode CLI only.
- The upstream `publish.yml` workflow. That workflow is bound to the
  `anomalyco/opencode` repository, to non-standard runner labels, and to
  upstream publishing secrets, and it publishes nothing when it runs in this
  repository. Openick uses its own release workflow defined in Section 10.
- Publication to npm, Homebrew, Chocolatey, or any package registry.
- Changes to the upstream source tree committed directly to `main`. The full
  materialized tree exists only inside a workflow run and inside the source
  archive attached to a release.
- Tracking of upstream pre-releases, draft releases, the upstream development
  branch, and the v2.x.x release line.

## 5. Upstream Detection

Detection is implemented by `scripts/check-upstream.sh` and runs inside the
workflow in Section 8.

1. The script reads the current pin from `upstream.json`.
2. The script lists the releases of `anomalyco/opencode` through the GitHub
   API with `gh api repos/anomalyco/opencode/releases --paginate`.
3. The script discards every release that is a draft or a pre-release.
4. The script discards every tag that does not match the regular expression
   `^v1\.[0-9]+\.[0-9]+$`.
5. The script selects the highest remaining tag by semantic version ordering.
   The GitHub `releases/latest` endpoint is never used, because that endpoint
   returns the newest stable release of any major line and would silently move
   this repository to the v2.x.x line.
6. The script compares the selected tag with the pinned tag:
   - Equal tags end the run successfully with no commit, no issue, and no
     release.
   - A higher tag starts the synchronization sequence in Section 8.
   - A lower tag is treated as a detection error. The run fails and the
     failure handling in Section 11 applies. The pin never moves backwards
     through automation.

The tag commit SHA is resolved with
`gh api repos/anomalyco/opencode/git/ref/tags/<tag>` followed, for annotated
tags, by dereferencing the tag object to its commit. The resolved commit SHA
is written into `upstream.json` with the tag.

## 6. Delta Model and the Branding Guard

### 6.1 Patches

- Patches live in `patches/` and are named `NNNN-<slug>.patch`, numbered from
  `0001` in application order.
- Each patch file carries a header block with three lines: `Purpose:`,
  `Upstream files:`, and `Rebase note:`. The header makes every patch
  reviewable without reading the diff.
- Patches are generated against the pinned upstream tag and apply with
  `git apply --index` in filename order.
- A patch that no longer applies to a new upstream tag is a synchronization
  failure. Section 11 governs that failure. Automation never edits a patch to
  force it to apply.

### 6.2 Overlay

- Overlay files live in `overlay/` and mirror the upstream tree layout. The
  file `overlay/packages/opencode/src/example.ts` is copied to
  `packages/opencode/src/example.ts` in the materialized tree.
- Overlay application runs after patch application and copies files with
  `cp --parents` semantics, preserving relative paths.
- `overlay/README.md` is documentation for contributors and is excluded from
  the copy step. It is the only excluded overlay file.

### 6.3 Branding guard

The guard is implemented by `scripts/verify-branding.sh` and runs on every
materialized tree before any build starts.

The guard fails the run when any of the following is true:

1. A patch or an overlay path touches any of these upstream paths:
   - `packages/desktop/icons/**`
   - `packages/app/public/favicon*` and `packages/app/public/apple-touch-icon*`
   - `packages/console/app/public/favicon*` and
     `packages/console/app/public/apple-touch-icon*`
   - Any upstream path containing a `logo` path segment.
2. The materialized `packages/opencode/package.json` differs from the upstream
   tag in its `name` field or its `bin` field.
3. The built CLI artifact names differ from the upstream naming pattern
   `opencode-<os>-<arch>[-baseline][-musl]`.
4. The built binary reports a version string that differs from the pinned
   upstream version.

The guard result is recorded in the delta manifest of every release.

## 7. Materialization and Validation Gates

Materialization is implemented by `scripts/materialize.sh`:

1. Clone `https://github.com/anomalyco/opencode.git` into a temporary
   directory.
2. Check out the pinned tag from `upstream.json` and verify that `HEAD`
   equals the pinned commit SHA.
3. Apply every patch in `patches/` in filename order with `git apply --index`.
4. Copy the overlay tree into the clone.
5. Run `scripts/verify-branding.sh`.
6. Emit `delta-manifest.json` listing the pin, the commit SHA, every applied
   patch with its SHA-256 digest, and every overlay file with its SHA-256
   digest.

Validation gates, owned by Quality Control, run in this order after
materialization:

1. **Apply gate** — every patch applies cleanly and every overlay file copies.
2. **Branding gate** — `scripts/verify-branding.sh` passes.
3. **Smoke build gate** — Bun `1.4.4` builds the CLI for the runner platform
   with the upstream build script:
   `bun install` at the tree root, then
   `OPENCODE_VERSION=<version without the leading v> bun run packages/opencode/script/build.ts --single`.
4. **Smoke run gate** — the built binary runs `--version` and prints the
   pinned upstream version exactly.

A failed gate stops the sequence. `main` is not updated and no release is
published.

## 8. Scheduled Check and Auto-Merge

The workflow `.github/workflows/check-upstream.yml` implements the six-hour
cadence and the auto-merge.

- Trigger: `schedule` with cron `0 */6 * * *` and `workflow_dispatch` for
  manual runs. GitHub cron expressions are evaluated in UTC, so the check runs
  at 00:00, 06:00, 12:00, and 18:00 UTC.
- Concurrency: a single concurrency group for the workflow prevents two
  synchronization runs from racing.
- Permissions: `contents: write` and `issues: write`. No other permissions
  are granted.

Run sequence:

1. Check out `main`.
2. Run `scripts/check-upstream.sh`. An unchanged pin ends the run.
3. For a new tag, update `upstream.json` in a working copy of this repository.
4. Materialize the new upstream tag with the full delta and run every
   validation gate in Section 7, inside the same workflow run, before any
   commit is pushed.
5. Push one commit directly to `main` with the subject
   `chore(upstream): sync to OpenCode <tag>` and a body that records the
   previous tag, the new tag, the new commit SHA, and the gate results. This
   direct, fully automated push of a validated commit is the auto-merge: the
   synchronization is merged into `main` by automation alone, with no pull
   request and no human approval.
6. Dispatch `.github/workflows/release.yml` for the new tag.
7. A failure at any step leaves `main` and the pin untouched and follows
   Section 11.

The direct push mechanism is deliberate. A bot pull request created with the
default `GITHUB_TOKEN` does not trigger further workflow runs, so a
pull-request gate would stall waiting for checks that never start. Validating
inside the synchronization run and pushing the validated commit removes that
deadlock while keeping the rule that unvalidated code never reaches `main`.

## 9. Validation Workflow

The workflow `.github/workflows/validate.yml` protects human-made changes:

- Trigger: `pull_request` and `push` to `main` that touch `patches/`,
  `overlay/`, `scripts/`, `upstream.json`, or `.github/workflows/`.
- Steps: materialize the pinned upstream release with the delta from the
  change under test and run every validation gate in Section 7.
- This workflow is advisory for human contributors during the foundation
  phase defined by this plan. The binding gate for upstream updates is the
  in-run validation in Section 8, step 4.

## 10. Release Pipeline

The workflow `.github/workflows/release.yml` publishes the GitHub Release.

- Triggers: dispatch from `check-upstream.yml` after a successful auto-merge,
  and `workflow_dispatch` with a `tag` input for republishing the pinned
  release after a pipeline fix.
- Permissions: `contents: write`. No other permissions are granted.
- Runner: `ubuntu-latest` with Bun `1.4.4`, matching the `packageManager`
  field of the upstream root `package.json`.

Run sequence:

1. Read the pin from `upstream.json` and confirm that the requested tag
   equals the pinned tag. A mismatch fails the run.
2. Idempotency check: query the GitHub API for a release with the pinned tag.
   An existing release ends the run successfully without modifying the
   release. Releases are immutable once published; corrections ship with the
   next upstream version.
3. Materialize the pinned tree and run every validation gate in Section 7.
4. Build every CLI target with the upstream build script, with
   `OPENCODE_VERSION` set to the pinned version without the leading `v`:
   `bun run packages/opencode/script/build.ts`.
5. Package the built binaries with `scripts/package-release.sh`, using the
   upstream CLI asset names exactly:

   | Build output directory | Release asset |
   | --- | --- |
   | `opencode-linux-arm64` | `opencode-linux-arm64.tar.gz` |
   | `opencode-linux-arm64-musl` | `opencode-linux-arm64-musl.tar.gz` |
   | `opencode-linux-x64` | `opencode-linux-x64.tar.gz` |
   | `opencode-linux-x64-baseline` | `opencode-linux-x64-baseline.tar.gz` |
   | `opencode-linux-x64-musl` | `opencode-linux-x64-musl.tar.gz` |
   | `opencode-linux-x64-baseline-musl` | `opencode-linux-x64-baseline-musl.tar.gz` |
   | `opencode-darwin-arm64` | `opencode-darwin-arm64.zip` |
   | `opencode-darwin-x64` | `opencode-darwin-x64.zip` |
   | `opencode-darwin-x64-baseline` | `opencode-darwin-x64-baseline.zip` |
   | `opencode-windows-arm64` | `opencode-windows-arm64.zip` |
   | `opencode-windows-x64` | `opencode-windows-x64.zip` |
   | `opencode-windows-x64-baseline` | `opencode-windows-x64-baseline.zip` |

   Each archive contains the single `opencode` binary at the archive root,
   with its upstream file name. Windows archives contain `opencode.exe`.
6. Create `openick-source-<tag>.tar.gz` from the materialized tree and copy
   `delta-manifest.json` into the release asset set.
7. Generate `SHA256SUMS` covering every release asset and verify the checksum
   file against the assets before upload.
8. Create the GitHub Release with `gh release create <tag>` targeting the
   `main` commit that carries the pin. The release title is the tag. The
   release notes contain the upstream release link, the upstream commit SHA,
   the patch list, the overlay inventory, the branding guard result, and a
   statement that Openick is a delta build of the official OpenCode release
   and that the OpenCode binary and brand are unmodified.
9. The Auditor verification in Section 12 runs against the published release
   before the run is reported as successful.

## 11. Failure Handling

- **Patch conflict or gate failure during synchronization:** `main` and the
  pin stay on the previous upstream version. The workflow opens one GitHub
  issue titled `Upstream sync blocked: OpenCode <tag>` containing the failed
  gate, the failing patch or file, and the workflow run link. A second issue
  for the same tag is never opened; the workflow searches open issues for the
  title first.
- **Release failure after a successful auto-merge:** the pin on `main` is
  correct and stays. The release workflow is re-run with `workflow_dispatch`
  after the pipeline fix. The idempotency check in Section 10 makes the re-run
  safe.
- **Detection error, including a lower selected tag:** the run fails, `main`
  is untouched, and the failure is reported through the workflow run status.
- Repair work on a blocked patch is human work performed under the Programmer
  role. The repaired patch is committed to `main`, and the next scheduled
  check retries the synchronization with the repaired delta.

## 12. Audit and Provenance

Every release is auditable end to end from public data:

- `upstream.json` on `main` records the repository, tag, version, commit SHA,
  and the timestamp of the last successful synchronization.
- The auto-merge commit records the previous tag, the new tag, the commit
  SHA, and the gate results.
- `delta-manifest.json` in the release records every patch and overlay file
  with SHA-256 digests.
- `SHA256SUMS` in the release covers every asset.
- The release notes link the upstream release and state the branding guard
  result.

## 13. Repository Layout

```
.
├── AGENTS.md
├── README.md
├── upstream.json
├── docs/
│   └── plan/
│       └── 0001-openick-delta-repository.md
├── overlay/
│   └── README.md
├── patches/
│   └── README.md
├── scripts/
│   ├── check-upstream.sh
│   ├── materialize.sh
│   ├── package-release.sh
│   └── verify-branding.sh
└── .github/
    └── workflows/
        ├── check-upstream.yml
        ├── release.yml
        └── validate.yml
```

Plan files are numbered with four digits and a slug:
`docs/plan/000<N+1>-<plan-name>.md`, where `N` is the number of the highest
existing plan. One plan file covers one context. A plan states decisions in
declarative form; a plan never lists alternative options for a decision that
has been made.

## 14. Acceptance Criteria

This plan is implemented when every item is true:

- [x] `upstream.json` pins `anomalyco/opencode` at `v1.19.5` with commit
      `810c0eba1a7348036f8bdf61e6632d0c36c6876c`.
- [x] `scripts/check-upstream.sh` prints the pinned tag when it is the highest
      stable v1.x.x tag and prints the higher tag when the upstream pin is
      lowered in a test fixture.
- [x] `scripts/materialize.sh` materializes `v1.19.5` with an empty delta and
      produces a `delta-manifest.json` whose commit SHA matches the pin.
- [x] `scripts/verify-branding.sh` passes on the empty delta and fails on a
      test patch that modifies an icon path.
- [x] The three workflows parse as valid YAML and reference only scripts that
      exist in the repository.
- [ ] A manual dispatch of `check-upstream.yml` on the current pin completes
      as a no-op.
- [ ] A manual dispatch of `release.yml` publishes the GitHub Release
      `v1.19.5` with the assets defined in Section 10.
- [ ] `README.md` and `AGENTS.md` describe the implemented system and contain
      no statement that contradicts this plan.
- [x] The commit history that lands this foundation on `main` consists of
      atomic commits as defined in Section 16, with one logical change per
      commit.

## 15. Amendment Log

| Date | Amendment |
| --- | --- |
| 2026-10-29 | Initial version of this plan. |
| 2026-10-29 | Added Atomic Commits as Locked Decision 8 and defined the rule in Section 16, at the repository owner's instruction, before the foundation history was pushed. |

## 16. Atomic Commits

An atomic commit is the smallest complete unit of change: one logical
concern, fully implemented, independently understandable, and independently
revertible without breaking the repository or dragging unrelated changes with
it. Commits are made small and frequently, as each unit of work is completed,
never accumulated into one large commit at the end of a task.

Rules:

1. One commit carries one logical change: one patch, one script, one
   workflow, one document, one pin advancement, one fix. A change that cannot
   be described in a single Conventional Commits subject line is split into
   multiple commits before it is committed, never after.
2. A commit never mixes categories. Feature work, refactoring, formatting,
   documentation, and plan corrections travel in separate commits. A plan
   correction that belongs to a fix sits in its own commit immediately beside
   the fix commit in the same commit series.
3. Every commit leaves the repository in a consistent state: committed
   documentation agrees with committed code, shell scripts pass `bash -n`,
   and workflow files parse as valid YAML at every commit that touches them.
4. A commit subject uses Conventional Commits in English, and the commit body
   states why the change exists and names the active role from Section 3.
5. The automated synchronization commit defined in Section 8 is atomic by
   construction: it modifies `upstream.json` and no other file.
6. History on `main` is append-only. A mistake is corrected by a new atomic
   fix commit or a revert commit. Force-pushing `main` is prohibited.
7. A commit that fails a validation gate is never pushed. The fix is a new
   atomic commit, so the published history shows the correction honestly.
