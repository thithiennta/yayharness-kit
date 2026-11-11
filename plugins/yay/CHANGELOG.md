# yay kit changelog

`/yay:harness-update` reads this file to tell a repo what changed between its recorded kit version and the installed one. Each entry lists new skills, config keys, template changes and behavior changes.

## 0.2.0
- **Browser tests: `/yay:e2e-setup` and `/yay:e2e`.** Playwright against a wp-env site, one per checkout. Each worktree gets its own port, so parallel branches never share a database. `yayh e2e status|detect|scaffold|port|url|env|run|specs|cli`. `yayh e2e scaffold` writes the starter `tests/e2e/` package (config, seed script, admin and customer logins, `wp()` WP-CLI fixture, smoke spec) and `.github/workflows/e2e.yml`. It only fills gaps, and it adopts an existing Playwright setup. New config keys: `e2e.dir`, `e2e.port`, `e2e.baseUrl`, `e2e.wpEnvArgs`, `commands.e2e`, `e2e-install`, `e2e-start`, `e2e-stop`, `e2e-reset`. Contract: `reference/e2e.md`.
- **Targeted e2e in the flow:** plans gain an `**E2E:**` line (browser-only flows, usually none; `yayh plan check` warns when it's missing in a repo with e2e). `/yay:implement` writes and runs specs tagged `@P-<n>` (Finish step 2; the later Finish steps are renumbered). `/yay:fix` writes an `@B-<n>` regression spec only for UI-only bugs, fail-first. `/yay:release` runs the full suite in preflight: a product bug blocks, flakes don't. A new workflow rule says so, and a new knowledge doc, `docs/knowledge/e2e.md`, holds the details.
Code quality (reuse existing code, leave comments alone) and less blocking (ask less).
- **Ask less, block less:**
  - **At most one question round of 1–3 questions, and only the hardest ones:** decisions that are expensive to undo, or that only the user can make. Claude decides everything else and lists it under **Decided** in the report, PR or artifact, so the user can overrule it. Open, non-blocking points go in the artifact for the next checkpoint.
  - **No standalone confirmations:** no "mark it ready?" (plan check passing means ready), no version confirmation (only a major bump or a conflict is asked), no "proceed with the draft?", no approval step before writing the roadmap, and no end-of-run "push?". Work is committed locally, and the report ends with the push and PR commands, unless `--pr` was given.
  - Deletes, overwrites, live-site writes, pushes and tags still need a yes.
  - The rules are in `reference/asking.md`, which the SessionStart hook loads next to the code rules.
- **Code rules for every session:** the SessionStart hook loads `reference/code-rules.md` into every yay repo session. It covers searching before creating, calling existing helpers, small diffs, and a WPCS-compatible comment policy: docblocks yes; no new, grown or reworded comments; nothing explaining other files; no change-log comments. The rules ship with the plugin, so `/yay:harness-update` isn't needed.
- **Plans:** each plan task has a `Reuse:` line (`yayh plan check` warns when it's missing, or when `none` has no reason). `/yay:plan`'s self-review looks for re-implementations.
- **`yayh code find|similar|index|new`:** a search over PHP and JS/TS classes, functions, methods and consts, matching names and docblock summaries.
- **Knowledge:** a new core doc, `docs/knowledge/helpers.md` (the reuse map), written by `/yay:knowledge-init` and kept current by `/yay:knowledge-update`. The project block's "Read when" points at it before adding any function.
- **`yayh review diff [base] [--plan=P-n]`:** flag-only findings. Kinds: `similar-exists`, `comment-edited`, `comment-grown`, `comment-heavy`, `comment-elsewhere`, `comment-changelog`, `docblock-prose`, `outside-plan`.
- **`yay:code-reviewer` agent:** a read-only reviewer for reuse and comments. `/yay:implement` (step 4.4, `--no-review` to skip) and `/yay:fix` run it before the PR. Each finding is fixed, or answered in the PR's new "Reuse and comments review" section.
- **PostToolUse hint hook (`hint-edit.sh`):** after an edit, a non-blocking note when a new function looks like an existing one, an edit only changes comments, existing comment lines were rewritten, or several inline comments were added.
- **Fix:** `yayh plan check` read an unticked task's ID as `]`.

## 0.1.0
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
- `/yay:roadmap`: plan or re-plan dated sprints against capacity and freeze windows, `--status` (read-only progress, slipped items, open bugs, status drift), quick `--add`/`--move`/`--drop`, `--multi-agent` portfolio co-planning (`workflows/roadmap-portfolio.js`, one owner agent per plugin), and `--publish` as a private page.
  - `yayh roadmap list|get|set|add|move|sprints|current|check|status|links|peers`.
  - `/yay:implement` and `/yay:release` set item status through `yayh roadmap set`. The `roadmap` commit scope is always allowed.
- Hardening:
  - skill descriptions lead with their trigger phrases and stay under 420 characters, so the skill listing never cuts them off
  - `yayh … --help` anywhere prints usage and changes nothing, and artifact or roadmap titles that look like options are rejected
  - `/yay:release` runs `commands.test` first (lint only warns), and a hotfix release tags locally without asking
  - an eval suite in `evals/` (5 cases with a no-plugin baseline)
  - `ONBOARDING.md` for the team
- Reliability: no `| head` or `| grep -q` pipes anywhere (a lint test enforces it), because they fail under `pipefail`. The PHP engine now prints nothing for empty arrays.
- Hooks: they block edits to generated and kit-owned files, commits on the base branch, `--no-verify`, `yay:debug` leftovers, and tags made outside `/yay:release`; they check commit messages and branch names; at session start they flag a harness older than the kit.
