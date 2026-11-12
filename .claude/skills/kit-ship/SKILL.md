---
name: kit-ship
description: Ship a change to the yay kit itself (this repo, not a plugin repo) from working tree to merged main in one go - branch, CHANGELOG entry, tests (skipped when a green run already covers the code), validate, conventional commit, PR, merge, pull. Use when the user says "ship this", "commit and merge", "kit-ship", "push it to main", "open and merge the PR" while working on the kit.
argument-hint: "[type(scope): summary] [--no-merge] [--draft]"
---

# /kit-ship

Arguments: `$ARGUMENTS`

Ships what is in the kit repo's working tree (or already committed on a work branch) to `main`, without stopping. Plugin repos have their own flow (`/yay:implement`, `/yay:fix`); this skill is only for `~/yayharness`. To release a version afterwards, use `/kit-release`.

Run every command from the repo root (`git rev-parse --show-toplevel`).

## 1. What ships

- `git status --porcelain` and, on a work branch, `git log --oneline main..HEAD`. Nothing uncommitted and no commits ahead of `main`: say there's nothing to ship and stop.
- Read the diff (`git diff`, plus untracked files) so the commit message and PR describe it. Leave out anything that isn't part of the change: `.DS_Store`, editor files, `tests/.times`, `tests/.passed`, `plugins/yay/evals/results/`. Something that looks unrelated (a second change mixed in): ship only the part matching the arguments or the main change, and name the rest in the report as left uncommitted.
- **Header.** From the arguments when given, otherwise write one: `type(scope): summary` per `plugins/yay/reference/git-conventions.md` (imperative, lowercase, no period, at most 72 characters). Scope `harness` for kit code and skills, `roadmap` for `ROADMAP.md`/`PLAN.md`, `release` for release tooling. `!` for a change that breaks existing plugin repos (a config key renamed, a managed file moved).

## 2. Branch

On `main`: `git switch -c <type>/<slug>`. The slug is the summary in kebab case, at most 5 words. Already on a work branch: stay on it, unless it's already merged (`git merge-base --is-ancestor HEAD origin/main` after `git fetch origin`): then `git switch -c <type>/<slug> origin/main`, which keeps the uncommitted changes. Never commit on `main`.

## 3. CHANGELOG

`plugins/yay/CHANGELOG.md` is what `/yay:harness-update` shows plugin repos, so every change they would notice gets an entry: a skill, agent, hook, `yayh` command, template, config key or behaviour. Docs about the kit's own planning (`ROADMAP.md`, `PLAN.md`), tests only and repo chores don't.

- The top section must be `## Unreleased (<next>)`. When it isn't there, add it above the last release: `<next>` is the last released version (`plugins/yay/.claude-plugin/plugin.json`) bumped **minor** for a `feat` or a `!`, **patch** otherwise. A later `feat` raises an existing patch heading to the minor.
- Add one bullet in the style of the entries below it: **bold what changed**, then what a plugin repo sees and needs to do (for example "Run `/yay:harness-update` to pick up the rule."). Sub-bullets for details.

## 4. Checks

1. **Tests.** `./tests/run.sh --tested`. Exit 0 means a green full run already tested the kit code exactly as it is now (a skill, doc or changelog change doesn't change that code): skip, and keep the `tested …` line for the PR. Otherwise run `./tests/run.sh` (the full suite: every file on the first engine, the JSON-backend files on every engine; it stamps `tests/.passed` when green). It takes about a minute and a half. Any failure stops the ship. Show the FAIL lines and fix them only if the fix is plainly part of this change, then run again; otherwise stop and report.
2. **Manifests.** `claude plugin validate .` and `claude plugin validate plugins/yay`. An error stops the ship.
3. **Skill size.** A `SKILL.md` that this change grew past 150 lines: mention it in the PR under **Not verified** (ROADMAP R-8 is shrinking them). It doesn't block.

## 5. Commit

Stage by path, never `git add -A` or `git add .`. Commit with the header and a body of 2-5 `- ` bullets: what changed and why, wrapped at 72 columns, in the style of `git log -5 --format=%B`. End it with the attribution trailer your session settings give, if any.

## 6. PR and merge

1. `git push -u origin <branch>`.
2. `gh pr create --base main --head <branch> --assignee @me --title "<header>" [--draft] --body-file <file>` with the sections the kit's PRs use:
   - `## Summary`: one or two sentences.
   - `## Changes`: the bullets, with file paths.
   - `## Not verified`: what no check proved (a skill's wording isn't covered by unit tests: say so when skills changed). Tests: either "Full suite: passed" or "Skipped: `<tested line>`".
   - `## How to test`: the commands, for example `claude plugin marketplace update yayharness`, then the skill or `yayh` command to try.
3. Unless `--no-merge` or `--draft`: `gh pr merge <n> --merge`. Keep the remote branch (the kit has kept them so far). A merge that fails (conflict, a required check): stop and report the PR URL with the reason. Never force-push or rebase `main`.
4. **Update `main`** where it's checked out (`git worktree list`). In this checkout: `git switch main && git pull --ff-only`. In another one (you shipped from a worktree, and git won't switch to a branch checked out elsewhere): `git -C <that path> pull --ff-only` when its tree is clean; otherwise leave it and say it's behind. A worktree under `.claude/worktrees/` whose branch is now merged: name `git worktree remove <path>` in the report, since the session may be running inside it.

## 7. Report

The header, the PR URL and whether it merged, the tests line (run and passed, or skipped and why), the validate results, the CHANGELOG entry (or why there isn't one), and anything left uncommitted. **Next:** `/kit-release` when `## Unreleased` holds what should go out, otherwise nothing.

## Don'ts

- Never commit on `main`, never `--no-verify`, never stage with `-A`.
- Never skip the full suite because of `--quick` or `--changed`: only a `--tested` hit skips it.
- Never merge a PR whose test run failed.
