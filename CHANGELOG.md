# Changelog

## 2026-02-16

- Removed project overrides system (SKILL.md sections, `add_project_overrides.rb` script, docs).
- Added CI release workflow (`skills-release.yml`) — skills are automatically bumped, tagged, and released on merge to main.
- Relaxed `metadata.version` audit requirement — CI bootstraps missing versions to build 1.

## 2026-02-13

- Switched to per-skill build IDs and removed global catalog versioning.
- Updated release flow to bump and tag a single skill build at a time.
