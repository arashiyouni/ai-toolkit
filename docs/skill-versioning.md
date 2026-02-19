# Skill Versioning

## Overview

Skills use per-skill build IDs (positive integers). There is no global catalog version. Each skill tracks its own build independently in `SKILL.md` metadata and in `marketplace.json`.

## Build IDs

- Stored in `skills/<name>/SKILL.md` under `metadata.version`.
- Mirrored in `marketplace.json` for each skill entry.
- Incremented per skill when that skill changes.

## Release Tags

Per-skill releases use tags in the format:

`skill-<name>-b<build>`

Example: `skill-core-coding-standards-b12`.

## Auto Updates

- `npx skills update` upgrades each installed skill to the latest build.
- Pinned installs stay on their pinned tag until you change them.
- Builds are per skill, so only skills that changed get new build IDs.

## Pinning

- Use tag pinning for reproducibility: `skill-<name>-b<build>`.
- Pin when you need stable behavior, then upgrade intentionally.

## CI Release

Releases are automated via GitHub Actions (`.github/workflows/skills-release.yml`).

When a push to `main` changes files under `skills/*/`:

1. CI detects which skills changed.
2. For each changed skill, increments `metadata.version` in SKILL.md and `marketplace.json`.
3. Commits the bump, creates per-skill tags (`skill-<name>-b<build>`), and pushes.

Contributors do not need to bump versions or create tags. `scripts/release.sh` is available for manual releases outside the normal PR flow.

## Marketplace

`marketplace.json` only tracks per-skill build IDs. It does not contain a global version field.
