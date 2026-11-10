# yay kit changelog

`/yay:harness-update` reads this file to tell a repo what changed between its recorded kit version and the installed one. Each entry lists new skills, config keys, template changes and behavior changes.

## 0.1.0 (unreleased)
- First version: `/yay:harness-init` and `/yay:harness-update`.
- `yayh` helper CLI: config, IDs, slugs, front-matter, manifest, git, harness.
- Kit files: the managed CLAUDE.md block, `.claude/rules/yay-{workflow,git,wordpress}.md`, `.claude/settings.json` (merged with `.yay/settings.extra.json`), the PR template, the docs skeleton, and `.gitignore` entries.
- Git conventions: `<type>/<slug>` branches with no owner prefix. PRs are assigned to their owner.
- `/yay:knowledge-init` and `/yay:knowledge-update` write and maintain the CLAUDE.md project block and `docs/knowledge/`. The `yay:knowledge-scout` agent explores areas in parallel. `yayh knowledge check|stale|stamp` keeps the docs verifiable: paths and links must exist, there's a 90-line budget for the block, and drift is tracked through `covers` and `updated_ref`.
- `/yay:brainstorm`, `/yay:plan`, `/yay:implement`, `/yay:debug` and `/yay:fix`. New artifacts are created untracked and carried into the work's worktree (`yayh artifact new|resolve|list|carry`, `yayh plan tasks|tick|check`, `yayh id conflicts`). The `yay:hypothesis-checker` agent checks bug hypotheses in parallel. `yayh run <command>` honours `.nvmrc`, and `yayh debug markers` finds leftover instrumentation.
- Config: per-developer `.yay/local.json` (gitignored) overrides the shared config. `site.wpPath` is derived when the repo sits in `wp-content/plugins/`. `id next` also counts IDs on the base branch.
- `/yay:changelog`, `/yay:build` and `/yay:release` (prepare, `--tag-only`, `--hotfix`).
  - `yayh version current|list|check|set|tested`.
  - `yayh changelog collect|suggest|baseline|style|write|entry`. The baseline is the last tag, a release commit, or the version's first appearance, in which case the skill asks.
  - `yayh build zip|check`: one top folder, dev files, per-edition `package.forbidden`, version and Stable tag, `php -l`, repo `checks`.
  - `package.output` may map editions to globs.
  - `config validate` rejects edition-keyed maps that use unknown editions.
  - `yayh git merged-worktrees`.
- Reliability: no `| head` or `| grep -q` pipes anywhere (a lint test enforces it), because they fail under `pipefail`. The PHP engine now prints nothing for empty arrays.
- Hooks: they block edits to generated and kit-owned files, commits on the base branch, `--no-verify`, `yay:debug` leftovers, and tags made outside `/yay:release`; they check commit messages and branch names; at session start they flag a harness older than the kit.
