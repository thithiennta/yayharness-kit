# yayharness build plan

17 skills, all `/yay:*`. `⟵` marks a dependency. A box gets ticked when the task's tests pass.

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

## P4 Ship ✅ ⟵ T0.2, T3.3
- [x] T4.1 `/yay:changelog`: copies the readme's own style (heading, bullet marker, labels) and writes customer-facing notes to `docs/releases/`
- [x] T4.2 `/yay:build`: per-edition package and `yayh build check`
- [x] T4.3 `/yay:release`: prepare, `--tag-only` and `--hotfix`; ties off `fixed_in`, `shipped:` and plan status; tags only with `YAY_RELEASE=1` ⟵ T4.1, T4.2, T3.5
- Headless run on the YayReturns clone: release 1.1.0 from the merged P-1 and B-1 work.
  - The changelog has one customer line. It correctly left out the bug that was introduced and fixed between releases, and still set `fixed_in`.
  - Pro and Lite zips: 6/6 PASS each.
  - `--tag-only` tagged after the simulated merge and rebuilt from the tag.
  - Fixed from the run:
    - `package.output` can be an edition map
    - the baseline handles repos without tags (asks when ambiguous)
    - `package.forbidden` follows edition names, and validate guards it
    - merged-worktree cleanup
    - the PHP engine printed `[]` for an empty array, which made "[]" run as a check

## P5 Roadmap ✅ ⟵ T3.1, T3.2
- [x] T5.1 `/yay:roadmap` for a single repo
- [x] T5.2 `--multi-agent` and `--publish` ⟵ T5.1 (workflow script ready; a live multi-plugin run waits for the pilot choice)

## P6 Hardening ✅ ⟵ all
- [x] T6.1 Audit all 13 skills' hints and descriptions
- [x] T6.2 `claude plugin eval` suites
- [x] T6.3 End-to-end fixture run, including debug → fix → hotfix release
- [x] T6.4 Team onboarding README

## P7 Code quality ✅ ⟵ P6
Goal: generated code reuses existing functions instead of re-implementing them, and doesn't add, grow or reword comments needlessly (WPCS docblocks are still required). Findings are flagged, never blocking.
- [x] T7.1 Baseline evals: reuse, comment discipline (the "show in menu" settings case), unrelated comments untouched
- [x] T7.2 Code rule delivered by the SessionStart hook (current in every yay repo, no sync needed) ⟵ T7.1
- [x] T7.3 `Reuse:` line per plan task, `yayh plan check` warns ⟵ T7.2
- [x] T7.4 `yayh code find` symbol search + `docs/knowledge/helpers.md` index ⟵ T7.2
- [x] T7.5 `yayh review diff`: new functions vs similar existing, comment churn, out-of-plan files ⟵ T7.4
- [x] T7.6 `yay:code-reviewer` agent before the PR in implement and fix ⟵ T7.5
- [x] T7.7 Edit-time hook hints (similar function exists, comment-only edit) ⟵ T7.5
- [x] T7.8 Re-run evals vs baseline, kit 0.2.0 ⟵ all

## P8 E2E ✅ ⟵ P7
Goal: browser tests the flow uses in a targeted way. A plan names the 0–2 flows that only a browser can prove; implement and fix write specs for those, tagged with their artifact, and release runs the whole suite. Decided by the user: targeted (not "run only", not "separate").
- [x] T8.1 `lib/e2e.sh` + `yayh e2e status|detect|scaffold|port|url|env|run|specs|cli`: one wp-env site per checkout (base port from the slug, worktree ports from the path)
- [x] T8.2 `templates/e2e/` starter (Playwright, wp-env with the repo mapped as the plugin folder, a repeatable seed, admin and customer logins, `wp()` fixture, smoke spec, CI workflow) ⟵ T8.1
- [x] T8.3 `reference/e2e.md`, `/yay:e2e-init` (scaffold or adopt; replaced `/yay:e2e-setup`, see T8.6), `/yay:e2e` (write, run, triage) ⟵ T8.2
- [x] T8.4 Plan `**E2E:**` line + plan-check warning; implement, fix and release steps; workflow rule; `e2e.md` knowledge doc ⟵ T8.3
- [x] T8.5 Unit tests (`test_e2e.sh`), plus a real run on a throwaway Woo plugin: install, wp-env + WooCommerce, seed, 4/4 smoke ⟵ all
- [x] T8.6 `/yay:e2e-init` replaces `/yay:e2e-setup`: `yayh e2e surfaces`, `yay:e2e-scout` agents, a Flows table in `docs/knowledge/e2e.md`, baseline specs for critical browser-only flows (pass twice, fail when the precondition breaks; bugs become `B-<n>` with `test.fail`); plan, e2e and fix read the map ⟵ T8.5
- Not yet run live: a worktree's own port (`WP_ENV_PORT`) side by side with the main site, adopting YayWholesale's existing setup, the CI workflow on GitHub.

## P10 Parked decisions and later work ✅ ⟵ P9
Goal: a decision that can't be made while planning or building, or work that should wait, is written down instead of stopping the run or getting lost. The next step that works on the same plan picks it up again and updates the plan.
- [x] T10.1 Backlog `kind: idea|decision|deferred` with `from`, `affects`, `default`, `decision`, `settled`; `yayh backlog open [--for=<ID>] [--kind=]` (plan ↔ roadmap item ↔ source, every worktree) and `yayh backlog settle`; `yayh plan check` warns about open notes
- [x] T10.2 Plan, implement, fix and autopilot (skill and workflow) write notes rather than stopping, and pick them up before working on a plan; roadmap reads deferred notes; workflow rule, asking rules, PR template, artifacts contract
- [x] T10.3 Unit tests (`test_backlog.sh`)
- Not yet run live: an autopilot run where a sheet answer settles a tracked note through a `Settles:` line.

## P9 Tests: unit, integration, JS, and a layer per task ✅ ⟵ P8
- [x] T9.1 `lib/tests.sh` + `yayh test status|detect|scaffold|run|list`: PHPUnit + Brain Monkey unit, the WP/Woo test suite in wp-env's tests site (its own DB; the dev site's would be wiped), JS runner by package.json
- [x] T9.2 `templates/tests/` (unit/integration configs, bootstraps, `TestCase`, smoke tests, Vitest config, CI) ⟵ T9.1
- [x] T9.3 `reference/testing.md` (the ladder), `/yay:test-init` (scout, scaffold or adopt, baseline tests, Coverage table), `/yay:test`, `yay:test-scout` ⟵ T9.2
- [x] T9.4 Plan `**Tests:**` items carry a layer (+ plan-check warning), implement/fix/debug/release/workflow rule use the ladder ⟵ T9.3
- [x] T9.5 Unit tests (`test_tests.sh`), plus a live run on the throwaway Woo plugin: unit 3/3, integration 3/3 (WooCommerce product price through the plugin's filter), js 1/1, a broken unit fails, and the e2e site's data and smoke survive the integration run ⟵ all
