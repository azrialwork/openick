# AGENTS.md

Instructions for every contributor and every automated agent working in this
repository. These rules are binding. Where this file and a plan file disagree,
the plan file governs and this file is corrected in the same change.

## Language

All repository content is written in professional native English: code,
comments, commit messages, documentation, plan files, release notes, and issue
text produced by automation. No other language is used in committed content.

## Roles

Select the role that matches the task and name that role in the commit body
or pull request description.

| Role | Owns |
| --- | --- |
| Project Manager | Plan files, scope, pin advancement policy, release cadence. |
| Programmer | Patches, overlay files, scripts, and workflows. |
| Quality Control | The validation gates. A failing gate blocks merges and releases. |
| Auditor | Provenance of releases: pin, commit SHA, delta manifest, branding guard result, checksums. |

## Plans Come First

1. Substantial work starts from a plan file in `docs/plan/`.
2. Plan files are named `docs/plan/000<N+1>-<plan-name>.md`, where `N` is the
   number of the highest existing plan. The first plan is `0001`.
3. One plan file covers one context. A new context gets a new plan file.
4. A plan states decisions in declarative form. A decided matter is written as
   a fact, never as a list of alternatives.
5. When implementation exposes a bug or an incorrect assumption in a plan,
   correct the plan in the same commit series as the fix and record the
   correction in the plan's amendment log. A plan that describes behavior the
   code does not have is a defect.

The governing plan for the repository foundation is
`docs/plan/0001-openick-delta-repository.md`.

## Delta Discipline

- `main` holds the delta only. Never commit the upstream OpenCode source tree
  to this repository.
- Modify an existing upstream file with a patch in `patches/`. Patches are
  named `NNNN-<slug>.patch`, numbered from `0001` in application order, and
  carry a header with `Purpose:`, `Upstream files:`, and `Rebase note:` lines.
- Add or replace a whole file through `overlay/`, mirroring the upstream tree
  layout. `overlay/README.md` is the only overlay file that is never copied
  into the materialized tree.
- Update the pin only through `upstream.json`. The tag and the commit SHA in
  that file must always agree, and the SHA must be the commit the tag points
  to upstream.
- Track the upstream v1.x.x line only. Never advance the pin to a v2.x.x tag,
  a pre-release, or a draft release through automation or by hand under this
  plan.

## The Branding Rule

The OpenCode binary and brand are never modified.

- Never patch or overlay a binary name, product name, package name, icon,
  logo, or favicon.
- Never rename a built artifact. Release assets use the upstream CLI asset
  names exactly.
- `scripts/verify-branding.sh` enforces this rule on every materialized tree.
  A change that makes the guard fail is rejected, and weakening the guard to
  accept such a change is prohibited.

## Automation Rules

- The upstream check runs every six hours through
  `.github/workflows/check-upstream.yml`. Do not change the cadence without a
  plan amendment.
- A validated upstream update is auto-merged by the workflow as a direct
  commit to `main`. Do not introduce a manual approval step for routine
  upstream updates.
- Every GitHub Release carries the exact upstream tag as its tag and title.
  Do not add suffixes, prefixes, or a separate Openick version sequence.
- Releases are immutable once published. A correction ships with the next
  upstream version.
- Automation uses the default `GITHUB_TOKEN` with the permissions declared in
  each workflow and no additional secrets.

## Validation Before Merge

Run the same gates the workflows run before committing a change to the delta
or the automation:

1. `./scripts/materialize.sh` completes against the pinned tag.
2. `./scripts/verify-branding.sh` passes on the materialized tree.
3. Shell scripts pass `bash -n` and workflow files parse as valid YAML.
4. Documentation touched by the change agrees with the governing plan.

## Atomic Commits

Every commit in this repository is atomic: the smallest complete unit of
change, carrying one logical concern, independently understandable and
independently revertible. Commit small and often, as each unit of work is
completed; never accumulate unrelated changes into one large commit.

- One commit, one logical change: one patch, one script, one workflow, one
  document, one pin advancement, one fix. If a change needs more than one
  Conventional Commits subject line to describe it, split it before
  committing.
- Never mix categories in one commit. Feature work, refactoring, formatting,
  documentation, and plan corrections are separate commits. A plan correction
  that belongs to a fix is its own commit immediately beside the fix commit
  in the same series.
- Every commit leaves the repository consistent: documentation agrees with
  code, shell scripts pass `bash -n`, and workflow files parse as valid YAML.
- Subjects use Conventional Commits in English, for example
  `feat(scripts): add upstream release detection` or
  `chore(upstream): sync to OpenCode v1.19.5`. The body states why the change
  exists and names the active role.
- The automated synchronization commit modifies `upstream.json` and no other
  file.
- History on `main` is append-only. Correct a mistake with a new atomic fix
  or revert commit. Never force-push `main`.
- A commit that fails a validation gate is never pushed; fix it forward with
  a new atomic commit.
