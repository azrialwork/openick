# Overlay

This directory holds the overlay half of the Openick delta. Patches live in
`patches/`; the rules for both halves are defined in
`docs/plan/0001-openick-delta-repository.md` and `AGENTS.md`.

## Rules

- Overlay files mirror the upstream tree layout. The file
  `overlay/packages/opencode/src/example.ts` is copied to
  `packages/opencode/src/example.ts` in the materialized tree.
- Overlay application runs after patch application and replaces whole files.
- This `README.md` is the only overlay file that is never copied into the
  materialized tree.
- An overlay file never carries a binary name, a product name, a package
  name, an icon, a logo, or a favicon. `scripts/verify-branding.sh` enforces
  this rule on every materialized tree.

## Current State

The overlay carries one file, defined in
`docs/plan/0002-android-arm64-build.md`:

- `patches/@opentui%2Fcore@0.4.5.patch` is copied into the materialized
  tree's own `patches/` directory, where Bun applies it to the published
  `@opentui/core` 0.4.5 package on every install. It teaches the OpenTUI
  native asset loader the `android-arm64` target.
