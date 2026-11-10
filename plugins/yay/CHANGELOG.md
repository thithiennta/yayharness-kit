# yay kit changelog

`/yay:harness-update` reads this file to tell a repo what changed between its recorded kit version and the installed one. Each entry lists new skills, config keys, template changes and behavior changes.

## 0.1.0 (unreleased)
- First version: `/yay:harness-init` and `/yay:harness-update`.
- `yayh` helper CLI: config, IDs, slugs, front-matter, manifest, git, harness.
- Kit files: the managed CLAUDE.md block, `.claude/rules/yay-{workflow,git,wordpress}.md`, `.claude/settings.json` (merged with `.yay/settings.extra.json`), the PR template, the docs skeleton, and `.gitignore` entries.
- Git conventions: `<type>/<slug>` branches with no owner prefix. PRs are assigned to their owner.
- `/yay:knowledge-init` and `/yay:knowledge-update` write and maintain the CLAUDE.md project block and `docs/knowledge/`. The `yay:knowledge-scout` agent explores areas in parallel. `yayh knowledge check|stale|stamp` keeps the docs verifiable: paths and links must exist, there's a 90-line budget for the block, and drift is tracked through `covers` and `updated_ref`.
- Hooks: they block edits to generated and kit-owned files, commits on the base branch, `--no-verify`, `yay:debug` leftovers, and tags made outside `/yay:release`; they check commit messages and branch names; at session start they flag a harness older than the kit.
