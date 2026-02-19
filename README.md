# Ravn AI Toolkit

A la carte AI skills for LLM-assisted development across platforms.

## Quick Start

```bash
# Add a skill (latest build)
npx skills add ravnhq/ai-toolkit -s core-coding-standards

# List available skills
npx skills add ravnhq/ai-toolkit -l

# Update installed skills
npx skills update
```

## Versioning

Skills use per-skill build IDs (positive integers). The catalog has no global version.

```bash
# Latest (default)
npx skills add ravnhq/ai-toolkit -s core-coding-standards

# Pin to a specific build
npx skills add https://github.com/ravnhq/ai-toolkit/tree/skill-core-coding-standards-b12 -s core-coding-standards
```

## Auto-Updates

- `npx skills update` upgrades each installed skill to its latest build unless pinned.

## Catalog

See `marketplace.json` for the full catalog. Drafts live in `skills/_drafts/`.

## Docs

- `docs/skill-versioning.md`
- `scripts/skills_audit.rb`
- `scripts/skills_harness.rb`

## Help

- Check `docs/skill-versioning.md` first.
- Run `ruby scripts/skills_audit.rb` and `ruby scripts/skills_harness.rb` to diagnose issues.
- Open an issue in the repo with repro steps and relevant logs.

## Contributing

1. Create or edit a skill in `skills/<name>/`.
2. Open a PR to `main`.

CI handles the rest: validation, `marketplace.json` sync, build bumps, and release tags all run automatically on merge.
