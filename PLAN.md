# yayharness build plan

13 skills, all `/yay:*`. `⟵` marks a dependency. A box gets ticked when the task's tests pass.

## Decisions
- Distribution: plugin `yay` in this marketplace. Local only for now.
- `harness-init` hard-wipes the old harness, including all of `docs/`, on a branch, after you confirm the list.
- Fresh design. Tracking lives in in-repo markdown.
- Each repo declares its commands in `.yay/config.json` and the kit runs them. JSON, so hooks need no YAML parser.
- Soft-gated workflow plus enforced git conventions.
- Changelog goes to `readme.txt`, is built from conventional commits and PRs, and comes with customer-facing release notes.
- Integrations: a worktree per task, and a multi-agent roadmap.
- `harness-update` re-syncs kit-owned files only. Knowledge has its own init and update skills.
- The helper CLI is `yayh`, because a plugin's `bin/` comes after the user's PATH and `yay` may already exist there (the Arch Linux AUR helper).
- Teammates run `claude plugin install` once. `enabledPlugins` alone doesn't install the plugin.
- `.claude/settings.json` is generated from the kit template deep-merged with `.yay/settings.extra.json`. A hook blocks hand edits to it.
- Kit commits always allow the scopes `harness`, `release`, `changelog` and `knowledge`. Skills stage with `yayh harness files`, never `git add -A`.
- Branches stay `<type>/<slug>` with no owner prefix. PRs are assigned to their owner (`gh pr create --assignee @me`). implement, fix and release follow this.

## P0 Foundations ✅
- [x] T0.1 Repo scaffold: marketplace and plugin manifests, layout
- [x] T0.2 Contracts: `reference/config.md` + `config.schema.json`, `artifacts.md`, `ownership.md`, `git-conventions.md`
- [x] T0.3 `lib/` + `bin/yayh`: config, front-matter, IDs, manifest, git, worktrees ⟵ T0.2
- [x] T0.4 Fixtures (`tests/fixtures/build.sh`: legacy-rich, legacy-notibar, legacy-currency, bare) and the test runner ⟵ T0.1

## P1 Harness lifecycle ✅ ⟵ P0
- [x] T1.1 Stack detection and old-harness inventory (`yayh harness detect|inventory`). Detection checked read-only on 8 real plugins.
- [x] T1.2 `/yay:harness-init`: wipe, set up files, write config ⟵ T1.1. A headless run on the legacy-rich fixture passed.
- [x] T1.3 Hooks: edit guard (generated paths, kit files, the managed block of CLAUDE.md), commit guard (base branch, `--no-verify`, `yay:debug`, tags), post-commit message and branch check, session-start version notice ⟵ T0.3
- [x] T1.4 `/yay:harness-update`: manifest re-sync with `--check`, `--diff`, `--force` and `--only`. The kit version is stamped only when nothing is left unresolved ⟵ T1.2. A headless run with simulated drift passed.

## P2 Knowledge ✅ ⟵ P1
- [x] T2.1 `/yay:knowledge-init`: the `yay:knowledge-scout` agent runs in parallel per area; `yayh knowledge check|stamp`; writing guide in `reference/knowledge.md`. Headless run on a YayReturns clone: 9 docs, the check passes, a 60-line block.
- [x] T2.2 `/yay:knowledge-update` ⟵ T2.1: `yayh knowledge stale` gives stale, fresh, never, bad-ref and uncovered per doc.
- Fixed from the real run: the debug-marker hook matched the kit's own text (only comment-form markers in non-markdown files count now); `--keep=` became a CLI option, not an env var; the skill now spells out that a hard wipe means no self-chosen restores.

## P3 Dev workflow ✅ ⟵ T0.2, P2
- [x] T3.1 `/yay:brainstorm`
- [x] T3.2 `/yay:plan`, with `--check` and `yayh plan check` ⟵ T3.1
- [x] T3.3 `/yay:implement` ⟵ T3.2, T1.3
- [x] T3.4 `/yay:debug`, with the `yay:hypothesis-checker` agent ⟵ T0.2, P2
- [x] T3.5 `/yay:fix`, including `--hotfix` from the last tag ⟵ T3.4, T3.3
- Headless run on the YayReturns clone with a planted off-by-one (`>=` in `WithdrawalDeadline::is_past()`):
  - debug found the commit, the line and all 5 places it surfaces, and proved it with `php -r` at both commits;
  - fix confirmed the tests failed before and passed after (57 tests);
  - brainstorm, plan and implement produced 7 commits with `Plan:` trailers, passed lint, typecheck and both builds, and reported the planted bug as pre-existing instead of fixing it on the feature branch.
  - Fixed from the run: knowledge check no longer flags external template paths, and `yayh run` uses `.nvmrc` through nvm.

## P4 Ship ⟵ T0.2, T3.3 (runs in parallel with P5)
- [ ] T4.1 `/yay:changelog`
- [ ] T4.2 `/yay:build`
- [ ] T4.3 `/yay:release` ⟵ T4.1, T4.2, T3.5

## P5 Roadmap ⟵ T3.1, T3.2
- [ ] T5.1 `/yay:roadmap` for a single repo
- [ ] T5.2 `--multi-agent` and `--publish` ⟵ T5.1

## P6 Hardening ⟵ all
- [ ] T6.1 Audit all 13 skills' hints and descriptions
- [ ] T6.2 `claude plugin eval` suites
- [ ] T6.3 End-to-end fixture run, including debug → fix → hotfix release
- [ ] T6.4 Team onboarding README
